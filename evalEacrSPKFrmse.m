function [rmse_soc, rmse_v, out] = evalEacrSPKFrmse(soc0, T0, SigmaX0, SigmaV, SigmaW, model, showErrorFigs)
% evalEacrSPKFrmse Evaluate iterEacrSPKF against ROM ground truth.
%
% Inputs (aligned with initESCSPKF):
%   soc0          Initial SOC (percent or fraction)
%   T0            Temperature [degC]
%   SigmaX0       Initial state covariance for ESC-SPKF
%   SigmaV        Voltage measurement noise variance
%   SigmaW        Process/current noise variance
%   model         Full ESC model struct
%   showErrorFigs Logical flag for SOC/voltage error figures
%
% Outputs:
%   rmse_soc      SOC RMSE [-]
%   rmse_v        Voltage RMSE [V]
%   out           Struct with time series, bounds, and errors

if nargin < 7 || isempty(showErrorFigs)
    showErrorFigs = false;
end
if ~isscalar(showErrorFigs)
    error('evalEacrSPKFrmse:BadShowFlag', 'showErrorFigs must be a scalar logical.');
end
showErrorFigs = logical(showErrorFigs);

if exist('iterEacrSPKF', 'file') ~= 2
    error('evalEacrSPKFrmse:MissingEstimator', ...
        'iterEacrSPKF.m was not found on the MATLAB path.');
end

if soc0 > 1
    soc0_frac = soc0 / 100;
else
    soc0_frac = soc0;
end
soc0_frac = max(0, min(1, soc0_frac));

script_fullpath = mfilename('fullpath');
script_dir = fileparts(script_fullpath);
parent_dir = fileparts(script_dir);

rom_file = firstExistingFile({ ...
    fullfile(script_dir, 'models', 'ROM_NMC30_HRA12.mat'), ...
    fullfile(script_dir, 'ROM_NMC30_HRA12.mat'), ...
    fullfile(parent_dir, 'models', 'ROM_NMC30_HRA12.mat'), ...
    fullfile(parent_dir, 'src', 'MPC-EKF4FastCharge', 'ROM_NMC30_HRA12.mat')}, ...
    'evalEacrSPKFrmse:MissingROMFile', ...
    'No ROM model file found.');

rom_data = load(rom_file);
ROM = rom_data.ROM;

ts = 1;
capacity_ah = model.QParam;
i_1c = capacity_ah;
[i_profile, ~] = buildScript1Profile(i_1c, capacity_ah, ts);
i_profile = i_profile(:);
t = (0:numel(i_profile) - 1).' * ts;
n_samples = numel(t);

rom_voltage = NaN(n_samples, 1);
rom_soc = NaN(n_samples, 1);
rom_soc(1) = soc0_frac;
rom_state = [];
init_cfg = struct('SOC0', soc0_frac * 100, 'warnOff', true);

for k = 1:n_samples
    if k == 1
        [rom_voltage(k), ~, rom_state] = OB_step(i_profile(k), T0, [], ROM, init_cfg);
        rom_soc(k) = soc0_frac;
    else
        [rom_voltage(k), ~, rom_state] = OB_step(i_profile(k), T0, rom_state, ROM, []);
        rom_soc(k) = rom_soc(k - 1) - (i_profile(k) * ts) / (3600 * capacity_ah);
        rom_soc(k) = max(0, min(1, rom_soc(k)));
    end
end

spkf_data = initESCSPKF(soc0, T0, SigmaX0, SigmaV, SigmaW, model);

soc_est = NaN(n_samples, 1);
soc_est(1) = soc0_frac;
v_est = NaN(n_samples, 1);
v_est(1) = OCVfromSOCtemp(soc_est(1), T0, model);
soc_bnd = NaN(n_samples, 1);
v_bnd = NaN(n_samples, 1);

for k = 2:n_samples
    [soc_est(k), v_est(k), soc_bnd(k), spkf_data, v_bnd(k)] = iterEacrSPKF( ...
        rom_voltage(k), i_profile(k), T0, ts, spkf_data);
    soc_est(k) = max(0, min(1, soc_est(k)));
end

soc_error = rom_soc - soc_est;
v_error = rom_voltage - v_est;

rmse_soc = sqrt(mean(soc_error(~isnan(soc_error)).^2));
rmse_v = sqrt(mean(v_error(~isnan(v_error)).^2));

if showErrorFigs
    figure('Name', 'SOC Estimation Error vs ROM Ground Truth', 'NumberTitle', 'off');
    plot(t, 100 * soc_error, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('iterEacrSPKF (RMSE = %.3f%%)', 100 * rmse_soc));
    hold on;
    plot(t, 100 * soc_bnd, 'k:', 'LineWidth', 1.1, 'DisplayName', '+3\sigma bound');
    plot(t, -100 * soc_bnd, 'k:', 'LineWidth', 1.1, 'DisplayName', '-3\sigma bound');
    yline(0, 'k--', 'LineWidth', 1.0, 'HandleVisibility', 'off');
    grid on;
    xlabel('Time [s]');
    ylabel('SOC Error [%]');
    title('SOC Estimation Error vs ROM Ground Truth');
    legend('Location', 'best');

    figure('Name', 'Voltage Estimation Error vs ROM Ground Truth', 'NumberTitle', 'off');
    plot(t, v_error, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('iterEacrSPKF (RMSE = %.2f mV)', 1000 * rmse_v));
    hold on;
    plot(t, v_bnd, 'k:', 'LineWidth', 1.1, 'DisplayName', '+3\sigma bound');
    plot(t, -v_bnd, 'k:', 'LineWidth', 1.1, 'DisplayName', '-3\sigma bound');
    yline(0, 'k--', 'LineWidth', 1.0, 'HandleVisibility', 'off');
    grid on;
    xlabel('Time [s]');
    ylabel('Voltage Error [V]');
    title('Voltage Estimation Error vs ROM Ground Truth');
    legend('Location', 'best');
end

out = struct();
out.t = t;
out.i_profile = i_profile;
out.rom_soc = rom_soc;
out.rom_voltage = rom_voltage;
out.soc_est = soc_est;
out.v_est = v_est;
out.soc_bnd = soc_bnd;
out.v_bnd = v_bnd;
out.soc_error = soc_error;
out.v_error = v_error;
out.rmse_soc = rmse_soc;
out.rmse_v = rmse_v;
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
current_a = [current_a, current_level * ones(1, num_samples)]; %#ok<AGROW>
step_id = [step_id, step_value * ones(1, num_samples)]; %#ok<AGROW>
end
