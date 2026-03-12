% KFEval.m
% Evaluate selected SOC estimators on a saved synthetic dataset:
%   1. ROM-based EKF (physics-based model)
%   2. ESC-SPKF (ECM SPKF)
%   3. EacrSPKF (ESC with process/sensor autocorrelated)
%   4. EsSPKF (ESC with simplified online R0 estimation)
%   5. EBiSPKF (ESC-SPKF with external bias tracking)
%   6. Em7SPKF (EBiSPKF + simplified R0-SPKF branch)

clear;
% clc; close all;
clear iterEKF iterESCSPKF iterEacrSPKF iterEsSPKF iterEBiSPKF Em7SPKF;

%% Settings
tc = 25;                          % Temperature [°C]
ts = 1;                           % Sampling time [s]
SOCfigs = false;                  % Plot per-estimator SOC error + bounds figures.
Vfigs = false;                    % Plot per-estimator voltage error + bounds figures.
InnovationACFPACFfigs = true;     % Plot pre-fit innovation ACF/PACF diagnostics.

% Initial conditions
soc_init = 100;                   % Initial SOC [%]
u_init = 0;                       %#ok<NASGU> % Initial current [A]

script_fullpath = mfilename('fullpath');
if isempty(script_fullpath)
    script_fullpath = which('KFEval');
end
if isempty(script_fullpath)
    script_dir = pwd;
else
    script_dir = fileparts(script_fullpath);
end
project_root = fileparts(fileparts(fileparts(script_dir)));
esc_id_root = fullfile(script_dir, 'ESC_Id');

%% Load / create reusable dataset
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

%% Load ROM + ESC models
rom_file = firstExistingFile({ ...
    fullfile(script_dir, 'models', 'ROM_NMC30_HRA12.mat'), ...
    fullfile(script_dir, 'ROM_NMC30_HRA12.mat'), ...
    fullfile(project_root, 'models', 'ROM_NMC30_HRA12.mat'), ...
    fullfile(project_root, 'src', 'MPC-EKF4FastCharge', 'ROM_NMC30_HRA12.mat')}, ...
    'KFEval:MissingROMFile', ...
    'No ROM model file found.');
rom_data = load(rom_file);
ROM = rom_data.ROM;

esc_model_file = firstExistingFile({ ...
    fullfile(script_dir, 'models', 'NMC30model.mat'), ...
    fullfile(script_dir, 'NMC30model.mat'), ...
    fullfile(esc_id_root, 'NMC30model.mat'), ...
    fullfile(project_root, 'models', 'NMC30model.mat')}, ...
    'KFEval:MissingFullESCModel', ...
    'No NMC30 full ESC model found.');
esc_model_data = load(esc_model_file);
nmc30_esc = esc_model_data.nmc30_model;

if ~isfield(nmc30_esc, 'RCParam')
    error('KFEval:MissingRCParam', ...
        'Loaded ESC model is not full: RCParam is missing.');
end
n_rc = numel(getParamESC('RCParam', tc, nmc30_esc));
if n_rc < 1
    error('KFEval:NoRCBranches', ...
        'Loaded ESC model is not full: no RC branches detected.');
end

%% KFinits (based on SOCestimatorsEval.m)
% Method 1: ROM-based EKF
nx = 12;  % Number of ROM states
sigma_x0 = diag([ones(1, nx), 2e6]);
sigma_w_ekf = 1e2;
sigma_v_ekf = 1e-3;

% ESC Methods
% sigma_w_esc = 1e-3; sigma_v_esc = 1e-3;
sigma_w_esc = sigma_w_ekf; sigma_v_esc = sigma_v_ekf;
SigmaX0 = diag([1e-6 * ones(1, n_rc), 1e-6, 1e-3]);

% ESC Dual Methods
SigmaR0 = 1e-6;
SigmaWR0 = 1e-16;
R0init = getParamESC('R0Param', tc, nmc30_esc);

% ESC Bias-Tracking Methods
% sigma_v_bias = 1e2;
sigma_v_bias = sigma_v_esc;


%% Method 1: ROM-EKF
ekf_data = initKF(soc_init, tc, sigma_x0, sigma_v_ekf, sigma_w_ekf, 'OutB', ROM);

soc_ekf = NaN(n_samples, 1); soc_ekf(1) = soc_init / 100;
v_ekf = NaN(n_samples, 1); v_ekf(1) = rom_voltage(1);
soc_ekf_bnd = NaN(n_samples, 1);
v_ekf_bnd = NaN(n_samples, 1);
innov_pre_ekf = NaN(n_samples, 1);
sk_ekf = NaN(n_samples, 1);

for k = 2:n_samples
    [z_ekf, bound_ekf, ekf_data] = iterEKF(rom_voltage(k), i_profile(k), temp_profile(k), ekf_data);
    if isfield(ekf_data, 'lastInnovationPre')
        innov_pre_ekf(k) = ekf_data.lastInnovationPre;
    end
    if isfield(ekf_data, 'lastSk')
        sk_ekf(k) = ekf_data.lastSk;
    end

    if ~isnan(z_ekf(end))
        soc_ekf(k) = max(0, min(1, z_ekf(end)));
        v_ekf(k) = z_ekf(end-1);
        soc_ekf_bnd(k) = bound_ekf(end);
        v_ekf_bnd(k) = bound_ekf(end-1);
    else
        soc_ekf(k) = soc_ekf(k-1);
        v_ekf(k) = v_ekf(k-1);
        soc_ekf_bnd(k) = soc_ekf_bnd(k-1);
        v_ekf_bnd(k) = v_ekf_bnd(k-1);
    end
end

%% Method 2: ESC-SPKF
spkf_esc = initESCSPKF(soc_init, tc, SigmaX0, sigma_v_esc, sigma_w_esc, nmc30_esc);

soc_spkf = NaN(n_samples, 1); soc_spkf(1) = soc_init / 100;
v_spkf = NaN(n_samples, 1); v_spkf(1) = OCVfromSOCtemp(soc_spkf(1), tc, nmc30_esc);
soc_spkf_bnd = NaN(n_samples, 1);
v_spkf_bnd = NaN(n_samples, 1);
innov_pre_spkf = NaN(n_samples, 1);
sk_spkf = NaN(n_samples, 1);

for k = 2:n_samples
    [soc_spkf(k), v_spkf(k), soc_spkf_bnd(k), spkf_esc, v_spkf_bnd(k)] = ...
        iterESCSPKF(rom_voltage(k), i_profile(k), temp_profile(k), ts, spkf_esc);
    if isfield(spkf_esc, 'lastInnovationPre')
        innov_pre_spkf(k) = spkf_esc.lastInnovationPre;
    end
    if isfield(spkf_esc, 'lastSk')
        sk_spkf(k) = spkf_esc.lastSk;
    end
    soc_spkf(k) = max(0, min(1, soc_spkf(k)));
end

%% Method 3: EacrSPKF
if exist('iterEacrSPKF', 'file') ~= 2
    error('KFEval:MissingEacr', 'iterEacrSPKF.m not found on MATLAB path.');
end
eacr_esc = initESCSPKF(soc_init, tc, SigmaX0, sigma_v_esc, sigma_w_esc, nmc30_esc);

soc_eacr = NaN(n_samples, 1); soc_eacr(1) = soc_init / 100;
v_eacr = NaN(n_samples, 1); v_eacr(1) = OCVfromSOCtemp(soc_eacr(1), tc, nmc30_esc);
soc_eacr_bnd = NaN(n_samples, 1);
v_eacr_bnd = NaN(n_samples, 1);
innov_pre_eacr = NaN(n_samples, 1);
sk_eacr = NaN(n_samples, 1);

for k = 2:n_samples
    [soc_eacr(k), v_eacr(k), soc_eacr_bnd(k), eacr_esc, v_eacr_bnd(k)] = ...
        iterEacrSPKF(rom_voltage(k), i_profile(k), temp_profile(k), ts, eacr_esc);
    if isfield(eacr_esc, 'lastInnovationPre')
        innov_pre_eacr(k) = eacr_esc.lastInnovationPre;
    end
    if isfield(eacr_esc, 'lastSk')
        sk_eacr(k) = eacr_esc.lastSk;
    end
    soc_eacr(k) = max(0, min(1, soc_eacr(k)));
end

%% Method 4: EsSPKF
esspkf_esc = initEDUKF(soc_init, R0init, tc, SigmaX0, sigma_v_esc, sigma_w_esc, ...
    SigmaR0, SigmaWR0, nmc30_esc);

soc_esspkf = NaN(n_samples, 1); soc_esspkf(1) = soc_init / 100;
v_esspkf = NaN(n_samples, 1); v_esspkf(1) = OCVfromSOCtemp(soc_esspkf(1), tc, nmc30_esc);
soc_esspkf_bnd = NaN(n_samples, 1);
v_esspkf_bnd = NaN(n_samples, 1);
r0_esspkf = NaN(n_samples, 1); r0_esspkf(1) = esspkf_esc.R0hat;
r0_esspkf_bnd = NaN(n_samples, 1);
innov_pre_esspkf = NaN(n_samples, 1);
sk_esspkf = NaN(n_samples, 1);

for k = 2:n_samples
    [soc_esspkf(k), v_esspkf(k), soc_esspkf_bnd(k), esspkf_esc, v_esspkf_bnd(k), ...
        r0_esspkf(k), r0_esspkf_bnd(k)] = ...
        iterEsSPKF(rom_voltage(k), i_profile(k), temp_profile(k), ts, esspkf_esc);
    if isfield(esspkf_esc, 'lastInnovationPre')
        innov_pre_esspkf(k) = esspkf_esc.lastInnovationPre;
    end
    if isfield(esspkf_esc, 'lastSk')
        sk_esspkf(k) = esspkf_esc.lastSk;
    end
    soc_esspkf(k) = max(0, min(1, soc_esspkf(k)));
end

%% Bias configuration for Methods 5-6
nx_esc = n_rc + 2;
nb_bias = 2; % one current/state bias + one output/measurement bias
current_bias_idx = 1;
output_bias_idx = 2;

current_bias_init = 0;
output_bias_init = 0;
current_bias_var0 = 1e-5;
output_bias_var0 = 1e-5;

RC_bias = exp(-ts./abs(getParamESC('RCParam', tc, nmc30_esc)))';
R_bias = getParamESC('RParam', tc, nmc30_esc)';
M_bias = getParamESC('MParam', tc, nmc30_esc);
Q_bias = getParamESC('QParam', tc, nmc30_esc);
R0_bias = getParamESC('R0Param', tc, nmc30_esc);

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
dOCVdSOC0 = (OCVfromSOCtemp(soc_hi, tc, nmc30_esc) - OCVfromSOCtemp(soc_lo, tc, nmc30_esc)) / ...
    max(soc_hi - soc_lo, eps);
Cd_bias = zeros(1, nx_esc);
Cd_bias(1, 1:n_rc) = -R_bias;
Cd_bias(1, n_rc + 1) = M_bias;
Cd_bias(1, nx_esc) = dOCVdSOC0;

biasCfg = struct();
biasCfg.nb = nb_bias;
biasCfg.bhat0 = [current_bias_init; output_bias_init];
biasCfg.SigmaB0 = diag([current_bias_var0, output_bias_var0]);
biasCfg.Bb = Bb_bias;
biasCfg.Cb = Cb_bias;
biasCfg.biasModelStatic = true;
biasCfg.Ad = Ad_bias;
biasCfg.Cd = Cd_bias;
biasCfg.currentBiasInd = current_bias_idx;

%% Method 5: EBiSPKF
ebispkf_esc = initESCSPKF(soc_init, tc, SigmaX0, sigma_v_bias, sigma_w_esc, nmc30_esc, biasCfg);

soc_ebispkf = NaN(n_samples, 1); soc_ebispkf(1) = soc_init / 100;
v_ebispkf = NaN(n_samples, 1); v_ebispkf(1) = OCVfromSOCtemp(soc_ebispkf(1), tc, nmc30_esc);
soc_ebispkf_bnd = NaN(n_samples, 1);
v_ebispkf_bnd = NaN(n_samples, 1);
bias_ebispkf = NaN(n_samples, nb_bias);
bias_ebispkf_bnd = NaN(n_samples, nb_bias);
bias_ebispkf(1, :) = ebispkf_esc.bhat(:).';
bias_ebispkf_bnd(1, :) = (3 * sqrt(max(diag(ebispkf_esc.SigmaB), 0))).';
innov_pre_ebispkf = NaN(n_samples, 1);
sk_ebispkf = NaN(n_samples, 1);

for k = 2:n_samples
    [soc_ebispkf(k), v_ebispkf(k), soc_ebispkf_bnd(k), ebispkf_esc, v_ebispkf_bnd(k), ...
        bhat_k, bbnd_k] = iterEBiSPKF(rom_voltage(k), i_profile(k), temp_profile(k), ts, ebispkf_esc);
    if isfield(ebispkf_esc, 'lastInnovationPre')
        innov_pre_ebispkf(k) = ebispkf_esc.lastInnovationPre;
    end
    if isfield(ebispkf_esc, 'lastSk')
        sk_ebispkf(k) = ebispkf_esc.lastSk;
    end
    soc_ebispkf(k) = max(0, min(1, soc_ebispkf(k)));
    bias_ebispkf(k, :) = bhat_k(:).';
    bias_ebispkf_bnd(k, :) = bbnd_k(:).';
end

%% Method 6: Em7SPKF
em7_esc = Em7init(soc_init, R0init, tc, SigmaX0, sigma_v_bias, sigma_w_esc, ...
    SigmaR0, SigmaWR0, nmc30_esc, biasCfg);

soc_em7 = NaN(n_samples, 1); soc_em7(1) = soc_init / 100;
v_em7 = NaN(n_samples, 1); v_em7(1) = OCVfromSOCtemp(soc_em7(1), tc, nmc30_esc);
soc_em7_bnd = NaN(n_samples, 1);
v_em7_bnd = NaN(n_samples, 1);
bias_em7 = NaN(n_samples, nb_bias);
bias_em7_bnd = NaN(n_samples, nb_bias);
bias_em7(1, :) = em7_esc.bhat(:).';
bias_em7_bnd(1, :) = (3 * sqrt(max(diag(em7_esc.SigmaB), 0))).';
r0_em7 = NaN(n_samples, 1); r0_em7(1) = em7_esc.R0hat;
r0_em7_bnd = NaN(n_samples, 1);
innov_pre_em7 = NaN(n_samples, 1);
sk_em7 = NaN(n_samples, 1);

for k = 2:n_samples
    [soc_em7(k), v_em7(k), soc_em7_bnd(k), em7_esc, v_em7_bnd(k), ...
        bhat_k, bbnd_k, r0_em7(k), r0_em7_bnd(k)] = ...
        Em7SPKF(rom_voltage(k), i_profile(k), temp_profile(k), ts, em7_esc);
    if isfield(em7_esc, 'lastInnovationPre')
        innov_pre_em7(k) = em7_esc.lastInnovationPre;
    end
    if isfield(em7_esc, 'lastSk')
        sk_em7(k) = em7_esc.lastSk;
    end
    soc_em7(k) = max(0, min(1, soc_em7(k)));
    bias_em7(k, :) = bhat_k(:).';
    bias_em7_bnd(k, :) = bbnd_k(:).';
end

%% Metrics
error_ekf = rom_soc - soc_ekf;
error_spkf = rom_soc - soc_spkf;
error_eacr = rom_soc - soc_eacr;
error_esspkf = rom_soc - soc_esspkf;
error_ebispkf = rom_soc - soc_ebispkf;
error_em7 = rom_soc - soc_em7;
if isfield(dataset, 'soc_cc') && numel(dataset.soc_cc) == n_samples
    soc_cc = dataset.soc_cc(:);
else
    soc_cc = NaN(n_samples, 1);
end
error_cc = rom_soc - soc_cc;

v_error_ekf = rom_voltage - v_ekf;
v_error_spkf = rom_voltage - v_spkf;
v_error_eacr = rom_voltage - v_eacr;
v_error_esspkf = rom_voltage - v_esspkf;
v_error_ebispkf = rom_voltage - v_ebispkf;
v_error_em7 = rom_voltage - v_em7;

rmse_ekf = sqrt(mean(error_ekf(~isnan(error_ekf)).^2));
rmse_spkf = sqrt(mean(error_spkf(~isnan(error_spkf)).^2));
rmse_eacr = sqrt(mean(error_eacr(~isnan(error_eacr)).^2));
rmse_esspkf = sqrt(mean(error_esspkf(~isnan(error_esspkf)).^2));
rmse_ebispkf = sqrt(mean(error_ebispkf(~isnan(error_ebispkf)).^2));
rmse_em7 = sqrt(mean(error_em7(~isnan(error_em7)).^2));
rmse_cc = sqrt(mean(error_cc(~isnan(error_cc)).^2));

v_rmse_ekf = sqrt(mean(v_error_ekf(~isnan(v_error_ekf)).^2));
v_rmse_spkf = sqrt(mean(v_error_spkf(~isnan(v_error_spkf)).^2));
v_rmse_eacr = sqrt(mean(v_error_eacr(~isnan(v_error_eacr)).^2));
v_rmse_esspkf = sqrt(mean(v_error_esspkf(~isnan(v_error_esspkf)).^2));
v_rmse_ebispkf = sqrt(mean(v_error_ebispkf(~isnan(v_error_ebispkf)).^2));
v_rmse_em7 = sqrt(mean(v_error_em7(~isnan(v_error_em7)).^2));

fprintf('\nKFEval Results (vs ROM ground truth)\n');
fprintf('  ROM-EKF:    SOC RMSE = %.4f%%, V RMSE = %.2f mV\n', 100 * rmse_ekf, 1000 * v_rmse_ekf);
fprintf('  ESC-SPKF:   SOC RMSE = %.4f%%, V RMSE = %.2f mV\n', 100 * rmse_spkf, 1000 * v_rmse_spkf);
fprintf('  EacrSPKF:   SOC RMSE = %.4f%%, V RMSE = %.2f mV\n', 100 * rmse_eacr, 1000 * v_rmse_eacr);
fprintf('  EsSPKF:     SOC RMSE = %.4f%%, V RMSE = %.2f mV\n', 100 * rmse_esspkf, 1000 * v_rmse_esspkf);
fprintf('  EBiSPKF:    SOC RMSE = %.4f%%, V RMSE = %.2f mV\n', 100 * rmse_ebispkf, 1000 * v_rmse_ebispkf);
fprintf('  Em7SPKF:    SOC RMSE = %.4f%%, V RMSE = %.2f mV\n', 100 * rmse_em7, 1000 * v_rmse_em7);

fprintf('\nBias / Innovation Diagnostics (error = ROM truth - estimate):\n');
printEstimatorBiasMetrics('ROM-EKF', error_ekf, v_error_ekf, innov_pre_ekf, sk_ekf);
printEstimatorBiasMetrics('ESC-SPKF', error_spkf, v_error_spkf, innov_pre_spkf, sk_spkf);
printEstimatorBiasMetrics('EacrSPKF', error_eacr, v_error_eacr, innov_pre_eacr, sk_eacr);
printEstimatorBiasMetrics('EsSPKF', error_esspkf, v_error_esspkf, innov_pre_esspkf, sk_esspkf);
printEstimatorBiasMetrics('EBiSPKF', error_ebispkf, v_error_ebispkf, innov_pre_ebispkf, sk_ebispkf);
printEstimatorBiasMetrics('Em7SPKF', error_em7, v_error_em7, innov_pre_em7, sk_em7);

if InnovationACFPACFfigs
    plotInnovationAcfPacf( ...
        {innov_pre_ekf, innov_pre_spkf, innov_pre_eacr, innov_pre_esspkf, innov_pre_ebispkf, innov_pre_em7}, ...
        {'ROM-EKF', 'ESC-SPKF', 'EacrSPKF', 'EsSPKF', 'EBiSPKF', 'Em7SPKF'}, ...
        60, ...
        'Pre-fit Innovation ACF/PACF (KFEval)');
end

%% Summary plots
figure('Name', 'Cell Voltage', 'NumberTitle', 'off');
plot(t, rom_voltage, 'k-', 'LineWidth', 2, 'DisplayName', 'ROM (Ground Truth)'); hold on;
plot(t, v_ekf, 'r-', 'LineWidth', 1.5, 'DisplayName', 'ROM-EKF');
plot(t, v_spkf, 'g:', 'LineWidth', 1.5, 'DisplayName', 'ESC-SPKF');
plot(t, v_eacr, 'b-.', 'LineWidth', 1.5, 'DisplayName', 'EacrSPKF');
plot(t, v_esspkf, 'c--', 'LineWidth', 1.5, 'DisplayName', 'EsSPKF');
plot(t, v_ebispkf, '-', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.5, 'DisplayName', 'EBiSPKF');
plot(t, v_em7, '-', 'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.5, 'DisplayName', 'Em7SPKF');
grid on; xlabel('Time [s]'); ylabel('Voltage [V]');
title('Cell Voltage');
legend('Location', 'best');

figure('Name', 'SOC Comparison', 'NumberTitle', 'off');
plot(t, 100 * rom_soc, 'k-', 'LineWidth', 2.5, 'DisplayName', 'ROM (Ground Truth)'); hold on;
plot(t, 100 * soc_cc, 'b--', 'LineWidth', 1.5, 'DisplayName', sprintf('Coulomb Counting (RMSE=%.3f%%)', 100 * rmse_cc));
plot(t, 100 * soc_ekf, 'r-', 'LineWidth', 1.5, 'DisplayName', sprintf('ROM-EKF (RMSE=%.3f%%)', 100 * rmse_ekf));
plot(t, 100 * soc_spkf, 'g:', 'LineWidth', 1.5, 'DisplayName', sprintf('ESC-SPKF (RMSE=%.3f%%)', 100 * rmse_spkf));
plot(t, 100 * soc_eacr, 'b-.', 'LineWidth', 1.5, 'DisplayName', sprintf('EacrSPKF (RMSE=%.3f%%)', 100 * rmse_eacr));
plot(t, 100 * soc_esspkf, 'c--', 'LineWidth', 1.5, 'DisplayName', sprintf('EsSPKF (RMSE=%.3f%%)', 100 * rmse_esspkf));
plot(t, 100 * soc_ebispkf, '-', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.5, ...
    'DisplayName', sprintf('EBiSPKF (RMSE=%.3f%%)', 100 * rmse_ebispkf));
plot(t, 100 * soc_em7, '-', 'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Em7SPKF (RMSE=%.3f%%)', 100 * rmse_em7));
grid on; xlabel('Time [s]'); ylabel('SOC [%]');
title('SOC Estimation Comparison');
legend('Location', 'best');

% Plot 4: SOC errors
figure('Name', 'SOC Errors', 'NumberTitle', 'off');
plot(t, 100 * error_cc, 'b--', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('Coulomb Counting (RMSE=%.3f%%)', 100 * rmse_cc));
hold on;
plot(t, 100 * error_ekf, 'r-', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('ROM-EKF (RMSE=%.3f%%)', 100 * rmse_ekf));
plot(t, 100 * error_spkf, 'g:', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('ESC-SPKF (RMSE=%.3f%%)', 100 * rmse_spkf));
plot(t, 100 * error_eacr, 'm-.', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('EacrSPKF (RMSE=%.3f%%)', 100 * rmse_eacr));
plot(t, 100 * error_esspkf, 'c--', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('EsSPKF (RMSE=%.3f%%)', 100 * rmse_esspkf));
plot(t, 100 * error_ebispkf, '-', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('EBiSPKF (RMSE=%.3f%%)', 100 * rmse_ebispkf));
plot(t, 100 * error_em7, '-', 'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('Em7SPKF (RMSE=%.3f%%)', 100 * rmse_em7));
grid on; xlabel('Time [s]'); ylabel('SOC Error [%]');
title('SOC Estimation Errors vs ROM Ground Truth');
legend('Location', 'best');

figure('Name', 'Voltage Errors', 'NumberTitle', 'off');
plot(t, v_error_ekf, 'r-', 'LineWidth', 1.5, 'DisplayName', sprintf('ROM-EKF (RMSE=%.2f mV)', 1000 * v_rmse_ekf)); hold on;
plot(t, v_error_spkf, 'g:', 'LineWidth', 1.5, 'DisplayName', sprintf('ESC-SPKF (RMSE=%.2f mV)', 1000 * v_rmse_spkf));
plot(t, v_error_eacr, 'b-.', 'LineWidth', 1.5, 'DisplayName', sprintf('EacrSPKF (RMSE=%.2f mV)', 1000 * v_rmse_eacr));
plot(t, v_error_esspkf, 'c--', 'LineWidth', 1.5, 'DisplayName', sprintf('EsSPKF (RMSE=%.2f mV)', 1000 * v_rmse_esspkf));
plot(t, v_error_ebispkf, '-', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.5, ...
    'DisplayName', sprintf('EBiSPKF (RMSE=%.2f mV)', 1000 * v_rmse_ebispkf));
plot(t, v_error_em7, '-', 'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Em7SPKF (RMSE=%.2f mV)', 1000 * v_rmse_em7));
grid on; xlabel('Time [s]'); ylabel('Voltage Error [V]');
title('Voltage Estimation Errors vs ROM Ground Truth');
legend('Location', 'best');

%% Optional per-estimator error + bounds plots
methodNames = {'ROM-EKF', 'ESC-SPKF', 'EacrSPKF', 'EsSPKF', 'EBiSPKF', 'Em7SPKF'};
socErrList = {error_ekf, error_spkf, error_eacr, error_esspkf, error_ebispkf, error_em7};
socBndList = {soc_ekf_bnd, soc_spkf_bnd, soc_eacr_bnd, soc_esspkf_bnd, soc_ebispkf_bnd, soc_em7_bnd};
vErrList = {v_error_ekf, v_error_spkf, v_error_eacr, v_error_esspkf, v_error_ebispkf, v_error_em7};
vBndList = {v_ekf_bnd, v_spkf_bnd, v_eacr_bnd, v_esspkf_bnd, v_ebispkf_bnd, v_em7_bnd};

if SOCfigs
    for idx = 1:numel(methodNames)
        figure('Name', ['SOC Error (' methodNames{idx} ')'], 'NumberTitle', 'off');
        plot(t, 100 * socErrList{idx}, 'LineWidth', 1.3); hold on; grid on;
        set(gca, 'colororderindex', 1); plot(t, 100 * socBndList{idx}, ':');
        set(gca, 'colororderindex', 1); plot(t, -100 * socBndList{idx}, ':');
        title(sprintf('SOC estimation error (percent, %s)', methodNames{idx}));
        legend('Error', '+3\sigma', '-3\sigma', 'Location', 'best');
    end
end

if Vfigs
    for idx = 1:numel(methodNames)
        figure('Name', ['Voltage Error (' methodNames{idx} ')'], 'NumberTitle', 'off');
        plot(t, vErrList{idx}, 'LineWidth', 1.3); hold on; grid on;
        set(gca, 'colororderindex', 1); plot(t, vBndList{idx}, ':');
        set(gca, 'colororderindex', 1); plot(t, -vBndList{idx}, ':');
        title(sprintf('Voltage estimation error (%s)', methodNames{idx}));
        legend('Error', '+3\sigma', '-3\sigma', 'Location', 'best');
    end
end

function file_path = firstExistingFile(candidates, error_id, error_msg)
file_path = firstExistingFileOrEmpty(candidates);
if isempty(file_path)
    searched = sprintf('\n  - %s', candidates{:});
    error(error_id, '%s Searched:%s', error_msg, searched);
end
end

function file_path = firstExistingFileOrEmpty(candidates)
file_path = '';
for idx = 1:numel(candidates)
    if exist(candidates{idx}, 'file')
        file_path = candidates{idx};
        return;
    end
end
end
