% sandbox.m
% A/B sandbox to compare EacrSPKF vs EnacrSPKF on the saved ROM dataset.

clear;
% clc; close all;
clear iterESCSPKF iterEacrSPKF iterEnacrSPKF;

%% Settings
tc = 25;                          % Temperature [°C]
ts = 1;                           % Sampling time [s]
SOCfigs = false;                  % Plot per-estimator SOC error + bounds figures.
Vfigs = false;                    % Plot per-estimator voltage error + bounds figures.
InnovationACFPACFfigs = true;     % Plot pre-fit innovation ACF/PACF diagnostics.
soc_init = 100;                   % Initial SOC [%]

script_fullpath = mfilename('fullpath');
if isempty(script_fullpath)
    script_fullpath = which('sandbox');
end
if isempty(script_fullpath)
    script_dir = pwd;
else
    script_dir = fileparts(script_fullpath);
end
project_root = fileparts(fileparts(fileparts(script_dir)));
esc_id_root = fullfile(script_dir, 'ESC_Id');

%% Load / create dataset
dataset_file = fullfile(script_dir, 'datasets', 'rom_script1_dataset.mat');
if exist(dataset_file, 'file')
    ds = load(dataset_file);
    dataset = ds.dataset;
else
    dataset = createROMSyntheticDataset(dataset_file, ...
        struct('soc_init', soc_init, 'tc', tc, 'ts', ts));
end

t = dataset.time_s(:);
i_profile = dataset.current_a(:);
rom_voltage = dataset.voltage_v(:);
rom_soc = dataset.soc_true(:);
n_samples = numel(t);

if ~isfield(dataset, 'temperature_c') || numel(dataset.temperature_c) ~= n_samples
    temp_profile = tc * ones(n_samples, 1);
else
    temp_profile = dataset.temperature_c(:);
end

%% Load ESC model
esc_model_file = firstExistingFile({ ...
    fullfile(script_dir, 'models', 'NMC30model.mat'), ...
    fullfile(script_dir, 'NMC30model.mat'), ...
    fullfile(esc_id_root, 'NMC30model.mat'), ...
    fullfile(project_root, 'models', 'NMC30model.mat')}, ...
    'sandbox:MissingFullESCModel', ...
    'No NMC30 full ESC model found.');
esc_model_data = load(esc_model_file);
nmc30_esc = esc_model_data.nmc30_model;

if ~isfield(nmc30_esc, 'RCParam')
    error('sandbox:MissingRCParam', ...
        'Loaded ESC model is not full: RCParam is missing.');
end
n_rc = numel(getParamESC('RCParam', tc, nmc30_esc));
if n_rc < 1
    error('sandbox:NoRCBranches', ...
        'Loaded ESC model is not full: no RC branches detected.');
end

%% Shared init tuning (ESC family)
sigma_w = 1e-2;
sigma_v = 1e-2;
SigmaX0 = diag([1e-6 * ones(1, n_rc), 1e-6, 1e-3]);

%% EacrSPKF
if exist('iterEacrSPKF', 'file') ~= 2
    error('sandbox:MissingEacr', 'iterEacrSPKF.m not found on MATLAB path.');
end
eacr_data = initESCSPKF(soc_init, tc, SigmaX0, sigma_v, sigma_w, nmc30_esc);
soc_eacr = NaN(n_samples, 1); soc_eacr(1) = soc_init / 100;
v_eacr = NaN(n_samples, 1); v_eacr(1) = OCVfromSOCtemp(soc_eacr(1), tc, nmc30_esc);
soc_eacr_bnd = NaN(n_samples, 1);
v_eacr_bnd = NaN(n_samples, 1);
innov_pre_eacr = NaN(n_samples, 1);
sk_eacr = NaN(n_samples, 1);

for k = 2:n_samples
    [soc_eacr(k), v_eacr(k), soc_eacr_bnd(k), eacr_data, v_eacr_bnd(k)] = ...
        iterEacrSPKF(rom_voltage(k), i_profile(k), temp_profile(k), ts, eacr_data);
    if isfield(eacr_data, 'lastInnovationPre')
        innov_pre_eacr(k) = eacr_data.lastInnovationPre;
    end
    if isfield(eacr_data, 'lastSk')
        sk_eacr(k) = eacr_data.lastSk;
    end
    soc_eacr(k) = max(0, min(1, soc_eacr(k)));
end

%% EnacrSPKF
if exist('iterEnacrSPKF', 'file') ~= 2
    error('sandbox:MissingEnacr', 'iterEnacrSPKF.m not found on MATLAB path.');
end
enacr_data = initESCSPKF(soc_init, tc, SigmaX0, sigma_v, sigma_w, nmc30_esc);
soc_enacr = NaN(n_samples, 1); soc_enacr(1) = soc_init / 100;
v_enacr = NaN(n_samples, 1); v_enacr(1) = OCVfromSOCtemp(soc_enacr(1), tc, nmc30_esc);
soc_enacr_bnd = NaN(n_samples, 1);
v_enacr_bnd = NaN(n_samples, 1);
innov_pre_enacr = NaN(n_samples, 1);
sk_enacr = NaN(n_samples, 1);

for k = 2:n_samples
    [soc_enacr(k), v_enacr(k), soc_enacr_bnd(k), enacr_data, v_enacr_bnd(k)] = ...
        iterEnacrSPKF(rom_voltage(k), i_profile(k), temp_profile(k), ts, enacr_data);
    if isfield(enacr_data, 'lastInnovationPre')
        innov_pre_enacr(k) = enacr_data.lastInnovationPre;
    end
    if isfield(enacr_data, 'lastSk')
        sk_enacr(k) = enacr_data.lastSk;
    end
    soc_enacr(k) = max(0, min(1, soc_enacr(k)));
end

%% Metrics
error_eacr = rom_soc - soc_eacr;
error_enacr = rom_soc - soc_enacr;
v_error_eacr = rom_voltage - v_eacr;
v_error_enacr = rom_voltage - v_enacr;

rmse_eacr = sqrt(mean(error_eacr(~isnan(error_eacr)).^2));
rmse_enacr = sqrt(mean(error_enacr(~isnan(error_enacr)).^2));
v_rmse_eacr = sqrt(mean(v_error_eacr(~isnan(v_error_eacr)).^2));
v_rmse_enacr = sqrt(mean(v_error_enacr(~isnan(v_error_enacr)).^2));

fprintf('\nSandbox Results (vs ROM ground truth)\n');
fprintf('  EacrSPKF:  SOC RMSE = %.4f%%, V RMSE = %.2f mV\n', 100 * rmse_eacr, 1000 * v_rmse_eacr);
fprintf('  EnacrSPKF: SOC RMSE = %.4f%%, V RMSE = %.2f mV\n', 100 * rmse_enacr, 1000 * v_rmse_enacr);

fprintf('\nBias / Innovation Diagnostics (error = ROM truth - estimate):\n');
printEstimatorBiasMetrics('EacrSPKF', error_eacr, v_error_eacr, innov_pre_eacr, sk_eacr);
printEstimatorBiasMetrics('EnacrSPKF', error_enacr, v_error_enacr, innov_pre_enacr, sk_enacr);

if InnovationACFPACFfigs
    plotInnovationAcfPacf( ...
        {innov_pre_eacr, innov_pre_enacr}, ...
        {'EacrSPKF', 'EnacrSPKF'}, ...
        60, ...
        'Pre-fit Innovation ACF/PACF (sandbox)');
end

%% Plots
figure('Name', 'Sandbox: Cell Voltage', 'NumberTitle', 'off');
plot(t, rom_voltage, 'k-', 'LineWidth', 2, 'DisplayName', 'ROM (Ground Truth)'); hold on;
plot(t, v_eacr, 'b-.', 'LineWidth', 1.5, 'DisplayName', 'EacrSPKF');
plot(t, v_enacr, 'm-', 'LineWidth', 1.5, 'DisplayName', 'EnacrSPKF');
grid on; xlabel('Time [s]'); ylabel('Voltage [V]');
title('Sandbox Voltage Comparison');
legend('Location', 'best');

figure('Name', 'Sandbox: SOC Comparison', 'NumberTitle', 'off');
plot(t, 100 * rom_soc, 'k-', 'LineWidth', 2.5, 'DisplayName', 'ROM (Ground Truth)'); hold on;
plot(t, 100 * soc_eacr, 'b-.', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('EacrSPKF (RMSE=%.3f%%)', 100 * rmse_eacr));
plot(t, 100 * soc_enacr, 'm-', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('EnacrSPKF (RMSE=%.3f%%)', 100 * rmse_enacr));
grid on; xlabel('Time [s]'); ylabel('SOC [%]');
title('Sandbox SOC Comparison');
legend('Location', 'best');

figure('Name', 'Sandbox: SOC Errors', 'NumberTitle', 'off');
plot(t, 100 * error_eacr, 'b-.', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('EacrSPKF (RMSE=%.3f%%)', 100 * rmse_eacr)); hold on;
plot(t, 100 * error_enacr, 'm-', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('EnacrSPKF (RMSE=%.3f%%)', 100 * rmse_enacr));
grid on; xlabel('Time [s]'); ylabel('SOC Error [%]');
title('SOC Estimation Errors vs ROM Ground Truth');
legend('Location', 'best');

figure('Name', 'Sandbox: Voltage Errors', 'NumberTitle', 'off');
plot(t, v_error_eacr, 'b-.', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('EacrSPKF (RMSE=%.2f mV)', 1000 * v_rmse_eacr)); hold on;
plot(t, v_error_enacr, 'm-', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('EnacrSPKF (RMSE=%.2f mV)', 1000 * v_rmse_enacr));
grid on; xlabel('Time [s]'); ylabel('Voltage Error [V]');
title('Voltage Estimation Errors vs ROM Ground Truth');
legend('Location', 'best');

if SOCfigs
    figure('Name', 'Sandbox: SOC Error (EacrSPKF)', 'NumberTitle', 'off');
    plot(t, 100 * error_eacr, 'b-.', 'LineWidth', 1.3); hold on; grid on;
    set(gca, 'colororderindex', 1); plot(t, 100 * soc_eacr_bnd, ':');
    set(gca, 'colororderindex', 1); plot(t, -100 * soc_eacr_bnd, ':');
    title('SOC estimation error (EacrSPKF)');
    legend('Error', '+3\sigma', '-3\sigma', 'Location', 'best');

    figure('Name', 'Sandbox: SOC Error (EnacrSPKF)', 'NumberTitle', 'off');
    plot(t, 100 * error_enacr, 'm-', 'LineWidth', 1.3); hold on; grid on;
    set(gca, 'colororderindex', 1); plot(t, 100 * soc_enacr_bnd, ':');
    set(gca, 'colororderindex', 1); plot(t, -100 * soc_enacr_bnd, ':');
    title('SOC estimation error (EnacrSPKF)');
    legend('Error', '+3\sigma', '-3\sigma', 'Location', 'best');
end

if Vfigs
    figure('Name', 'Sandbox: Voltage Error (EacrSPKF)', 'NumberTitle', 'off');
    plot(t, v_error_eacr, 'b-.', 'LineWidth', 1.3); hold on; grid on;
    set(gca, 'colororderindex', 1); plot(t, v_eacr_bnd, ':');
    set(gca, 'colororderindex', 1); plot(t, -v_eacr_bnd, ':');
    title('Voltage estimation error (EacrSPKF)');
    legend('Error', '+3\sigma', '-3\sigma', 'Location', 'best');

    figure('Name', 'Sandbox: Voltage Error (EnacrSPKF)', 'NumberTitle', 'off');
    plot(t, v_error_enacr, 'm-', 'LineWidth', 1.3); hold on; grid on;
    set(gca, 'colororderindex', 1); plot(t, v_enacr_bnd, ':');
    set(gca, 'colororderindex', 1); plot(t, -v_enacr_bnd, ':');
    title('Voltage estimation error (EnacrSPKF)');
    legend('Error', '+3\sigma', '-3\sigma', 'Location', 'best');
end

function file_path = firstExistingFile(candidates, error_id, error_msg)
file_path = '';
for idx = 1:numel(candidates)
    if exist(candidates{idx}, 'file')
        file_path = candidates{idx};
        break;
    end
end
if isempty(file_path)
    searched = sprintf('\n  - %s', candidates{:});
    error(error_id, '%s Searched:%s', error_msg, searched);
end
end
