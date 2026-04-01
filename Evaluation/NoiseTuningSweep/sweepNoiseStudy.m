function sweepResults = sweepNoiseStudy(sigmaWRange, sigmaVRange, stepMultiplier, cfg)
% sweepNoiseStudy Sweep process and sensor noise over configurable ranges.
% Grid sweeping 10 estimators can take hours. Patience is advised!
%
% Usage:
%   results = sweepNoiseStudy()
%   results = sweepNoiseStudy([1e-3 1e1], [1e-3 1e1], 5)
%   results = sweepNoiseStudy([1e-4 1e0], [1e-5 1e-1], 2, cfg)
%
% Inputs:
%   sigmaWRange     Two-element [min max] process-noise range. Default [1e-3 1e1].
%   sigmaVRange     Two-element [min max] sensor-noise range. Default [1e-3 1e1].
%   stepMultiplier  Multiplicative step between sweep points. Default 5.
%   cfg             Optional struct. Useful fields:
%                     tc, ts, dataset_mode, sweep_mode,
%                     fixed_sigma_w, fixed_sigma_v, include_rom_ekf,
%                     estimator_names,
%                     use_parallel, NoiseSummaryfigs,
%                     PlotSocRmsefigs, PlotVoltageRmsefigs,
%                     esc_dataset_file, rom_dataset_file, raw_bus_file,
%                     rom_file, esc_model_file, tuning
%
% Output:
%   sweepResults    Struct with sweep settings, RMSE tables, and run results.

clear iterEKF iterESCSPKF iterESCEKF iterEaEKF iterEacrSPKF iterEnacrSPKF;
clear iterEDUKF iterEsSPKF iterEbSPKF iterEBiSPKF;

input_meta = captureInputMeta(nargin, sigmaWRange, sigmaVRange, stepMultiplier, cfg);

if nargin < 1 || isempty(sigmaWRange)
    sigmaWRange = [1e-3 1e2];
end
if nargin < 2 || isempty(sigmaVRange)
    sigmaVRange = [1e-6 2e-1];
end
if nargin < 3 || isempty(stepMultiplier)
    stepMultiplier = 5;
end
if nargin < 4 || isempty(cfg)
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
else
    here = fileparts(mfilename('fullpath'));
end

repo_root = fileparts(fileparts(here));
addpath(genpath(repo_root));

cfg = normalizeStudyConfig(cfg, repo_root, input_meta);
[sigma_w_values, sigma_v_values] = buildSweepAxes(cfg, sigmaWRange, sigmaVRange, stepMultiplier);

esc_src = load(cfg.esc_model_file);
ROM = [];
if any(strcmp(cfg.estimator_names, 'ROM-EKF'))
    if isempty(cfg.rom_file)
        error('sweepNoiseStudy:MissingROMFile', ...
            'ROM-EKF was selected but no ROM model file was found.');
    end
    rom_src = load(cfg.rom_file);
    if ~isfield(rom_src, 'ROM')
        error('sweepNoiseStudy:BadROMFile', 'Expected variable "ROM" in %s.', cfg.rom_file);
    end
    ROM = rom_src.ROM;
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
n_w = numel(sigma_w_values);
n_v = numel(sigma_v_values);
n_runs = n_w * n_v;
[run_w_idx, run_v_idx, run_sigma_w, run_sigma_v] = buildRunPlan(sigma_w_values, sigma_v_values);
hwait = createSweepWaitbar(n_runs, estimator_names, sigma_w_values, sigma_v_values);
cleanup_waitbar = onCleanup(@() closeSweepWaitbar(hwait)); %#ok<NASGU>
completed_runs = 0;

soc_rmse = NaN(n_w, n_v, n_estimators);
voltage_rmse = NaN(n_w, n_v, n_estimators);
soc_me = NaN(n_w, n_v, n_estimators);
voltage_me = NaN(n_w, n_v, n_estimators);
soc_mssd = NaN(n_w, n_v, n_estimators);
voltage_mssd = NaN(n_w, n_v, n_estimators);
all_results = cell(n_w, n_v);

[use_parallel, parallel_message] = resolveParallelMode(cfg);
if cfg.use_parallel && ~use_parallel
    fprintf('%s\n', parallel_message);
elseif use_parallel
    fprintf('Parallel sweep enabled.\n');
end

fprintf('\nNoise covariance sweep starting with %d estimator(s).\n', n_estimators);
fprintf('Included estimators: %s\n', strjoin(estimator_names, ', '));

if use_parallel
    run_outputs = cell(n_runs, 1);
    progress_queue = parallel.pool.DataQueue;
    afterEach(progress_queue, @onParallelProgress);

    parfor run_idx = 1:n_runs
        run_outputs{run_idx} = evaluateSweepPoint( ...
            run_sigma_w(run_idx), run_sigma_v(run_idx), ...
            evalDataset, cfg, ROM, nmc30_esc, flags);
        send(progress_queue, struct( ...
            'run_idx', run_idx, ...
            'sigma_w', run_sigma_w(run_idx), ...
            'sigma_v', run_sigma_v(run_idx)));
    end

    for run_idx = 1:n_runs
        [soc_rmse, voltage_rmse, soc_me, voltage_me, soc_mssd, voltage_mssd, all_results] = storeSweepPoint( ...
            soc_rmse, voltage_rmse, soc_me, voltage_me, soc_mssd, voltage_mssd, all_results, ...
            run_w_idx(run_idx), run_v_idx(run_idx), run_outputs{run_idx});
    end
else
    for run_idx = 1:n_runs
        point_output = evaluateSweepPoint( ...
            run_sigma_w(run_idx), run_sigma_v(run_idx), ...
            evalDataset, cfg, ROM, nmc30_esc, flags);
        [soc_rmse, voltage_rmse, soc_me, voltage_me, soc_mssd, voltage_mssd, all_results] = storeSweepPoint( ...
            soc_rmse, voltage_rmse, soc_me, voltage_me, soc_mssd, voltage_mssd, all_results, ...
            run_w_idx(run_idx), run_v_idx(run_idx), point_output);
        updateProgress(run_idx, run_sigma_w(run_idx), run_sigma_v(run_idx));
    end
end
updateSweepWaitbar(hwait, n_runs, n_runs, sigma_w_values(end), sigma_v_values(end), n_estimators);

summary_table = buildSummaryTable( ...
    estimator_names, sigma_w_values, sigma_v_values, ...
    soc_rmse, voltage_rmse, soc_me, voltage_me, soc_mssd, voltage_mssd);

fprintf('\nNoise-covariance sweep summary (%s dataset)\n', upper(cfg.dataset_mode));
fprintf('Sweep mode: %s\n', upper(cfg.sweep_mode));
fprintf('sigma_w range: %s\n', formatSweepVector(sigma_w_values));
fprintf('sigma_v range: %s\n', formatSweepVector(sigma_v_values));
disp(summary_table);

fprintf('\nAggregate summary across sigma_w / sigma_v sweep\n');
for est_idx = 1:n_estimators
    soc_vals = soc_rmse(:, :, est_idx);
    v_vals = voltage_rmse(:, :, est_idx);
    soc_mssd_vals = soc_mssd(:, :, est_idx);
    v_mssd_vals = voltage_mssd(:, :, est_idx);
    fprintf('  %-10s mean SOC RMSE = %.3f%%, best = %.3f%%, worst = %.3f%% | ', ...
        estimator_names{est_idx}, finiteMean(soc_vals(:)), finiteMin(soc_vals(:)), finiteMax(soc_vals(:)));
    fprintf('mean SOC MSSD = %.6f %%^2 | ', finiteMean(soc_mssd_vals(:)));
    fprintf('mean V RMSE = %.2f mV, best = %.2f mV, worst = %.2f mV | ', ...
        finiteMean(v_vals(:)), finiteMin(v_vals(:)), finiteMax(v_vals(:)));
    fprintf('mean V MSSD = %.4f mV^2\n', finiteMean(v_mssd_vals(:)));
end

sweepResults = struct();
sweepResults.dataset_mode = cfg.dataset_mode;
sweepResults.sweep_mode = cfg.sweep_mode;
sweepResults.sigma_w_values = sigma_w_values(:);
sweepResults.sigma_v_values = sigma_v_values(:);
sweepResults.estimator_names = estimator_names;
sweepResults.soc_rmse_percent = soc_rmse;
sweepResults.voltage_rmse_mv = voltage_rmse;
sweepResults.soc_me_percent = soc_me;
sweepResults.voltage_me_mv = voltage_me;
sweepResults.soc_mssd_percent2 = soc_mssd;
sweepResults.voltage_mssd_mv2 = voltage_mssd;
sweepResults.summary_table = summary_table;
sweepResults.evalDataset = evalDataset;
sweepResults.all_results = all_results;
sweepResults.total_runs = n_runs;

if cfg.NoiseSummaryfigs
    plotNoiseSweepSummary(sweepResults);
end
if cfg.PlotSocRmsefigs
    plotNoiseSweepHeatmaps(sweepResults, {'soc_rmse_percent', 'soc_mssd_percent2'});
end
if cfg.PlotVoltageRmsefigs
    plotNoiseSweepHeatmaps(sweepResults, {'voltage_rmse_mv', 'voltage_mssd_mv2'});
end

if nargout == 0
    assignin('base', 'noiseCovSweepResults', sweepResults);
end

    function updateProgress(completed_runs_value, sigma_w_value, sigma_v_value)
        completed_runs = completed_runs_value; %#ok<NASGU>
        updateSweepWaitbar(hwait, completed_runs_value, n_runs, sigma_w_value, sigma_v_value, n_estimators);
        fprintf('Noise covariance sweep point %d/%d: sigma_w = %.3g, sigma_v = %.3g, %d estimator(s)\n', ...
            completed_runs_value, n_runs, sigma_w_value, sigma_v_value, n_estimators);
    end

    function onParallelProgress(progress_data)
        completed_runs = completed_runs + 1;
        updateSweepWaitbar(hwait, completed_runs, n_runs, progress_data.sigma_w, progress_data.sigma_v, n_estimators);
        fprintf('Noise covariance sweep point %d/%d: sigma_w = %.3g, sigma_v = %.3g, %d estimator(s)\n', ...
            completed_runs, n_runs, progress_data.sigma_w, progress_data.sigma_v, n_estimators);
    end
end

function cfg = normalizeStudyConfig(cfg, repo_root, input_meta)
tuning_defaults = defaultNoiseTuning();

cfg.tc = getCfg(cfg, 'tc', 25);
cfg.ts = getCfg(cfg, 'ts', 1);
cfg.dataset_mode = getCfg(cfg, 'dataset_mode', 'esc');
cfg.sweep_mode = lower(getCfg(cfg, 'sweep_mode', 'grid'));
cfg.fixed_sigma_w = getCfg(cfg, 'fixed_sigma_w', 1e-3);
cfg.fixed_sigma_v = getCfg(cfg, 'fixed_sigma_v', 1e-3);
cfg.include_rom_ekf = logical(getCfg(cfg, 'include_rom_ekf', false));
cfg.estimator_names = normalizeEstimatorSelection(getCfg(cfg, 'estimator_names', defaultNoiseEstimatorNames()));
cfg.use_parallel = logical(getCfg(cfg, 'use_parallel', false));
cfg.NoiseSummaryfigs = getCfg(cfg, 'NoiseSummaryfigs', false);
cfg.PlotSocRmsefigs = getCfg(cfg, 'PlotSocRmsefigs', true);
cfg.PlotVoltageRmsefigs = getCfg(cfg, 'PlotVoltageRmsefigs', true);
cfg.esc_dataset_file = getCfg(cfg, 'esc_dataset_file', ...
    fullfile(repo_root, 'data', 'evaluation', 'processed', 'desktop_atl20_bss_v1', 'nominal', 'esc_bus_coreBattery_dataset.mat'));
cfg.rom_dataset_file = getCfg(cfg, 'rom_dataset_file', ...
    fullfile(repo_root, 'data', 'evaluation', 'processed', 'behavioral_nmc30_bss_v1', 'nominal', 'rom_bus_coreBattery_dataset.mat'));
cfg.raw_bus_file = getCfg(cfg, 'raw_bus_file', ...
    fullfile(repo_root, 'data', 'evaluation', 'raw', 'omtlife8ahc_hp', 'Bus_CoreBatteryData_Data.mat'));
cfg.rom_file = getCfg(cfg, 'rom_file', ...
    firstExistingFileOrEmpty({ ...
    fullfile(repo_root, 'models', 'ROM_ATL20_beta.mat')}));
cfg.esc_model_file = getCfg(cfg, 'esc_model_file', ...
    firstExistingFile({ ...
    fullfile(repo_root, 'models', 'ATLmodel.mat'), ...
    fullfile(repo_root, 'ESC_Id', 'FullESCmodels', 'LFP', 'ATLmodel.mat')}, ...
    'sweepNoiseStudy:MissingESCModel', ...
    'No ATL ESC model file found.'));
cfg.tuning = getCfg(cfg, 'tuning', tuning_defaults);
cfg.tuning = mergeStructDefaults(cfg.tuning, tuning_defaults);
cfg = resolveEstimatorSelectionConfig(cfg, input_meta);
cfg.esc_dataset_file = resolveEvaluationDatasetPath(cfg.esc_dataset_file, repo_root, 'access', 'benchmark', 'must_exist', false);
cfg.rom_dataset_file = resolveEvaluationDatasetPath(cfg.rom_dataset_file, repo_root, 'access', 'benchmark', 'must_exist', false);
cfg.raw_bus_file = resolveEvaluationDatasetPath(cfg.raw_bus_file, repo_root, 'access', 'builder', 'must_exist', false);
end

function cfg = resolveEstimatorSelectionConfig(cfg, input_meta)
rom_cfg_was_set = isfield(input_meta.cfg_fields, 'include_rom_ekf');
name_cfg_was_set = isfield(input_meta.cfg_fields, 'estimator_names');

if cfg.include_rom_ekf && ~any(strcmp(cfg.estimator_names, 'ROM-EKF'))
    cfg.estimator_names = [{'ROM-EKF'}, cfg.estimator_names];
end

if any(strcmp(cfg.estimator_names, 'ROM-EKF')) && isempty(cfg.rom_file)
    error('sweepNoiseStudy:MissingROMFile', ...
        'ROM-EKF was selected but no ATL ROM model file was found.');
end

if input_meta.is_default_invocation || name_cfg_was_set || rom_cfg_was_set
    return;
end
end

function input_meta = captureInputMeta(nargin_value, sigmaWRange, sigmaVRange, stepMultiplier, cfg)
input_meta = struct();
input_meta.range_w_was_set = nargin_value >= 1 && ~isempty(sigmaWRange);
input_meta.range_v_was_set = nargin_value >= 2 && ~isempty(sigmaVRange);
input_meta.step_was_set = nargin_value >= 3 && ~isempty(stepMultiplier);
cfg_fields = struct();
if nargin_value >= 4 && ~isempty(cfg) && isstruct(cfg)
    names = fieldnames(cfg);
    for idx = 1:numel(names)
        cfg_fields.(names{idx}) = true;
    end
end
input_meta.cfg_fields = cfg_fields;
input_meta.cfg_was_set = ~isempty(fieldnames(cfg_fields));
input_meta.is_default_invocation = ~( ...
    input_meta.range_w_was_set || input_meta.range_v_was_set || ...
    input_meta.step_was_set || input_meta.cfg_was_set);
end

function [sigma_w_values, sigma_v_values] = buildSweepAxes(cfg, sigmaWRange, sigmaVRange, stepMultiplier)
switch cfg.sweep_mode
    case 'sigma_w'
        sigma_w_values = buildLogLikeSweep(sigmaWRange, stepMultiplier);
        sigma_v_values = cfg.fixed_sigma_v;
    case 'sigma_v'
        sigma_w_values = cfg.fixed_sigma_w;
        sigma_v_values = buildLogLikeSweep(sigmaVRange, stepMultiplier);
    case 'grid'
        sigma_w_values = buildLogLikeSweep(sigmaWRange, stepMultiplier);
        sigma_v_values = buildLogLikeSweep(sigmaVRange, stepMultiplier);
    otherwise
        error('sweepNoiseStudy:BadSweepMode', ...
            'cfg.sweep_mode must be "sigma_w", "sigma_v", or "grid".');
end
end

function tuning = defaultNoiseTuning()
tuning = struct();
tuning.SigmaX0_rc = 1e-6;
tuning.SigmaX0_hk = 1e-6;
tuning.SigmaX0_soc = 1e-3;
tuning.sigma_x0_rom_tail = 2e6;
tuning.SigmaR0 = 1e-6;
tuning.SigmaWR0 = 1e-16;
tuning.current_bias_var0 = 1e-5;
tuning.single_bias_process_var = 1e-8;
end

function names = defaultNoiseEstimatorNames()
names = {'EbSPKF', 'ESC-SPKF', 'EBiSPKF', 'EaEKF', 'EsSPKF', 'EDUKF'};
end

function sweep_values = buildLogLikeSweep(valueRange, stepMultiplier)
if ~isnumeric(valueRange) || numel(valueRange) ~= 2
    error('sweepNoiseStudy:BadRange', 'Sweep ranges must be two-element numeric vectors.');
end
if ~isscalar(stepMultiplier) || ~isfinite(stepMultiplier) || stepMultiplier <= 1
    error('sweepNoiseStudy:BadMultiplier', 'stepMultiplier must be a scalar greater than 1.');
end

range = sort(double(valueRange(:).'));
if any(range <= 0)
    error('sweepNoiseStudy:BadRange', 'Sweep ranges must be strictly positive.');
end

sweep_values = range(1);
while sweep_values(end) * stepMultiplier < range(2) * (1 - 1e-12)
    sweep_values(end + 1) = sweep_values(end) * stepMultiplier; %#ok<AGROW>
end
if abs(sweep_values(end) - range(2)) > eps(range(2))
    sweep_values(end + 1) = range(2); %#ok<AGROW>
end
sweep_values = unique(sweep_values, 'stable');
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
        evalDataset.title_prefix = 'Noise Sweep ATL BSS';
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
        evalDataset.title_prefix = 'Noise Sweep NMC30';
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
        evalDataset.title_prefix = 'Noise Sweep Bus CoreBattery';
        evalDataset.r0_reference = getParamESC('R0Param', cfg.tc, model);

    otherwise
        error('sweepNoiseStudy:BadDatasetMode', ...
            'Unsupported dataset_mode "%s". Use "esc", "rom", or "bus_raw".', cfg.dataset_mode);
end
end

function estimators = buildAllEstimators(soc_init_kf, cfg, ROM, model, noise_cfg)
tuning = cfg.tuning;
n_rc = numel(getParamESC('RCParam', cfg.tc, model));
SigmaX0 = diag([ ...
    tuning.SigmaX0_rc * ones(1, n_rc), ...
    tuning.SigmaX0_hk, ...
    tuning.SigmaX0_soc]);
R0init = getParamESC('R0Param', cfg.tc, model);

sigma_w = noise_cfg.sigma_w;
sigma_v = noise_cfg.sigma_v;
estimators = repmat(estimatorTemplate(), numel(cfg.estimator_names), 1);

for idx = 1:numel(cfg.estimator_names)
    switch cfg.estimator_names{idx}
        case 'ROM-EKF'
            rom_state_count = inferRomTransientStateCount(ROM, getFieldOr(tuning, 'nx_rom', []));
            sigma_x0_rom = diag([ones(1, rom_state_count), tuning.sigma_x0_rom_tail]);
            estimators(idx) = makeEstimator( ...
                'ROM-EKF', ...
                initKF(soc_init_kf, cfg.tc, sigma_x0_rom, sigma_v, sigma_w, 'OutB', ROM), ...
                @stepRomEkf, soc_init_kf, [0.64 0.08 0.18], '-');

        case 'ESC-SPKF'
            estimators(idx) = makeEstimator('ESC-SPKF', ...
                initESCSPKF(soc_init_kf, cfg.tc, SigmaX0, sigma_v, sigma_w, model), ...
                @stepEscSpkf, soc_init_kf, [0.00 0.45 0.74], ':');

        case 'ESC-EKF'
            estimators(idx) = makeEstimator('ESC-EKF', ...
                initESCSPKF(soc_init_kf, cfg.tc, SigmaX0, sigma_v, sigma_w, model), ...
                @stepEscEkf, soc_init_kf, [0.85 0.33 0.10], '--');

        case 'EaEKF'
            estimators(idx) = makeEstimator('EaEKF', ...
                initEaEKF(soc_init_kf, cfg.tc, SigmaX0, sigma_v, sigma_w, model), ...
                @stepEaEkf, soc_init_kf, [0.93 0.69 0.13], '-.');

        case 'EacrSPKF'
            estimators(idx) = makeEstimator('EacrSPKF', ...
                initESCSPKF(soc_init_kf, cfg.tc, SigmaX0, sigma_v, sigma_w, model), ...
                @stepEacrSpkf, soc_init_kf, [0.49 0.18 0.56], '-');

        case 'EnacrSPKF'
            estimators(idx) = makeEstimator('EnacrSPKF', ...
                initESCSPKF(soc_init_kf, cfg.tc, SigmaX0, sigma_v, sigma_w, model), ...
                @stepEnacrSpkf, soc_init_kf, [0.47 0.67 0.19], '--');

        case 'EDUKF'
            estimators(idx) = makeEstimator('EDUKF', ...
                initEDUKF(soc_init_kf, R0init, cfg.tc, SigmaX0, sigma_v, sigma_w, ...
                tuning.SigmaR0, tuning.SigmaWR0, model), ...
                @stepEdukf, soc_init_kf, [0.30 0.75 0.93], '-');
            estimators(idx).tracksR0 = true;
            estimators(idx).r0_init = estimators(idx).kfData.R0hat;

        case 'EsSPKF'
            estimators(idx) = makeEstimator('EsSPKF', ...
                initEDUKF(soc_init_kf, R0init, cfg.tc, SigmaX0, sigma_v, sigma_w, ...
                tuning.SigmaR0, tuning.SigmaWR0, model), ...
                @stepEsSpkf, soc_init_kf, [0.13 0.55 0.13], '--');
            estimators(idx).tracksR0 = true;
            estimators(idx).r0_init = estimators(idx).kfData.R0hat;

        case 'EbSPKF'
            estimators(idx) = makeEstimator('EbSPKF', ...
                initEbSpkf(soc_init_kf, cfg.tc, SigmaX0, sigma_v, sigma_w, ...
                tuning.single_bias_process_var, tuning.current_bias_var0, model), ...
                @stepEbSpkf, soc_init_kf, [0.25 0.25 0.25], ':');
            estimators(idx).bias_dim = 1;
            estimators(idx).bias_init = estimators(idx).kfData.xhat(estimators(idx).kfData.ibInd);
            estimators(idx).bias_bnd_init = 3 * sqrt(max( ...
                estimators(idx).kfData.SigmaX(estimators(idx).kfData.ibInd, estimators(idx).kfData.ibInd), 0));

        case 'EBiSPKF'
            estimators(idx) = makeEstimator('EBiSPKF', ...
                initEbiSpkf(soc_init_kf, cfg.tc, SigmaX0, sigma_v, sigma_w, tuning.current_bias_var0, model), ...
                @stepEbiSpkf, soc_init_kf, [0.64 0.08 0.18], '-.');
            estimators(idx).bias_dim = 1;
            estimators(idx).bias_init = estimators(idx).kfData.bhat(:).';
            estimators(idx).bias_bnd_init = 3 * sqrt(max(diag(estimators(idx).kfData.SigmaB), 0)).';

        case 'Em7SPKF'
            estimators(idx) = makeEstimator('Em7SPKF', ...
                initEm7Spkf(soc_init_kf, R0init, cfg.tc, SigmaX0, sigma_v, sigma_w, ...
                tuning.SigmaR0, tuning.SigmaWR0, tuning.current_bias_var0, model), ...
                @stepEm7Spkf, soc_init_kf, [0.82 0.23 0.47], '-');
            estimators(idx).tracksR0 = true;
            estimators(idx).r0_init = estimators(idx).kfData.R0hat;
            estimators(idx).bias_dim = 1;
            estimators(idx).bias_init = estimators(idx).kfData.bhat(:).';
            estimators(idx).bias_bnd_init = 3 * sqrt(max(diag(estimators(idx).kfData.SigmaB), 0)).';

        otherwise
            error('sweepNoiseStudy:UnsupportedEstimator', ...
                'Unsupported estimator "%s".', cfg.estimator_names{idx});
    end
end
end

function summary_table = buildSummaryTable(estimator_names, sigma_w_values, sigma_v_values, soc_rmse, voltage_rmse, soc_me, voltage_me, soc_mssd, voltage_mssd)
n_estimators = numel(estimator_names);
best_soc_rmse = NaN(n_estimators, 1);
best_soc_me = NaN(n_estimators, 1);
best_soc_mssd = NaN(n_estimators, 1);
best_v_rmse = NaN(n_estimators, 1);
best_v_me = NaN(n_estimators, 1);
best_v_mssd = NaN(n_estimators, 1);
best_sigma_w = NaN(n_estimators, 1);
best_sigma_v = NaN(n_estimators, 1);

for est_idx = 1:n_estimators
    soc_slice = soc_rmse(:, :, est_idx);
    [best_val, linear_idx] = min(soc_slice(:));
    [w_idx, v_idx] = ind2sub(size(soc_slice), linear_idx);
    best_soc_rmse(est_idx) = best_val;
    best_soc_me(est_idx) = soc_me(w_idx, v_idx, est_idx);
    best_soc_mssd(est_idx) = soc_mssd(w_idx, v_idx, est_idx);
    best_v_rmse(est_idx) = voltage_rmse(w_idx, v_idx, est_idx);
    best_v_me(est_idx) = voltage_me(w_idx, v_idx, est_idx);
    best_v_mssd(est_idx) = voltage_mssd(w_idx, v_idx, est_idx);
    best_sigma_w(est_idx) = sigma_w_values(w_idx);
    best_sigma_v(est_idx) = sigma_v_values(v_idx);
end

summary_table = table( ...
    best_sigma_w, best_sigma_v, best_soc_rmse, best_soc_me, best_soc_mssd, ...
    best_v_rmse, best_v_me, best_v_mssd, ...
    'VariableNames', {'BestSigmaW', 'BestSigmaV', 'BestSocRmsePct', 'BestSocMePct', 'BestSocMssdPct2', ...
    'VoltageRmseMvAtBestSoc', 'VoltageMeMvAtBestSoc', 'VoltageMssdMv2AtBestSoc'}, ...
    'RowNames', matlab.lang.makeUniqueStrings(estimator_names));
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

function step = stepRomEkf(vk, ik, Tk, ~, kfData)
[zk, boundzk, kfData] = iterEKF(vk, ik, Tk, kfData);
step = baseStepStruct(zk(end), zk(end-1), boundzk(end), boundzk(end-1), kfData);
end

function step = stepEscSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd] = iterESCSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
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
        error('sweepNoiseStudy:BadDatasetFile', 'Expected variable "dataset" in %s.', dataset_file);
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
        error('sweepNoiseStudy:BadDatasetFile', 'Expected variable "dataset" in %s.', dataset_file);
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
    error('sweepNoiseStudy:MissingReferenceSOC0', ...
        'No initial SOC is available from dataset.soc_true(1) or dataset.soc_init_percent.');
end
end

function profile = loadBusCoreBatteryProfile(profile_file)
if exist(profile_file, 'file') ~= 2
    error('sweepNoiseStudy:MissingProfile', 'Profile file not found: %s', profile_file);
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
    error('sweepNoiseStudy:MissingSignals', ...
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
    error('sweepNoiseStudy:SignalLengthMismatch', ...
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
    value = rowMeanOmitNan(data);
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
    error('sweepNoiseStudy:TimeLengthMismatch', ...
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
    error('sweepNoiseStudy:MissingProfileSOC0', ...
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

function out = mergeStructDefaults(in, defaults)
out = defaults;
names = fieldnames(in);
for idx = 1:numel(names)
    out.(names{idx}) = in.(names{idx});
end
end

function value = getCfg(cfg, fieldName, defaultValue)
if isfield(cfg, fieldName) && ~isempty(cfg.(fieldName))
    value = cfg.(fieldName);
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

function text_value = formatSweepVector(values)
parts = formatTickLabels(values);
text_value = strjoin(parts, ', ');
end

function labels = formatTickLabels(values)
labels = arrayfun(@(x) sprintf('%.3g', x), values, 'UniformOutput', false);
end

function values = rowMeanOmitNan(data)
valid_counts = sum(isfinite(data), 2);
data(~isfinite(data)) = 0;
values = sum(data, 2) ./ max(valid_counts, 1);
values(valid_counts == 0) = NaN;
end

function model = extractEscModelStruct(raw)
if isfield(raw, 'nmc30_model')
    model = raw.nmc30_model;
elseif isfield(raw, 'model')
    model = raw.model;
else
    error('sweepNoiseStudy:BadESCModelFile', ...
        'Expected variable "nmc30_model" or "model" in the ESC model file.');
end
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

error('sweepNoiseStudy:MissingROMStateCount', ...
    'Could not infer the ROM transient-state count from ROM.ROMmdls.');
end

function estimator_names = normalizeEstimatorSelection(raw_names)
if ischar(raw_names)
    raw_names = {raw_names};
elseif isa(raw_names, 'string')
    raw_names = cellstr(raw_names(:));
elseif ~iscell(raw_names)
    error('sweepNoiseStudy:BadEstimatorSelection', ...
        'cfg.estimator_names must be a char vector, string array, or cell array.');
end

estimator_names = cell(1, numel(raw_names));
for idx = 1:numel(raw_names)
    name = char(raw_names{idx});
    key = regexprep(upper(name), '[^A-Z0-9]', '');
    switch key
        case {'ITEREKF', 'ITERROMEKF', 'ROMEKF'}
            estimator_names{idx} = 'ROM-EKF';
        case {'ITERESCSPKF', 'ESCSPKF'}
            estimator_names{idx} = 'ESC-SPKF';
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
            error('sweepNoiseStudy:UnsupportedEstimator', ...
                'Unsupported estimator selector "%s".', name);
    end
end

estimator_names = unique(estimator_names, 'stable');
if isempty(estimator_names)
    error('sweepNoiseStudy:NoEstimators', ...
        'cfg.estimator_names must select at least one estimator.');
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

function [run_w_idx, run_v_idx, run_sigma_w, run_sigma_v] = buildRunPlan(sigma_w_values, sigma_v_values)
n_w = numel(sigma_w_values);
n_v = numel(sigma_v_values);
n_runs = n_w * n_v;

run_w_idx = zeros(n_runs, 1);
run_v_idx = zeros(n_runs, 1);
run_sigma_w = zeros(n_runs, 1);
run_sigma_v = zeros(n_runs, 1);

run_idx = 0;
for w_idx = 1:n_w
    for v_idx = 1:n_v
        run_idx = run_idx + 1;
        run_w_idx(run_idx) = w_idx;
        run_v_idx(run_idx) = v_idx;
        run_sigma_w(run_idx) = sigma_w_values(w_idx);
        run_sigma_v(run_idx) = sigma_v_values(v_idx);
    end
end
end

function point_output = evaluateSweepPoint(sigma_w_value, sigma_v_value, evalDataset, cfg, ROM, model, flags)
noise_cfg = struct('sigma_w', sigma_w_value, 'sigma_v', sigma_v_value);
estimators = buildAllEstimators(evalDataset.soc_init_reference, cfg, ROM, model, noise_cfg);
run_results = xKFeval(evalDataset, estimators, flags);
point_output = collectPointMetrics(run_results);
end

function point_output = collectPointMetrics(run_results)
point_output = struct();
point_output.run_results = run_results;
n_estimators = numel(run_results.estimators);
point_output.soc_rmse = NaN(1, n_estimators);
point_output.voltage_rmse = NaN(1, n_estimators);
point_output.soc_me = NaN(1, n_estimators);
point_output.voltage_me = NaN(1, n_estimators);
point_output.soc_mssd = NaN(1, n_estimators);
point_output.voltage_mssd = NaN(1, n_estimators);
for est_idx = 1:n_estimators
    point_output.soc_rmse(est_idx) = 100 * run_results.estimators(est_idx).rmse_soc;
    point_output.voltage_rmse(est_idx) = 1000 * run_results.estimators(est_idx).rmse_voltage;
    point_output.soc_me(est_idx) = 100 * run_results.estimators(est_idx).me_soc;
    point_output.voltage_me(est_idx) = 1000 * run_results.estimators(est_idx).me_voltage;
    point_output.soc_mssd(est_idx) = 1e4 * run_results.estimators(est_idx).mssd_soc;
    point_output.voltage_mssd(est_idx) = 1e6 * run_results.estimators(est_idx).mssd_voltage;
end
end

function [soc_rmse, voltage_rmse, soc_me, voltage_me, soc_mssd, voltage_mssd, all_results] = storeSweepPoint( ...
        soc_rmse, voltage_rmse, soc_me, voltage_me, soc_mssd, voltage_mssd, all_results, w_idx, v_idx, point_output)
all_results{w_idx, v_idx} = point_output.run_results;
soc_rmse(w_idx, v_idx, :) = reshape(point_output.soc_rmse, 1, 1, []);
voltage_rmse(w_idx, v_idx, :) = reshape(point_output.voltage_rmse, 1, 1, []);
soc_me(w_idx, v_idx, :) = reshape(point_output.soc_me, 1, 1, []);
voltage_me(w_idx, v_idx, :) = reshape(point_output.voltage_me, 1, 1, []);
soc_mssd(w_idx, v_idx, :) = reshape(point_output.soc_mssd, 1, 1, []);
voltage_mssd(w_idx, v_idx, :) = reshape(point_output.voltage_mssd, 1, 1, []);
end

function [use_parallel, message] = resolveParallelMode(cfg)
use_parallel = false;
message = '';
if ~cfg.use_parallel
    return;
end

if exist('parfor', 'builtin') ~= 5 || exist('gcp', 'file') ~= 2
    message = 'Parallel sweep requested but Parallel Computing Toolbox is unavailable. Falling back to serial for-loop.';
    return;
end

if ~license('test', 'Distrib_Computing_Toolbox')
    message = 'Parallel sweep requested but Parallel Computing Toolbox is not licensed. Falling back to serial for-loop.';
    return;
end

try
    gcp('nocreate');
    use_parallel = true;
catch
    message = 'Parallel sweep requested but no parallel pool could be initialized. Falling back to serial for-loop.';
end
end

function hwait = createSweepWaitbar(n_runs, estimator_names, sigma_w_values, sigma_v_values)
hwait = [];
message = sprintf('Sweep 0/%d | sigma_w=%.3g | sigma_v=%.3g | %d estimator(s)', ...
    n_runs, sigma_w_values(1), sigma_v_values(1), numel(estimator_names));
try
    hwait = waitbar(0, message, 'Name', 'Noise Covariance Sweep');
catch
    hwait = [];
end
end

function updateSweepWaitbar(hwait, completed_runs, total_runs, sigma_w_value, sigma_v_value, n_estimators)
if isempty(hwait) || ~ishandle(hwait)
    return;
end
fraction = completed_runs / max(total_runs, 1);
message = sprintf('Sweep %d/%d | sigma_w=%.3g | sigma_v=%.3g | %d estimator(s)', ...
    completed_runs, total_runs, sigma_w_value, sigma_v_value, n_estimators);
waitbar(fraction, hwait, message);
end

function closeSweepWaitbar(hwait)
if ~isempty(hwait) && ishandle(hwait)
    close(hwait);
end
end
