function results = ABestComp(cfg)
% ABestComp Compare EDUKF and EsSPKF on the ROM bus_coreBattery dataset.
%
% Usage:
%   results = ABestComp()
%   results = ABestComp(cfg)
%
% Useful cfg fields:
%   tc                    Temperature in degC. Default 25.
%   ts                    Sampling time in seconds. Default 1.
%   dataset_file          ROM dataset MAT file.
%   profile_file          Source profile used if the ROM dataset must be rebuilt.
%   esc_model_file        ESC model MAT file.
%   SOCfigs               Show per-estimator SOC error figures.
%   Vfigs                 Show per-estimator voltage error figures.
%   InnovationACFPACFfigs Show innovation ACF/PACF figure.
%   R0figs                Show R0 comparison figure.
%   ComparisonFigs        Show direct EDUKF vs EsSPKF overlay figures.
%   Verbose               Print xKFeval summaries and diagnostics.

if nargin < 1 || isempty(cfg)
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

repo_root = fileparts(here);
addpath(genpath(repo_root));

cfg = normalizeConfig(cfg, here, repo_root);

dataset = loadOrBuildRomDataset(cfg.dataset_file, cfg.profile_file, cfg.tc);
esc_src = load(cfg.esc_model_file);
model = extractEscModelStruct(esc_src);

evalDataset = buildEvalDataset(dataset, model, cfg);
estimators = buildEstimators(evalDataset.soc_init_reference, cfg, model);

flags = struct();
flags.SOCfigs = cfg.SOCfigs;
flags.Vfigs = cfg.Vfigs;
flags.Biasfigs = false;
flags.R0figs = cfg.R0figs;
flags.InnovationACFPACFfigs = cfg.InnovationACFPACFfigs;
flags.default_temperature_c = cfg.tc;
flags.Verbose = cfg.Verbose;

results = xKFeval(evalDataset, estimators, flags);

if cfg.ComparisonFigs
    plotComparisonResults(results);
end

if nargout == 0
    assignin('base', 'abest_results', results);
end
end

function cfg = normalizeConfig(cfg, evaluation_root, repo_root)
cfg.tc = getCfg(cfg, 'tc', 25);
cfg.ts = getCfg(cfg, 'ts', 1);
cfg.dataset_file = getCfg(cfg, 'dataset_file', ...
    fullfile(repo_root, 'data', 'evaluation', 'processed', 'behavioral_nmc30_bss_v1', 'nominal', 'rom_bus_coreBattery_dataset.mat'));
cfg.profile_file = getCfg(cfg, 'profile_file', ...
    fullfile(repo_root, 'data', 'evaluation', 'raw', 'omtlife8ahc_hp', 'Bus_CoreBatteryData_Data.mat'));
cfg.esc_model_file = getCfg(cfg, 'esc_model_file', ...
    firstExistingFile({ ...
    fullfile(repo_root, 'models', 'NMC30model.mat'), ...
    fullfile(repo_root, 'ESC_Id', 'NMC30', 'NMC30model.mat')}, ...
    'ABestComp:MissingESCModel', ...
    'No NMC30 ESC model file found.'));

cfg.SOCfigs = getCfg(cfg, 'SOCfigs', false);
cfg.Vfigs = getCfg(cfg, 'Vfigs', false);
cfg.InnovationACFPACFfigs = getCfg(cfg, 'InnovationACFPACFfigs', true);
cfg.R0figs = getCfg(cfg, 'R0figs', true);
cfg.ComparisonFigs = getCfg(cfg, 'ComparisonFigs', true);
cfg.Verbose = getCfg(cfg, 'Verbose', true);

cfg.dataset_file = resolveEvaluationDatasetPath(cfg.dataset_file, repo_root, 'access', 'benchmark', 'must_exist', false);
cfg.profile_file = resolveEvaluationDatasetPath(cfg.profile_file, repo_root, 'access', 'builder', 'must_exist', false);
end

function evalDataset = buildEvalDataset(dataset, model, cfg)
temperature_c = selectTemperatureTrace(dataset, cfg.tc);
soc_init_reference = inferReferenceSoc0(dataset);

evalDataset = struct();
evalDataset.time_s = dataset.time_s(:);
evalDataset.current_a = dataset.current_a(:);
evalDataset.voltage_v = dataset.voltage_v(:);
evalDataset.temperature_c = temperature_c(:);
evalDataset.dataset_soc = getOptionalField(dataset, 'soc_true', []);
evalDataset.reference_soc = getOptionalField(dataset, 'soc_true', []);
evalDataset.metric_soc = evalDataset.reference_soc;
evalDataset.metric_voltage = dataset.voltage_v(:);
evalDataset.soc_init_reference = soc_init_reference;
evalDataset.capacity_ah = getParamESC('QParam', cfg.tc, model);
evalDataset.reference_name = 'ROM reference';
evalDataset.voltage_name = 'ROM voltage';
evalDataset.title_prefix = 'ABest NMC30';
evalDataset.r0_reference = getParamESC('R0Param', cfg.tc, model);
end

function estimators = buildEstimators(soc_init_kf, cfg, model)
n_rc = numel(getParamESC('RCParam', cfg.tc, model));
SigmaX0 = diag([1e-6 * ones(1, n_rc), 1e-6, 1e-3]);
sigma_w_esc = 1e-3;
sigma_v_esc = 1e-3;
SigmaR0 = 1e-6;
SigmaWR0 = 1e-16;
R0init = getParamESC('R0Param', cfg.tc, model);

estimators = repmat(estimatorTemplate(), 2, 1);

estimators(1) = makeEstimator( ...
    'EDUKF', ...
    initEDUKF(soc_init_kf, R0init, cfg.tc, SigmaX0, sigma_v_esc, sigma_w_esc, ...
    SigmaR0, SigmaWR0, model), ...
    @stepEdukf, soc_init_kf, [0.30 0.75 0.93], '-');
estimators(1).tracksR0 = true;
estimators(1).r0_init = estimators(1).kfData.R0hat;

estimators(2) = makeEstimator( ...
    'EsSPKF', ...
    initEDUKF(soc_init_kf, R0init, cfg.tc, SigmaX0, sigma_v_esc, sigma_w_esc, ...
    SigmaR0, SigmaWR0, model), ...
    @stepEsSpkf, soc_init_kf, [0.13 0.55 0.13], '--');
estimators(2).tracksR0 = true;
estimators(2).r0_init = estimators(2).kfData.R0hat;
end

function plotComparisonResults(results)
time_s = results.dataset.time_s;
reference_soc = results.dataset.reference_soc;
reference_voltage = results.dataset.voltage_v;
est_a = results.estimators(1);
est_b = results.estimators(2);

figure('Name', 'ABest Comparison - SOC', 'NumberTitle', 'off');
plot(time_s, 100 * reference_soc, 'k-', 'LineWidth', 2.2, 'DisplayName', results.dataset.reference_name);
hold on;
plot(time_s, 100 * est_a.soc, '-', 'Color', est_a.color, 'LineWidth', 1.4, ...
    'DisplayName', sprintf('%s (RMSE %.3f%%)', est_a.name, 100 * est_a.rmse_soc));
plot(time_s, 100 * est_b.soc, '--', 'Color', est_b.color, 'LineWidth', 1.4, ...
    'DisplayName', sprintf('%s (RMSE %.3f%%)', est_b.name, 100 * est_b.rmse_soc));
grid on;
xlabel('Time [s]');
ylabel('SOC [%]');
title('EDUKF vs EsSPKF - SOC');
legend('Location', 'best');

figure('Name', 'ABest Comparison - Voltage', 'NumberTitle', 'off');
plot(time_s, reference_voltage, 'k-', 'LineWidth', 2.0, 'DisplayName', results.dataset.voltage_name);
hold on;
plot(time_s, est_a.voltage, '-', 'Color', est_a.color, 'LineWidth', 1.4, ...
    'DisplayName', sprintf('%s (RMSE %.2f mV)', est_a.name, 1000 * est_a.rmse_voltage));
plot(time_s, est_b.voltage, '--', 'Color', est_b.color, 'LineWidth', 1.4, ...
    'DisplayName', sprintf('%s (RMSE %.2f mV)', est_b.name, 1000 * est_b.rmse_voltage));
grid on;
xlabel('Time [s]');
ylabel('Voltage [V]');
title('EDUKF vs EsSPKF - Voltage');
legend('Location', 'best');

figure('Name', 'ABest Comparison - Errors', 'NumberTitle', 'off');
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(time_s, 100 * est_a.error_soc, '-', 'Color', est_a.color, 'LineWidth', 1.2, ...
    'DisplayName', est_a.name);
hold on;
plot(time_s, 100 * est_b.error_soc, '--', 'Color', est_b.color, 'LineWidth', 1.2, ...
    'DisplayName', est_b.name);
grid on;
xlabel('Time [s]');
ylabel('SOC Error [%]');
title('SOC error');
legend('Location', 'best');

nexttile;
plot(time_s, 1000 * est_a.error_voltage, '-', 'Color', est_a.color, 'LineWidth', 1.2, ...
    'DisplayName', est_a.name);
hold on;
plot(time_s, 1000 * est_b.error_voltage, '--', 'Color', est_b.color, 'LineWidth', 1.2, ...
    'DisplayName', est_b.name);
grid on;
xlabel('Time [s]');
ylabel('Voltage Error [mV]');
title('Voltage error');
legend('Location', 'best');

if est_a.has_r0 || est_b.has_r0
    figure('Name', 'ABest Comparison - R0', 'NumberTitle', 'off');
    if isfinite(results.dataset.r0_reference)
        yline(results.dataset.r0_reference, 'k--', 'LineWidth', 1.0, 'DisplayName', 'Reference R0');
        hold on;
    else
        hold on;
    end
    if est_a.has_r0
        plot(time_s, est_a.r0, '-', 'Color', est_a.color, 'LineWidth', 1.3, 'DisplayName', est_a.name);
    end
    if est_b.has_r0
        plot(time_s, est_b.r0, '--', 'Color', est_b.color, 'LineWidth', 1.3, 'DisplayName', est_b.name);
    end
    grid on;
    xlabel('Time [s]');
    ylabel('R0 [Ohm]');
    title('R0 estimate comparison');
    legend('Location', 'best');
end
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

function dataset = loadOrBuildRomDataset(dataset_file, profile_file, tc)
if exist(dataset_file, 'file') == 2
    loaded = load(dataset_file);
    if ~isfield(loaded, 'dataset')
        error('ABestComp:BadDatasetFile', 'Expected variable "dataset" in %s.', dataset_file);
    end
    dataset = loaded.dataset;
    return;
end

cfg = struct();
cfg.profile_file = profile_file;
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
    error('ABestComp:MissingReferenceSOC0', ...
        'No initial SOC is available from dataset.soc_true(1) or dataset.soc_init_percent.');
end
end

function value = getCfg(cfg, field_name, default_value)
if isfield(cfg, field_name) && ~isempty(cfg.(field_name))
    value = cfg.(field_name);
else
    value = default_value;
end
end

function value = getOptionalField(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end

function value = getFieldOr(s, field_name, default_value)
if isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end

function model = extractEscModelStruct(raw)
if isfield(raw, 'nmc30_model')
    model = raw.nmc30_model;
elseif isfield(raw, 'model')
    model = raw.model;
else
    error('ABestComp:BadESCModelFile', ...
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

function resolved = resolveExistingPath(input_path, base_dir)
if exist(input_path, 'file') == 2
    resolved = input_path;
    return;
end

candidate = fullfile(base_dir, input_path);
if exist(candidate, 'file') == 2
    resolved = candidate;
else
    resolved = input_path;
end
end

function resolved = resolveOutputPath(input_path, base_dir)
if exist(input_path, 'file') == 2
    resolved = input_path;
    return;
end

if isAbsolutePath(input_path)
    resolved = input_path;
else
    resolved = fullfile(base_dir, input_path);
end
end

function tf = isAbsolutePath(path_in)
path_in = char(path_in);
tf = numel(path_in) >= 2 && path_in(2) == ':';
end
