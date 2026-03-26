function validation = BSSsimESCdataVal(cfg)
% BSSsimESCdataVal Validate the ESC-simulated bus_coreBattery dataset.

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

evaluation_root = fileparts(here);
repo_root = fileparts(evaluation_root);
addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'utility')));

cfg = normalizeConfig(cfg, here, evaluation_root);
dataset = loadOrBuildDataset(cfg);
validation = analyzeDataset(dataset, cfg);

printSummary(validation);
if cfg.show_plots
    makePlots(dataset, validation, cfg);
end

if nargout == 0
    assignin('base', 'escProfileValidation', validation);
end
end

function cfg = normalizeConfig(cfg, escsim_root, evaluation_root)
cfg.profile_file = getCfg(cfg, 'profile_file', ...
    fullfile(evaluation_root, 'OMTLIFE8AHC-HP', 'Bus_CoreBatteryData_Data.mat'));
cfg.dataset_file = getCfg(cfg, 'dataset_file', ...
    fullfile(escsim_root, 'datasets', 'esc_bus_coreBattery_dataset.mat'));
cfg.tc = getCfg(cfg, 'tc', 25);
cfg.source_capacity_ah = getCfg(cfg, 'source_capacity_ah', []);
cfg.rebuild_dataset = getCfg(cfg, 'rebuild_dataset', false);
cfg.show_plots = getCfg(cfg, 'show_plots', true);
cfg.validation_name = getCfg(cfg, 'validation_name', '');

cfg.profile_file = resolveExistingPath(cfg.profile_file, evaluation_root);
cfg.dataset_file = resolveOutputPath(cfg.dataset_file, escsim_root);

if isempty(cfg.validation_name)
    [~, name, ext] = fileparts(cfg.profile_file);
    cfg.validation_name = [name, ext];
end
end

function dataset = loadOrBuildDataset(cfg)
need_build = cfg.rebuild_dataset || exist(cfg.dataset_file, 'file') ~= 2;
expected_profile = normalizePath(cfg.profile_file);

if ~need_build
    loaded = load(cfg.dataset_file);
    if ~isfield(loaded, 'dataset')
        error('BSSsimESCdataVal:BadDatasetFile', ...
            'Expected variable "dataset" in %s.', cfg.dataset_file);
    end
    dataset = loaded.dataset;
    if ~isfield(dataset, 'source_profile_file') || ...
            ~pathsMatch(dataset.source_profile_file, expected_profile)
        need_build = true;
    end
end

if need_build
    build_cfg = struct();
    build_cfg.profile_file = cfg.profile_file;
    build_cfg.tc = cfg.tc;
    copy_fields = {'source_capacity_ah', 'original_capacity_ah', ...
        'original_1c_current_a', 'current_sign', 'soc_init', 'model_file'};
    for idx = 1:numel(copy_fields)
        field_name = copy_fields{idx};
        if isfield(cfg, field_name) && ~isempty(cfg.(field_name))
            build_cfg.(field_name) = cfg.(field_name);
        end
    end
    dataset = BSSsimESCdata(cfg.dataset_file, build_cfg);
end
end

function validation = analyzeDataset(dataset, cfg)
validation = struct();
validation.validation_name = cfg.validation_name;
validation.profile_file = cfg.profile_file;
validation.dataset_file = cfg.dataset_file;
validation.n_samples = numel(dataset.time_s);
validation.duration_s = dataset.time_s(end) - dataset.time_s(1);
validation.source_capacity_ah = getFieldOr(dataset, 'source_capacity_ah', NaN);
validation.target_capacity_ah = getFieldOr(dataset, 'target_capacity_ah', NaN);
validation.current_scale_factor = getFieldOr(dataset, 'current_scale_factor', NaN);
validation.model_file = getFieldOr(dataset, 'esc_model_file', '');
validation.temperature_note = getFieldOr(dataset, 'temperature_note', '');

source_current = getRequiredField(dataset, 'source_current_a');
target_current = getRequiredField(dataset, 'current_a');
source_capacity = validation.source_capacity_ah;
target_capacity = validation.target_capacity_ah;

validation.source_c_rate = source_current(:) / source_capacity;
validation.target_c_rate = target_current(:) / target_capacity;
valid_c_rate = isfinite(validation.source_c_rate) & isfinite(validation.target_c_rate);
[validation.c_rate_rmse, validation.c_rate_mean_error, validation.c_rate_max_abs_error] = ...
    calcErrorStats(validation.source_c_rate(valid_c_rate) - validation.target_c_rate(valid_c_rate));

source_soc = getOptionalVector(dataset, 'source_soc_ref');
soc_cc = getOptionalVector(dataset, 'soc_cc');
validation.has_soc = ~isempty(source_soc) && ~isempty(soc_cc);
if validation.has_soc
    valid_soc = isfinite(source_soc) & isfinite(soc_cc);
    [validation.soc_rmse, validation.soc_mean_error, validation.soc_max_abs_error] = ...
        calcErrorStats(source_soc(valid_soc) - soc_cc(valid_soc));
else
    validation.soc_rmse = NaN;
    validation.soc_mean_error = NaN;
    validation.soc_max_abs_error = NaN;
end

source_voltage = getOptionalVector(dataset, 'source_voltage_v');
esc_voltage = getOptionalVector(dataset, 'voltage_v');
validation.has_voltage = ~isempty(source_voltage) && ~isempty(esc_voltage);
if validation.has_voltage
    valid_voltage = isfinite(source_voltage) & isfinite(esc_voltage);
    [validation.voltage_rmse, validation.voltage_mean_error, validation.voltage_max_abs_error] = ...
        calcErrorStats(source_voltage(valid_voltage) - esc_voltage(valid_voltage));
    if nnz(valid_voltage) >= 2
        corr_matrix = corrcoef(source_voltage(valid_voltage), esc_voltage(valid_voltage));
        validation.voltage_corr = corr_matrix(1, 2);
        validation.voltage_fit = polyfit(source_voltage(valid_voltage), esc_voltage(valid_voltage), 1);
    else
        validation.voltage_corr = NaN;
        validation.voltage_fit = [NaN, NaN];
    end
else
    validation.voltage_rmse = NaN;
    validation.voltage_mean_error = NaN;
    validation.voltage_max_abs_error = NaN;
    validation.voltage_corr = NaN;
    validation.voltage_fit = [NaN, NaN];
end

source_temp = getOptionalVector(dataset, 'source_temperature_c');
validation.has_temperature = ~isempty(source_temp) && any(isfinite(source_temp));
if validation.has_temperature
    validation.source_temperature_mean = mean(source_temp, 'omitnan');
    validation.source_temperature_min = min(source_temp, [], 'omitnan');
    validation.source_temperature_max = max(source_temp, [], 'omitnan');
else
    validation.source_temperature_mean = NaN;
    validation.source_temperature_min = NaN;
    validation.source_temperature_max = NaN;
end
end

function printSummary(validation)
fprintf('\nESC profile validation: %s\n', validation.validation_name);
fprintf('  Samples: %d | Duration: %.1f s\n', validation.n_samples, validation.duration_s);
fprintf('  Source capacity: %.3f Ah | Target capacity: %.3f Ah\n', ...
    validation.source_capacity_ah, validation.target_capacity_ah);
fprintf('  Current scale factor: %.6f\n', validation.current_scale_factor);
fprintf('  C-rate RMSE: %.5f | Mean error: %.5f | Max abs: %.5f\n', ...
    validation.c_rate_rmse, validation.c_rate_mean_error, validation.c_rate_max_abs_error);

if validation.has_soc
    fprintf('  SOC RMSE: %.4f %% | Mean error: %.4f %% | Max abs: %.4f %%\n', ...
        100 * validation.soc_rmse, 100 * validation.soc_mean_error, 100 * validation.soc_max_abs_error);
else
    fprintf('  SOC metrics: unavailable (source SOC reference missing)\n');
end

if validation.has_voltage
    fprintf('  Voltage RMSE: %.2f mV | Mean error: %.2f mV | Max abs: %.2f mV\n', ...
        1000 * validation.voltage_rmse, ...
        1000 * validation.voltage_mean_error, ...
        1000 * validation.voltage_max_abs_error);
    fprintf('  Voltage correlation: %.4f | Fit: Vesc = %.4f * Vsrc + %.4f\n', ...
        validation.voltage_corr, validation.voltage_fit(1), validation.voltage_fit(2));
else
    fprintf('  Voltage metrics: unavailable (source voltage missing)\n');
end

if validation.has_temperature
    fprintf('  Source temperature: mean %.2f degC | range [%.2f, %.2f] degC\n', ...
        validation.source_temperature_mean, ...
        validation.source_temperature_min, ...
        validation.source_temperature_max);
end
if ~isempty(validation.temperature_note)
    fprintf('  Note: %s\n', validation.temperature_note);
end
end

function makePlots(dataset, validation, cfg)
t = dataset.time_s(:);
source_current = dataset.source_current_a(:);
target_current = dataset.current_a(:);

figure('Name', sprintf('ESC Validation - Current - %s', cfg.validation_name), ...
    'NumberTitle', 'off');
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(t, source_current, 'k-', 'LineWidth', 1.4, 'DisplayName', 'Source current');
hold on;
plot(t, target_current, 'r--', 'LineWidth', 1.2, 'DisplayName', 'ESC-applied current');
grid on;
xlabel('Time [s]');
ylabel('Current [A]');
title('Current traces');
legend('Location', 'best');

nexttile;
plot(t, validation.source_c_rate, 'k-', 'LineWidth', 1.4, 'DisplayName', 'Source C-rate');
hold on;
plot(t, validation.target_c_rate, 'r--', 'LineWidth', 1.2, 'DisplayName', 'ESC-applied C-rate');
grid on;
xlabel('Time [s]');
ylabel('C-rate [-]');
title(sprintf('C-rate preservation (RMSE %.5f)', validation.c_rate_rmse));
legend('Location', 'best');

if validation.has_soc
    source_soc = dataset.source_soc_ref(:);
    soc_cc = dataset.soc_cc(:);
    soc_error = source_soc - soc_cc;

    figure('Name', sprintf('ESC Validation - SOC - %s', cfg.validation_name), ...
        'NumberTitle', 'off');
    tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    plot(t, 100 * source_soc, 'k-', 'LineWidth', 1.6, 'DisplayName', 'Source SOC');
    hold on;
    plot(t, 100 * soc_cc, 'b--', 'LineWidth', 1.3, 'DisplayName', 'ESC SOC');
    grid on;
    xlabel('Time [s]');
    ylabel('SOC [%]');
    title(sprintf('SOC overlay (RMSE %.3f%%)', 100 * validation.soc_rmse));
    legend('Location', 'best');

    nexttile;
    plot(t, 100 * soc_error, 'b-', 'LineWidth', 1.2);
    grid on;
    xlabel('Time [s]');
    ylabel('SOC Error [%]');
    title(sprintf('SOC error: source - ESC (ME %.3f%%)', 100 * validation.soc_mean_error));
end

if validation.has_voltage
    source_voltage = dataset.source_voltage_v(:);
    esc_voltage = dataset.voltage_v(:);
    voltage_error = source_voltage - esc_voltage;
    valid_voltage = isfinite(source_voltage) & isfinite(esc_voltage);

    figure('Name', sprintf('ESC Validation - Voltage - %s', cfg.validation_name), ...
        'NumberTitle', 'off');
    tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    plot(t, source_voltage, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Source voltage');
    hold on;
    plot(t, esc_voltage, 'r--', 'LineWidth', 1.3, 'DisplayName', 'ESC simulated voltage');
    grid on;
    xlabel('Time [s]');
    ylabel('Voltage [V]');
    title(sprintf('Voltage overlay (RMSE %.2f mV)', 1000 * validation.voltage_rmse));
    legend('Location', 'best');

    nexttile;
    plot(t, 1000 * voltage_error, 'b-', 'LineWidth', 1.2);
    grid on;
    xlabel('Time [s]');
    ylabel('Voltage Error [mV]');
    title(sprintf('Voltage error: source - ESC (ME %.2f mV)', 1000 * validation.voltage_mean_error));

    nexttile;
    if any(valid_voltage)
        scatter(source_voltage(valid_voltage), esc_voltage(valid_voltage), 10, t(valid_voltage), 'filled');
        hold on;
        v_min = min([source_voltage(valid_voltage); esc_voltage(valid_voltage)]);
        v_max = max([source_voltage(valid_voltage); esc_voltage(valid_voltage)]);
        plot([v_min, v_max], [v_min, v_max], 'k--', 'LineWidth', 1.0, 'DisplayName', 'Unity line');
        if all(isfinite(validation.voltage_fit))
            fit_x = linspace(v_min, v_max, 100);
            fit_y = polyval(validation.voltage_fit, fit_x);
            plot(fit_x, fit_y, 'r-', 'LineWidth', 1.1, 'DisplayName', 'Linear fit');
        end
        grid on;
        xlabel('Source voltage [V]');
        ylabel('ESC voltage [V]');
        title(sprintf('Voltage correlation (R = %.3f)', validation.voltage_corr));
        cb = colorbar;
        cb.Label.String = 'Time [s]';
        legend('Location', 'best');
    else
        text(0.1, 0.5, 'No finite source/ESC voltage pairs available', 'Units', 'normalized');
        axis off;
        title('Voltage correlation');
    end
end
end

function value = getRequiredField(s, field_name)
if ~isfield(s, field_name) || isempty(s.(field_name))
    error('BSSsimESCdataVal:MissingField', 'Dataset.%s is required.', field_name);
end
value = s.(field_name);
end

function value = getOptionalVector(s, field_name)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name)(:);
else
    value = [];
end
end

function value = getCfg(cfg, field_name, default_value)
if isfield(cfg, field_name) && ~isempty(cfg.(field_name))
    value = cfg.(field_name);
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

function resolved = resolveExistingPath(input_path, evaluation_root)
if exist(input_path, 'file') == 2
    resolved = input_path;
    return;
end

candidate = fullfile(evaluation_root, input_path);
if exist(candidate, 'file') == 2
    resolved = candidate;
    return;
end

resolved = input_path;
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

function tf = pathsMatch(path_a, path_b)
a = comparablePath(path_a);
b = comparablePath(path_b);
tf = strcmpi(a, b) || endsWith(a, stripLeadingSeparators(b), 'IgnoreCase', true) || ...
    endsWith(b, stripLeadingSeparators(a), 'IgnoreCase', true);
end

function out = normalizePath(path_in)
out = strrep(char(path_in), '/', '\');
end

function out = comparablePath(path_in)
out = lower(strrep(char(path_in), '/', '\'));
out = regexprep(out, '\\+', '\\');
end

function out = stripLeadingSeparators(path_in)
out = regexprep(char(path_in), '^[\\/]+', '');
end

function tf = isAbsolutePath(path_in)
path_in = char(path_in);
tf = numel(path_in) >= 2 && path_in(2) == ':';
end

function [rmse_val, mean_val, max_abs_val] = calcErrorStats(error_vec)
if isempty(error_vec)
    rmse_val = NaN;
    mean_val = NaN;
    max_abs_val = NaN;
    return;
end

rmse_val = sqrt(mean(error_vec.^2));
mean_val = mean(error_vec);
max_abs_val = max(abs(error_vec));
end
