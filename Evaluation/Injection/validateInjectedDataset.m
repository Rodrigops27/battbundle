function validation = validateInjectedDataset(datasetInput, cfg)
% validateInjectedDataset Validate an injected dataset against its clean source trace.

if nargin < 1 || isempty(datasetInput)
    error('validateInjectedDataset:MissingInput', ...
        'Provide an injected dataset struct or MAT file path.');
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end

cfg.show_plots = getCfg(cfg, 'show_plots', true);
cfg.validation_name = getCfg(cfg, 'validation_name', '');

dataset = loadDatasetInput(datasetInput);
if isempty(cfg.validation_name)
    cfg.validation_name = getFieldOr(dataset, 'injection_case', 'Injected Dataset');
end

source_current = selectFirstAvailable(dataset, {'source_current_a', 'current_a_true'});
source_voltage = selectFirstAvailable(dataset, {'source_voltage_v', 'voltage_v_true'});
source_soc = selectFirstAvailable(dataset, {'source_soc_ref', 'soc_true'});

if isempty(source_current) || isempty(source_voltage)
    error('validateInjectedDataset:MissingCleanTrace', ...
        'Injected dataset must contain clean current/voltage traces in source_* or *_true fields.');
end

validation = struct();
validation.validation_name = cfg.validation_name;
validation.n_samples = numel(dataset.time_s);
validation.duration_s = dataset.time_s(end) - dataset.time_s(1);
validation.current_error_a = source_current(:) - dataset.current_a(:);
validation.voltage_error_v = source_voltage(:) - dataset.voltage_v(:);
validation.current_rmse_a = calcRmse(validation.current_error_a);
validation.current_me_a = mean(validation.current_error_a, 'omitnan');
validation.current_max_abs_a = max(abs(validation.current_error_a), [], 'omitnan');
validation.voltage_rmse_mv = 1000 * calcRmse(validation.voltage_error_v);
validation.voltage_me_mv = 1000 * mean(validation.voltage_error_v, 'omitnan');
validation.voltage_max_abs_mv = 1000 * max(abs(validation.voltage_error_v), [], 'omitnan');
validation.has_soc = ~isempty(source_soc) && isfield(dataset, 'soc_true') && ~isempty(dataset.soc_true);
if validation.has_soc
    validation.soc_rmse_pct = 100 * calcRmse(source_soc(:) - dataset.soc_true(:));
else
    validation.soc_rmse_pct = NaN;
end

printSummary(validation);
if cfg.show_plots
    makePlots(dataset, source_current, source_voltage, validation);
end
end

function dataset = loadDatasetInput(datasetInput)
if isstruct(datasetInput)
    dataset = datasetInput;
    return;
end

if isstring(datasetInput)
    datasetInput = char(datasetInput);
end
if ~ischar(datasetInput) || exist(datasetInput, 'file') ~= 2
    error('validateInjectedDataset:BadInput', ...
        'datasetInput must be an injected dataset struct or an existing MAT file.');
end

loaded = load(datasetInput);
if ~isfield(loaded, 'dataset')
    error('validateInjectedDataset:BadFile', ...
        'Expected variable "dataset" in %s.', datasetInput);
end
dataset = loaded.dataset;
end

function value = selectFirstAvailable(dataset, field_names)
value = [];
for idx = 1:numel(field_names)
    field_name = field_names{idx};
    if isfield(dataset, field_name) && ~isempty(dataset.(field_name))
        value = dataset.(field_name);
        return;
    end
end
end

function value = calcRmse(error_signal)
error_signal = error_signal(isfinite(error_signal));
if isempty(error_signal)
    value = NaN;
else
    value = sqrt(mean(error_signal .^ 2));
end
end

function printSummary(validation)
fprintf('\nInjection dataset validation: %s\n', validation.validation_name);
fprintf('  Samples: %d | Duration: %.1f s\n', validation.n_samples, validation.duration_s);
fprintf('  Current RMSE: %.4f A | ME: %.4f A | Max abs: %.4f A\n', ...
    validation.current_rmse_a, validation.current_me_a, validation.current_max_abs_a);
fprintf('  Voltage RMSE: %.2f mV | ME: %.2f mV | Max abs: %.2f mV\n', ...
    validation.voltage_rmse_mv, validation.voltage_me_mv, validation.voltage_max_abs_mv);
if validation.has_soc
    fprintf('  SOC preservation RMSE: %.4f %%\n', validation.soc_rmse_pct);
end
end

function makePlots(dataset, source_current, source_voltage, validation)
t = dataset.time_s(:);

figure('Name', sprintf('Injection Validation - Current - %s', validation.validation_name), ...
    'NumberTitle', 'off');
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
plot(t, source_current, 'k-', 'LineWidth', 1.4, 'DisplayName', 'Clean current');
hold on;
plot(t, dataset.current_a, 'r--', 'LineWidth', 1.2, 'DisplayName', 'Injected current');
grid on;
xlabel('Time [s]');
ylabel('Current [A]');
title('Current overlay');
legend('Location', 'best');
nexttile;
plot(t, validation.current_error_a, 'b-', 'LineWidth', 1.2);
grid on;
xlabel('Time [s]');
ylabel('Current Error [A]');
title(sprintf('Current error (RMSE %.4f A)', validation.current_rmse_a));

figure('Name', sprintf('Injection Validation - Voltage - %s', validation.validation_name), ...
    'NumberTitle', 'off');
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
plot(t, source_voltage, 'k-', 'LineWidth', 1.4, 'DisplayName', 'Clean voltage');
hold on;
plot(t, dataset.voltage_v, 'r--', 'LineWidth', 1.2, 'DisplayName', 'Injected voltage');
grid on;
xlabel('Time [s]');
ylabel('Voltage [V]');
title('Voltage overlay');
legend('Location', 'best');
nexttile;
plot(t, 1000 * validation.voltage_error_v, 'b-', 'LineWidth', 1.2);
grid on;
xlabel('Time [s]');
ylabel('Voltage Error [mV]');
title(sprintf('Voltage error (RMSE %.2f mV)', validation.voltage_rmse_mv));
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
