function sweepResults = runNoiseCovStudy(sigmaWRange, sigmaVRange, stepMultiplier, cfg)
% runNoiseCovStudy Wrapper for estimator noise-covariance sweep studies.
%
% Examples:
%   runNoiseCovStudy
%   runNoiseCovStudy([1e-4 1e0], [1e-4 1e0], 2)
%   runNoiseCovStudy([], [], [], struct('sweep_mode', 'sigma_w'))
%
% The wrapper owns the default tuning and plotting choices. By default it
% runs two lighter 1D sweeps:
%   1. sigma_w sweep with sigma_v fixed
%   2. sigma_v sweep with sigma_w fixed
%
% Set cfg.sweep_mode to:
%   'both'    default lighter pair of sweeps
%   'sigma_w' process-noise only
%   'sigma_v' sensor-noise only
%   'grid'    full 2D sigma_w / sigma_v sweep

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

cfg = normalizeWrapperConfig(cfg);

switch cfg.sweep_mode
    case 'both'
        sigma_w_cfg = cfg;
        sigma_w_cfg.sweep_mode = 'sigma_w';
        sigma_w_results = sweepNoiseStudy(sigmaWRange, sigmaVRange, stepMultiplier, sigma_w_cfg);
        if cfg.PlotEaEkfCovfigs
            plotEaEkfCovarianceSweeps(sigma_w_results);
        end

        sigma_v_cfg = cfg;
        sigma_v_cfg.sweep_mode = 'sigma_v';
        sigma_v_results = sweepNoiseStudy(sigmaWRange, sigmaVRange, stepMultiplier, sigma_v_cfg);
        if cfg.PlotEaEkfCovfigs
            plotEaEkfCovarianceSweeps(sigma_v_results);
        end

        sweepResults = struct();
        sweepResults.mode = 'both';
        sweepResults.sigma_w_sweep = sigma_w_results;
        sweepResults.sigma_v_sweep = sigma_v_results;

    case {'sigma_w', 'sigma_v', 'grid'}
        sweepResults = sweepNoiseStudy(sigmaWRange, sigmaVRange, stepMultiplier, cfg);
        if cfg.PlotEaEkfCovfigs
            plotEaEkfCovarianceSweeps(sweepResults);
        end

    otherwise
        error('runNoiseCovStudy:BadSweepMode', ...
            'cfg.sweep_mode must be "both", "sigma_w", "sigma_v", or "grid".');
end

if nargout == 0
    assignin('base', 'noiseCovSweepResults', sweepResults);
end
end

function cfg = normalizeWrapperConfig(cfg)
defaults = struct();
defaults.dataset_mode = 'rom';
defaults.tc = 25;
defaults.ts = 1;
defaults.sweep_mode = 'both';
defaults.fixed_sigma_w = 1e-3;
defaults.fixed_sigma_v = 1e-3;
defaults.NoiseSummaryfigs = false;
defaults.PlotSocRmsefigs = true;
defaults.PlotVoltageRmsefigs = true;
defaults.PlotEaEkfCovfigs = true;
defaults.tuning = defaultWrapperTuning();

cfg = mergeStructDefaults(cfg, defaults);
cfg.tuning = mergeStructDefaults(cfg.tuning, defaultWrapperTuning());
cfg.sweep_mode = lower(cfg.sweep_mode);
end

function tuning = defaultWrapperTuning()
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

function out = mergeStructDefaults(in, defaults)
out = defaults;
names = fieldnames(in);
for idx = 1:numel(names)
    out.(names{idx}) = in.(names{idx});
end
end

function plotEaEkfCovarianceSweeps(sweepResults)
ea_idx = find(strcmp(sweepResults.estimator_names, 'EaEKF'), 1, 'first');
if isempty(ea_idx)
    warning('runNoiseCovStudy:MissingEaEKF', 'EaEKF was not found in the sweep results.');
    return;
end

[process_diag, sensor_noise] = extractEaEkfCovariances(sweepResults, ea_idx);
if isempty(process_diag) || isempty(sensor_noise)
    warning('runNoiseCovStudy:MissingEaEKFCovariance', ...
        'EaEKF final SigmaW/SigmaV were not available in the sweep results.');
    return;
end

sigma_w_values = sweepResults.sigma_w_values(:);
sigma_v_values = sweepResults.sigma_v_values(:);
n_states = size(process_diag, 3);

if numel(sigma_w_values) > 1 && numel(sigma_v_values) > 1
    figure('Name', 'EaEKF Estimated Process Noise', 'NumberTitle', 'off');
    tiledlayout(n_states, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    for state_idx = 1:n_states
        nexttile;
        imagesc(log10(sigma_v_values), log10(sigma_w_values), process_diag(:, :, state_idx));
        axis xy;
        grid on;
        xlabel('log_{10}(\sigma_v)');
        ylabel('log_{10}(\sigma_w)');
        title(sprintf('EaEKF Estimated Process Noise Q(%d,%d)', state_idx, state_idx));
        cb = colorbar;
        ylabel(cb, 'Estimated Variance');
        xticks(log10(sigma_v_values));
        xticklabels(formatTickLabels(sigma_v_values));
        yticks(log10(sigma_w_values));
        yticklabels(formatTickLabels(sigma_w_values));
    end

    figure('Name', 'EaEKF Estimated Sensor Noise', 'NumberTitle', 'off');
    imagesc(log10(sigma_v_values), log10(sigma_w_values), sensor_noise);
    axis xy;
    grid on;
    xlabel('log_{10}(\sigma_v)');
    ylabel('log_{10}(\sigma_w)');
    title('EaEKF Estimated Sensor Noise R');
    cb = colorbar;
    ylabel(cb, 'Estimated Variance');
    xticks(log10(sigma_v_values));
    xticklabels(formatTickLabels(sigma_v_values));
    yticks(log10(sigma_w_values));
    yticklabels(formatTickLabels(sigma_w_values));
else
    swept_values = sigma_w_values;
    swept_label = '\sigma_w';
    if numel(sigma_v_values) > 1
        swept_values = sigma_v_values;
        swept_label = '\sigma_v';
    end

    figure('Name', 'EaEKF Estimated Process Noise', 'NumberTitle', 'off');
    tiledlayout(n_states, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    for state_idx = 1:n_states
        nexttile;
        semilogx(swept_values, extractLine(process_diag(:, :, state_idx)), '-o', 'LineWidth', 1.3);
        grid on;
        xlabel(swept_label);
        ylabel('Estimated Variance');
        title(sprintf('EaEKF Estimated Process Noise Q(%d,%d)', state_idx, state_idx));
    end

    figure('Name', 'EaEKF Estimated Sensor Noise', 'NumberTitle', 'off');
    semilogx(swept_values, extractLine(sensor_noise), '-o', 'LineWidth', 1.3);
    grid on;
    xlabel(swept_label);
    ylabel('Estimated Variance');
    title('EaEKF Estimated Sensor Noise R');
end
end

function [process_diag, sensor_noise] = extractEaEkfCovariances(sweepResults, ea_idx)
n_w = numel(sweepResults.sigma_w_values);
n_v = numel(sweepResults.sigma_v_values);
process_diag = [];
sensor_noise = NaN(n_w, n_v);

for w_idx = 1:n_w
    for v_idx = 1:n_v
        run_results = sweepResults.all_results{w_idx, v_idx};
        if isempty(run_results) || numel(run_results.estimators) < ea_idx
            continue;
        end

        kfData = run_results.estimators(ea_idx).kfDataFinal;
        if ~isstruct(kfData)
            continue;
        end

        q_diag = extractCovarianceDiagonal(kfData, 'SigmaW');
        if isempty(q_diag)
            continue;
        end
        if isempty(process_diag)
            process_diag = NaN(n_w, n_v, numel(q_diag));
        end
        process_diag(w_idx, v_idx, :) = q_diag(:);

        r_diag = extractCovarianceDiagonal(kfData, 'SigmaV');
        if ~isempty(r_diag)
            sensor_noise(w_idx, v_idx) = r_diag(1);
        end
    end
end
end

function diag_values = extractCovarianceDiagonal(kfData, field_name)
diag_values = [];
if ~isfield(kfData, field_name) || isempty(kfData.(field_name))
    return;
end

cov_value = kfData.(field_name);
if isscalar(cov_value)
    diag_values = double(cov_value);
elseif isvector(cov_value)
    diag_values = double(cov_value(:));
elseif ismatrix(cov_value)
    diag_values = double(diag(cov_value));
end
end

function labels = formatTickLabels(values)
labels = arrayfun(@(x) sprintf('%.3g', x), values, 'UniformOutput', false);
end

function line_values = extractLine(values)
if isvector(values)
    line_values = values(:);
elseif size(values, 1) == 1
    line_values = values(:);
else
    line_values = values(:, 1);
end
end
