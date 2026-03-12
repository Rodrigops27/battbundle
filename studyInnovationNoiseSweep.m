% studyInnovationNoiseSweep.m
% Sweep process-noise and sensor-noise covariances to study innovation
% lag-1 autocorrelation drift toward/away from 0.
%
% Sweeps:
%   1) sigma_w in [1e-6, ..., 1e2], sigma_v fixed
%   2) sigma_v in [1e-6, ..., 1e2], sigma_w fixed
%
% Estimators included:
%   - ROM-EKF
%   - ESC-SPKF
%   - EBiSPKF
%   - EsSPKF
%
% Notes:
%   - NIS in this project is scalar (m = 1), i.e., NIS_k = nu_k^2 / S_k.
%   - This study uses pre-fit innovation nu_k from each estimator iteration.

clear; clc;

script_fullpath = mfilename('fullpath');
if isempty(script_fullpath)
    script_fullpath = which('studyInnovationNoiseSweep');
end
if isempty(script_fullpath)
    script_dir = pwd;
else
    script_dir = fileparts(script_fullpath);
end
project_root = fileparts(fileparts(fileparts(script_dir)));

% Ensure required subfolders are reachable when script is run directly.
addpath(script_dir);
addpath(fullfile(script_dir, 'utility'));
addpath(fullfile(script_dir, 'utility', 'estimators'));
addpath(fullfile(script_dir, 'utility', 'ESCmgmt'));

%% Study settings
tc = 25;
ts = 1;
soc_init = 100;

sigma_w_fixed = 1e2;
sigma_v_fixed = 1e-3;
sigma_w_values = 10 .^ (-6:2);
sigma_v_values = 10 .^ (-6:2);

estimator_labels = {'ROM-EKF', 'ESC-SPKF', 'EBiSPKF', 'EsSPKF'};
n_estimators = numel(estimator_labels);
n_sigma_w = numel(sigma_w_values);
n_sigma_v = numel(sigma_v_values);

%% Load models
rom_file = firstExistingFile({ ...
    fullfile(script_dir, 'models', 'ROM_NMC30_HRA12.mat'), ...
    fullfile(script_dir, 'ROM_NMC30_HRA12.mat'), ...
    fullfile(project_root, 'models', 'ROM_NMC30_HRA12.mat'), ...
    fullfile(project_root, 'src', 'MPC-EKF4FastCharge', 'ROM_NMC30_HRA12.mat')}, ...
    'studyInnovationNoiseSweep:MissingROMFile', ...
    'No ROM model file found.');

esc_model_file = firstExistingFile({ ...
    fullfile(script_dir, 'models', 'NMC30model.mat'), ...
    fullfile(script_dir, 'NMC30model.mat'), ...
    fullfile(script_dir, 'ESC_Id', 'NMC30model.mat'), ...
    fullfile(project_root, 'models', 'NMC30model.mat')}, ...
    'studyInnovationNoiseSweep:MissingFullESCModel', ...
    'No NMC30 full ESC model found.');

rom_data = load(rom_file);
ROM = rom_data.ROM;
esc_data = load(esc_model_file);
nmc30_esc = esc_data.nmc30_model;

if ~isfield(nmc30_esc, 'RCParam')
    error('studyInnovationNoiseSweep:MissingRCParam', ...
        'Loaded ESC model is not full: RCParam is missing.');
end
n_rc = numel(getParamESC('RCParam', tc, nmc30_esc));
if n_rc < 1
    error('studyInnovationNoiseSweep:NoRCBranches', ...
        'Loaded ESC model is not full: no RC branches detected.');
end

fprintf('Loaded models: ROM states=%d, ESC RC branches=%d\n', size(ROM.ROMmdls, 2), n_rc);

%% Build profile + ground-truth ROM voltage once
capacity_ah = nmc30_esc.QParam;
i_1c = capacity_ah;
[i_profile, ~] = buildScript1Profile(i_1c, capacity_ah, ts);
i_profile = i_profile(:);
t = (0:length(i_profile)-1).' * ts;
n_samples = numel(t);

rom_voltage = NaN(n_samples, 1);
init_cfg = struct('SOC0', soc_init, 'warnOff', true);
rom_state = [];
for k = 1:n_samples
    if k == 1
        [rom_voltage(k), ~, rom_state] = OB_step(i_profile(k), tc, [], ROM, init_cfg);
    else
        [rom_voltage(k), ~, rom_state] = OB_step(i_profile(k), tc, rom_state, ROM, []);
    end
end

%% Sweep 1: sigma_w
rho_w = NaN(n_sigma_w, n_estimators);
for idx = 1:n_sigma_w
    sigma_w = sigma_w_values(idx);
    sigma_v = sigma_v_fixed;

    innov = runEstimatorsForNoise( ...
        rom_voltage, i_profile, tc, ts, soc_init, ROM, nmc30_esc, n_rc, sigma_w, sigma_v);

    rho_w(idx, :) = [ ...
        lag1Autocorr(innov.ekf), ...
        lag1Autocorr(innov.spkf), ...
        lag1Autocorr(innov.ebispkf), ...
        lag1Autocorr(innov.esspkf)];

    fprintf('sigma_w sweep %2d/%2d: sigma_w=%g, sigma_v=%g\n', idx, n_sigma_w, sigma_w, sigma_v);
end

%% Sweep 2: sigma_v
rho_v = NaN(n_sigma_v, n_estimators);
for idx = 1:n_sigma_v
    sigma_w = sigma_w_fixed;
    sigma_v = sigma_v_values(idx);

    innov = runEstimatorsForNoise( ...
        rom_voltage, i_profile, tc, ts, soc_init, ROM, nmc30_esc, n_rc, sigma_w, sigma_v);

    rho_v(idx, :) = [ ...
        lag1Autocorr(innov.ekf), ...
        lag1Autocorr(innov.spkf), ...
        lag1Autocorr(innov.ebispkf), ...
        lag1Autocorr(innov.esspkf)];

    fprintf('sigma_v sweep %2d/%2d: sigma_w=%g, sigma_v=%g\n', idx, n_sigma_v, sigma_w, sigma_v);
end

%% Print compact tables
fprintf('\nLag-1 innovation autocorrelation vs sigma_w (sigma_v fixed = %g)\n', sigma_v_fixed);
printLag1Table(sigma_w_values, estimator_labels, rho_w);

fprintf('\nLag-1 innovation autocorrelation vs sigma_v (sigma_w fixed = %g)\n', sigma_w_fixed);
printLag1Table(sigma_v_values, estimator_labels, rho_v);

%% Plots: lag-1 autocorrelation trends
figure('Name', 'Innovation Lag-1 Autocorrelation Noise Sweep', 'NumberTitle', 'off');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
for j = 1:n_estimators
    semilogx(sigma_w_values, rho_w(:, j), '-o', 'LineWidth', 1.4, 'DisplayName', estimator_labels{j});
    hold on;
end
yline(0, 'k--', 'HandleVisibility', 'off');
grid on; xlabel('sigma_w'); ylabel('lag-1 autocorrelation');
title(sprintf('Process noise sweep (sigma_v fixed = %.1e)', sigma_v_fixed));
legend('Location', 'best');

nexttile;
for j = 1:n_estimators
    semilogx(sigma_v_values, rho_v(:, j), '-o', 'LineWidth', 1.4, 'DisplayName', estimator_labels{j});
    hold on;
end
yline(0, 'k--', 'HandleVisibility', 'off');
grid on; xlabel('sigma_v'); ylabel('lag-1 autocorrelation');
title(sprintf('Sensor noise sweep (sigma_w fixed = %.1e)', sigma_w_fixed));
legend('Location', 'best');

%% Optional: ACF/PACF snapshots for ROM-EKF at low/base/high sigma_w
snapshot_idx = [1, ceil(n_sigma_w/2), n_sigma_w];
snapshot_labels = cell(1, numel(snapshot_idx));
snapshot_series = cell(1, numel(snapshot_idx));
for n = 1:numel(snapshot_idx)
    idx = snapshot_idx(n);
    sigma_w = sigma_w_values(idx);
    sigma_v = sigma_v_fixed;
    innov = runEstimatorsForNoise( ...
        rom_voltage, i_profile, tc, ts, soc_init, ROM, nmc30_esc, n_rc, sigma_w, sigma_v);
    snapshot_series{n} = innov.ekf;
    snapshot_labels{n} = sprintf('ROM-EKF, sigma_w = %.0e', sigma_w_values(idx));
end
plotInnovationAcfPacf(snapshot_series, snapshot_labels, 60, 'ROM-EKF pre-fit innovation ACF/PACF snapshots');

%% Export result struct
noiseSweepResults = struct();
noiseSweepResults.sigma_w_values = sigma_w_values;
noiseSweepResults.sigma_v_values = sigma_v_values;
noiseSweepResults.sigma_w_fixed = sigma_w_fixed;
noiseSweepResults.sigma_v_fixed = sigma_v_fixed;
noiseSweepResults.estimators = estimator_labels;
noiseSweepResults.rho_w = rho_w;
noiseSweepResults.rho_v = rho_v;
noiseSweepResults.timestamp = datetime('now');

fprintf('\nStudy complete. Results available in variable: noiseSweepResults\n');

function innov = runEstimatorsForNoise(rom_voltage, i_profile, tc, ts, soc_init, ROM, model, n_rc, sigma_w, sigma_v)
n_samples = numel(i_profile);

innov = struct('ekf', NaN(n_samples, 1), 'spkf', NaN(n_samples, 1), ...
    'ebispkf', NaN(n_samples, 1), 'esspkf', NaN(n_samples, 1));

% ROM-EKF
nx = 12;
sigma_x0 = diag([ones(1, nx), 2e6]);
ekf_data = initKF(soc_init, tc, sigma_x0, sigma_v, sigma_w, 'OutB', ROM);
for k = 2:n_samples
    [~, ~, ekf_data] = iterEKF(rom_voltage(k), i_profile(k), tc, ekf_data);
    if isfield(ekf_data, 'lastInnovationPre')
        innov.ekf(k) = ekf_data.lastInnovationPre;
    end
end

% ESC-SPKF
SigmaX0 = diag([1e-6 * ones(1, n_rc), 1e-6, 1e-3]);
spkf_esc = initESCSPKF(soc_init, tc, SigmaX0, sigma_v, sigma_w, model);
for k = 2:n_samples
    [~, ~, ~, spkf_esc, ~] = iterESCSPKF(rom_voltage(k), i_profile(k), tc, ts, spkf_esc);
    if isfield(spkf_esc, 'lastInnovationPre')
        innov.spkf(k) = spkf_esc.lastInnovationPre;
    end
end

% EBiSPKF
nx_esc = n_rc + 2;
nb_bias = 2;
current_bias_idx = 1;
output_bias_idx = 2;

RC_bias = exp(-ts./abs(getParamESC('RCParam', tc, model)))';
R_bias = getParamESC('RParam', tc, model)';
M_bias = getParamESC('MParam', tc, model);
Q_bias = getParamESC('QParam', tc, model);
R0_bias = getParamESC('R0Param', tc, model);

Bb_bias = zeros(nx_esc, nb_bias);
Bb_bias(1:n_rc, current_bias_idx) = -(1 - RC_bias);
Bb_bias(nx_esc, current_bias_idx) = ts / (3600 * Q_bias);
Cb_bias = zeros(1, nb_bias);
Cb_bias(1, current_bias_idx) = R0_bias;
Cb_bias(1, output_bias_idx) = 1;

Ad_bias = eye(nx_esc);
Ad_bias(1:n_rc, 1:n_rc) = diag(RC_bias);

soc0_norm = soc_init / 100;
ds = 1e-6;
soc_hi = min(1.05, soc0_norm + ds);
soc_lo = max(-0.05, soc0_norm - ds);
dOCVdSOC0 = (OCVfromSOCtemp(soc_hi, tc, model) - OCVfromSOCtemp(soc_lo, tc, model)) / ...
    max(soc_hi - soc_lo, eps);

Cd_bias = zeros(1, nx_esc);
Cd_bias(1, 1:n_rc) = -R_bias;
Cd_bias(1, n_rc + 1) = M_bias;
Cd_bias(1, nx_esc) = dOCVdSOC0;

biasCfg = struct();
biasCfg.nb = nb_bias;
biasCfg.bhat0 = [0; 0];
biasCfg.SigmaB0 = diag([1e-5, 1e-5]);
biasCfg.Bb = Bb_bias;
biasCfg.Cb = Cb_bias;
biasCfg.biasModelStatic = true;
biasCfg.Ad = Ad_bias;
biasCfg.Cd = Cd_bias;
biasCfg.currentBiasInd = current_bias_idx;

ebispkf_esc = initESCSPKF(soc_init, tc, SigmaX0, sigma_v, sigma_w, model, biasCfg);
for k = 2:n_samples
    [~, ~, ~, ebispkf_esc, ~, ~, ~] = iterEBiSPKF(rom_voltage(k), i_profile(k), tc, ts, ebispkf_esc);
    if isfield(ebispkf_esc, 'lastInnovationPre')
        innov.ebispkf(k) = ebispkf_esc.lastInnovationPre;
    end
end

% EsSPKF
SigmaR0 = 1e-6;
SigmaWR0 = 1e-16;
R0init = getParamESC('R0Param', tc, model);
esspkf_esc = initEDUKF(soc_init, R0init, tc, SigmaX0, sigma_v, sigma_w, SigmaR0, SigmaWR0, model);
for k = 2:n_samples
    [~, ~, ~, esspkf_esc, ~, ~, ~] = iterEsSPKF(rom_voltage(k), i_profile(k), tc, ts, esspkf_esc);
    if isfield(esspkf_esc, 'lastInnovationPre')
        innov.esspkf(k) = esspkf_esc.lastInnovationPre;
    end
end
end

function rho = lag1Autocorr(x)
x = x(:);
x = x(isfinite(x));
if numel(x) < 3
    rho = NaN;
    return;
end
x = x - mean(x);
x0 = x(1:end-1);
x1 = x(2:end);
den = sqrt(sum(x0.^2) * sum(x1.^2));
if den <= eps
    rho = NaN;
else
    rho = sum(x0 .* x1) / den;
end
end

function printLag1Table(scales, labels, rho)
header = sprintf('%12s', 'scale');
for j = 1:numel(labels)
    header = [header, sprintf('%14s', labels{j})]; %#ok<AGROW>
end
fprintf('%s\n', header);
for i = 1:numel(scales)
    line = sprintf('%12.4g', scales(i));
    for j = 1:size(rho, 2)
        line = [line, sprintf('%14.4f', rho(i, j))]; %#ok<AGROW>
    end
    fprintf('%s\n', line);
end
end

function file_path = firstExistingFile(candidates, error_id, error_msg)
file_path = '';
for idx = 1:numel(candidates)
    if exist(candidates{idx}, 'file')
        file_path = candidates{idx};
        return;
    end
end
searched = sprintf('\n  - %s', candidates{:});
error(error_id, '%s Searched:%s', error_msg, searched);
end

function [current_a, step_id] = buildScript1Profile(i_1c, capacity_ah, ts)
current_a = [];
step_id = [];
target_discharge_ah = 0.90 * capacity_ah;

[current_a, step_id] = appendSegment(current_a, step_id, 0, 10 * 60, 1, ts);
[current_a, step_id] = appendSegment(current_a, step_id, i_1c, ...
    0.10 * capacity_ah * 3600 / i_1c, 2, ts);

while sum(max(current_a, 0)) * ts / 3600 < target_discharge_ah
    [current_a, step_id] = appendSegment(current_a, step_id, 0.50 * i_1c, 45, 3, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 0, 15, 4, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 1.00 * i_1c, 45, 5, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 0, 45, 6, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 1.50 * i_1c, 30, 3, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 0, 30, 4, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 0.25 * i_1c, 90, 5, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 0, 30, 6, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 0.75 * i_1c, 60, 3, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 0, 30, 8, ts);
end

dis_ah = cumsum(max(current_a, 0)) * ts / 3600;
last_idx = find(dis_ah >= target_discharge_ah, 1, 'first');
current_a = current_a(1:last_idx);
step_id = step_id(1:last_idx);
[current_a, step_id] = appendSegment(current_a, step_id, 0, 10 * 60, 8, ts);
end

function [current_a, step_id] = appendSegment(current_a, step_id, current_level, duration_s, step_value, ts)
num_samples = max(1, round(duration_s / ts));
current_a = [current_a, current_level * ones(1, num_samples)];
step_id = [step_id, step_value * ones(1, num_samples)];
end
