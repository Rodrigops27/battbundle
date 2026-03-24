function sweepResults = sweepInitSocStudy(socRangePercent, socStepPercent, cfg)
% sweepInitSocStudy Sweep ESC-estimator initial SOC over a configurable range.
%
% Usage:
%   results = sweepInitSocStudy()
%   results = sweepInitSocStudy([45 80], 2)
%   results = sweepInitSocStudy([45 80], 2, cfg)
%
% Inputs:
%   socRangePercent  Two-element [start end] range in percent. Default [0 100].
%   socStepPercent   Sweep step in percent. Default 10.
%   cfg              Optional struct. Useful fields:
%                      tc, ts, dataset_mode, SweepSummaryfigs,
%                      PlotSocEstimationfigs, PlotVoltageEstimationfigs,
%                      esc_dataset_file, rom_dataset_file, raw_bus_file,
%                      esc_model_file, estimator_names, SaveResults,
%                      results_file, tuning, parallel
%
% Output:
%   sweepResults     Struct with sweep settings, RMSE tables, and run results.

clear iterEKF iterESCSPKF iterESCEKF iterEaEKF iterEacrSPKF iterEnacrSPKF;
clear iterEDUKF iterEsSPKF iterEbSPKF iterEBiSPKF;

if nargin < 1 || isempty(socRangePercent)
    socRangePercent = [0 100];
end
if nargin < 2 || isempty(socStepPercent)
    socStepPercent = 10;
end
if nargin < 3 || isempty(cfg)
    cfg = struct();
end

if ~isdeployed
    here = fileparts(which(mfilename));
    if isempty(here)
        here = fileparts(mfilename('fullpath'));
    end
    if isempty(here)
        here = pwd;
    end
    cd(here);
end

repo_root = fileparts(fileparts(here));
addpath(genpath(repo_root));

cfg = normalizeStudyConfig(cfg, repo_root);
soc0_sweep_percent = buildSocSweep(socRangePercent, socStepPercent);
[use_parallel, parallel_message] = resolveParallelMode(cfg.parallel);

esc_src = load(cfg.esc_model_file);
rom_model = [];
if any(strcmp(cfg.estimator_names, 'ROM-EKF'))
    if isempty(cfg.rom_file)
        error('sweepInitSocStudy:MissingROMFile', ...
            'ROM-EKF was selected but no ROM model file was found.');
    end
    rom_src = load(cfg.rom_file);
    if ~isfield(rom_src, 'ROM')
        error('sweepInitSocStudy:BadROMFile', 'Expected variable "ROM" in %s.', cfg.rom_file);
    end
    rom_model = rom_src.ROM;
end
nmc30_esc = extractEscModelStruct(esc_src);
evalDataset = buildEvalDataset(cfg, nmc30_esc);

flags = struct();
flags.SOCfigs = false;
flags.Vfigs = false;
flags.Summaryfigs = false;
flags.InnovationACFPACFfigs = false;
flags.R0figs = false;
flags.Biasfigs = false;
flags.default_temperature_c = cfg.tc;
flags.Verbose = false;

estimator_names = cfg.estimator_names(:).';
n_estimators = numel(estimator_names);
n_sweeps = numel(soc0_sweep_percent);

soc_rmse = NaN(n_sweeps, n_estimators);
voltage_rmse = NaN(n_sweeps, n_estimators);
all_results = cell(n_sweeps, 1);

if ~isempty(parallel_message)
    fprintf('%s\n', parallel_message);
elseif use_parallel
    fprintf('Initial-SOC sweep parallel execution enabled.\n');
end

if use_parallel
    parfor sweep_idx = 1:n_sweeps
        [run_results, soc_rmse_row, voltage_rmse_row] = evaluateSweepPoint( ...
            soc0_sweep_percent(sweep_idx), cfg, nmc30_esc, rom_model, estimator_names, evalDataset, flags);
        all_results{sweep_idx} = run_results;
        soc_rmse(sweep_idx, :) = soc_rmse_row;
        voltage_rmse(sweep_idx, :) = voltage_rmse_row;
    end
else
    for sweep_idx = 1:n_sweeps
        [run_results, soc_rmse_row, voltage_rmse_row] = evaluateSweepPoint( ...
            soc0_sweep_percent(sweep_idx), cfg, nmc30_esc, rom_model, estimator_names, evalDataset, flags);
        all_results{sweep_idx} = run_results;
        soc_rmse(sweep_idx, :) = soc_rmse_row;
        voltage_rmse(sweep_idx, :) = voltage_rmse_row;
    end
end

row_names = cellstr(compose('SOC%06.2f', soc0_sweep_percent(:)));
var_names = matlab.lang.makeValidName(estimator_names, 'ReplacementStyle', 'delete');
soc_rmse_table = array2table(soc_rmse, 'VariableNames', var_names, 'RowNames', row_names);
voltage_rmse_table = array2table(voltage_rmse, 'VariableNames', var_names, 'RowNames', row_names);

fprintf('\nInitial-SOC sweep summary (%s dataset)\n', upper(cfg.dataset_mode));
fprintf('Sweep range: %.2f%% to %.2f%% in %.2f%% steps\n', ...
    soc0_sweep_percent(1), soc0_sweep_percent(end), socStepPercent);
fprintf('SOC RMSE table [%%]\n');
disp(soc_rmse_table);
fprintf('Voltage RMSE table [mV]\n');
disp(voltage_rmse_table);

fprintf('\nAggregate summary across initial SOC sweep\n');
for est_idx = 1:n_estimators
    fprintf('  %-10s mean SOC RMSE = %.3f%%, best = %.3f%%, worst = %.3f%% | ', ...
        estimator_names{est_idx}, ...
        finiteMean(soc_rmse(:, est_idx)), ...
        finiteMin(soc_rmse(:, est_idx)), ...
        finiteMax(soc_rmse(:, est_idx)));
    fprintf('mean V RMSE = %.2f mV, best = %.2f mV, worst = %.2f mV\n', ...
        finiteMean(voltage_rmse(:, est_idx)), ...
        finiteMin(voltage_rmse(:, est_idx)), ...
        finiteMax(voltage_rmse(:, est_idx)));
end

if cfg.SweepSummaryfigs
    plotSweepRmseFigures(soc0_sweep_percent, soc_rmse, voltage_rmse, estimator_names, cfg.dataset_mode);
end
if cfg.PlotSocEstimationfigs
    plotPerEstimatorSocConvergence(all_results, soc0_sweep_percent, estimator_names);
end
if cfg.PlotVoltageEstimationfigs
    plotPerEstimatorVoltageConvergence(all_results, soc0_sweep_percent, estimator_names);
end

sweepResults = struct();
sweepResults.dataset_mode = cfg.dataset_mode;
sweepResults.soc_range_percent = [soc0_sweep_percent(1), soc0_sweep_percent(end)];
sweepResults.soc_step_percent = socStepPercent;
sweepResults.soc0_sweep_percent = soc0_sweep_percent(:);
sweepResults.estimator_names = estimator_names;
sweepResults.soc_rmse_percent = soc_rmse;
sweepResults.voltage_rmse_mv = voltage_rmse;
sweepResults.soc_rmse_table = soc_rmse_table;
sweepResults.voltage_rmse_table = voltage_rmse_table;
sweepResults.evalDataset = evalDataset;
sweepResults.all_results = all_results;
sweepResults.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
sweepResults.study_script = mfilename('fullpath');
sweepResults.config = cfg;
sweepResults.saved_results_file = '';
sweepResults.result_variable = 'sweepResults';

if cfg.SaveResults
    results_file = resolveInitSocResultsFile(cfg, here, evalDataset);
    sweepResults.saved_results_file = results_file;
    saveInitSocResults(results_file, sweepResults);
end

if nargout == 0
    assignin('base', 'initSocSweepResults', sweepResults);
end
end

function cfg = normalizeStudyConfig(cfg, repo_root)
evaluation_root = fullfile(repo_root, 'Evaluation');
tuning_defaults = defaultInitSocTuning();

cfg.tc = getCfg(cfg, 'tc', 25);
cfg.ts = getCfg(cfg, 'ts', 1);
cfg.dataset_mode = getCfg(cfg, 'dataset_mode', 'esc');
cfg.SweepSummaryfigs = getCfg(cfg, 'SweepSummaryfigs', false);
cfg.PlotSocEstimationfigs = getCfg(cfg, 'PlotSocEstimationfigs', true);
cfg.PlotVoltageEstimationfigs = getCfg(cfg, 'PlotVoltageEstimationfigs', true);
cfg.SaveResults = logical(getCfg(cfg, 'SaveResults', true));
cfg.results_file = getCfg(cfg, 'results_file', '');
cfg.parallel = mergeStructDefaults(getCfg(cfg, 'parallel', struct()), defaultParallelConfig());
cfg.esc_dataset_file = getCfg(cfg, 'esc_dataset_file', ...
    fullfile(evaluation_root, 'ESCSimData', 'datasets', 'esc_bus_coreBattery_dataset.mat'));
cfg.rom_dataset_file = getCfg(cfg, 'rom_dataset_file', ...
    fullfile(evaluation_root, 'ROMSimData', 'datasets', 'rom_bus_coreBattery_dataset.mat'));
cfg.rom_file = getCfg(cfg, 'rom_file', ...
    firstExistingFileOrEmpty({ ...
    fullfile(repo_root, 'models', 'ROM_ATL20_beta.mat')}));
cfg.raw_bus_file = getCfg(cfg, 'raw_bus_file', ...
    fullfile(evaluation_root, 'OMTLIFE8AHC-HP', 'Bus_CoreBatteryData_Data.mat'));
cfg.esc_model_file = getCfg(cfg, 'esc_model_file', ...
    firstExistingFile({ ...
    fullfile(repo_root, 'models', 'ATLmodel.mat'), ...
    fullfile(repo_root, 'ESC_Id', 'FullESCmodels', 'LFP', 'ATLmodel.mat')}, ...
    'sweepInitSocStudy:MissingESCModel', ...
    'No ATL ESC model file found.'));
cfg.estimator_names = normalizeEstimatorSelection(getCfg(cfg, 'estimator_names', defaultInitSocEstimatorNames()));
cfg.tuning = getCfg(cfg, 'tuning', tuning_defaults);
cfg.tuning_bundle = resolveEstimatorTuningBundle( ...
    cfg.tuning, cfg.estimator_names, tuning_defaults, repo_root);
end

function parallel_cfg = defaultParallelConfig()
parallel_cfg = struct( ...
    'use_parallel', false, ...
    'auto_start_pool', true, ...
    'pool_size', []);
end

function [run_results, soc_rmse_row, voltage_rmse_row] = evaluateSweepPoint( ...
        soc_init_kf, cfg, model, ROM, estimator_names, evalDataset, flags)
estimators = buildEscEstimators(soc_init_kf, cfg, model, ROM, estimator_names);
run_results = xKFeval(evalDataset, estimators, flags);
soc_rmse_row = NaN(1, numel(estimator_names));
voltage_rmse_row = NaN(1, numel(estimator_names));
for est_idx = 1:numel(estimator_names)
    soc_rmse_row(est_idx) = 100 * run_results.estimators(est_idx).rmse_soc;
    voltage_rmse_row(est_idx) = 1000 * run_results.estimators(est_idx).rmse_voltage;
end
end

function names = defaultInitSocEstimatorNames()
names = {'ESC-SPKF', 'ESC-EKF', 'EaEKF', 'EacrSPKF', 'EnacrSPKF', ...
    'EDUKF', 'EsSPKF', 'EbSPKF', 'EBiSPKF', 'Em7SPKF'};
end

function tuning = defaultInitSocTuning()
tuning = struct();
tuning.SigmaX0_rc = 1e-6;
tuning.SigmaX0_hk = 1e-6;
tuning.SigmaX0_soc = 1e-3;
tuning.sigma_w_ekf = 1e2;
tuning.sigma_v_ekf = 1e-3;
tuning.sigma_w_esc = 1e-3;
tuning.sigma_v_esc = 1e-3;
tuning.sigma_x0_rom_tail = 2e6;
tuning.SigmaR0 = 1e-6;
tuning.SigmaWR0 = 1e-16;
tuning.current_bias_var0 = 1e-5;
tuning.single_bias_process_var = 1e-8;
end

function out = mergeStructDefaults(in, defaults)
out = defaults;
names = fieldnames(in);
for idx = 1:numel(names)
    out.(names{idx}) = in.(names{idx});
end
end

function [use_parallel, message] = resolveParallelMode(parallel_cfg)
use_parallel = false;
message = '';
if ~getCfg(parallel_cfg, 'use_parallel', false)
    return;
end
if exist('gcp', 'file') ~= 2 || exist('parpool', 'file') ~= 2
    message = 'Parallel initial-SOC sweep requested but Parallel Computing Toolbox functions are unavailable. Falling back to serial execution.';
    return;
end
if ~license('test', 'Distrib_Computing_Toolbox')
    message = 'Parallel initial-SOC sweep requested but Parallel Computing Toolbox is not licensed. Falling back to serial execution.';
    return;
end

pool = gcp('nocreate');
if isempty(pool) && getCfg(parallel_cfg, 'auto_start_pool', true)
    try
        pool_size = getCfg(parallel_cfg, 'pool_size', []);
        if isempty(pool_size)
            parpool('local');
        else
            parpool('local', pool_size);
        end
    catch ME
        message = sprintf('Parallel initial-SOC sweep requested but a pool could not be started (%s). Falling back to serial execution.', ME.message);
        return;
    end
elseif isempty(pool)
    message = 'Parallel initial-SOC sweep requested but no pool exists and auto_start_pool is false. Falling back to serial execution.';
    return;
end

use_parallel = true;
end

function value = getCfg(cfg, fieldName, defaultValue)
if isfield(cfg, fieldName) && ~isempty(cfg.(fieldName))
    value = cfg.(fieldName);
else
    value = defaultValue;
end
end

function soc_sweep = buildSocSweep(socRangePercent, socStepPercent)
if ~isnumeric(socRangePercent) || numel(socRangePercent) ~= 2
    error('sweepInitSocStudy:BadRange', 'socRangePercent must be a two-element numeric vector.');
end
if ~isscalar(socStepPercent) || ~isfinite(socStepPercent) || socStepPercent <= 0
    error('sweepInitSocStudy:BadStep', 'socStepPercent must be a positive scalar.');
end

soc_range = sort(double(socRangePercent(:).'));
soc_range(1) = max(0, soc_range(1));
soc_range(2) = min(100, soc_range(2));
soc_sweep = soc_range(1):double(socStepPercent):soc_range(2);
if isempty(soc_sweep) || abs(soc_sweep(end) - soc_range(2)) > 1e-9
    soc_sweep = [soc_sweep, soc_range(2)];
end
soc_sweep = unique(soc_sweep, 'stable');
end

function evalDataset = buildEvalDataset(cfg, model)
switch lower(cfg.dataset_mode)
    case 'esc'
        dataset = loadOrBuildEscDataset(cfg.esc_dataset_file, cfg.raw_bus_file, cfg.esc_model_file, cfg.tc);
        evalDataset = struct();
        evalDataset.time_s = dataset.time_s(:);
        evalDataset.current_a = dataset.current_a(:);
        evalDataset.voltage_v = dataset.voltage_v(:);
        evalDataset.temperature_c = selectTemperatureTrace(dataset, cfg.tc);
        evalDataset.dataset_soc = getOptionalField(dataset, 'soc_true', []);
        evalDataset.soc_init_reference = inferReferenceSoc0(dataset);
        evalDataset.capacity_ah = getParamESC('QParam', cfg.tc, model);
        evalDataset.reference_name = 'ESC reference';
        evalDataset.voltage_name = 'ESC';
        evalDataset.title_prefix = 'Init Sweep ATL BSS';
        evalDataset.r0_reference = getParamESC('R0Param', cfg.tc, model);

    case 'rom'
        dataset = loadOrBuildRomDataset(cfg.rom_dataset_file, cfg.raw_bus_file, cfg.tc);
        evalDataset = struct();
        evalDataset.time_s = dataset.time_s(:);
        evalDataset.current_a = dataset.current_a(:);
        evalDataset.voltage_v = dataset.voltage_v(:);
        evalDataset.temperature_c = selectTemperatureTrace(dataset, cfg.tc);
        evalDataset.dataset_soc = getOptionalField(dataset, 'soc_true', []);
        evalDataset.soc_init_reference = inferReferenceSoc0(dataset);
        evalDataset.capacity_ah = getParamESC('QParam', cfg.tc, model);
        evalDataset.reference_name = 'Reference';
        evalDataset.voltage_name = 'ROM';
        evalDataset.title_prefix = 'Init Sweep NMC30';
        evalDataset.r0_reference = getParamESC('R0Param', cfg.tc, model);

    case 'bus_raw'
        profile = loadBusCoreBatteryProfile(cfg.raw_bus_file);
        profile = resampleProfile(profile, cfg.ts);
        evalDataset = struct();
        evalDataset.time_s = profile.time_s(:);
        evalDataset.current_a = profile.current_a(:);
        evalDataset.voltage_v = profile.voltage_v(:);
        evalDataset.temperature_c = selectProfileTemperature(profile, cfg.tc);
        evalDataset.dataset_soc = profile.soc_ref(:);
        evalDataset.soc_init_reference = inferProfileReferenceSoc0(profile);
        evalDataset.capacity_ah = getParamESC('QParam', cfg.tc, model);
        evalDataset.reference_name = 'Reference';
        evalDataset.voltage_name = 'Measured';
        evalDataset.title_prefix = 'Init Sweep Bus CoreBattery';
        evalDataset.r0_reference = getParamESC('R0Param', cfg.tc, model);

    otherwise
        error('sweepInitSocStudy:BadDatasetMode', ...
            'Unsupported dataset_mode "%s". Use "esc", "rom", or "bus_raw".', cfg.dataset_mode);
end
end

function estimators = buildEscEstimators(soc_init_kf, cfg, model, ROM, estimator_names)
n_rc = numel(getParamESC('RCParam', cfg.tc, model));
R0init = getParamESC('R0Param', cfg.tc, model);

estimators = repmat(estimatorTemplate(), numel(estimator_names), 1);

for idx = 1:numel(estimator_names)
    tuning = resolvedTuningForEstimator(cfg.tuning_bundle, estimator_names{idx});
    SigmaX0 = diag([ ...
        tuning.SigmaX0_rc * ones(1, n_rc), ...
        tuning.SigmaX0_hk, ...
        tuning.SigmaX0_soc]);
    switch estimator_names{idx}
        case 'ESC-SPKF'
            estimators(idx) = makeEstimator('ESC-SPKF', ...
                initESCSPKF(soc_init_kf, cfg.tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, model), ...
                @stepEscSpkf, soc_init_kf, [0.00 0.45 0.74], ':');

        case 'ROM-EKF'
            rom_state_count = inferRomTransientStateCount(ROM, getFieldOr(tuning, 'nx_rom', []));
            sigma_x0_rom = diag([ones(1, rom_state_count), tuning.sigma_x0_rom_tail]);
            estimators(idx) = makeEstimator('ROM-EKF', ...
                initKF(soc_init_kf, cfg.tc, sigma_x0_rom, tuning.sigma_v_ekf, tuning.sigma_w_ekf, 'OutB', ROM), ...
                @stepRomEkf, soc_init_kf, [0.64 0.08 0.18], '-');

        case 'ESC-EKF'
            estimators(idx) = makeEstimator('ESC-EKF', ...
                initESCSPKF(soc_init_kf, cfg.tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, model), ...
                @stepEscEkf, soc_init_kf, [0.85 0.33 0.10], '--');

        case 'EaEKF'
            estimators(idx) = makeEstimator('EaEKF', ...
                initEaEKF(soc_init_kf, cfg.tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, model), ...
                @stepEaEkf, soc_init_kf, [0.93 0.69 0.13], '-.');

        case 'EacrSPKF'
            estimators(idx) = makeEstimator('EacrSPKF', ...
                initESCSPKF(soc_init_kf, cfg.tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, model), ...
                @stepEacrSpkf, soc_init_kf, [0.49 0.18 0.56], '-');

        case 'EnacrSPKF'
            estimators(idx) = makeEstimator('EnacrSPKF', ...
                initESCSPKF(soc_init_kf, cfg.tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, model), ...
                @stepEnacrSpkf, soc_init_kf, [0.47 0.67 0.19], '--');

        case 'EDUKF'
            estimators(idx) = makeEstimator('EDUKF', ...
                initEDUKF(soc_init_kf, R0init, cfg.tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, ...
                tuning.SigmaR0, tuning.SigmaWR0, model), ...
                @stepEdukf, soc_init_kf, [0.30 0.75 0.93], '-');
            estimators(idx).tracksR0 = true;
            estimators(idx).r0_init = estimators(idx).kfData.R0hat;

        case 'EsSPKF'
            estimators(idx) = makeEstimator('EsSPKF', ...
                initEDUKF(soc_init_kf, R0init, cfg.tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, ...
                tuning.SigmaR0, tuning.SigmaWR0, model), ...
                @stepEsSpkf, soc_init_kf, [0.13 0.55 0.13], '--');
            estimators(idx).tracksR0 = true;
            estimators(idx).r0_init = estimators(idx).kfData.R0hat;

        case 'EbSPKF'
            estimators(idx) = makeEstimator('EbSPKF', ...
                initEbSpkf(soc_init_kf, cfg.tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, ...
                tuning.single_bias_process_var, tuning.current_bias_var0, model), ...
                @stepEbSpkf, soc_init_kf, [0.25 0.25 0.25], ':');
            estimators(idx).bias_dim = 1;
            estimators(idx).bias_init = estimators(idx).kfData.xhat(estimators(idx).kfData.ibInd);
            estimators(idx).bias_bnd_init = 3 * sqrt(max( ...
                estimators(idx).kfData.SigmaX(estimators(idx).kfData.ibInd, estimators(idx).kfData.ibInd), 0));

        case 'EBiSPKF'
            estimators(idx) = makeEstimator('EBiSPKF', ...
                initEbiSpkf(soc_init_kf, cfg.tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, ...
                tuning.current_bias_var0, model), ...
                @stepEbiSpkf, soc_init_kf, [0.64 0.08 0.18], '-.');
            estimators(idx).bias_dim = 1;
            estimators(idx).bias_init = estimators(idx).kfData.bhat(:).';
            estimators(idx).bias_bnd_init = 3 * sqrt(max(diag(estimators(idx).kfData.SigmaB), 0)).';

        case 'Em7SPKF'
            estimators(idx) = makeEstimator('Em7SPKF', ...
                initEm7Spkf(soc_init_kf, R0init, cfg.tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, ...
                tuning.SigmaR0, tuning.SigmaWR0, tuning.current_bias_var0, model), ...
                @stepEm7Spkf, soc_init_kf, [0.82 0.23 0.47], '-');
            estimators(idx).tracksR0 = true;
            estimators(idx).r0_init = estimators(idx).kfData.R0hat;
            estimators(idx).bias_dim = 1;
            estimators(idx).bias_init = estimators(idx).kfData.bhat(:).';
            estimators(idx).bias_bnd_init = 3 * sqrt(max(diag(estimators(idx).kfData.SigmaB), 0)).';

        otherwise
            error('sweepInitSocStudy:UnsupportedEstimator', ...
                'Unsupported estimator "%s".', estimator_names{idx});
    end
end
end

function tuning = resolvedTuningForEstimator(tuning_bundle, estimator_name)
matches = strcmpi({tuning_bundle.resolved_estimators.estimator_name}, estimator_name);
if ~any(matches)
    error('sweepInitSocStudy:MissingResolvedTuning', ...
        'No resolved tuning entry was found for estimator %s.', estimator_name);
end
tuning = tuning_bundle.resolved_estimators(find(matches, 1, 'first')).tuning;
end

function estimator = makeEstimator(name, kfData, stepFcn, soc0_percent, color, lineStyle)
estimator = estimatorTemplate();
estimator.name = name;
estimator.kfData = kfData;
estimator.stepFcn = stepFcn;
estimator.soc0_percent = soc0_percent;
estimator.color = color;
estimator.lineStyle = lineStyle;
end

function estimator = estimatorTemplate()
estimator = struct( ...
    'name', '', ...
    'kfData', struct(), ...
    'stepFcn', [], ...
    'soc0_percent', NaN, ...
    'color', [], ...
    'lineStyle', '-', ...
    'tracksR0', false, ...
    'r0_init', NaN, ...
    'bias_dim', 0, ...
    'bias_init', [], ...
    'bias_bnd_init', []);
end

function step = stepEscSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd] = iterESCSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
end

function step = stepRomEkf(vk, ik, Tk, ~, kfData)
[zk, boundzk, kfData] = iterEKF(vk, ik, Tk, kfData);
step = baseStepStruct(zk(end), zk(end-1), boundzk(end), boundzk(end-1), kfData);
end

function step = stepEscEkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd] = iterESCEKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
end

function step = stepEaEkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd] = iterEaEKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
end

function step = stepEacrSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd] = iterEacrSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
end

function step = stepEnacrSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd] = iterEnacrSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
end

function step = stepEdukf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd, r0_est, r0_bnd] = iterEDUKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
step.r0 = r0_est;
step.r0_bnd = r0_bnd;
end

function step = stepEsSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd, r0_est, r0_bnd] = iterEsSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
step.r0 = r0_est;
step.r0_bnd = r0_bnd;
end

function step = stepEbSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd, ib_est, ib_bnd] = iterEbSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
step.bias = ib_est;
step.bias_bnd = ib_bnd;
end

function step = stepEbiSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd, ib_est, ib_bnd] = iterEBiSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
step.bias = ib_est;
step.bias_bnd = ib_bnd;
end

function step = stepEm7Spkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd, bias_est, bias_bnd, r0_est, r0_bnd] = Em7SPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
step.r0 = r0_est;
step.r0_bnd = r0_bnd;
step.bias = bias_est;
step.bias_bnd = bias_bnd;
end

function step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData)
step = struct();
step.soc = soc;
step.voltage = v_pred;
step.soc_bnd = soc_bnd;
step.voltage_bnd = v_bnd;
step.kfData = kfData;
step.innovation_pre = getFieldOr(kfData, 'lastInnovationPre', NaN);
step.sk = getFieldOr(kfData, 'lastSk', NaN);
step.r0 = NaN;
step.r0_bnd = NaN;
step.bias = [];
step.bias_bnd = [];
end

function kfData = initEbSpkf(soc0, T0, SigmaX0, SigmaV, sigma_w_current, sigma_w_bias, sigma_ib0, model)
clear iterEbSPKF;

kfData = initESCSPKF(soc0, T0, SigmaX0, SigmaV, [sigma_w_current; sigma_w_bias], model);
kfData.ibInd = kfData.Nx + 1;
kfData.currentNoiseInd = 1;
kfData.biasNoiseInd = 2;
kfData.xhat = [kfData.xhat; 0];
kfData.SigmaX = blkdiag(kfData.SigmaX, sigma_ib0);
kfData.Nx = kfData.Nx + 1;
kfData.Na = kfData.Nx + kfData.Nw + kfData.Nv;
kfData.Snoise = real(chol(diag([kfData.SigmaW(:); kfData.SigmaV(:)]), 'lower'));

h = sqrt(3);
kfData.h = h;
weight1 = (h * h - kfData.Na) / (h * h);
weight2 = 1 / (2 * h * h);
kfData.Wm = [weight1; weight2 * ones(2 * kfData.Na, 1)];
kfData.Wc = kfData.Wm;
end

function kfData = initEbiSpkf(soc0, T0, SigmaX0, SigmaV, SigmaW, sigma_ib0, model)
biasCfg = struct();
biasCfg.nb = 1;
biasCfg.bhat0 = 0;
biasCfg.SigmaB0 = sigma_ib0;
biasCfg.currentBiasInd = 1;
kfData = initESCSPKF(soc0, T0, SigmaX0, SigmaV, SigmaW, model, biasCfg);
end

function kfData = initEm7Spkf(soc0, R0init, T0, SigmaX0, SigmaV, SigmaW, SigmaR0, SigmaWR0, sigma_ib0, model)
biasCfg = struct();
biasCfg.nb = 1;
biasCfg.bhat0 = 0;
biasCfg.SigmaB0 = sigma_ib0;
biasCfg.currentBiasInd = 1;
kfData = Em7init(soc0, R0init, T0, SigmaX0, SigmaV, SigmaW, SigmaR0, SigmaWR0, model, biasCfg);
end

function dataset = loadOrBuildRomDataset(dataset_file, raw_bus_file, tc)
if exist(dataset_file, 'file') == 2
    raw = load(dataset_file);
    if ~isfield(raw, 'dataset')
        error('sweepInitSocStudy:BadDatasetFile', 'Expected variable "dataset" in %s.', dataset_file);
    end
    dataset = raw.dataset;
    return;
end

cfg = struct();
cfg.profile_file = raw_bus_file;
cfg.source_capacity_ah = 8;
cfg.tc = tc;
dataset = createBusCoreBatterySyntheticDataset(dataset_file, cfg);
end

function dataset = loadOrBuildEscDataset(dataset_file, raw_bus_file, esc_model_file, tc)
if exist(dataset_file, 'file') == 2
    raw = load(dataset_file);
    if ~isfield(raw, 'dataset')
        error('sweepInitSocStudy:BadDatasetFile', 'Expected variable "dataset" in %s.', dataset_file);
    end
    dataset = raw.dataset;
    if isfield(dataset, 'esc_model_file') && pathsMatchPortable(dataset.esc_model_file, esc_model_file)
        return;
    end
end

cfg = struct();
cfg.profile_file = raw_bus_file;
cfg.model_file = esc_model_file;
cfg.tc = tc;
dataset = BSSsimESCdata(dataset_file, cfg);
end

function temperature_c = selectTemperatureTrace(dataset, default_temp)
n_samples = numel(dataset.time_s);
if isfield(dataset, 'temperature_c') && numel(dataset.temperature_c) == n_samples
    temperature_c = dataset.temperature_c(:);
else
    temperature_c = default_temp * ones(n_samples, 1);
end
end

function soc0 = inferReferenceSoc0(dataset)
if isfield(dataset, 'soc_true') && ~isempty(dataset.soc_true) && isfinite(dataset.soc_true(1))
    soc0 = 100 * dataset.soc_true(1);
elseif isfield(dataset, 'soc_init_percent') && ~isempty(dataset.soc_init_percent) && isfinite(dataset.soc_init_percent)
    soc0 = double(dataset.soc_init_percent);
else
    error('sweepInitSocStudy:MissingReferenceSOC0', ...
        'No initial SOC is available from dataset.soc_true(1) or dataset.soc_init_percent.');
end
end

function profile = loadBusCoreBatteryProfile(profile_file)
if exist(profile_file, 'file') ~= 2
    error('sweepInitSocStudy:MissingProfile', 'Profile file not found: %s', profile_file);
end

raw = load(profile_file);
primary = choosePrimaryNode(raw);

profile = struct();
[current_raw, ~] = extractSignal(primary, {'Total_Current_A', 'Current_Vector_A'});
[voltage_raw, ~] = extractSignal(primary, {'Voltage_Vector_V', 'Total_Voltage_V'});
[soc_raw, ~] = extractSignal(primary, {'SOC_Vector_Percent'});
[temp_raw, ~] = extractSignal(primary, {'Temperature_Vector_degC'});

profile.current_a = coerceNumericVector(current_raw, false);
profile.voltage_v = normalizeOptionalSignal(voltage_raw, numel(profile.current_a), 'voltage');
profile.soc_ref = normalizeSocSignal(normalizeOptionalSignal(soc_raw, numel(profile.current_a), 'soc'));
profile.temperature_c = normalizeOptionalSignal(temp_raw, numel(profile.current_a), 'temperature');

if isempty(profile.current_a) || isempty(profile.voltage_v)
    error('sweepInitSocStudy:MissingSignals', ...
        'The evaluation dataset must contain at least current and voltage.');
end

if isa(current_raw, 'timeseries')
    profile.time_s = normalizeTimeVector(current_raw.Time, numel(profile.current_a), 'current.Time');
else
    profile.time_s = (0:numel(profile.current_a)-1).';
end
profile.current_a = orientCurrentToDischargePositive(profile.current_a, profile.time_s, profile.soc_ref);
end

function profile = resampleProfile(profile, ts)
time_s = profile.time_s(:);
if numel(time_s) < 2
    return;
end

[time_s, unique_idx] = unique(time_s, 'stable');
profile.current_a = profile.current_a(unique_idx);
profile.voltage_v = profile.voltage_v(unique_idx);
if ~isempty(profile.soc_ref)
    profile.soc_ref = profile.soc_ref(unique_idx);
end
if ~isempty(profile.temperature_c)
    profile.temperature_c = profile.temperature_c(unique_idx);
end

dt = diff(time_s);
if all(abs(dt - ts) <= 1e-9)
    profile.time_s = time_s;
    return;
end

new_time = (time_s(1):ts:time_s(end)).';
profile.current_a = interp1(time_s, profile.current_a(:), new_time, 'previous', 'extrap');
profile.voltage_v = interp1(time_s, profile.voltage_v(:), new_time, 'linear', 'extrap');
if ~isempty(profile.soc_ref)
    profile.soc_ref = interp1(time_s, profile.soc_ref(:), new_time, 'linear', 'extrap');
    profile.soc_ref = normalizeSocSignal(profile.soc_ref);
end
if ~isempty(profile.temperature_c)
    profile.temperature_c = interp1(time_s, profile.temperature_c(:), new_time, 'linear', 'extrap');
end
profile.time_s = new_time(:);
end

function current_a = orientCurrentToDischargePositive(current_a, time_s, soc_ref)
current_a = current_a(:);
if isempty(soc_ref) || all(isnan(soc_ref)) || numel(current_a) < 3
    return;
end

dt = diff(time_s(:));
dsoc = diff(soc_ref(:));
current_k = current_a(1:end-1);
valid = isfinite(dt) & dt > 0 & isfinite(dsoc) & isfinite(current_k) & abs(current_k) > 1e-9;
if ~any(valid)
    return;
end

alignment_score = sum(current_k(valid) .* (-dsoc(valid) ./ dt(valid)));
if alignment_score < 0
    current_a = -current_a;
end
end

function primary = choosePrimaryNode(raw)
names = fieldnames(raw);
if numel(names) == 1
    primary = raw.(names{1});
else
    primary = raw;
end
end

function [value, path_used] = extractSignal(node, selectors)
value = [];
path_used = '';
for idx = 1:numel(selectors)
    selector = selectors{idx};
    if isstruct(node) && isfield(node, selector)
        value = node.(selector);
        path_used = selector;
        return;
    end
end
end

function out = normalizeOptionalSignal(raw_value, n_expected, signal_name)
if isempty(raw_value)
    out = [];
    return;
end
out = coerceNumericVector(raw_value, false);
if isempty(out)
    out = [];
    return;
end
if numel(out) ~= n_expected
    error('sweepInitSocStudy:SignalLengthMismatch', ...
        'Source %s signal has %d samples, expected %d.', signal_name, numel(out), n_expected);
end
out = out(:);
end

function value = coerceNumericVector(raw_value, allow_scalar)
value = [];
if isempty(raw_value)
    return;
end
if isa(raw_value, 'timeseries')
    value = coerceTimeseriesData(raw_value, allow_scalar);
    return;
end
if isnumeric(raw_value)
    if isscalar(raw_value)
        if allow_scalar
            value = double(raw_value);
        end
    elseif isvector(raw_value)
        value = double(raw_value(:));
    end
end
end

function value = coerceTimeseriesData(ts_obj, allow_scalar)
value = [];
data = ts_obj.Data;
if isempty(data) || ~isnumeric(data)
    return;
end

data = double(data);
if isvector(data)
    value = data(:);
    if isscalar(value) && ~allow_scalar
        value = [];
    end
    return;
end

data = reshape(data, size(data, 1), []);
if size(data, 2) == 1
    value = data(:, 1);
elseif allow_scalar && numel(data) == 1
    value = data(1);
else
    value = mean(data, 2, 'omitnan');
end
end

function time_s = normalizeTimeVector(time_raw, n_expected, signal_name)
if isdatetime(time_raw)
    time_raw = seconds(time_raw(:) - time_raw(1));
elseif isduration(time_raw)
    time_raw = seconds(time_raw(:));
else
    time_raw = double(time_raw(:));
end
if numel(time_raw) ~= n_expected
    error('sweepInitSocStudy:TimeLengthMismatch', ...
        'Source %s vector has %d samples, expected %d.', signal_name, numel(time_raw), n_expected);
end
time_s = double(time_raw(:) - time_raw(1));
end

function soc = normalizeSocSignal(soc)
if isempty(soc)
    return;
end
soc = soc(:);
if any(abs(soc) > 1.5)
    soc = soc / 100;
end
soc = min(max(soc, 0), 1);
end

function temperature_c = selectProfileTemperature(profile, default_temp)
n_samples = numel(profile.time_s);
if isfield(profile, 'temperature_c') && numel(profile.temperature_c) == n_samples && ~isempty(profile.temperature_c)
    temperature_c = profile.temperature_c(:);
else
    temperature_c = default_temp * ones(n_samples, 1);
end
end

function soc0 = inferProfileReferenceSoc0(profile)
if ~isempty(profile.soc_ref) && any(isfinite(profile.soc_ref))
    soc0 = 100 * profile.soc_ref(find(isfinite(profile.soc_ref), 1, 'first'));
else
    error('sweepInitSocStudy:MissingProfileSOC0', ...
        'The raw bus dataset does not contain an initial SOC reference.');
end
end

function value = getOptionalField(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function value = getFieldOr(s, fieldName, defaultValue)
if isfield(s, fieldName)
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function value = finiteMean(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = mean(x);
end
end

function value = finiteMin(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = min(x);
end
end

function value = finiteMax(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = max(x);
end
end

function plotSweepRmseFigures(soc0_sweep_percent, soc_rmse, voltage_rmse, estimator_names, dataset_mode)
palette = lines(numel(estimator_names));

figure('Name', 'Initial SOC Sweep - SOC RMSE', 'NumberTitle', 'off');
hold on;
for est_idx = 1:numel(estimator_names)
    plot(soc0_sweep_percent, soc_rmse(:, est_idx), '-o', ...
        'LineWidth', 1.4, 'Color', palette(est_idx, :), ...
        'DisplayName', estimator_names{est_idx});
end
grid on;
xlabel('Initial SOC [%]');
ylabel('SOC RMSE [%]');
title(sprintf('Initial SOC Sweep SOC RMSE (%s)', upper(dataset_mode)));
legend('Location', 'best');

figure('Name', 'Initial SOC Sweep - Voltage RMSE', 'NumberTitle', 'off');
hold on;
for est_idx = 1:numel(estimator_names)
    plot(soc0_sweep_percent, voltage_rmse(:, est_idx), '-o', ...
        'LineWidth', 1.4, 'Color', palette(est_idx, :), ...
        'DisplayName', estimator_names{est_idx});
end
grid on;
xlabel('Initial SOC [%]');
ylabel('Voltage RMSE [mV]');
title(sprintf('Initial SOC Sweep Voltage RMSE (%s)', upper(dataset_mode)));
legend('Location', 'best');
end

function model = extractEscModelStruct(raw)
if isfield(raw, 'nmc30_model')
    model = raw.nmc30_model;
elseif isfield(raw, 'model')
    model = raw.model;
else
    error('sweepInitSocStudy:BadESCModelFile', ...
        'Expected variable "nmc30_model" or "model" in the ESC model file.');
end
end

function estimator_names = normalizeEstimatorSelection(raw_names)
if ischar(raw_names)
    raw_names = {raw_names};
elseif isa(raw_names, 'string')
    raw_names = cellstr(raw_names(:));
elseif ~iscell(raw_names)
    error('sweepInitSocStudy:BadEstimatorSelection', ...
        'cfg.estimator_names must be a char vector, string array, or cell array.');
end

estimator_names = cell(1, numel(raw_names));
for idx = 1:numel(raw_names)
    name = char(raw_names{idx});
    key = regexprep(upper(name), '[^A-Z0-9]', '');
    switch key
        case {'ITERESCSPKF', 'ESCSPKF'}
            estimator_names{idx} = 'ESC-SPKF';
        case {'ITEREKF', 'ITERROMEKF', 'ROMEKF'}
            estimator_names{idx} = 'ROM-EKF';
        case {'ITERESCEKF', 'ESCEKF'}
            estimator_names{idx} = 'ESC-EKF';
        case {'ITEREAEKF', 'EAEKF'}
            estimator_names{idx} = 'EaEKF';
        case {'ITEREACRSPKF', 'EACRSPKF'}
            estimator_names{idx} = 'EacrSPKF';
        case {'ITERENACRSPKF', 'ENACRSPKF'}
            estimator_names{idx} = 'EnacrSPKF';
        case {'ITEREDUKF', 'EDUKF'}
            estimator_names{idx} = 'EDUKF';
        case {'ITERESSPKF', 'ESSPKF'}
            estimator_names{idx} = 'EsSPKF';
        case {'ITEREBSPKF', 'EBSPKF'}
            estimator_names{idx} = 'EbSPKF';
        case {'ITEREBISPKF', 'EBISPKF'}
            estimator_names{idx} = 'EBiSPKF';
        case {'ITEREM7SPKF', 'EM7SPKF'}
            estimator_names{idx} = 'Em7SPKF';
        otherwise
            error('sweepInitSocStudy:UnsupportedEstimator', ...
                'Unsupported estimator selector "%s".', name);
    end
end

estimator_names = unique(estimator_names, 'stable');
if isempty(estimator_names)
    error('sweepInitSocStudy:NoEstimators', ...
        'cfg.estimator_names must select at least one estimator.');
end
end

function results_file = resolveInitSocResultsFile(cfg, here, evalDataset)
if ~isempty(cfg.results_file)
    results_file = cfg.results_file;
    return;
end

title_prefix = getFieldOr(evalDataset, 'title_prefix', 'init_soc_sweep');
base_name = sprintf('%s_init_soc_sweep_results.mat', sanitizeFilename(title_prefix));
results_file = fullfile(here, 'results', base_name);
end

function n_states = inferRomTransientStateCount(ROM, fallback_value)
if nargin < 2
    fallback_value = [];
end

if isfield(ROM, 'ROMmdls') && ~isempty(ROM.ROMmdls)
    n_states = size(ROM.ROMmdls(1).A, 1) - 1;
    return;
end

if ~isempty(fallback_value)
    n_states = fallback_value;
    return;
end

error('sweepInitSocStudy:MissingROMStateCount', ...
    'Could not infer the ROM transient-state count from ROM.ROMmdls.');
end

function saveInitSocResults(results_file, sweepResults)
results_dir = fileparts(results_file);
if ~isempty(results_dir) && exist(results_dir, 'dir') ~= 7
    mkdir(results_dir);
end
save(results_file, 'sweepResults');
fprintf('\nInitial-SOC sweep results saved to %s\n', results_file);
end

function name = sanitizeFilename(name)
name = regexprep(char(name), '[^\w\-]+', '_');
name = regexprep(name, '_+', '_');
name = regexprep(name, '^_|_$', '');
if isempty(name)
    name = 'init_soc_sweep';
end
end

function path_out = normalizePath(path_in)
path_out = strrep(char(path_in), '/', filesep);
path_out = strrep(path_out, '\', filesep);
end

function tf = pathsMatchPortable(path_a, path_b)
a = comparablePath(path_a);
b = comparablePath(path_b);
tf = strcmpi(a, b) || endsWith(a, stripLeadingSeparators(b), 'IgnoreCase', true) || ...
    endsWith(b, stripLeadingSeparators(a), 'IgnoreCase', true);
end

function path_out = comparablePath(path_in)
path_out = lower(normalizePath(path_in));
path_out = regexprep(path_out, [regexptranslate('escape', filesep), '+'], filesep);
end

function path_out = stripLeadingSeparators(path_in)
path_out = regexprep(char(path_in), '^[\\/]+', '');
end

function file_path = firstExistingFile(candidates, error_id, error_msg)
file_path = '';
for idx = 1:numel(candidates)
    if exist(candidates{idx}, 'file') == 2
        file_path = candidates{idx};
        return;
    end
end

searched = sprintf('\n  - %s', candidates{:});
error(error_id, '%s Searched:%s', error_msg, searched);
end

function file_path = firstExistingFileOrEmpty(candidates)
file_path = '';
for idx = 1:numel(candidates)
    if exist(candidates{idx}, 'file') == 2
        file_path = candidates{idx};
        return;
    end
end
end
