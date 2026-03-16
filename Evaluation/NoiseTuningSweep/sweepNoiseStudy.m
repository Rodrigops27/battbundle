function sweepResults = sweepNoiseStudy(sigmaWRange, sigmaVRange, stepMultiplier, cfg)
% sweepNoiseStudy Sweep process and sensor noise over configurable ranges.
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
%                     fixed_sigma_w, fixed_sigma_v, NoiseSummaryfigs,
%                     PlotSocRmsefigs, PlotVoltageRmsefigs,
%                     rom_dataset_file, raw_bus_file, rom_file,
%                     esc_model_file, tuning
%
% Output:
%   sweepResults    Struct with sweep settings, RMSE tables, and run results.

clear iterEKF iterESCSPKF iterESCEKF iterEaEKF iterEacrSPKF iterEnacrSPKF;
clear iterEDUKF iterEsSPKF iterEbSPKF iterEBiSPKF;

if nargin < 1 || isempty(sigmaWRange)
    sigmaWRange = [1e-3 1e1];
end
if nargin < 2 || isempty(sigmaVRange)
    sigmaVRange = [1e-3 1e1];
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
    cd(here);
end

repo_root = fileparts(fileparts(here));
addpath(genpath(repo_root));

cfg = normalizeStudyConfig(cfg, repo_root);
[sigma_w_values, sigma_v_values] = buildSweepAxes(cfg, sigmaWRange, sigmaVRange, stepMultiplier);

rom_src = load(cfg.rom_file);
esc_src = load(cfg.esc_model_file);
if ~isfield(rom_src, 'ROM')
    error('sweepNoiseStudy:BadROMFile', 'Expected variable "ROM" in %s.', cfg.rom_file);
end
ROM = rom_src.ROM;
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

estimator_names = { ...
    'ROM-EKF', 'ESC-SPKF', 'ESC-EKF', 'EaEKF', 'EacrSPKF', ...
    'EnacrSPKF', 'EDUKF', 'EsSPKF', 'EbSPKF', 'EBiSPKF'};
n_estimators = numel(estimator_names);
n_w = numel(sigma_w_values);
n_v = numel(sigma_v_values);
n_runs = n_w * n_v;

soc_rmse = NaN(n_w, n_v, n_estimators);
voltage_rmse = NaN(n_w, n_v, n_estimators);
soc_me = NaN(n_w, n_v, n_estimators);
voltage_me = NaN(n_w, n_v, n_estimators);
all_results = cell(n_w, n_v);

for w_idx = 1:n_w
    for v_idx = 1:n_v
        noise_cfg = struct('sigma_w', sigma_w_values(w_idx), 'sigma_v', sigma_v_values(v_idx));
        estimators = buildAllEstimators(evalDataset.soc_init_reference, cfg, ROM, nmc30_esc, noise_cfg);
        run_results = xKFeval(evalDataset, estimators, flags);
        all_results{w_idx, v_idx} = run_results;

        for est_idx = 1:n_estimators
            soc_rmse(w_idx, v_idx, est_idx) = 100 * run_results.estimators(est_idx).rmse_soc;
            voltage_rmse(w_idx, v_idx, est_idx) = 1000 * run_results.estimators(est_idx).rmse_voltage;
            soc_me(w_idx, v_idx, est_idx) = 100 * run_results.estimators(est_idx).me_soc;
            voltage_me(w_idx, v_idx, est_idx) = 1000 * run_results.estimators(est_idx).me_voltage;
        end
    end
end

summary_table = buildSummaryTable(estimator_names, sigma_w_values, sigma_v_values, soc_rmse, voltage_rmse, soc_me, voltage_me);

fprintf('\nNoise-covariance sweep summary (%s dataset)\n', upper(cfg.dataset_mode));
fprintf('Sweep mode: %s\n', upper(cfg.sweep_mode));
fprintf('sigma_w range: %s\n', formatSweepVector(sigma_w_values));
fprintf('sigma_v range: %s\n', formatSweepVector(sigma_v_values));
disp(summary_table);

fprintf('\nAggregate summary across sigma_w / sigma_v sweep\n');
for est_idx = 1:n_estimators
    soc_vals = soc_rmse(:, :, est_idx);
    v_vals = voltage_rmse(:, :, est_idx);
    fprintf('  %-10s mean SOC RMSE = %.3f%%, best = %.3f%%, worst = %.3f%% | ', ...
        estimator_names{est_idx}, finiteMean(soc_vals(:)), finiteMin(soc_vals(:)), finiteMax(soc_vals(:)));
    fprintf('mean V RMSE = %.2f mV, best = %.2f mV, worst = %.2f mV\n', ...
        finiteMean(v_vals(:)), finiteMin(v_vals(:)), finiteMax(v_vals(:)));
end

if cfg.NoiseSummaryfigs
    plotAggregateNoiseFigures(sigma_w_values, sigma_v_values, soc_rmse, voltage_rmse, estimator_names, cfg.sweep_mode);
end
if cfg.PlotSocRmsefigs
    plotPerEstimatorPerformanceFigures(sigma_w_values, sigma_v_values, soc_rmse, estimator_names, 'SOC RMSE [%]', 'SOC', cfg.sweep_mode);
end
if cfg.PlotVoltageRmsefigs
    plotPerEstimatorPerformanceFigures(sigma_w_values, sigma_v_values, voltage_rmse, estimator_names, 'Voltage RMSE [mV]', 'Voltage', cfg.sweep_mode);
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
sweepResults.summary_table = summary_table;
sweepResults.evalDataset = evalDataset;
sweepResults.all_results = all_results;
sweepResults.total_runs = n_runs;

if nargout == 0
    assignin('base', 'noiseCovSweepResults', sweepResults);
end
end

function cfg = normalizeStudyConfig(cfg, repo_root)
evaluation_root = fullfile(repo_root, 'Evaluation');
tuning_defaults = defaultNoiseTuning();

cfg.tc = getCfg(cfg, 'tc', 25);
cfg.ts = getCfg(cfg, 'ts', 1);
cfg.dataset_mode = getCfg(cfg, 'dataset_mode', 'rom');
cfg.sweep_mode = lower(getCfg(cfg, 'sweep_mode', 'grid'));
cfg.fixed_sigma_w = getCfg(cfg, 'fixed_sigma_w', 1e-3);
cfg.fixed_sigma_v = getCfg(cfg, 'fixed_sigma_v', 1e-3);
cfg.NoiseSummaryfigs = getCfg(cfg, 'NoiseSummaryfigs', false);
cfg.PlotSocRmsefigs = getCfg(cfg, 'PlotSocRmsefigs', true);
cfg.PlotVoltageRmsefigs = getCfg(cfg, 'PlotVoltageRmsefigs', true);
cfg.rom_dataset_file = getCfg(cfg, 'rom_dataset_file', ...
    fullfile(evaluation_root, 'ROMSimData', 'datasets', 'rom_bus_coreBattery_dataset.mat'));
cfg.raw_bus_file = getCfg(cfg, 'raw_bus_file', ...
    fullfile(evaluation_root, 'OMTLIFE8AHC-HP', 'Bus_CoreBatteryData_Data.mat'));
cfg.rom_file = getCfg(cfg, 'rom_file', ...
    firstExistingFile({ ...
    fullfile(repo_root, 'models', 'ROM_NMC30_HRA12.mat'), ...
    fullfile(repo_root, 'models', 'ROM_NMC30_HRA.mat')}, ...
    'sweepNoiseStudy:MissingROMFile', ...
    'No ROM model file found.'));
cfg.esc_model_file = getCfg(cfg, 'esc_model_file', ...
    firstExistingFile({ ...
    fullfile(repo_root, 'models', 'NMC30model.mat'), ...
    fullfile(repo_root, 'ESC_Id', 'NMC30', 'NMC30model.mat')}, ...
    'sweepNoiseStudy:MissingESCModel', ...
    'No NMC30 ESC model file found.'));
cfg.tuning = getCfg(cfg, 'tuning', tuning_defaults);
cfg.tuning = mergeStructDefaults(cfg.tuning, tuning_defaults);
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
tuning.nx_rom = 12;
tuning.SigmaR0 = 1e-6;
tuning.SigmaWR0 = 1e-16;
tuning.current_bias_var0 = 1e-5;
tuning.single_bias_process_var = 1e-8;
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
            'Unsupported dataset_mode "%s". Use "rom" or "bus_raw".', cfg.dataset_mode);
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
sigma_x0_rom = diag([ones(1, tuning.nx_rom), tuning.sigma_x0_rom_tail]);

estimators = repmat(estimatorTemplate(), 10, 1);

estimators(1) = makeEstimator( ...
    'ROM-EKF', ...
    initKF(soc_init_kf, cfg.tc, sigma_x0_rom, sigma_v, sigma_w, 'OutB', ROM), ...
    @stepRomEkf, soc_init_kf, [0.64 0.08 0.18], '-');

estimators(2) = makeEstimator('ESC-SPKF', ...
    initESCSPKF(soc_init_kf, cfg.tc, SigmaX0, sigma_v, sigma_w, model), ...
    @stepEscSpkf, soc_init_kf, [0.00 0.45 0.74], ':');

estimators(3) = makeEstimator('ESC-EKF', ...
    initESCSPKF(soc_init_kf, cfg.tc, SigmaX0, sigma_v, sigma_w, model), ...
    @stepEscEkf, soc_init_kf, [0.85 0.33 0.10], '--');

estimators(4) = makeEstimator('EaEKF', ...
    initEaEKF(soc_init_kf, cfg.tc, SigmaX0, sigma_v, sigma_w, model), ...
    @stepEaEkf, soc_init_kf, [0.93 0.69 0.13], '-.');

estimators(5) = makeEstimator('EacrSPKF', ...
    initESCSPKF(soc_init_kf, cfg.tc, SigmaX0, sigma_v, sigma_w, model), ...
    @stepEacrSpkf, soc_init_kf, [0.49 0.18 0.56], '-');

estimators(6) = makeEstimator('EnacrSPKF', ...
    initESCSPKF(soc_init_kf, cfg.tc, SigmaX0, sigma_v, sigma_w, model), ...
    @stepEnacrSpkf, soc_init_kf, [0.47 0.67 0.19], '--');

estimators(7) = makeEstimator('EDUKF', ...
    initEDUKF(soc_init_kf, R0init, cfg.tc, SigmaX0, sigma_v, sigma_w, ...
    tuning.SigmaR0, tuning.SigmaWR0, model), ...
    @stepEdukf, soc_init_kf, [0.30 0.75 0.93], '-');
estimators(7).tracksR0 = true;
estimators(7).r0_init = estimators(7).kfData.R0hat;

estimators(8) = makeEstimator('EsSPKF', ...
    initEDUKF(soc_init_kf, R0init, cfg.tc, SigmaX0, sigma_v, sigma_w, ...
    tuning.SigmaR0, tuning.SigmaWR0, model), ...
    @stepEsSpkf, soc_init_kf, [0.13 0.55 0.13], '--');
estimators(8).tracksR0 = true;
estimators(8).r0_init = estimators(8).kfData.R0hat;

estimators(9) = makeEstimator('EbSPKF', ...
    initEbSpkf(soc_init_kf, cfg.tc, SigmaX0, sigma_v, sigma_w, ...
    tuning.single_bias_process_var, tuning.current_bias_var0, model), ...
    @stepEbSpkf, soc_init_kf, [0.25 0.25 0.25], ':');
estimators(9).bias_dim = 1;
estimators(9).bias_init = estimators(9).kfData.xhat(estimators(9).kfData.ibInd);
estimators(9).bias_bnd_init = 3 * sqrt(max( ...
    estimators(9).kfData.SigmaX(estimators(9).kfData.ibInd, estimators(9).kfData.ibInd), 0));

estimators(10) = makeEstimator('EBiSPKF', ...
    initEbiSpkf(soc_init_kf, cfg.tc, SigmaX0, sigma_v, sigma_w, tuning.current_bias_var0, model), ...
    @stepEbiSpkf, soc_init_kf, [0.64 0.08 0.18], '-.');
estimators(10).bias_dim = 1;
estimators(10).bias_init = estimators(10).kfData.bhat(:).';
estimators(10).bias_bnd_init = 3 * sqrt(max(diag(estimators(10).kfData.SigmaB), 0)).';
end

function summary_table = buildSummaryTable(estimator_names, sigma_w_values, sigma_v_values, soc_rmse, voltage_rmse, soc_me, voltage_me)
n_estimators = numel(estimator_names);
best_soc_rmse = NaN(n_estimators, 1);
best_soc_me = NaN(n_estimators, 1);
best_v_rmse = NaN(n_estimators, 1);
best_v_me = NaN(n_estimators, 1);
best_sigma_w = NaN(n_estimators, 1);
best_sigma_v = NaN(n_estimators, 1);

for est_idx = 1:n_estimators
    soc_slice = soc_rmse(:, :, est_idx);
    [best_val, linear_idx] = min(soc_slice(:));
    [w_idx, v_idx] = ind2sub(size(soc_slice), linear_idx);
    best_soc_rmse(est_idx) = best_val;
    best_soc_me(est_idx) = soc_me(w_idx, v_idx, est_idx);
    best_v_rmse(est_idx) = voltage_rmse(w_idx, v_idx, est_idx);
    best_v_me(est_idx) = voltage_me(w_idx, v_idx, est_idx);
    best_sigma_w(est_idx) = sigma_w_values(w_idx);
    best_sigma_v(est_idx) = sigma_v_values(v_idx);
end

summary_table = table( ...
    best_sigma_w, best_sigma_v, best_soc_rmse, best_soc_me, best_v_rmse, best_v_me, ...
    'VariableNames', {'BestSigmaW', 'BestSigmaV', 'BestSocRmsePct', 'BestSocMePct', 'VoltageRmseMvAtBestSoc', 'VoltageMeMvAtBestSoc'}, ...
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

function plotAggregateNoiseFigures(sigma_w_values, sigma_v_values, soc_rmse, voltage_rmse, estimator_names, sweep_mode)
palette = lines(numel(estimator_names));

if strcmp(sweep_mode, 'sigma_v')
    x_values = sigma_v_values;
    x_label = '\sigma_v';
    soc_source = @() squeeze(meanOverDim1OmitNan(soc_rmse(:, :, :)));
    v_source = @() squeeze(meanOverDim1OmitNan(voltage_rmse(:, :, :)));
else
    x_values = sigma_w_values;
    x_label = '\sigma_w';
    soc_source = @() squeeze(meanOverDim2OmitNan(soc_rmse(:, :, :)));
    v_source = @() squeeze(meanOverDim2OmitNan(voltage_rmse(:, :, :)));
end

soc_curves = soc_source();
v_curves = v_source();

figure('Name', 'Noise Sweep - Mean SOC RMSE', 'NumberTitle', 'off');
hold on;
for est_idx = 1:numel(estimator_names)
    semilogx(x_values, soc_curves(:, est_idx), '-o', ...
        'LineWidth', 1.4, 'Color', palette(est_idx, :), ...
        'DisplayName', estimator_names{est_idx});
end
grid on;
xlabel(x_label);
ylabel('Mean SOC RMSE [%]');
title(sprintf('Noise Sweep Mean SOC RMSE vs %s', x_label));
legend('Location', 'best');

figure('Name', 'Noise Sweep - Mean Voltage RMSE', 'NumberTitle', 'off');
hold on;
for est_idx = 1:numel(estimator_names)
    semilogx(x_values, v_curves(:, est_idx), '-o', ...
        'LineWidth', 1.4, 'Color', palette(est_idx, :), ...
        'DisplayName', estimator_names{est_idx});
end
grid on;
xlabel(x_label);
ylabel('Mean Voltage RMSE [mV]');
title(sprintf('Noise Sweep Mean Voltage RMSE vs %s', x_label));
legend('Location', 'best');
end

function plotPerEstimatorPerformanceFigures(sigma_w_values, sigma_v_values, data_cube, estimator_names, colorbar_label, figure_prefix, sweep_mode)
if numel(sigma_w_values) > 1 && numel(sigma_v_values) > 1
    plotPerEstimatorHeatmaps(sigma_w_values, sigma_v_values, data_cube, estimator_names, colorbar_label, figure_prefix);
elseif strcmp(sweep_mode, 'sigma_v')
    plotPerEstimatorCurves(sigma_v_values, squeeze(data_cube(1, :, :)), estimator_names, colorbar_label, figure_prefix, '\sigma_v');
else
    plotPerEstimatorCurves(sigma_w_values, squeeze(data_cube(:, 1, :)), estimator_names, colorbar_label, figure_prefix, '\sigma_w');
end
end

function plotPerEstimatorHeatmaps(sigma_w_values, sigma_v_values, data_cube, estimator_names, colorbar_label, figure_prefix)
for est_idx = 1:numel(estimator_names)
    figure('Name', sprintf('%s - %s', figure_prefix, estimator_names{est_idx}), 'NumberTitle', 'off');
    imagesc(log10(sigma_v_values), log10(sigma_w_values), data_cube(:, :, est_idx));
    axis xy;
    grid on;
    xlabel('log_{10}(\sigma_v)');
    ylabel('log_{10}(\sigma_w)');
    title(sprintf('%s Sweep - %s', figure_prefix, estimator_names{est_idx}));
    cb = colorbar;
    ylabel(cb, colorbar_label);
    xticks(log10(sigma_v_values));
    xticklabels(formatTickLabels(sigma_v_values));
    yticks(log10(sigma_w_values));
    yticklabels(formatTickLabels(sigma_w_values));
end
end

function plotPerEstimatorCurves(x_values, data_matrix, estimator_names, y_label, figure_prefix, x_label)
for est_idx = 1:numel(estimator_names)
    figure('Name', sprintf('%s - %s', figure_prefix, estimator_names{est_idx}), 'NumberTitle', 'off');
    semilogx(x_values, data_matrix(:, est_idx), '-o', 'LineWidth', 1.4);
    grid on;
    xlabel(x_label);
    ylabel(y_label);
    title(sprintf('%s Sweep - %s', figure_prefix, estimator_names{est_idx}));
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

function values = meanOverDim2OmitNan(data)
valid_counts = sum(isfinite(data), 2);
data(~isfinite(data)) = 0;
values = sum(data, 2) ./ max(valid_counts, 1);
values(valid_counts == 0) = NaN;
end

function values = meanOverDim1OmitNan(data)
valid_counts = sum(isfinite(data), 1);
data(~isfinite(data)) = 0;
values = sum(data, 1) ./ max(valid_counts, 1);
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
