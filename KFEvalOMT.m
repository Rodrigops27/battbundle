% KFEvalOMT.m
% Evaluate ESC-based SOC estimators on the measured OMTLIFE bus profile:
%   1. ESC-SPKF (ECM SPKF)
%   2. EacrSPKF (ESC with process/sensor autocorrelated)
%   3. EsSPKF (ESC with simplified online R0 estimation)
%   4. EBiSPKF (ESC-SPKF with external bias tracking)
%   5. Em7SPKF (EBiSPKF + simplified R0-SPKF branch)

clear;
clear iterESCSPKF iterEacrSPKF iterEsSPKF iterEBiSPKF Em7SPKF;

%% Settings
tc = 25;                          % Temperature [degC]
ts = 1;                           % Target sampling time [s]
SOCfigs = false;                  % Plot per-estimator SOC error + bounds figures.
Vfigs = false;                    % Plot per-estimator voltage error + bounds figures.
InnovationACFPACFfigs = true;     % Plot pre-fit innovation ACF/PACF diagnostics.
use_dataset_temperature = false;  % Default: keep the 25 degC identification assumption.

dataset_file_override = '';       % Optional .mat path for the OMT profile.
esc_model_file_override = '';     % Optional .mat path for the identified OMT ESC model.
soc_init_reference = [];          % [%] Empty -> first dataset SOC sample or fit-summary initial SOC.
soc_init_kf = [];                 % [%] Empty -> soc_init_reference.

script_fullpath = mfilename('fullpath');
if isempty(script_fullpath)
    script_fullpath = which('KFEvalOMT');
end
if isempty(script_fullpath)
    script_dir = pwd;
else
    script_dir = fileparts(script_fullpath);
end
project_root = script_dir;
esc_id_root = fullfile(script_dir, 'ESC_Id');
addpath(script_dir);
addpath(genpath(fullfile(script_dir, 'utility')));
addpath(genpath(esc_id_root));

%% Load measured dataset
if isempty(dataset_file_override)
    dataset_file = fullfile(esc_id_root, 'Datasets', 'OMTLIFE8AHC-HP', 'Bus_CoreBatteryData_Data.mat');
else
    dataset_file = dataset_file_override;
end
dataset = loadBusCoreBatteryProfile(dataset_file);
dataset = resampleProfile(dataset, ts);

t = dataset.time_s(:);
meas_voltage = dataset.voltage_v(:);
i_profile = dataset.current_a(:);
dataset_soc = dataset.soc_ref(:);
n_samples = numel(t);

if n_samples < 10
    error('KFEvalOMT:TooFewSamples', 'Dataset contains too few samples.');
end

valid = isfinite(t) & isfinite(i_profile) & isfinite(meas_voltage);
if nnz(valid) < 10
    error('KFEvalOMT:NoValidSamples', 'Dataset does not contain enough valid current/voltage samples.');
end
t = t(valid);
i_profile = i_profile(valid);
meas_voltage = meas_voltage(valid);
if ~isempty(dataset_soc)
    dataset_soc = dataset_soc(valid);
end
t = t - t(1);
n_samples = numel(t);

%% Load ESC model
esc_model_file = firstExistingFileOrOverride({ ...
    fullfile(esc_id_root, 'OMTLIFEmodel.mat'), ...
    fullfile(script_dir, 'OMTLIFEmodel.mat'), ...
    fullfile(project_root, 'models', 'OMTLIFEmodel.mat')}, ...
    esc_model_file_override, ...
    'KFEvalOMT:MissingESCModel', ...
    'No OMTLIFE identified ESC model found.');
esc_model_data = load(esc_model_file);
omt_esc = extractModelStruct(esc_model_data);

if ~isfield(omt_esc, 'RCParam')
    error('KFEvalOMT:MissingRCParam', ...
        'Loaded ESC model is not full: RCParam is missing.');
end
n_rc = numel(getParamESC('RCParam', tc, omt_esc));
if n_rc < 1
    error('KFEvalOMT:NoRCBranches', ...
        'Loaded ESC model is not full: no RC branches detected.');
end

%% Reference SOC
if isempty(soc_init_reference)
    if ~isempty(dataset_soc) && any(isfinite(dataset_soc))
        soc_init_reference = 100 * dataset_soc(find(isfinite(dataset_soc), 1, 'first'));
    elseif isfield(esc_model_data, 'fit_summary') && isfield(esc_model_data.fit_summary, 'initial_soc')
        soc_init_reference = 100 * double(esc_model_data.fit_summary.initial_soc);
    else
        error('KFEvalOMT:MissingReferenceSOC0', ...
            'No initial SOC is available from the dataset or model fit summary. Set soc_init_reference explicitly.');
    end
end
if isempty(soc_init_kf)
    soc_init_kf = soc_init_reference;
end

model_temp = resolveModelTemperature(omt_esc, tc);
temp_profile = model_temp * ones(n_samples, 1);
if use_dataset_temperature && ~isempty(dataset.temperature_c) && numel(dataset.temperature_c) == numel(dataset.time_s)
    dataset_temp = dataset.temperature_c(valid);
    if isscalar(omt_esc.temps)
        if all(isfinite(dataset_temp)) && all(abs(dataset_temp - model_temp) <= 1e-9)
            temp_profile = dataset_temp(:);
        else
            warning('KFEvalOMT:IgnoringDatasetTemperature', ...
                ['Ignoring dataset temperature trace because the ESC model is single-temperature ' ...
                 'at %.2f degC.'], model_temp);
        end
    else
        temp_profile = dataset_temp(:);
    end
end

soc_ref = NaN(n_samples, 1);
soc_ref(1) = soc_init_reference / 100;
q_ref = getParamESC('QParam', tc, omt_esc);
for k = 2:n_samples
    soc_ref(k) = soc_ref(k-1) - (i_profile(k-1) * ts) / (3600 * q_ref);
    soc_ref(k) = max(0, min(1, soc_ref(k)));
end

%% KF initialization
sigma_w_esc = 1e2;
sigma_v_esc = 1e-3;
SigmaX0 = diag([1e-6 * ones(1, n_rc), 1e-6, 1e-3]);

SigmaR0 = 1e-6;
SigmaWR0 = 1e-16;
R0init = getParamESC('R0Param', tc, omt_esc);

sigma_v_bias = sigma_v_esc;

%% Method 1: ESC-SPKF
spkf_esc = initESCSPKF(soc_init_kf, tc, SigmaX0, sigma_v_esc, sigma_w_esc, omt_esc);

soc_spkf = NaN(n_samples, 1); soc_spkf(1) = soc_init_kf / 100;
v_spkf = NaN(n_samples, 1); v_spkf(1) = meas_voltage(1);
soc_spkf_bnd = NaN(n_samples, 1);
v_spkf_bnd = NaN(n_samples, 1);
innov_pre_spkf = NaN(n_samples, 1);
sk_spkf = NaN(n_samples, 1);

for k = 2:n_samples
    [soc_spkf(k), v_spkf(k), soc_spkf_bnd(k), spkf_esc, v_spkf_bnd(k)] = ...
        iterESCSPKF(meas_voltage(k), i_profile(k), temp_profile(k), ts, spkf_esc);
    if isfield(spkf_esc, 'lastInnovationPre')
        innov_pre_spkf(k) = spkf_esc.lastInnovationPre;
    end
    if isfield(spkf_esc, 'lastSk')
        sk_spkf(k) = spkf_esc.lastSk;
    end
    soc_spkf(k) = max(0, min(1, soc_spkf(k)));
end

%% Method 2: EacrSPKF
eacr_esc = initESCSPKF(soc_init_kf, tc, SigmaX0, sigma_v_esc, sigma_w_esc, omt_esc);

soc_eacr = NaN(n_samples, 1); soc_eacr(1) = soc_init_kf / 100;
v_eacr = NaN(n_samples, 1); v_eacr(1) = meas_voltage(1);
soc_eacr_bnd = NaN(n_samples, 1);
v_eacr_bnd = NaN(n_samples, 1);
innov_pre_eacr = NaN(n_samples, 1);
sk_eacr = NaN(n_samples, 1);

for k = 2:n_samples
    [soc_eacr(k), v_eacr(k), soc_eacr_bnd(k), eacr_esc, v_eacr_bnd(k)] = ...
        iterEacrSPKF(meas_voltage(k), i_profile(k), temp_profile(k), ts, eacr_esc);
    if isfield(eacr_esc, 'lastInnovationPre')
        innov_pre_eacr(k) = eacr_esc.lastInnovationPre;
    end
    if isfield(eacr_esc, 'lastSk')
        sk_eacr(k) = eacr_esc.lastSk;
    end
    soc_eacr(k) = max(0, min(1, soc_eacr(k)));
end

%% Method 3: EsSPKF
esspkf_esc = initEDUKF(soc_init_kf, R0init, tc, SigmaX0, sigma_v_esc, sigma_w_esc, ...
    SigmaR0, SigmaWR0, omt_esc);

soc_esspkf = NaN(n_samples, 1); soc_esspkf(1) = soc_init_kf / 100;
v_esspkf = NaN(n_samples, 1); v_esspkf(1) = meas_voltage(1);
soc_esspkf_bnd = NaN(n_samples, 1);
v_esspkf_bnd = NaN(n_samples, 1);
r0_esspkf = NaN(n_samples, 1); r0_esspkf(1) = esspkf_esc.R0hat;
r0_esspkf_bnd = NaN(n_samples, 1);
innov_pre_esspkf = NaN(n_samples, 1);
sk_esspkf = NaN(n_samples, 1);

for k = 2:n_samples
    [soc_esspkf(k), v_esspkf(k), soc_esspkf_bnd(k), esspkf_esc, v_esspkf_bnd(k), ...
        r0_esspkf(k), r0_esspkf_bnd(k)] = ...
        iterEsSPKF(meas_voltage(k), i_profile(k), temp_profile(k), ts, esspkf_esc);
    if isfield(esspkf_esc, 'lastInnovationPre')
        innov_pre_esspkf(k) = esspkf_esc.lastInnovationPre;
    end
    if isfield(esspkf_esc, 'lastSk')
        sk_esspkf(k) = esspkf_esc.lastSk;
    end
    soc_esspkf(k) = max(0, min(1, soc_esspkf(k)));
end

%% Bias configuration for Methods 4-5
nx_esc = n_rc + 2;
nb_bias = 2;
current_bias_idx = 1;
output_bias_idx = 2;

current_bias_init = 0;
output_bias_init = 0;
current_bias_var0 = 1e-5;
output_bias_var0 = 1e-5;

RC_bias = exp(-ts./abs(getParamESC('RCParam', tc, omt_esc)))';
R_bias = getParamESC('RParam', tc, omt_esc)';
M_bias = getParamESC('MParam', tc, omt_esc);
Q_bias = getParamESC('QParam', tc, omt_esc);
R0_bias = getParamESC('R0Param', tc, omt_esc);

Bb_bias = zeros(nx_esc, nb_bias);
Bb_bias(1:n_rc, current_bias_idx) = -(1 - RC_bias);
Bb_bias(nx_esc, current_bias_idx) = ts / (3600 * Q_bias);
Cb_bias = zeros(1, nb_bias);
Cb_bias(1, current_bias_idx) = R0_bias;
Cb_bias(1, output_bias_idx) = 1;

Ad_bias = eye(nx_esc);
Ad_bias(1:n_rc, 1:n_rc) = diag(RC_bias);

soc0_norm = soc_init_kf / 100;
ds = 1e-6;
soc_hi = min(1.05, soc0_norm + ds);
soc_lo = max(-0.05, soc0_norm - ds);
dOCVdSOC0 = (OCVfromSOCtemp(soc_hi, tc, omt_esc) - OCVfromSOCtemp(soc_lo, tc, omt_esc)) / ...
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

%% Method 4: EBiSPKF
ebispkf_esc = initESCSPKF(soc_init_kf, tc, SigmaX0, sigma_v_bias, sigma_w_esc, omt_esc, biasCfg);

soc_ebispkf = NaN(n_samples, 1); soc_ebispkf(1) = soc_init_kf / 100;
v_ebispkf = NaN(n_samples, 1); v_ebispkf(1) = meas_voltage(1);
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
        bhat_k, bbnd_k] = iterEBiSPKF(meas_voltage(k), i_profile(k), temp_profile(k), ts, ebispkf_esc);
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

%% Method 5: Em7SPKF
em7_esc = Em7init(soc_init_kf, R0init, tc, SigmaX0, sigma_v_bias, sigma_w_esc, ...
    SigmaR0, SigmaWR0, omt_esc, biasCfg);

soc_em7 = NaN(n_samples, 1); soc_em7(1) = soc_init_kf / 100;
v_em7 = NaN(n_samples, 1); v_em7(1) = meas_voltage(1);
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
        Em7SPKF(meas_voltage(k), i_profile(k), temp_profile(k), ts, em7_esc);
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
error_spkf = soc_ref - soc_spkf;
error_eacr = soc_ref - soc_eacr;
error_esspkf = soc_ref - soc_esspkf;
error_ebispkf = soc_ref - soc_ebispkf;
error_em7 = soc_ref - soc_em7;

v_error_spkf = meas_voltage - v_spkf;
v_error_eacr = meas_voltage - v_eacr;
v_error_esspkf = meas_voltage - v_esspkf;
v_error_ebispkf = meas_voltage - v_ebispkf;
v_error_em7 = meas_voltage - v_em7;

rmse_spkf = sqrt(mean(error_spkf(~isnan(error_spkf)).^2));
rmse_eacr = sqrt(mean(error_eacr(~isnan(error_eacr)).^2));
rmse_esspkf = sqrt(mean(error_esspkf(~isnan(error_esspkf)).^2));
rmse_ebispkf = sqrt(mean(error_ebispkf(~isnan(error_ebispkf)).^2));
rmse_em7 = sqrt(mean(error_em7(~isnan(error_em7)).^2));

v_rmse_spkf = sqrt(mean(v_error_spkf(~isnan(v_error_spkf)).^2));
v_rmse_eacr = sqrt(mean(v_error_eacr(~isnan(v_error_eacr)).^2));
v_rmse_esspkf = sqrt(mean(v_error_esspkf(~isnan(v_error_esspkf)).^2));
v_rmse_ebispkf = sqrt(mean(v_error_ebispkf(~isnan(v_error_ebispkf)).^2));
v_rmse_em7 = sqrt(mean(v_error_em7(~isnan(v_error_em7)).^2));

fprintf('\nKFEvalOMT Results (vs Reference)\n');
fprintf('  ESC-SPKF:   SOC RMSE = %.4f%%, V RMSE = %.2f mV\n', 100 * rmse_spkf, 1000 * v_rmse_spkf);
fprintf('  EacrSPKF:   SOC RMSE = %.4f%%, V RMSE = %.2f mV\n', 100 * rmse_eacr, 1000 * v_rmse_eacr);
fprintf('  EsSPKF:     SOC RMSE = %.4f%%, V RMSE = %.2f mV\n', 100 * rmse_esspkf, 1000 * v_rmse_esspkf);
fprintf('  EBiSPKF:    SOC RMSE = %.4f%%, V RMSE = %.2f mV\n', 100 * rmse_ebispkf, 1000 * v_rmse_ebispkf);
fprintf('  Em7SPKF:    SOC RMSE = %.4f%%, V RMSE = %.2f mV\n', 100 * rmse_em7, 1000 * v_rmse_em7);

fprintf('\nBias / Innovation Diagnostics (error = Reference - estimate):\n');
diag_spkf = printEstimatorBiasMetrics('ESC-SPKF', error_spkf, v_error_spkf, innov_pre_spkf, sk_spkf); %#ok<NASGU>
diag_eacr = printEstimatorBiasMetrics('EacrSPKF', error_eacr, v_error_eacr, innov_pre_eacr, sk_eacr); %#ok<NASGU>
diag_esspkf = printEstimatorBiasMetrics('EsSPKF', error_esspkf, v_error_esspkf, innov_pre_esspkf, sk_esspkf); %#ok<NASGU>
diag_ebispkf = printEstimatorBiasMetrics('EBiSPKF', error_ebispkf, v_error_ebispkf, innov_pre_ebispkf, sk_ebispkf); %#ok<NASGU>
diag_em7 = printEstimatorBiasMetrics('Em7SPKF', error_em7, v_error_em7, innov_pre_em7, sk_em7); %#ok<NASGU>

if InnovationACFPACFfigs
    plotInnovationAcfPacf( ...
        {innov_pre_spkf, innov_pre_eacr, innov_pre_esspkf, innov_pre_ebispkf, innov_pre_em7}, ...
        {'ESC-SPKF', 'EacrSPKF', 'EsSPKF', 'EBiSPKF', 'Em7SPKF'}, ...
        60, ...
        'Pre-fit Innovation ACF/PACF (KFEvalOMT)');
end

%% Summary plots
figure('Name', 'OMTLIFE Cell Voltage', 'NumberTitle', 'off');
plot(t, meas_voltage, 'k-', 'LineWidth', 2, 'DisplayName', 'Measured'); hold on;
plot(t, v_spkf, 'g:', 'LineWidth', 1.5, 'DisplayName', 'ESC-SPKF');
plot(t, v_eacr, 'b-.', 'LineWidth', 1.5, 'DisplayName', 'EacrSPKF');
plot(t, v_esspkf, 'c--', 'LineWidth', 1.5, 'DisplayName', 'EsSPKF');
plot(t, v_ebispkf, '-', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.5, 'DisplayName', 'EBiSPKF');
plot(t, v_em7, '-', 'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.5, 'DisplayName', 'Em7SPKF');
grid on; xlabel('Time [s]'); ylabel('Voltage [V]');
title('Measured Voltage vs ESC Filters');
legend('Location', 'best');

figure('Name', 'OMTLIFE SOC Comparison', 'NumberTitle', 'off');
plot(t, 100 * soc_ref, 'k-', 'LineWidth', 2.5, 'DisplayName', 'Reference'); hold on;
if ~isempty(dataset_soc) && any(isfinite(dataset_soc))
    plot(t, 100 * dataset_soc, '--', 'Color', [0.55 0.55 0.55], 'LineWidth', 1.0, 'DisplayName', 'Dataset SOC');
end
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

figure('Name', 'OMTLIFE SOC Errors', 'NumberTitle', 'off');
hold on;
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
title('SOC Estimation Errors vs Reference');
legend('Location', 'best');

figure('Name', 'OMTLIFE Voltage Errors', 'NumberTitle', 'off');
plot(t, v_error_spkf, 'g:', 'LineWidth', 1.5, 'DisplayName', sprintf('ESC-SPKF (RMSE=%.2f mV)', 1000 * v_rmse_spkf)); hold on;
plot(t, v_error_eacr, 'b-.', 'LineWidth', 1.5, 'DisplayName', sprintf('EacrSPKF (RMSE=%.2f mV)', 1000 * v_rmse_eacr));
plot(t, v_error_esspkf, 'c--', 'LineWidth', 1.5, 'DisplayName', sprintf('EsSPKF (RMSE=%.2f mV)', 1000 * v_rmse_esspkf));
plot(t, v_error_ebispkf, '-', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.5, ...
    'DisplayName', sprintf('EBiSPKF (RMSE=%.2f mV)', 1000 * v_rmse_ebispkf));
plot(t, v_error_em7, '-', 'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Em7SPKF (RMSE=%.2f mV)', 1000 * v_rmse_em7));
grid on; xlabel('Time [s]'); ylabel('Voltage Error [V]');
title('Voltage Estimation Errors vs Measured Voltage');
legend('Location', 'best');

%% Optional per-estimator error + bounds plots
methodNames = {'ESC-SPKF', 'EacrSPKF', 'EsSPKF', 'EBiSPKF', 'Em7SPKF'};
socErrList = {error_spkf, error_eacr, error_esspkf, error_ebispkf, error_em7};
socBndList = {soc_spkf_bnd, soc_eacr_bnd, soc_esspkf_bnd, soc_ebispkf_bnd, soc_em7_bnd};
vErrList = {v_error_spkf, v_error_eacr, v_error_esspkf, v_error_ebispkf, v_error_em7};
vBndList = {v_spkf_bnd, v_eacr_bnd, v_esspkf_bnd, v_ebispkf_bnd, v_em7_bnd};

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

results = struct(); %#ok<NASGU>
results.time_s = t;
results.current_a = i_profile;
results.voltage_v = meas_voltage;
results.soc_reference = soc_ref;
results.soc_dataset = dataset_soc;
results.methods.esc_spkf = packEstimatorResult(soc_spkf, v_spkf, soc_spkf_bnd, v_spkf_bnd, error_spkf, v_error_spkf, rmse_spkf, v_rmse_spkf);
results.methods.eacr_spkf = packEstimatorResult(soc_eacr, v_eacr, soc_eacr_bnd, v_eacr_bnd, error_eacr, v_error_eacr, rmse_eacr, v_rmse_eacr);
results.methods.es_spkf = packEstimatorResult(soc_esspkf, v_esspkf, soc_esspkf_bnd, v_esspkf_bnd, error_esspkf, v_error_esspkf, rmse_esspkf, v_rmse_esspkf);
results.methods.ebi_spkf = packEstimatorResult(soc_ebispkf, v_ebispkf, soc_ebispkf_bnd, v_ebispkf_bnd, error_ebispkf, v_error_ebispkf, rmse_ebispkf, v_rmse_ebispkf);
results.methods.em7_spkf = packEstimatorResult(soc_em7, v_em7, soc_em7_bnd, v_em7_bnd, error_em7, v_error_em7, rmse_em7, v_rmse_em7);
results.methods.es_spkf.r0 = r0_esspkf;
results.methods.es_spkf.r0_bnd = r0_esspkf_bnd;
results.methods.ebi_spkf.bias = bias_ebispkf;
results.methods.ebi_spkf.bias_bnd = bias_ebispkf_bnd;
results.methods.em7_spkf.bias = bias_em7;
results.methods.em7_spkf.bias_bnd = bias_em7_bnd;
results.methods.em7_spkf.r0 = r0_em7;
results.methods.em7_spkf.r0_bnd = r0_em7_bnd;

function estimator = packEstimatorResult(soc, v, soc_bnd, v_bnd, soc_err, v_err, soc_rmse, v_rmse)
estimator = struct();
estimator.soc = soc;
estimator.voltage = v;
estimator.soc_bnd = soc_bnd;
estimator.voltage_bnd = v_bnd;
estimator.soc_error = soc_err;
estimator.voltage_error = v_err;
estimator.soc_rmse = soc_rmse;
estimator.voltage_rmse = v_rmse;
end

function file_path = firstExistingFileOrOverride(candidates, override_file, error_id, error_msg)
if ~isempty(override_file)
    if exist(override_file, 'file')
        file_path = override_file;
        return;
    end
    error(error_id, '%s Override file not found: %s', error_msg, override_file);
end

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

function model = extractModelStruct(raw)
if isfield(raw, 'model')
    model = raw.model;
elseif isfield(raw, 'nmc30_model')
    model = raw.nmc30_model;
else
    error('KFEvalOMT:BadModelFile', ...
        'Expected variable "model" or "nmc30_model" in ESC model file.');
end
end

function temp_value = resolveModelTemperature(model, default_temp)
if isfield(model, 'temps') && ~isempty(model.temps)
    temp_value = double(model.temps(1));
else
    temp_value = double(default_temp);
end
end

function profile = loadBusCoreBatteryProfile(profile_file)
if exist(profile_file, 'file') ~= 2
    error('KFEvalOMT:MissingProfile', ...
        'Profile file not found: %s', profile_file);
end

raw = load(profile_file);
primary = choosePrimaryNode(raw);

profile = struct();
profile.profile_file = profile_file;
[~, name, ext] = fileparts(profile_file);
profile.profile_name = [name, ext];

[current_raw, ~] = extractSignal(primary, {'Total_Current_A', 'Current_Vector_A'});
[voltage_raw, ~] = extractSignal(primary, {'Voltage_Vector_V', 'Total_Voltage_V'});
[soc_raw, ~] = extractSignal(primary, {'SOC_Vector_Percent'});
[temp_raw, ~] = extractSignal(primary, {'Temperature_Vector_degC'});

profile.current_a = coerceNumericVector(current_raw, false);
profile.voltage_v = normalizeOptionalSignal(voltage_raw, numel(profile.current_a), 'voltage');
profile.soc_ref = normalizeSocSignal(normalizeOptionalSignal(soc_raw, numel(profile.current_a), 'soc'));
profile.temperature_c = normalizeOptionalSignal(temp_raw, numel(profile.current_a), 'temperature');

if isempty(profile.current_a)
    error('KFEvalOMT:MissingCurrent', 'Could not locate current signal in %s.', profile_file);
end
if isempty(profile.voltage_v)
    error('KFEvalOMT:MissingVoltage', 'Could not locate voltage signal in %s.', profile_file);
end

if isa(current_raw, 'timeseries')
    profile.time_s = normalizeTimeVector(current_raw.Time, numel(profile.current_a), 'current.Time');
else
    profile.time_s = (0:numel(profile.current_a)-1).';
end
profile.current_a = orientCurrentToDischargePositive(profile.current_a, profile.time_s, profile.soc_ref);
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
    error('KFEvalOMT:SignalLengthMismatch', ...
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
    error('KFEvalOMT:TimeLengthMismatch', ...
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
soc = max(0, min(1, soc));
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
