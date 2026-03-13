% sandboxBusCoreBatteryProfile.m
% Validate the bus_coreBattery-driven synthetic dataset at 25 degC.

clear; clc;
%close all;

script_fullpath = mfilename('fullpath');
if isempty(script_fullpath)
    script_fullpath = which('sandboxBusCoreBatteryProfile');
end
if isempty(script_fullpath)
    script_dir = pwd;
else
    script_dir = fileparts(script_fullpath);
end
synthm_dir = fullfile(script_dir, 'Synthm');
if exist(synthm_dir, 'dir') == 7
    addpath(synthm_dir);
end

profile_file = fullfile(script_dir, 'ESC_Id', 'Datasets', 'OMTLIFE8AHC-HP', 'Bus_CoreBatteryData_Data.mat');
dataset_file = fullfile(script_dir, 'datasets', 'rom_bus_coreBattery_dataset.mat');
source_capacity_ah = 8;
tc = 25;
rebuild_dataset = false;

cfg = struct( ...
    'profile_file', profile_file, ...
    'source_capacity_ah', source_capacity_ah, ...
    'tc', tc);

need_build = rebuild_dataset || exist(dataset_file, 'file') ~= 2;
if ~need_build
    ds = load(dataset_file);
    dataset = ds.dataset;
    need_build = ~isfield(dataset, 'source_profile_file') || ~strcmpi(dataset.source_profile_file, profile_file);
end

if need_build
    dataset = createBusCoreBatterySyntheticDataset(dataset_file, cfg);
end

t = dataset.time_s(:);
source_c_rate = dataset.source_current_a(:) / dataset.source_capacity_ah;
target_c_rate = dataset.current_a(:) / dataset.target_capacity_ah;

if ~isfield(dataset, 'source_soc_ref') || all(isnan(dataset.source_soc_ref))
    error('sandboxBusCoreBatteryProfile:MissingSourceSOC', ...
        'The source dataset does not expose a usable reference SOC signal.');
end
soc_ref = dataset.source_soc_ref(:);
soc_cc = dataset.soc_cc(:);
soc_error = soc_ref - soc_cc;
valid_soc = isfinite(soc_error);
if ~any(valid_soc)
    error('sandboxBusCoreBatteryProfile:InvalidSourceSOC', ...
        'The source SOC signal could not be aligned with the generated dataset.');
end
soc_rmse = sqrt(mean(soc_error(valid_soc).^2));
soc_max_abs = max(abs(soc_error(valid_soc)));

if ~isfield(dataset, 'source_voltage_v') || all(isnan(dataset.source_voltage_v))
    error('sandboxBusCoreBatteryProfile:MissingSourceVoltage', ...
        'The source dataset does not expose a usable voltage signal.');
end
voltage_ref = dataset.source_voltage_v(:);
voltage_sim = dataset.voltage_v(:);
valid_voltage = isfinite(voltage_ref) & isfinite(voltage_sim);
if nnz(valid_voltage) < 2
    error('sandboxBusCoreBatteryProfile:InvalidSourceVoltage', ...
        'The source voltage signal could not be aligned with the generated dataset.');
end
voltage_rmse = sqrt(mean((voltage_ref(valid_voltage) - voltage_sim(valid_voltage)).^2));
voltage_ref_mean_removed = voltage_ref - mean(voltage_ref(valid_voltage));
voltage_sim_mean_removed = voltage_sim - mean(voltage_sim(valid_voltage));
voltage_ref_norm = normalizeSignal01(voltage_ref, valid_voltage);
voltage_sim_norm = normalizeSignal01(voltage_sim, valid_voltage);

corr_matrix = corrcoef(voltage_ref(valid_voltage), voltage_sim(valid_voltage));
voltage_r = corr_matrix(1, 2);
fit_coeff = polyfit(voltage_ref(valid_voltage), voltage_sim(valid_voltage), 1);

fprintf('\nBus coreBattery profile validation\n');
fprintf('  Source capacity used: %.3f Ah (%s)\n', dataset.source_capacity_ah, dataset.source_capacity_source);
fprintf('  Target capacity used: %.3f Ah\n', dataset.target_capacity_ah);
fprintf('  Current scale factor: %.6f\n', dataset.current_scale_factor);
fprintf('  SOC RMSE (reference vs NMC CC): %.4f %%\n', 100 * soc_rmse);
fprintf('  SOC max abs error: %.4f %%\n', 100 * soc_max_abs);
fprintf('  Voltage RMSE (dataset vs ROM): %.2f mV\n', 1000 * voltage_rmse);
fprintf('  Voltage correlation: %.4f\n', voltage_r);
fprintf('  Voltage fit: V_sim = %.4f * V_ref + %.4f\n', fit_coeff(1), fit_coeff(2));

figure('Name', 'bus coreBattery: C-rate and SOC validation', 'NumberTitle', 'off');
subplot(3, 1, 1);
plot(t, source_c_rate, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Source C-rate'); hold on;
plot(t, target_c_rate, 'r--', 'LineWidth', 1.3, 'DisplayName', 'NMC30-applied C-rate');
grid on;
xlabel('Time [s]');
ylabel('C-rate [-]');
title(sprintf('C-rate preservation (source %.3f Ah -> target %.3f Ah)', ...
    dataset.source_capacity_ah, dataset.target_capacity_ah));
legend('Location', 'best');

subplot(3, 1, 2);
plot(t, 100 * soc_ref, 'k-', 'LineWidth', 1.8, 'DisplayName', 'Source reference SOC'); hold on;
plot(t, 100 * soc_cc, 'b--', 'LineWidth', 1.4, 'DisplayName', 'NMC Coulomb counter');
grid on;
xlabel('Time [s]');
ylabel('SOC [%]');
title(sprintf('Reference SOC vs NMC Coulomb counter (RMSE %.3f%%)', 100 * soc_rmse));
legend('Location', 'best');

subplot(3, 1, 3);
plot(t, 100 * soc_error, 'b-', 'LineWidth', 1.2);
grid on;
xlabel('Time [s]');
ylabel('SOC Error [%]');
title(sprintf('SOC mismatch: reference - NMC CC (max abs %.3f%%)', 100 * soc_max_abs));

figure('Name', 'bus coreBattery: Voltage correlation', 'NumberTitle', 'off');
subplot(2, 1, 1);
plot(t, voltage_ref, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Dataset voltage'); hold on;
plot(t, voltage_sim, 'r--', 'LineWidth', 1.3, 'DisplayName', 'ROM simulated voltage');
grid on;
xlabel('Time [s]');
ylabel('Voltage [V]');
title(sprintf('Voltage overlay at %.1f degC (RMSE %.1f mV)', tc, 1000 * voltage_rmse));
legend('Location', 'best');

subplot(2, 1, 2);
scatter(voltage_ref(valid_voltage), voltage_sim(valid_voltage), 12, t(valid_voltage), 'filled'); hold on;
v_min = min([voltage_ref(valid_voltage); voltage_sim(valid_voltage)]);
v_max = max([voltage_ref(valid_voltage); voltage_sim(valid_voltage)]);
plot([v_min, v_max], [v_min, v_max], 'k--', 'LineWidth', 1.0, 'DisplayName', 'Unity line');
if all(isfinite(fit_coeff))
    fit_x = linspace(v_min, v_max, 100);
    fit_y = polyval(fit_coeff, fit_x);
    plot(fit_x, fit_y, 'r-', 'LineWidth', 1.2, 'DisplayName', 'Linear fit');
end
grid on;
xlabel('Dataset voltage [V]');
ylabel('ROM simulated voltage [V]');
title(sprintf('Voltage correlation (R = %.3f)', voltage_r));
cb = colorbar;
cb.Label.String = 'Time [s]';
legend('Location', 'best');

figure('Name', 'bus coreBattery: Voltage shape comparison', 'NumberTitle', 'off');
subplot(2, 1, 1);
plot(t, voltage_ref_mean_removed, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Dataset voltage (mean removed)'); hold on;
plot(t, voltage_sim_mean_removed, 'r--', 'LineWidth', 1.3, 'DisplayName', 'ROM voltage (mean removed)');
grid on;
xlabel('Time [s]');
ylabel('Voltage [V]');
title('Mean-removed voltage comparison');
legend('Location', 'best');

subplot(2, 1, 2);
plot(t, voltage_ref_norm, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Dataset voltage (normalized)'); hold on;
plot(t, voltage_sim_norm, 'r--', 'LineWidth', 1.3, 'DisplayName', 'ROM voltage (normalized)');
grid on;
xlabel('Time [s]');
ylabel('Normalized Voltage [-]');
title('Normalized voltage comparison');
legend('Location', 'best');

function signal_norm = normalizeSignal01(signal_in, valid_mask)
signal_norm = NaN(size(signal_in));
signal_valid = signal_in(valid_mask);
signal_min = min(signal_valid);
signal_max = max(signal_valid);
signal_span = signal_max - signal_min;
if signal_span <= eps
    signal_norm(valid_mask) = 0;
else
    signal_norm(valid_mask) = (signal_valid - signal_min) / signal_span;
end
end
