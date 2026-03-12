% runNMC30SOCComparison.m
% Simulates NMC30 fast-charge protocol with KF/MPC and compares SOC estimators:
%   1. Coulomb counting (baseline)
%   2. ROM-based EKF (physics-based model)
%   3. ESC-SPKF (electrical circuit model)
%   4. EaEKF (adaptive EKF on ESC model)
%   5. EsSPKF (ESC model with simplified online R0 estimation) 2be tested
%   6. EBiSPKF (ESC-SPKF with external bias tracking)
%   7. Em7SPKF (EBiSPKF + simplified R0-SPKF branch)

clear; 
%clc; close all;
clear iterEKF iterESCSPKF iterEaEKF iterEsSPKF iterEBiSPKF Em7SPKF;

script_fullpath = mfilename('fullpath');
if isempty(script_fullpath)
    script_fullpath = which('runNMC30SOCComparison');
end
if isempty(script_fullpath)
    script_dir = pwd;
else
    script_dir = fileparts(script_fullpath);
end
project_root = fileparts(fileparts(fileparts(script_dir)));
esc_id_root = fullfile(script_dir, 'ESC_Id');

% Optional fallback if the project tree is not already on the MATLAB path.
% addpath(script_dir);
% addpath(fullfile(esc_id_root, 'ModelMgmt'));

%% SETTINGS
tc = 25;                          % Temperature [°C]
ts = 1;                           % Sampling time [s]
SOCfigs = false;                   % Plot per-estimator SOC error + bounds figures.
Vfigs = false;                     % Plot per-estimator voltage error + bounds figures.
InnovationACFPACFfigs = true;      % Plot pre-fit innovation ACF/PACF diagnostics.

% Initial conditions
soc_init = 100;                   % Initial SOC [%]
u_init = 0;                       % Initial current [A]

% ROM and model files
rom_file = firstExistingFile({ ...
    fullfile(script_dir, 'models', 'ROM_NMC30_HRA12.mat'), ...
    fullfile(script_dir, 'ROM_NMC30_HRA12.mat'), ...
    fullfile(project_root, 'models', 'ROM_NMC30_HRA12.mat'), ...
    fullfile(project_root, 'src', 'MPC-EKF4FastCharge', 'ROM_NMC30_HRA12.mat')}, ...
    'runNMC30SOCComparison:MissingROMFile', ...
    'No ROM model file found.');

esc_model_file = firstExistingFile({ ...
    fullfile(script_dir, 'models', 'NMC30model.mat'), ...
    fullfile(script_dir, 'NMC30model.mat'), ...
    fullfile(esc_id_root, 'NMC30model.mat'), ...
    fullfile(project_root, 'models', 'NMC30model.mat')}, ...
    'runNMC30SOCComparison:MissingFullESCModel', ...
    'No NMC30 full ESC model found.');

esc_model_file_ocv_only = firstExistingFileOrEmpty({ ...
    fullfile(script_dir, 'models', 'NMC30model-ocv.mat'), ...
    fullfile(esc_id_root, 'NMC30model-ocv.mat'), ...
    fullfile(script_dir, 'NMC30model-ocv.mat')});  % Fallback: OCV only

% Load ESC model (try full model first, fall back to OCV-only)
if exist(esc_model_file, 'file')
    % fprintf('Using full identified model: %s\n', esc_model_file);
    esc_model_data = load(esc_model_file);
    nmc30_esc = esc_model_data.nmc30_model;
    is_full_model = true;
    fprintf('ESC model type: FULL (identified parameters)\n');
% elseif exist(esc_model_file_ocv_only, 'file')
%     fprintf('Using OCV-only model (template RC): %s\n', esc_model_file_ocv_only);
%     fprintf('For better accuracy, run: fullParameterIdentificationNMC30\n');
%     esc_model_data = load(esc_model_file_ocv_only);
%     nmc30_esc = esc_model_data.nmc30_model;
%     is_full_model = false;
else
    error('No NMC30 full ESC model found. Run createNMC30Model first.');
end

%% STEP 1: Load models
% fprintf('===== STEP 1: Load models =====\n');
rom_data = load(rom_file);
ROM = rom_data.ROM;

fprintf('ROM loaded: %d ROM states\n', size(ROM.ROMmdls, 2));
% fprintf('ESC model loaded: Q = %.2f Ah\n', nmc30_esc.QParam);
% Full ESC gate: all KF branches in this script require RC states.
if ~isfield(nmc30_esc, 'RCParam')
    error('runNMC30SOCComparison:MissingRCParam', ...
        'Loaded ESC model is not full: RCParam is missing.');
end
n_rc = numel(getParamESC('RCParam', tc, nmc30_esc));
if n_rc < 1
    error('runNMC30SOCComparison:NoRCBranches', ...
        'Loaded ESC model is not full: no RC branches detected.');
end
fprintf('ESC RC branches detected: %d\n', n_rc);

%% STEP 2: Generate test current profile (Script 1 discharge protocol)
fprintf('\n===---- STEP 2: Generate test current profile -----\n');

capacity_ah = nmc30_esc.QParam;
i_1c = capacity_ah;
[i_profile, step_id] = buildScript1Profile(i_1c, capacity_ah, ts); % #ok<NASGU>
i_profile = i_profile(:);
t = (0:length(i_profile)-1).' * ts;
n_samples = length(t);
final_time = t(end);

fprintf('Current profile: discharge from %.0f%% to ~10%% at 1C\n', soc_init);
fprintf('Profile range: [%.1f, %.1f] A, duration = %d s\n', ...
    min(i_profile), max(i_profile), final_time);

%% STEP 3: Simulate ROM (ground truth)
% fprintf('\n===== STEP 3: Simulate ROM (ground truth) =====\n');

% Pre-allocate storage
rom_state = [];
rom_voltage = NaN(n_samples, 1);
rom_soc = NaN(n_samples, 1);
rom_soc(1) = soc_init / 100;  % Convert to [0, 1]

% Initialize OB_step
init_cfg = struct('SOC0', soc_init, 'warnOff', true);

for k = 1:n_samples
    if k == 1
        [rom_voltage(k), rom_obs, rom_state] = OB_step(i_profile(k), tc, [], ROM, init_cfg);
        rom_soc(k) = soc_init / 100;
    else
        [rom_voltage(k), rom_obs, rom_state] = OB_step(i_profile(k), tc, rom_state, ROM, []);
        % SOC from OB_step: use coulomb counting from obs
        rom_soc(k) = rom_soc(k-1) - (i_profile(k) * ts) / (3600 * capacity_ah);
        rom_soc(k) = max(0, min(1, rom_soc(k)));
    end
    
    % if mod(k, 600) == 0
    %     fprintf('  ROM simulation: %d / %d samples (%.1f %%)\n', k, n_samples, 100*k/n_samples);
    % end
end

fprintf('ROM simulation complete. Voltage range: [%.2f, %.2f] V\n', ...
    min(rom_voltage), max(rom_voltage));

%% STEP 4: Estimate SOC using all methods
% fprintf('\n===== STEP 4: Estimate SOC using all methods =====\n');

% Method 1: Coulomb counting
soc_cc = NaN(n_samples, 1);
soc_cc(1) = soc_init / 100;
for k = 2:n_samples
    soc_cc(k) = soc_cc(k-1) - (i_profile(k) * ts) / (3600 * capacity_ah);
    soc_cc(k) = max(0, min(1, soc_cc(k)));
end

% Method 2: ROM-based EKF
% Initialize EKF
nx = 12;  % Number of ROM states
sigma_x0 = diag([ones(1, nx), 2e6]);
sigma_w  = 1e2;    % 1e2 process/current noise, big = "trust the sensor"
sigma_v  = 1e-3;    % 1e-3 voltage noise, big = "trust the model more than the sensor"

ekf_data = initKF(soc_init, tc, sigma_x0, sigma_v, sigma_w, 'OutB', ROM);

soc_ekf = NaN(n_samples, 1);
soc_ekf(1) = soc_init / 100;
v_ekf = NaN(n_samples, 1);
v_ekf(1) = rom_voltage(1);
soc_ekf_bnd = NaN(n_samples, 1);
v_ekf_bnd = NaN(n_samples, 1);
innov_pre_ekf = NaN(n_samples, 1);
sk_ekf = NaN(n_samples, 1);

for k = 2:n_samples
    [z_ekf, bound_ekf, ekf_data] = iterEKF(rom_voltage(k), i_profile(k), tc, ekf_data);
    if isfield(ekf_data, 'lastInnovationPre')
        innov_pre_ekf(k) = ekf_data.lastInnovationPre;
    end
    if isfield(ekf_data, 'lastSk')
        sk_ekf(k) = ekf_data.lastSk;
    end
    % iterEKF packages SOC as the final element of zk.
    if ~isnan(z_ekf(end))
        soc_ekf(k) = z_ekf(end);
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

% -------------------------------------------------------------------------
% ESC Methods:
SigmaX0 = diag([1e-6 * ones(1, n_rc), 1e-6, 1e-3]);
% soc_init = SOCfromOCVtemp(v0, T0, model)]; % Potential SOC0 guess

% Method 3: ESC-SPKF
% Initialize SPKF with ESC model
spkf_esc = initESCSPKF(soc_init,tc,SigmaX0,sigma_v,sigma_w,nmc30_esc);

soc_spkf = NaN(n_samples, 1);
soc_spkf(1) = soc_init / 100;
v_spkf = NaN(n_samples, 1);
v_spkf(1) = OCVfromSOCtemp(soc_spkf(1), tc, nmc30_esc);
soc_spkf_bnd = NaN(n_samples, 1);
v_spkf_bnd = NaN(n_samples, 1);
innov_pre_spkf = NaN(n_samples, 1);
sk_spkf = NaN(n_samples, 1);

for k = 2:n_samples
    [soc_spkf(k), v_spkf(k), soc_spkf_bnd(k), spkf_esc, v_spkf_bnd(k)] = iterESCSPKF(rom_voltage(k), ...
        i_profile(k), tc, ts, spkf_esc);
    if isfield(spkf_esc, 'lastInnovationPre')
        innov_pre_spkf(k) = spkf_esc.lastInnovationPre;
    end
    if isfield(spkf_esc, 'lastSk')
        sk_spkf(k) = spkf_esc.lastSk;
    end
    
    % Ensure SOC stays in valid range
    soc_spkf(k) = max(0, min(1, soc_spkf(k)));
end

% -------------------------------------------------------------------------
% Dual Methods

% Method 4: EaEKF (adaptive EKF on ESC model)
eaekf_esc = initEaEKF(soc_init, tc, SigmaX0, sigma_v, sigma_w, nmc30_esc);

soc_eaekf = NaN(n_samples, 1);
soc_eaekf(1) = soc_init / 100;
v_eaekf = NaN(n_samples, 1);
v_eaekf(1) = OCVfromSOCtemp(soc_eaekf(1), tc, nmc30_esc);
soc_eaekf_bnd = NaN(n_samples, 1);
v_eaekf_bnd = NaN(n_samples, 1);
sigma_v_eaekf = NaN(n_samples, 1);
sigma_w_eaekf_soc = NaN(n_samples, 1);
sigma_w_eaekf_trace = NaN(n_samples, 1);
sigma_v_eaekf(1) = eaekf_esc.SigmaV;
sigma_w_eaekf_soc(1) = eaekf_esc.SigmaW(eaekf_esc.soc_estInd, eaekf_esc.soc_estInd);
sigma_w_eaekf_trace(1) = trace(eaekf_esc.SigmaW);
innov_pre_eaekf = NaN(n_samples, 1);
sk_eaekf = NaN(n_samples, 1);

for k = 2:n_samples
    [soc_eaekf(k), v_eaekf(k), soc_eaekf_bnd(k), eaekf_esc, v_eaekf_bnd(k)] = ...
        iterEaEKF(rom_voltage(k), i_profile(k), tc, ts, eaekf_esc);
    if isfield(eaekf_esc, 'lastInnovationPre')
        innov_pre_eaekf(k) = eaekf_esc.lastInnovationPre;
    end
    if isfield(eaekf_esc, 'lastSk')
        sk_eaekf(k) = eaekf_esc.lastSk;
    end

    soc_eaekf(k) = max(0, min(1, soc_eaekf(k)));
    sigma_v_eaekf(k) = eaekf_esc.SigmaV;
    sigma_w_eaekf_soc(k) = eaekf_esc.SigmaW(eaekf_esc.soc_estInd, eaekf_esc.soc_estInd);
    sigma_w_eaekf_trace(k) = trace(eaekf_esc.SigmaW);
end

% Method 5: EsSPKF (simplified R0-SPKF branch)
SigmaR0 = 1e-6;
SigmaWR0 = 1e-16;
R0init = getParamESC('R0Param',tc,nmc30_esc);
esspkf_esc = initEDUKF(soc_init, R0init, tc, SigmaX0, sigma_v, sigma_w, SigmaR0, ...
    SigmaWR0, nmc30_esc);

soc_esspkf = NaN(n_samples, 1);
soc_esspkf(1) = soc_init / 100;
v_esspkf = NaN(n_samples, 1);
v_esspkf(1) = OCVfromSOCtemp(soc_esspkf(1), tc, nmc30_esc);
soc_esspkf_bnd = NaN(n_samples, 1);
v_esspkf_bnd = NaN(n_samples, 1);
r0_esspkf = NaN(n_samples, 1);
r0_esspkf(1) = esspkf_esc.R0hat;
r0_esspkf_bnd = NaN(n_samples, 1);
innov_pre_esspkf = NaN(n_samples, 1);
sk_esspkf = NaN(n_samples, 1);

for k = 2:n_samples
    [soc_esspkf(k), v_esspkf(k), soc_esspkf_bnd(k), esspkf_esc, v_esspkf_bnd(k), ...
        r0_esspkf(k), r0_esspkf_bnd(k)] = iterEsSPKF(rom_voltage(k), i_profile(k), tc, ts, esspkf_esc);
    if isfield(esspkf_esc, 'lastInnovationPre')
        innov_pre_esspkf(k) = esspkf_esc.lastInnovationPre;
    end
    if isfield(esspkf_esc, 'lastSk')
        sk_esspkf(k) = esspkf_esc.lastSk;
    end

    soc_esspkf(k) = max(0, min(1, soc_esspkf(k)));
end

% -------------------------------------------------------------------------
% Method 6: EBiSPKF (external bias-tracking branch)
nx_esc = n_rc + 2;
nb_bias = 1 + 1; % one current/state bias + one direct output-measurement bias
current_bias_idx = 1;
output_bias_idx = 2;

current_bias_init = 0;         % [A]
output_bias_init = 0;          % [V]
current_bias_var0 = 1e-5;      % initial covariance for current bias [A^2]
output_bias_var0 = 1e-5;        % initial covariance for output bias [V^2]

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
Cb_bias(1, output_bias_idx) = 1; % direct additive output-measurement bias [V]

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
biasCfg.bhat0 = [current_bias_init; output_bias_init]; % initial bias estimate [A; V]
biasCfg.SigmaB0 = diag([current_bias_var0, output_bias_var0]); % initial bias covariance
biasCfg.Bb = Bb_bias;
biasCfg.Cb = Cb_bias;
biasCfg.biasModelStatic = true;
biasCfg.Ad = Ad_bias;
biasCfg.Cd = Cd_bias;
biasCfg.currentBiasInd = current_bias_idx;

ebispkf_esc = initESCSPKF(soc_init, tc, SigmaX0, sigma_v, sigma_w, nmc30_esc, biasCfg);

soc_ebispkf = NaN(n_samples, 1);
soc_ebispkf(1) = soc_init / 100;
v_ebispkf = NaN(n_samples, 1);
v_ebispkf(1) = OCVfromSOCtemp(soc_ebispkf(1), tc, nmc30_esc);
soc_ebispkf_bnd = NaN(n_samples, 1);
v_ebispkf_bnd = NaN(n_samples, 1);
bias_ebispkf = NaN(n_samples, nb_bias);
bias_ebispkf_bnd = NaN(n_samples, nb_bias);
bias_ebispkf(1, :) = ebispkf_esc.bhat(:).';
bias_ebispkf_bnd(1, :) = (3 * sqrt(max(diag(ebispkf_esc.SigmaB), 0))).';
innov_pre_ebispkf = NaN(n_samples, 1);
sk_ebispkf = NaN(n_samples, 1);
current_bias_idx = ebispkf_esc.currentBiasInd;
other_bias_idx = setdiff(1:nb_bias, current_bias_idx, 'stable');
output_bias_idx = other_bias_idx(1);

for k = 2:n_samples
    [soc_ebispkf(k), v_ebispkf(k), soc_ebispkf_bnd(k), ebispkf_esc, v_ebispkf_bnd(k), ...
        bhat_k, bbnd_k] = iterEBiSPKF(rom_voltage(k), i_profile(k), tc, ts, ebispkf_esc);
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

% -------------------------------------------------------------------------
% Method 7: Em7SPKF (EBiSPKF + simplified R0-SPKF branch)
SigmaR0_em7 = 1e-6;
SigmaWR0_em7 = 1e-16;
R0init_em7 = getParamESC('R0Param', tc, nmc30_esc);

em7_esc = Em7init(soc_init, R0init_em7, tc, SigmaX0, sigma_v, sigma_w, ...
    SigmaR0_em7, SigmaWR0_em7, nmc30_esc, biasCfg);

soc_em7 = NaN(n_samples, 1);
soc_em7(1) = soc_init / 100;
v_em7 = NaN(n_samples, 1);
v_em7(1) = OCVfromSOCtemp(soc_em7(1), tc, nmc30_esc);
soc_em7_bnd = NaN(n_samples, 1);
v_em7_bnd = NaN(n_samples, 1);
bias_em7 = NaN(n_samples, nb_bias);
bias_em7_bnd = NaN(n_samples, nb_bias);
bias_em7(1, :) = em7_esc.bhat(:).';
bias_em7_bnd(1, :) = (3 * sqrt(max(diag(em7_esc.SigmaB), 0))).';
r0_em7 = NaN(n_samples, 1);
r0_em7(1) = em7_esc.R0hat;
r0_em7_bnd = NaN(n_samples, 1);
innov_pre_em7 = NaN(n_samples, 1);
sk_em7 = NaN(n_samples, 1);
em7_current_bias_idx = em7_esc.currentBiasInd;
em7_output_bias_idx = setdiff(1:nb_bias, em7_current_bias_idx, 'stable');
em7_output_bias_idx = em7_output_bias_idx(1);

for k = 2:n_samples
    [soc_em7(k), v_em7(k), soc_em7_bnd(k), em7_esc, v_em7_bnd(k), ...
        bhat_em7_k, bbnd_em7_k, r0_em7(k), r0_em7_bnd(k)] = Em7SPKF( ...
        rom_voltage(k), i_profile(k), tc, ts, em7_esc);
    if isfield(em7_esc, 'lastInnovationPre')
        innov_pre_em7(k) = em7_esc.lastInnovationPre;
    end
    if isfield(em7_esc, 'lastSk')
        sk_em7(k) = em7_esc.lastSk;
    end

    soc_em7(k) = max(0, min(1, soc_em7(k)));
    bias_em7(k, :) = bhat_em7_k(:).';
    bias_em7_bnd(k, :) = bbnd_em7_k(:).';
end

fprintf('SOC estimation complete.\n');

%% STEP 5: Analysis and comparison
% fprintf('\n===== STEP 5: Analysis =====\n');

% Calculate errors vs ROM (ground truth)
error_cc = rom_soc - soc_cc;
error_ekf = rom_soc - soc_ekf;
error_spkf = rom_soc - soc_spkf;
error_eaekf = rom_soc - soc_eaekf;
error_esspkf = rom_soc - soc_esspkf;
error_ebispkf = rom_soc - soc_ebispkf;
error_em7 = rom_soc - soc_em7;
v_error_ekf = rom_voltage - v_ekf;
v_error_spkf = rom_voltage - v_spkf;
v_error_eaekf = rom_voltage - v_eaekf;
v_error_esspkf = rom_voltage - v_esspkf;
v_error_ebispkf = rom_voltage - v_ebispkf;
v_error_em7 = rom_voltage - v_em7;

rmse_cc = sqrt(mean(error_cc.^2));
rmse_ekf = sqrt(mean(error_ekf(~isnan(error_ekf)).^2));
rmse_spkf = sqrt(mean(error_spkf(~isnan(error_spkf)).^2));
rmse_eaekf = sqrt(mean(error_eaekf(~isnan(error_eaekf)).^2));
rmse_esspkf = sqrt(mean(error_esspkf(~isnan(error_esspkf)).^2));
rmse_ebispkf = sqrt(mean(error_ebispkf(~isnan(error_ebispkf)).^2));
rmse_em7 = sqrt(mean(error_em7(~isnan(error_em7)).^2));

% Voltage RMSE calculations
v_rmse_ekf = sqrt(mean(v_error_ekf(~isnan(v_error_ekf)).^2));
v_rmse_spkf = sqrt(mean(v_error_spkf(~isnan(v_error_spkf)).^2));
v_rmse_eaekf = sqrt(mean(v_error_eaekf(~isnan(v_error_eaekf)).^2));
v_rmse_esspkf = sqrt(mean(v_error_esspkf(~isnan(v_error_esspkf)).^2));
v_rmse_ebispkf = sqrt(mean(v_error_ebispkf(~isnan(v_error_ebispkf)).^2));
v_rmse_em7 = sqrt(mean(v_error_em7(~isnan(v_error_em7)).^2));

max_error_cc = max(abs(error_cc));
max_error_ekf = max(abs(error_ekf(~isnan(error_ekf))));
max_error_spkf = max(abs(error_spkf(~isnan(error_spkf))));
max_error_eaekf = max(abs(error_eaekf(~isnan(error_eaekf))));
max_error_esspkf = max(abs(error_esspkf(~isnan(error_esspkf))));
max_error_ebispkf = max(abs(error_ebispkf(~isnan(error_ebispkf))));
max_error_em7 = max(abs(error_em7(~isnan(error_em7))));

fprintf('\nSOC Estimation Results (vs ROM ground truth):\n');
fprintf('  Coulomb Counting:      RMSE = %.4f, Max Error = %.4f\n', rmse_cc, max_error_cc);
fprintf('  ROM-EKF:               RMSE = %.4f, Max Error = %.4f\n', rmse_ekf, max_error_ekf);
fprintf('  ESC-SPKF:              RMSE = %.4f, Max Error = %.4f\n', rmse_spkf, max_error_spkf);
fprintf('  EaEKF:                 RMSE = %.4f, Max Error = %.4f\n', rmse_eaekf, max_error_eaekf);
fprintf('  EsSPKF:                RMSE = %.4f, Max Error = %.4f\n', rmse_esspkf, max_error_esspkf);
fprintf('  EBiSPKF:               RMSE = %.4f, Max Error = %.4f\n', rmse_ebispkf, max_error_ebispkf);
fprintf('  Em7SPKF:               RMSE = %.4f, Max Error = %.4f\n', rmse_em7, max_error_em7);

fprintf('\nBias / Innovation Diagnostics (error = ROM truth - estimate):\n');
diag_cc = printEstimatorBiasMetrics('Coulomb Counting', error_cc, [], [], []);
diag_ekf = printEstimatorBiasMetrics('ROM-EKF', error_ekf, v_error_ekf, innov_pre_ekf, sk_ekf);
diag_spkf = printEstimatorBiasMetrics('ESC-SPKF', error_spkf, v_error_spkf, innov_pre_spkf, sk_spkf);
diag_eaekf = printEstimatorBiasMetrics('EaEKF', error_eaekf, v_error_eaekf, innov_pre_eaekf, sk_eaekf);
diag_esspkf = printEstimatorBiasMetrics('EsSPKF', error_esspkf, v_error_esspkf, innov_pre_esspkf, sk_esspkf);
diag_ebispkf = printEstimatorBiasMetrics('EBiSPKF', error_ebispkf, v_error_ebispkf, innov_pre_ebispkf, sk_ebispkf);
diag_em7 = printEstimatorBiasMetrics('Em7SPKF', error_em7, v_error_em7, innov_pre_em7, sk_em7);

if InnovationACFPACFfigs
    plotInnovationAcfPacf( ...
        {innov_pre_ekf, innov_pre_spkf, innov_pre_eaekf, innov_pre_esspkf, innov_pre_ebispkf, innov_pre_em7}, ...
        {'ROM-EKF', 'ESC-SPKF', 'EaEKF', 'EsSPKF', 'EBiSPKF', 'Em7SPKF'}, ...
        60, ...
        'Pre-fit Innovation ACF/PACF (runNMC30SOCComparison)');
end

%% STEP 6: Plotting
% fprintf('\n===== STEP 6: Plotting =====\n');

% % Plot 1: Current profile
% figure('Name', 'Current Profile', 'NumberTitle', 'off');
% plot(t, i_profile, 'LineWidth', 2);
% grid on; xlabel('Time [s]'); ylabel('Current [A]');
% title('Discharge Current Profile (100% to ~10% at 1C)');

% Plot 2: Cell voltage
figure('Name', 'Cell Voltage', 'NumberTitle', 'off');
plot(t, rom_voltage, 'k-', 'LineWidth', 2, 'DisplayName', 'ROM (Ground Truth)');
hold on;
plot(t, v_ekf, 'r-', 'LineWidth', 1.5, 'DisplayName', 'ROM-EKF');
plot(t, v_spkf, 'g:', 'LineWidth', 1.5, 'DisplayName', 'ESC-SPKF');
plot(t, v_eaekf, 'm-.', 'LineWidth', 1.5, 'DisplayName', 'EaEKF');
plot(t, v_esspkf, 'c--', 'LineWidth', 1.5, 'DisplayName', 'EsSPKF');
plot(t, v_ebispkf, '-', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.5, 'DisplayName', 'EBiSPKF');
plot(t, v_em7, '-', 'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.5, 'DisplayName', 'Em7SPKF');
grid on; xlabel('Time [s]'); ylabel('Voltage [V]');
title('Cell Voltage');
legend('Location', 'best');

% Plot 3: SOC comparison
figure('Name', 'SOC Comparison', 'NumberTitle', 'off');
plot(t, 100*rom_soc, 'k-', 'LineWidth', 2.5, 'DisplayName', 'ROM (Ground Truth)');
hold on;
plot(t, 100*soc_cc, 'b--', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('Coulomb Counting (RMSE=%.3f%%)', 100*rmse_cc));
plot(t, 100*soc_ekf, 'r-', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('ROM-EKF (RMSE=%.3f%%)', 100*rmse_ekf));
plot(t, 100*soc_spkf, 'g:', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('ESC-SPKF (RMSE=%.3f%%)', 100*rmse_spkf));
plot(t, 100*soc_eaekf, 'm-.', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('EaEKF (RMSE=%.3f%%)', 100*rmse_eaekf));
plot(t, 100*soc_esspkf, 'c--', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('EsSPKF (RMSE=%.3f%%)', 100*rmse_esspkf));
plot(t, 100*soc_ebispkf, '-', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('EBiSPKF (RMSE=%.3f%%)', 100*rmse_ebispkf));
plot(t, 100*soc_em7, '-', 'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('Em7SPKF (RMSE=%.3f%%)', 100*rmse_em7));
grid on; xlabel('Time [s]'); ylabel('SOC [%]');
title('SOC Estimation Comparison');
legend('Location', 'best');

% Plot 4: SOC errors
figure('Name', 'SOC Errors', 'NumberTitle', 'off');
plot(t, 100*error_cc, 'b--', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('Coulomb Counting (RMSE=%.3f%%)', 100*rmse_cc));
hold on;
plot(t, 100*error_ekf, 'r-', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('ROM-EKF (RMSE=%.3f%%)', 100*rmse_ekf));
plot(t, 100*error_spkf, 'g:', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('ESC-SPKF (RMSE=%.3f%%)', 100*rmse_spkf));
plot(t, 100*error_eaekf, 'm-.', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('EaEKF (RMSE=%.3f%%)', 100*rmse_eaekf));
plot(t, 100*error_esspkf, 'c--', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('EsSPKF (RMSE=%.3f%%)', 100*rmse_esspkf));
plot(t, 100*error_ebispkf, '-', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('EBiSPKF (RMSE=%.3f%%)', 100*rmse_ebispkf));
plot(t, 100*error_em7, '-', 'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('Em7SPKF (RMSE=%.3f%%)', 100*rmse_em7));
grid on; xlabel('Time [s]'); ylabel('SOC Error [%]');
title('SOC Estimation Errors vs ROM Ground Truth');
legend('Location', 'best');

% Plot 5: Voltage estimation errors vs ROM ground truth
figure('Name', 'Voltage Errors', 'NumberTitle', 'off');
plot(t, v_error_ekf, 'r-', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('ROM-EKF (RMSE=%.2f mV)', 1000*v_rmse_ekf));
hold on;
plot(t, v_error_spkf, 'g:', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('ESC-SPKF (RMSE=%.2f mV)', 1000*v_rmse_spkf));
plot(t, v_error_eaekf, 'm-.', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('EaEKF (RMSE=%.2f mV)', 1000*v_rmse_eaekf));
plot(t, v_error_esspkf, 'c--', 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('EsSPKF (RMSE=%.2f mV)', 1000*v_rmse_esspkf));
plot(t, v_error_ebispkf, '-', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('EBiSPKF (RMSE=%.2f mV)', 1000*v_rmse_ebispkf));
plot(t, v_error_em7, '-', 'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.5, 'DisplayName', ...
    sprintf('Em7SPKF (RMSE=%.2f mV)', 1000*v_rmse_em7));
grid on; xlabel('Time [s]'); ylabel('Voltage Error [V]');
title('Voltage Estimation Errors vs ROM Ground Truth');
legend('Location', 'best');

trueSOC = rom_soc;

if SOCfigs
    figure('Name', 'SOC Error (ROM-EKF)', 'NumberTitle', 'off');
    plot(100 * (trueSOC - soc_ekf)); hold on; grid on;
    set(gca, 'colororderindex', 1); plot(100 * soc_ekf_bnd, ':');
    set(gca, 'colororderindex', 1); plot(-100 * soc_ekf_bnd, ':');
    title(sprintf('SOC estimation error (percent, %s)', 'ROM-EKF'));

    count_ekf = sum(abs(trueSOC - soc_ekf) > soc_ekf_bnd, 'omitnan');
    if any(isnan(soc_ekf))
        fprintf(' - EKF failed (NaN estimates)\n');
    else
        fprintf(' - SOC estimate outside of bounds %g %% of the time (%s)\n', ...
            count_ekf / length(trueSOC) * 100, 'ROM-EKF');
    end

    figure('Name', 'SOC Error (ESC-SPKF)', 'NumberTitle', 'off');
    plot(100 * (trueSOC - soc_spkf)); hold on; grid on;
    set(gca, 'colororderindex', 1); plot(100 * soc_spkf_bnd, ':');
    set(gca, 'colororderindex', 1); plot(-100 * soc_spkf_bnd, ':');
    title(sprintf('SOC estimation error (percent, %s)', 'ESC-SPKF'));

    count_spkf = sum(abs(trueSOC - soc_spkf) > soc_spkf_bnd, 'omitnan');
    if any(isnan(soc_spkf))
        fprintf(' - ESC-SPKF failed (NaN estimates)\n');
    else
        fprintf(' - SOC estimate outside of bounds %g %% of the time (%s)\n', ...
            count_spkf / length(trueSOC) * 100, 'ESC-SPKF');
    end

    figure('Name', 'SOC Error (EaEKF)', 'NumberTitle', 'off');
    plot(100 * (trueSOC - soc_eaekf)); hold on; grid on;
    set(gca, 'colororderindex', 1); plot(100 * soc_eaekf_bnd, ':');
    set(gca, 'colororderindex', 1); plot(-100 * soc_eaekf_bnd, ':');
    title(sprintf('SOC estimation error (percent, %s)', 'EaEKF'));

    count_eaekf = sum(abs(trueSOC - soc_eaekf) > soc_eaekf_bnd, 'omitnan');
    if any(isnan(soc_eaekf))
        fprintf(' - EaEKF failed (NaN estimates)\n');
    else
        fprintf(' - SOC estimate outside of bounds %g %% of the time (%s)\n', ...
            count_eaekf / length(trueSOC) * 100, 'EaEKF');
    end

    figure('Name', 'SOC Error (EsSPKF)', 'NumberTitle', 'off');
    plot(100 * (trueSOC - soc_esspkf)); hold on; grid on;
    set(gca, 'colororderindex', 1); plot(100 * soc_esspkf_bnd, ':');
    set(gca, 'colororderindex', 1); plot(-100 * soc_esspkf_bnd, ':');
    title(sprintf('SOC estimation error (percent, %s)', 'EsSPKF'));

    count_esspkf = sum(abs(trueSOC - soc_esspkf) > soc_esspkf_bnd, 'omitnan');
    if any(isnan(soc_esspkf))
        fprintf(' - EsSPKF failed (NaN estimates)\n');
    else
        fprintf(' - SOC estimate outside of bounds %g %% of the time (%s)\n', ...
            count_esspkf / length(trueSOC) * 100, 'EsSPKF');
    end

    figure('Name', 'SOC Error (EBiSPKF)', 'NumberTitle', 'off');
    plot(100 * (trueSOC - soc_ebispkf)); hold on; grid on;
    set(gca, 'colororderindex', 1); plot(100 * soc_ebispkf_bnd, ':');
    set(gca, 'colororderindex', 1); plot(-100 * soc_ebispkf_bnd, ':');
    title(sprintf('SOC estimation error (percent, %s)', 'EBiSPKF'));

    count_ebispkf = sum(abs(trueSOC - soc_ebispkf) > soc_ebispkf_bnd, 'omitnan');
    if any(isnan(soc_ebispkf))
        fprintf(' - EBiSPKF failed (NaN estimates)\n');
    else
        fprintf(' - SOC estimate outside of bounds %g %% of the time (%s)\n', ...
            count_ebispkf / length(trueSOC) * 100, 'EBiSPKF');
    end

    figure('Name', 'SOC Error (Em7SPKF)', 'NumberTitle', 'off');
    plot(100 * (trueSOC - soc_em7)); hold on; grid on;
    set(gca, 'colororderindex', 1); plot(100 * soc_em7_bnd, ':');
    set(gca, 'colororderindex', 1); plot(-100 * soc_em7_bnd, ':');
    title(sprintf('SOC estimation error (percent, %s)', 'Em7SPKF'));

    count_em7 = sum(abs(trueSOC - soc_em7) > soc_em7_bnd, 'omitnan');
    if any(isnan(soc_em7))
        fprintf(' - Em7SPKF failed (NaN estimates)\n');
    else
        fprintf(' - SOC estimate outside of bounds %g %% of the time (%s)\n', ...
            count_em7 / length(trueSOC) * 100, 'Em7SPKF');
    end
end

if Vfigs
    figure('Name', 'Voltage Error (ROM-EKF)', 'NumberTitle', 'off');
    plot(t, v_error_ekf); hold on; grid on;
    set(gca, 'colororderindex', 1); plot(t, +v_ekf_bnd, ':');
    set(gca, 'colororderindex', 1); plot(t, -v_ekf_bnd, ':');
    legend('Error', 'Bounds');
    title(sprintf('Voltage estimation error (%s)', 'ROM-EKF'));

    figure('Name', 'Voltage Error (ESC-SPKF)', 'NumberTitle', 'off');
    plot(t, v_error_spkf); hold on; grid on;
    set(gca, 'colororderindex', 1); plot(t, +v_spkf_bnd, ':');
    set(gca, 'colororderindex', 1); plot(t, -v_spkf_bnd, ':');
    legend('Error', 'Bounds');
    title(sprintf('Voltage estimation error (%s)', 'ESC-SPKF'));

    figure('Name', 'Voltage Error (EaEKF)', 'NumberTitle', 'off');
    plot(t, v_error_eaekf); hold on; grid on;
    set(gca, 'colororderindex', 1); plot(t, +v_eaekf_bnd, ':');
    set(gca, 'colororderindex', 1); plot(t, -v_eaekf_bnd, ':');
    legend('Error', 'Bounds');
    title(sprintf('Voltage estimation error (%s)', 'EaEKF'));

    figure('Name', 'Voltage Error (EsSPKF)', 'NumberTitle', 'off');
    plot(t, v_error_esspkf); hold on; grid on;
    set(gca, 'colororderindex', 1); plot(t, +v_esspkf_bnd, ':');
    set(gca, 'colororderindex', 1); plot(t, -v_esspkf_bnd, ':');
    legend('Error', 'Bounds');
    title(sprintf('Voltage estimation error (%s)', 'EsSPKF'));

    figure('Name', 'Voltage Error (EBiSPKF)', 'NumberTitle', 'off');
    plot(t, v_error_ebispkf); hold on; grid on;
    set(gca, 'colororderindex', 1); plot(t, +v_ebispkf_bnd, ':');
    set(gca, 'colororderindex', 1); plot(t, -v_ebispkf_bnd, ':');
    legend('Error', 'Bounds');
    title(sprintf('Voltage estimation error (%s)', 'EBiSPKF'));

    figure('Name', 'Voltage Error (Em7SPKF)', 'NumberTitle', 'off');
    plot(t, v_error_em7); hold on; grid on;
    set(gca, 'colororderindex', 1); plot(t, +v_em7_bnd, ':');
    set(gca, 'colororderindex', 1); plot(t, -v_em7_bnd, ':');
    legend('Error', 'Bounds');
    title(sprintf('Voltage estimation error (%s)', 'Em7SPKF'));
end

figure('Name', 'R0 Estimate Comparison', 'NumberTitle', 'off');
hold on;
plot(t, r0_esspkf, 'c--', 'LineWidth', 1.5, 'DisplayName', 'EsSPKF R0');
plot(t, r0_em7, '-', 'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.5, 'DisplayName', 'Em7SPKF R0');
yline(getParamESC('R0Param', tc, nmc30_esc), 'k--', 'LineWidth', 1.2, 'DisplayName', 'Model R0');
plot(t, r0_esspkf + r0_esspkf_bnd, 'c:', 'HandleVisibility', 'off');
plot(t, r0_esspkf - r0_esspkf_bnd, 'c:', 'HandleVisibility', 'off');
plot(t, r0_em7 + r0_em7_bnd, ':', 'Color', [0.20, 0.20, 0.20], 'HandleVisibility', 'off');
plot(t, r0_em7 - r0_em7_bnd, ':', 'Color', [0.20, 0.20, 0.20], 'HandleVisibility', 'off');
grid on; xlabel('Time [s]'); ylabel('R0 [Ohm]');
title('R0 Estimates with Bounds (EsSPKF vs Em7SPKF)');
legend('Location', 'best');

figure('Name', 'Current Bias Estimate (EBiSPKF)', 'NumberTitle', 'off');
plot(t, bias_ebispkf(:, current_bias_idx), '-', 'Color', [0.85, 0.33, 0.10], ...
    'LineWidth', 1.5, 'DisplayName', 'EBiSPKF current bias');
hold on;
plot(t, bias_ebispkf(:, current_bias_idx) + bias_ebispkf_bnd(:, current_bias_idx), ':', ...
    'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.2, 'DisplayName', 'Current bias + 3\sigma');
plot(t, bias_ebispkf(:, current_bias_idx) - bias_ebispkf_bnd(:, current_bias_idx), ':', ...
    'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.2, 'DisplayName', 'Current bias - 3\sigma');
yline(0, 'k--', 'LineWidth', 1.2, 'DisplayName', 'True bias (0 A)');
grid on; xlabel('Time [s]'); ylabel('Current Bias [A]');
title('Estimated Current-Sensor Bias (EBiSPKF)');
legend('Location', 'best');

figure('Name', 'Voltage Bias Estimate (EBiSPKF)', 'NumberTitle', 'off');
plot(t, bias_ebispkf(:, output_bias_idx), 'b-', 'LineWidth', 1.5, ...
    'DisplayName', 'EBiSPKF output bias');
hold on;
plot(t, bias_ebispkf(:, output_bias_idx) + bias_ebispkf_bnd(:, output_bias_idx), 'b:', ...
    'LineWidth', 1.2, 'DisplayName', 'Output bias + 3\sigma');
plot(t, bias_ebispkf(:, output_bias_idx) - bias_ebispkf_bnd(:, output_bias_idx), 'b:', ...
    'LineWidth', 1.2, 'DisplayName', 'Output bias - 3\sigma');
yline(0, 'k--', 'LineWidth', 1.2, 'DisplayName', 'Zero bias');
grid on; xlabel('Time [s]'); ylabel('Voltage Bias [V]');
title('Estimated Output/Measurement Bias (EBiSPKF)');
legend('Location', 'best');

figure('Name', 'Current Bias Estimate (Em7SPKF)', 'NumberTitle', 'off');
plot(t, bias_em7(:, em7_current_bias_idx), '-', 'Color', [0.20, 0.20, 0.20], ...
    'LineWidth', 1.5, 'DisplayName', 'Em7SPKF current bias');
hold on;
plot(t, bias_em7(:, em7_current_bias_idx) + bias_em7_bnd(:, em7_current_bias_idx), ':', ...
    'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.2, 'DisplayName', 'Current bias + 3\sigma');
plot(t, bias_em7(:, em7_current_bias_idx) - bias_em7_bnd(:, em7_current_bias_idx), ':', ...
    'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.2, 'DisplayName', 'Current bias - 3\sigma');
yline(0, 'k--', 'LineWidth', 1.2, 'DisplayName', 'True bias (0 A)');
grid on; xlabel('Time [s]'); ylabel('Current Bias [A]');
title('Estimated Current-Sensor Bias (Em7SPKF)');
legend('Location', 'best');

figure('Name', 'Voltage Bias Estimate (Em7SPKF)', 'NumberTitle', 'off');
plot(t, bias_em7(:, em7_output_bias_idx), '-', 'Color', [0.20, 0.20, 0.20], ...
    'LineWidth', 1.5, 'DisplayName', 'Em7SPKF output bias');
hold on;
plot(t, bias_em7(:, em7_output_bias_idx) + bias_em7_bnd(:, em7_output_bias_idx), ':', ...
    'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.2, 'DisplayName', 'Output bias + 3\sigma');
plot(t, bias_em7(:, em7_output_bias_idx) - bias_em7_bnd(:, em7_output_bias_idx), ':', ...
    'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.2, 'DisplayName', 'Output bias - 3\sigma');
yline(0, 'k--', 'LineWidth', 1.2, 'DisplayName', 'Zero bias');
grid on; xlabel('Time [s]'); ylabel('Voltage Bias [V]');
title('Estimated Output/Measurement Bias (Em7SPKF)');
legend('Location', 'best');

figure('Name', 'EaEKF Adaptive SigmaV', 'NumberTitle', 'off');
plot(t, sigma_v_eaekf, 'm-', 'LineWidth', 1.5, 'DisplayName', 'SigmaV (voltage-noise variance)');
grid on; xlabel('Time [s]'); ylabel('SigmaV [V^2]');
title('EaEKF Adapted Voltage-Noise Variance');
legend('Location', 'best');

figure('Name', 'EaEKF Adaptive SigmaW', 'NumberTitle', 'off');
plot(t, sigma_w_eaekf_soc, 'Color', [0.10, 0.50, 0.80], 'LineWidth', 1.5, ...
    'DisplayName', 'SigmaW(SOC,SOC)');
hold on;
plot(t, sigma_w_eaekf_trace, 'k--', 'LineWidth', 1.3, 'DisplayName', 'trace(SigmaW)');
grid on; xlabel('Time [s]'); ylabel('SigmaW [state^2]');
title('EaEKF Adapted Process/Current-Model Noise');
legend('Location', 'best');

% fprintf('Plotting complete. All figures displayed.\n');

%% STEP 7: Save results
% fprintf('\n===== STEP 7: Save results =====\n');
% results = struct();
% results.time = t;
% results.current = i_profile;
% results.voltage = rom_voltage;
% results.soc_rom = rom_soc;
% results.soc_cc = soc_cc;
% results.soc_ekf = soc_ekf;
% results.soc_spkf = soc_spkf;
% results.soc_eaekf = soc_eaekf;
% results.voltage_ekf = v_ekf;
% results.voltage_spkf = v_spkf;
% results.voltage_eaekf = v_eaekf;
% results.bounds = struct( ...
%     'soc_ekf', soc_ekf_bnd, ...
%     'voltage_ekf', v_ekf_bnd, ...
%     'soc_spkf', soc_spkf_bnd, ...
%     'voltage_spkf', v_spkf_bnd, ...
%     'soc_eaekf', soc_eaekf_bnd, ...
%     'voltage_eaekf', v_eaekf_bnd);
% results.rmse = struct('cc', rmse_cc, 'ekf', rmse_ekf, 'spkf', rmse_spkf, 'eaekf', rmse_eaekf);
% results.max_error = struct('cc', max_error_cc, 'ekf', max_error_ekf, 'spkf', max_error_spkf, 'eaekf', max_error_eaekf);
% 
% results_file = fullfile(script_dir, 'results_NMC30_SOC_comparison.mat');
% save(results_file, 'results');
% fprintf('Results saved to: %s\n', results_file);
% 
% fprintf('\n===== Simulation complete =====\n');

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
