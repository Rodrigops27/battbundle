function sweepResults = oneEstSweeNoise(sigmaWRange, sigmaVRange, stepMultiplier, cfg)
% oneEstSweeNoise Sweep noise covariances for a single estimator.
%
% Usage:
%   results = oneEstSweeNoise()
%   results = oneEstSweeNoise([1e0 1e2], [1e-6 2e-1], 5, cfg)
%
% Supported cfg.sweep_mode values:
%   'sigma_w' process-noise sweep with fixed sigma_v
%   'sigma_v' sensor-noise sweep with fixed sigma_w
%   'grid'    full 2D sweep
%
% Default estimator:
%   'ROM-EKF'

clear iterEKF;

if nargin < 1 || isempty(sigmaWRange)
    sigmaWRange = [1e0 1e2];
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
    cd(here);
end

repo_root = fileparts(fileparts(here));
addpath(genpath(repo_root));

cfg = normalizeStudyConfig(cfg, repo_root);
[sigma_w_values, sigma_v_values] = buildSweepAxes(cfg, sigmaWRange, sigmaVRange, stepMultiplier);

rom_src = load(cfg.rom_file);
esc_src = load(cfg.esc_model_file);
if ~isfield(rom_src, 'ROM')
    error('oneEstSweeNoise:BadROMFile', 'Expected variable "ROM" in %s.', cfg.rom_file);
end
ROM = rom_src.ROM;
model = extractEscModelStruct(esc_src);
evalDataset = buildEvalDataset(cfg, model);

flags = struct();
flags.SOCfigs = false;
flags.Vfigs = false;
flags.Summaryfigs = false;
flags.InnovationACFPACFfigs = false;
flags.R0figs = false;
flags.Biasfigs = false;
flags.default_temperature_c = cfg.tc;
flags.Verbose = false;

n_w = numel(sigma_w_values);
n_v = numel(sigma_v_values);
n_runs = n_w * n_v;

soc_rmse = NaN(n_w, n_v);
voltage_rmse = NaN(n_w, n_v);
soc_me = NaN(n_w, n_v);
voltage_me = NaN(n_w, n_v);
soc_mssd = NaN(n_w, n_v);
voltage_mssd = NaN(n_w, n_v);
nis_mean = NaN(n_w, n_v);
all_results = cell(n_w, n_v);
failure_mask = false(n_w, n_v);
failure_messages = cell(n_w, n_v);
failure_ids = cell(n_w, n_v);

for w_idx = 1:n_w
    for v_idx = 1:n_v
        noise_cfg = struct('sigma_w', sigma_w_values(w_idx), 'sigma_v', sigma_v_values(v_idx));
        estimator = buildEstimator(evalDataset.soc_init_reference, cfg, ROM, model, noise_cfg);
        try
            run_results = xKFeval(evalDataset, estimator, flags);
            all_results{w_idx, v_idx} = run_results;

            est_result = run_results.estimators(1);
            soc_rmse(w_idx, v_idx) = 100 * est_result.rmse_soc;
            voltage_rmse(w_idx, v_idx) = 1000 * est_result.rmse_voltage;
            soc_me(w_idx, v_idx) = 100 * est_result.me_soc;
            voltage_me(w_idx, v_idx) = 1000 * est_result.me_voltage;
            soc_mssd(w_idx, v_idx) = 1e4 * est_result.mssd_soc;
            voltage_mssd(w_idx, v_idx) = 1e6 * est_result.mssd_voltage;
            nis_mean(w_idx, v_idx) = computeInnovationRatio(est_result.innovation_pre, est_result.sk);
        catch ME
            failure_mask(w_idx, v_idx) = true;
            failure_messages{w_idx, v_idx} = ME.message;
            failure_ids{w_idx, v_idx} = ME.identifier;
            all_results{w_idx, v_idx} = struct( ...
                'error_identifier', ME.identifier, ...
                'error_message', ME.message, ...
                'sigma_w', sigma_w_values(w_idx), ...
                'sigma_v', sigma_v_values(v_idx));

            fprintf(['\n%s failed at sigma_w = %.3g, sigma_v = %.3g\n' ...
                '  %s\n'], cfg.estimator_name, sigma_w_values(w_idx), ...
                sigma_v_values(v_idx), ME.message);

            if ~cfg.continue_on_failure
                rethrow(ME);
            end
        end
    end
end

summary_table = buildSummaryTable(sigma_w_values, sigma_v_values, soc_rmse, voltage_rmse, soc_me, voltage_me, soc_mssd, voltage_mssd, nis_mean);
failure_table = buildFailureTable(sigma_w_values, sigma_v_values, failure_mask, failure_ids, failure_messages);

fprintf('\nSingle-estimator noise sweep (%s, %s dataset)\n', cfg.estimator_name, upper(cfg.dataset_mode));
fprintf('Sweep mode: %s\n', upper(cfg.sweep_mode));
fprintf('sigma_w values: %s\n', formatSweepVector(sigma_w_values));
fprintf('sigma_v values: %s\n', formatSweepVector(sigma_v_values));
disp(summary_table);

if ~isempty(failure_table)
    fprintf('\nFailed sweep points: %d / %d\n', height(failure_table), n_runs);
    if cfg.print_failure_table
        disp(failure_table);
    end
end

if ~all(isnan(soc_rmse(:)))
    best_point = summary_table(1, :);
    fprintf(['\nBest SOC RMSE point for %s: sigma_w = %.3g, sigma_v = %.3g, ', ...
        'SOC RMSE = %.3f%%, SOC ME = %.3f%%, SOC MSSD = %.6f %%^2, ', ...
        'V RMSE = %.2f mV, V ME = %.2f mV, V MSSD = %.4f mV^2, mean NIS = %.3f\n'], ...
        cfg.estimator_name, best_point.BestSigmaW, best_point.BestSigmaV, ...
        best_point.BestSocRmsePct, best_point.BestSocMePct, best_point.BestSocMssdPct2, ...
        best_point.VoltageRmseMvAtBestSoc, best_point.VoltageMeMvAtBestSoc, best_point.VoltageMssdMv2AtBestSoc, ...
        best_point.MeanNISAtBestSoc);
else
    fprintf('\nNo successful sweep points were completed for %s.\n', cfg.estimator_name);
end

if cfg.PlotSocMetricfigs
    plotMetricFigures(sigma_w_values, sigma_v_values, soc_rmse, soc_me, soc_mssd, ...
        'SOC', 'SOC RMSE [%]', 'SOC ME [%]', 'SOC MSSD [%^2]', cfg.sweep_mode, cfg.estimator_name);
end
if cfg.PlotVoltageMetricfigs
    plotMetricFigures(sigma_w_values, sigma_v_values, voltage_rmse, voltage_me, voltage_mssd, ...
        'Voltage', 'Voltage RMSE [mV]', 'Voltage ME [mV]', 'Voltage MSSD [mV^2]', cfg.sweep_mode, cfg.estimator_name);
end
if cfg.PlotInnovationMetricfigs
    plotInnovationFigure(sigma_w_values, sigma_v_values, nis_mean, cfg.sweep_mode, cfg.estimator_name);
end

sweepResults = struct();
sweepResults.estimator_name = cfg.estimator_name;
sweepResults.dataset_mode = cfg.dataset_mode;
sweepResults.sweep_mode = cfg.sweep_mode;
sweepResults.sigma_w_values = sigma_w_values(:);
sweepResults.sigma_v_values = sigma_v_values(:);
sweepResults.soc_rmse_percent = soc_rmse;
sweepResults.voltage_rmse_mv = voltage_rmse;
sweepResults.soc_me_percent = soc_me;
sweepResults.voltage_me_mv = voltage_me;
sweepResults.soc_mssd_percent2 = soc_mssd;
sweepResults.voltage_mssd_mv2 = voltage_mssd;
sweepResults.mean_nis = nis_mean;
sweepResults.summary_table = summary_table;
sweepResults.failure_mask = failure_mask;
sweepResults.failure_table = failure_table;
sweepResults.failure_messages = failure_messages;
sweepResults.failure_ids = failure_ids;
sweepResults.evalDataset = evalDataset;
sweepResults.all_results = all_results;
sweepResults.total_runs = n_runs;

if nargout == 0
    assignin('base', 'oneEstNoiseSweepResults', sweepResults);
end
end

function cfg = normalizeStudyConfig(cfg, repo_root)
defaults = struct();
defaults.estimator_name = 'ROM-EKF';
defaults.dataset_mode = 'rom';
defaults.tc = 25;
defaults.ts = 1;
defaults.sweep_mode = 'sigma_w';
defaults.fixed_sigma_w = 1e2;
defaults.fixed_sigma_v = 1e-2;
defaults.PlotSocMetricfigs = true;
defaults.PlotVoltageMetricfigs = true;
defaults.PlotInnovationMetricfigs = true;
defaults.continue_on_failure = true;
defaults.print_failure_table = true;
defaults.rom_dataset_file = fullfile(repo_root, 'Evaluation', 'ROMSimData', 'datasets', 'rom_bus_coreBattery_dataset.mat');
defaults.raw_bus_file = fullfile(repo_root, 'Evaluation', 'OMTLIFE8AHC-HP', 'Bus_CoreBatteryData_Data.mat');
defaults.rom_file = firstExistingFile({ ...
    fullfile(repo_root, 'models', 'ROM_NMC30_HRA12.mat'), ...
    fullfile(repo_root, 'models', 'ROM_NMC30_HRA.mat')}, ...
    'oneEstSweeNoise:MissingROMFile', ...
    'No ROM model file found.');
defaults.esc_model_file = firstExistingFile({ ...
    fullfile(repo_root, 'models', 'NMC30model.mat'), ...
    fullfile(repo_root, 'ESC_Id', 'NMC30', 'NMC30model.mat')}, ...
    'oneEstSweeNoise:MissingESCModel', ...
    'No NMC30 ESC model file found.');
defaults.tuning = defaultStudyTuning();

cfg = mergeStructDefaults(cfg, defaults);
cfg.tuning = mergeStructDefaults(cfg.tuning, defaultStudyTuning());
cfg.sweep_mode = lower(cfg.sweep_mode);
cfg.estimator_name = normalizeCharValue(cfg.estimator_name, 'oneEstSweeNoise:BadEstimatorName');
cfg.estimator_name = normalizeEstimatorName(cfg.estimator_name);
end

function estimator_name = normalizeEstimatorName(raw_name)
key = regexprep(upper(raw_name), '[^A-Z0-9]', '');
switch key
    case {'ITEREKF', 'ITERROMEKF', 'ROMEKF'}
        estimator_name = 'ROM-EKF';
    otherwise
        estimator_name = raw_name;
end
end

function tuning = defaultStudyTuning()
tuning = struct();
tuning.sigma_x0_rom_tail = 2e6;
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
        error('oneEstSweeNoise:BadSweepMode', ...
            'cfg.sweep_mode must be "sigma_w", "sigma_v", or "grid".');
end
end

function sweep_values = buildLogLikeSweep(valueRange, stepMultiplier)
if ~isnumeric(valueRange) || numel(valueRange) ~= 2
    error('oneEstSweeNoise:BadRange', 'Sweep ranges must be two-element numeric vectors.');
end
if ~isscalar(stepMultiplier) || ~isfinite(stepMultiplier) || stepMultiplier <= 1
    error('oneEstSweeNoise:BadMultiplier', 'stepMultiplier must be a scalar greater than 1.');
end

range = sort(double(valueRange(:).'));
if any(range <= 0)
    error('oneEstSweeNoise:BadRange', 'Sweep ranges must be strictly positive.');
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
        evalDataset.title_prefix = sprintf('%s Noise Sweep', cfg.estimator_name);

    case 'bus_raw'
        error('oneEstSweeNoise:UnsupportedDatasetMode', ...
            'The single-estimator study currently supports dataset_mode = "rom" only.');

    otherwise
        error('oneEstSweeNoise:BadDatasetMode', ...
            'Unsupported dataset_mode "%s".', cfg.dataset_mode);
end
end

function estimators = buildEstimator(soc_init_kf, cfg, ROM, model, noise_cfg)
switch upper(cfg.estimator_name)
    case 'ROM-EKF'
        n_rom_states = inferRomTransientStateCount(ROM, getFieldOr(cfg.tuning, 'nx_rom', []));
        sigma_x0_rom = diag([ones(1, n_rom_states), cfg.tuning.sigma_x0_rom_tail]);
        estimators = makeEstimator( ...
            'ROM-EKF', ...
            initKF(soc_init_kf, cfg.tc, sigma_x0_rom, noise_cfg.sigma_v, noise_cfg.sigma_w, 'OutB', ROM), ...
            @stepRomEkf, soc_init_kf, [0.64 0.08 0.18], '-');

    case 'EM7SPKF'
        n_rc = numel(getParamESC('RCParam', cfg.tc, model));
        SigmaX0 = diag([ ...
            getFieldOr(cfg.tuning, 'SigmaX0_rc', 1e-6) * ones(1, n_rc), ...
            getFieldOr(cfg.tuning, 'SigmaX0_hk', 1e-6), ...
            getFieldOr(cfg.tuning, 'SigmaX0_soc', 1e-3)]);
        R0init = getParamESC('R0Param', cfg.tc, model);
        estimators = makeEstimator( ...
            'Em7SPKF', ...
            initEm7Spkf(soc_init_kf, R0init, cfg.tc, SigmaX0, noise_cfg.sigma_v, noise_cfg.sigma_w, ...
            getFieldOr(cfg.tuning, 'SigmaR0', 1e-6), getFieldOr(cfg.tuning, 'SigmaWR0', 1e-16), ...
            getFieldOr(cfg.tuning, 'current_bias_var0', 1e-5), model), ...
            @stepEm7Spkf, soc_init_kf, [0.82 0.23 0.47], '-');
        estimators.tracksR0 = true;
        estimators.r0_init = estimators.kfData.R0hat;
        estimators.bias_dim = 1;
        estimators.bias_init = estimators.kfData.bhat(:).';
        estimators.bias_bnd_init = 3 * sqrt(max(diag(estimators.kfData.SigmaB), 0)).';
    otherwise
        error('oneEstSweeNoise:UnsupportedEstimator', ...
            'Supported estimator_name values are "ROM-EKF" and "Em7SPKF".');
end
end

function summary_table = buildSummaryTable(sigma_w_values, sigma_v_values, soc_rmse, voltage_rmse, soc_me, voltage_me, soc_mssd, voltage_mssd, nis_mean)
valid_mask = isfinite(soc_rmse);
if ~any(valid_mask(:))
    summary_table = table(NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
        'VariableNames', {'BestSigmaW', 'BestSigmaV', 'BestSocRmsePct', 'BestSocMePct', ...
        'BestSocMssdPct2', 'VoltageRmseMvAtBestSoc', 'VoltageMeMvAtBestSoc', ...
        'VoltageMssdMv2AtBestSoc', 'MeanNISAtBestSoc'});
    return;
end

[best_val, linear_idx] = min(soc_rmse(valid_mask));
valid_linear_idx = find(valid_mask);
linear_idx = valid_linear_idx(linear_idx);
[w_idx, v_idx] = ind2sub(size(soc_rmse), linear_idx);

summary_table = table( ...
    sigma_w_values(w_idx), sigma_v_values(v_idx), best_val, soc_me(w_idx, v_idx), ...
    soc_mssd(w_idx, v_idx), voltage_rmse(w_idx, v_idx), voltage_me(w_idx, v_idx), ...
    voltage_mssd(w_idx, v_idx), nis_mean(w_idx, v_idx), ...
    'VariableNames', {'BestSigmaW', 'BestSigmaV', 'BestSocRmsePct', 'BestSocMePct', ...
    'BestSocMssdPct2', 'VoltageRmseMvAtBestSoc', 'VoltageMeMvAtBestSoc', ...
    'VoltageMssdMv2AtBestSoc', 'MeanNISAtBestSoc'});
end

function failure_table = buildFailureTable(sigma_w_values, sigma_v_values, failure_mask, failure_ids, failure_messages)
[w_idx, v_idx] = find(failure_mask);
if isempty(w_idx)
    failure_table = table();
    return;
end

n_fail = numel(w_idx);
sigma_w = NaN(n_fail, 1);
sigma_v = NaN(n_fail, 1);
error_id = strings(n_fail, 1);
error_message = strings(n_fail, 1);
for idx = 1:n_fail
    sigma_w(idx) = sigma_w_values(w_idx(idx));
    sigma_v(idx) = sigma_v_values(v_idx(idx));
    error_id(idx) = string(failure_ids{w_idx(idx), v_idx(idx)});
    error_message(idx) = string(failure_messages{w_idx(idx), v_idx(idx)});
end

failure_table = table(sigma_w, sigma_v, error_id, error_message, ...
    'VariableNames', {'SigmaW', 'SigmaV', 'ErrorId', 'ErrorMessage'});
end

function plotMetricFigures(sigma_w_values, sigma_v_values, rmse_values, me_values, mssd_values, metric_prefix, rmse_label, me_label, mssd_label, sweep_mode, estimator_name)
if strcmp(sweep_mode, 'grid')
    figure('Name', sprintf('%s Noise Sweep - %s RMSE', estimator_name, metric_prefix), 'NumberTitle', 'off');
    imagesc(log10(sigma_v_values), log10(sigma_w_values), rmse_values);
    axis xy;
    grid on;
    xlabel('log_{10}(\sigma_v)');
    ylabel('log_{10}(\sigma_w)');
    title(sprintf('%s %s RMSE', estimator_name, metric_prefix));
    cb = colorbar;
    ylabel(cb, rmse_label);
    xticks(log10(sigma_v_values));
    xticklabels(formatTickLabels(sigma_v_values));
    yticks(log10(sigma_w_values));
    yticklabels(formatTickLabels(sigma_w_values));

    figure('Name', sprintf('%s Noise Sweep - %s ME', estimator_name, metric_prefix), 'NumberTitle', 'off');
    imagesc(log10(sigma_v_values), log10(sigma_w_values), me_values);
    axis xy;
    grid on;
    xlabel('log_{10}(\sigma_v)');
    ylabel('log_{10}(\sigma_w)');
    title(sprintf('%s %s ME', estimator_name, metric_prefix));
    cb = colorbar;
    ylabel(cb, me_label);
    xticks(log10(sigma_v_values));
    xticklabels(formatTickLabels(sigma_v_values));
    yticks(log10(sigma_w_values));
    yticklabels(formatTickLabels(sigma_w_values));

    figure('Name', sprintf('%s Noise Sweep - %s MSSD', estimator_name, metric_prefix), 'NumberTitle', 'off');
    imagesc(log10(sigma_v_values), log10(sigma_w_values), mssd_values);
    axis xy;
    grid on;
    xlabel('log_{10}(\sigma_v)');
    ylabel('log_{10}(\sigma_w)');
    title(sprintf('%s %s MSSD', estimator_name, metric_prefix));
    cb = colorbar;
    ylabel(cb, mssd_label);
    xticks(log10(sigma_v_values));
    xticklabels(formatTickLabels(sigma_v_values));
    yticks(log10(sigma_w_values));
    yticklabels(formatTickLabels(sigma_w_values));
else
    x_values = sigma_w_values;
    x_label = '\sigma_w';
    rmse_curve = rmse_values(:, 1);
    me_curve = me_values(:, 1);
    mssd_curve = mssd_values(:, 1);
    if strcmp(sweep_mode, 'sigma_v')
        x_values = sigma_v_values;
        x_label = '\sigma_v';
        rmse_curve = rmse_values(1, :).';
        me_curve = me_values(1, :).';
        mssd_curve = mssd_values(1, :).';
    end

    figure('Name', sprintf('%s Noise Sweep - %s Metrics', estimator_name, metric_prefix), 'NumberTitle', 'off');
    tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    semilogx(x_values, rmse_curve, '-o', 'LineWidth', 1.4);
    grid on;
    xlabel(x_label);
    ylabel(rmse_label);
    title(sprintf('%s %s RMSE', estimator_name, metric_prefix));

    nexttile;
    semilogx(x_values, me_curve, '-o', 'LineWidth', 1.4);
    grid on;
    xlabel(x_label);
    ylabel(me_label);
    title(sprintf('%s %s ME', estimator_name, metric_prefix));

    nexttile;
    semilogx(x_values, mssd_curve, '-o', 'LineWidth', 1.4);
    grid on;
    xlabel(x_label);
    ylabel(mssd_label);
    title(sprintf('%s %s MSSD', estimator_name, metric_prefix));
end
end

function plotInnovationFigure(sigma_w_values, sigma_v_values, nis_mean, sweep_mode, estimator_name)
if strcmp(sweep_mode, 'grid')
    figure('Name', sprintf('%s Noise Sweep - Mean NIS', estimator_name), 'NumberTitle', 'off');
    imagesc(log10(sigma_v_values), log10(sigma_w_values), nis_mean);
    axis xy;
    grid on;
    xlabel('log_{10}(\sigma_v)');
    ylabel('log_{10}(\sigma_w)');
    title(sprintf('%s Mean Innovation Ratio', estimator_name));
    cb = colorbar;
    ylabel(cb, 'Mean innovation^2 / S_k');
    xticks(log10(sigma_v_values));
    xticklabels(formatTickLabels(sigma_v_values));
    yticks(log10(sigma_w_values));
    yticklabels(formatTickLabels(sigma_w_values));
else
    x_values = sigma_w_values;
    x_label = '\sigma_w';
    nis_curve = nis_mean(:, 1);
    if strcmp(sweep_mode, 'sigma_v')
        x_values = sigma_v_values;
        x_label = '\sigma_v';
        nis_curve = nis_mean(1, :).';
    end

    figure('Name', sprintf('%s Noise Sweep - Mean NIS', estimator_name), 'NumberTitle', 'off');
    semilogx(x_values, nis_curve, '-o', 'LineWidth', 1.4); hold on;
    yline(1, 'k--', 'LineWidth', 1.0, 'DisplayName', 'Ideal NIS = 1');
    grid on;
    xlabel(x_label);
    ylabel('Mean innovation^2 / S_k');
    title(sprintf('%s Innovation Consistency', estimator_name));
    legend('NIS mean', 'Ideal NIS = 1', 'Location', 'best');
end
end

function value = computeInnovationRatio(innovation_pre, sk)
valid = isfinite(innovation_pre) & isfinite(sk) & sk > 0;
if ~any(valid)
    value = NaN;
    return;
end
value = mean((innovation_pre(valid) .^ 2) ./ sk(valid));
end

function estimator = makeEstimator(name, kfData, stepFcn, soc0_percent, color, lineStyle)
estimator = struct( ...
    'name', name, ...
    'kfData', kfData, ...
    'stepFcn', stepFcn, ...
    'soc0_percent', soc0_percent, ...
    'color', color, ...
    'lineStyle', lineStyle, ...
    'tracksR0', false, ...
    'r0_init', NaN, ...
    'bias_dim', 0, ...
    'bias_init', [], ...
    'bias_bnd_init', []);
end

function step = stepRomEkf(vk, ik, Tk, ~, kfData)
[zk, boundzk, kfData] = iterEKF(vk, ik, Tk, kfData);
step = struct();
step.soc = zk(end);
step.voltage = zk(end-1);
step.soc_bnd = boundzk(end);
step.voltage_bnd = boundzk(end-1);
step.kfData = kfData;
step.innovation_pre = getFieldOr(kfData, 'lastInnovationPre', NaN);
step.sk = getFieldOr(kfData, 'lastSk', NaN);
step.r0 = NaN;
step.r0_bnd = NaN;
step.bias = [];
step.bias_bnd = [];
end

function step = stepEm7Spkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd, bias_est, bias_bnd, r0_est, r0_bnd] = Em7SPKF(vk, ik, Tk, dt, kfData);
step = struct();
step.soc = soc;
step.voltage = v_pred;
step.soc_bnd = soc_bnd;
step.voltage_bnd = v_bnd;
step.kfData = kfData;
step.innovation_pre = getFieldOr(kfData, 'lastInnovationPre', NaN);
step.sk = getFieldOr(kfData, 'lastSk', NaN);
step.r0 = r0_est;
step.r0_bnd = r0_bnd;
step.bias = bias_est;
step.bias_bnd = bias_bnd;
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
        error('oneEstSweeNoise:BadDatasetFile', 'Expected variable "dataset" in %s.', dataset_file);
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
    error('oneEstSweeNoise:MissingReferenceSOC0', ...
        'No initial SOC is available from dataset.soc_true(1) or dataset.soc_init_percent.');
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

function value = normalizeCharValue(raw_value, error_id)
if ischar(raw_value)
    value = raw_value;
elseif isa(raw_value, 'string') && isscalar(raw_value)
    value = char(raw_value);
else
    error(error_id, 'Expected a character vector or scalar string.');
end
end

function labels = formatTickLabels(values)
labels = arrayfun(@(x) sprintf('%.3g', x), values, 'UniformOutput', false);
end

function text_value = formatSweepVector(values)
text_value = strjoin(formatTickLabels(values), ', ');
end

function model = extractEscModelStruct(raw)
if isfield(raw, 'nmc30_model')
    model = raw.nmc30_model;
elseif isfield(raw, 'model')
    model = raw.model;
else
    error('oneEstSweeNoise:BadESCModelFile', ...
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

error('oneEstSweeNoise:MissingROMStateCount', ...
    'Could not infer the ROM transient-state count from ROM.ROMmdls.');
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
