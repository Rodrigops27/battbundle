function validation = plotAutotuningCovarianceValidation(resultsInput, cfg)
% plotAutotuningCovarianceValidation Validate autotuned ESC covariances against EaEKF adaptation.
%
% This helper:
%   1. loads an aggregate autotuning result;
%   2. resolves the desktop scenario and tuned ESC-estimator covariances;
%   3. replays the tuned EaEKF on the saved evaluation dataset to recover
%      the adaptive SigmaW/SigmaV traces;
%   4. plots the EaEKF tracked covariances against the constant ESC-tuned
%      covariances plus EaEKF mean/median/mode reference lines.
%
% Inputs
%   resultsInput   Aggregate autotuning struct or MAT-file path.
%   cfg.scenario_name Optional scenario name. Default: first scenario with EaEKF.
%   cfg.ea_estimator_name Optional adaptive estimator name. Default: 'EaEKF'.
%   cfg.time_unit   'hours' (default), 'seconds', or 'samples'.
%
% Output
%   validation     Struct with figure handles, traced EaEKF covariances,
%                  constant tuned ESC covariances, and summary statistics.

if nargin < 2 || isempty(cfg)
    cfg = struct();
end

cfg = normalizeValidationConfig(cfg);
data = loadAutotuningData(resultsInput);
repo_root = getRepoRoot();

if ~isfield(data, 'config') || ~isstruct(data.config) || ~isfield(data.config, 'scenarios')
    error('plotAutotuningCovarianceValidation:MissingConfig', ...
        'This validation plot requires an aggregate autotuning result with a saved config/scenario list.');
end

scenario_cfg = selectScenarioConfig(data.config.scenarios, cfg.scenario_name, cfg.ea_estimator_name);
selected_runs = selectBestRunPerEstimator(data.runs, scenario_cfg.name);
[ea_run, esc_runs] = splitValidationRuns(selected_runs, cfg.ea_estimator_name);

if isempty(ea_run)
    error('plotAutotuningCovarianceValidation:MissingEaEKF', ...
        'Scenario %s does not contain an autotuned %s run.', scenario_cfg.name, cfg.ea_estimator_name);
end
if isempty(esc_runs)
    warning('plotAutotuningCovarianceValidation:NoEscComparators', ...
        'No constant ESC-based estimator runs were found for scenario %s.', scenario_cfg.name);
end

[dataset, model] = loadReplayInputs(scenario_cfg, repo_root);
[trace, state_labels] = replayEaEkfCovariances(dataset, model, scenario_cfg.modelSpec, ea_run.best_tuning);
stats = buildValidationStats(trace, state_labels);
constant_table = buildConstantCovarianceTable(esc_runs);
comparison = buildCovarianceComparison(constant_table, stats, state_labels);
figures = makeValidationFigures(trace, stats, constant_table, state_labels, scenario_cfg, ea_run, cfg);
printCovarianceComparison(comparison);

validation = struct();
validation.kind = 'autotuning_covariance_validation';
validation.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
validation.source = resultsInput;
validation.scenario_name = scenario_cfg.name;
validation.ea_estimator_name = ea_run.estimator_name;
validation.ea_best_objective = ea_run.best_objective;
validation.ea_best_tuning = ea_run.best_tuning;
validation.dataset_file = scenario_cfg.datasetSpec.dataset_file;
validation.esc_model_file = scenario_cfg.modelSpec.esc_model_file;
validation.trace = trace;
validation.state_labels = state_labels;
validation.stats = stats;
validation.constant_covariances = constant_table;
validation.comparison = comparison;
validation.figures = figures;

if nargout == 0
    assignin('base', 'autotuningCovarianceValidation', validation);
end
end

function cfg = normalizeValidationConfig(cfg)
if ~isfield(cfg, 'scenario_name')
    cfg.scenario_name = '';
end
if ~isfield(cfg, 'ea_estimator_name') || isempty(cfg.ea_estimator_name)
    cfg.ea_estimator_name = 'EaEKF';
end
if ~isfield(cfg, 'time_unit') || isempty(cfg.time_unit)
    cfg.time_unit = 'hours';
end
end

function repo_root = getRepoRoot()
here = fileparts(mfilename('fullpath'));
repo_root = fileparts(here);
end

function scenario_cfg = selectScenarioConfig(raw_scenarios, scenario_name, ea_estimator_name)
scenarios = ensureStructArray(raw_scenarios);
if isempty(scenarios)
    error('plotAutotuningCovarianceValidation:NoScenarios', ...
        'No scenarios were saved in the autotuning config.');
end

if ~isempty(scenario_name)
    matches = arrayfun(@(s) strcmpi(getFieldOr(s, 'name', ''), scenario_name), scenarios);
    if ~any(matches)
        error('plotAutotuningCovarianceValidation:UnknownScenario', ...
            'Scenario %s was not found in the autotuning config.', scenario_name);
    end
    scenario_cfg = scenarios(find(matches, 1, 'first'));
    return;
end

for idx = 1:numel(scenarios)
    estimator_names = normalizeNameList(getFieldOr(scenarios(idx), 'estimator_names', {}));
    if any(strcmpi(estimator_names, ea_estimator_name))
        scenario_cfg = scenarios(idx);
        return;
    end
end

scenario_cfg = scenarios(1);
end

function selected_runs = selectBestRunPerEstimator(raw_runs, scenario_name)
runs = ensureStructArray(raw_runs);
selected_runs = runs([]);
selected_names = {};

for idx = 1:numel(runs)
    run = runs(idx);
    if ~strcmpi(getFieldOr(run, 'scenario_name', ''), scenario_name)
        continue;
    end

    estimator_name = getFieldOr(run, 'estimator_name', '');
    existing_idx = find(strcmpi(selected_names, estimator_name), 1, 'first');
    if isempty(existing_idx)
        selected_runs(end+1, 1) = run; %#ok<AGROW>
        selected_names{end+1, 1} = estimator_name; %#ok<AGROW>
        continue;
    end

    current_objective = getFieldOr(selected_runs(existing_idx), 'best_objective', inf);
    candidate_objective = getFieldOr(run, 'best_objective', inf);
    if candidate_objective <= current_objective
        selected_runs(existing_idx) = run;
    end
end
end

function [ea_run, esc_runs] = splitValidationRuns(runs, ea_estimator_name)
ea_run = [];
esc_runs = runs([]);

for idx = 1:numel(runs)
    run = runs(idx);
    estimator_name = getFieldOr(run, 'estimator_name', '');
    if strcmpi(estimator_name, ea_estimator_name)
        ea_run = run;
        continue;
    end
    if strcmpi(estimator_name, 'ROM-EKF')
        continue;
    end
    if ~strcmpi(getFieldOr(run, 'process_noise_field', ''), 'sigma_w_esc') || ...
            ~strcmpi(getFieldOr(run, 'sensor_noise_field', ''), 'sigma_v_esc')
        continue;
    end
    esc_runs(end+1, 1) = run; %#ok<AGROW>
end
end

function [dataset, model] = loadReplayInputs(scenario_cfg, repo_root)
dataset = loadDatasetFromSpec(scenario_cfg.datasetSpec, repo_root);
model = loadEscModelFromSpec(scenario_cfg.modelSpec, repo_root);
end

function dataset = loadDatasetFromSpec(datasetSpec, repo_root)
dataset_file = resolvePathForReadOrRepo(getFieldOr(datasetSpec, 'dataset_file', ''), repo_root);
dataset_variable = getFieldOr(datasetSpec, 'dataset_variable', 'dataset');

if exist(dataset_file, 'file') ~= 2
    builder_fcn = getFieldOr(datasetSpec, 'builder_fcn', []);
    if isempty(builder_fcn)
        error('plotAutotuningCovarianceValidation:MissingDataset', ...
            'Dataset file not found: %s', dataset_file);
    end
    builder_cfg = getFieldOr(datasetSpec, 'builder_cfg', struct());
    builder_handle = resolveFunctionHandle(builder_fcn);
    dataset = builder_handle(dataset_file, builder_cfg);
    return;
end

loaded = load(dataset_file);
dataset = extractSavedStruct(loaded, dataset_file, dataset_variable, 'dataset');
end

function model = loadEscModelFromSpec(modelSpec, repo_root)
model_file = resolvePathForReadOrRepo(getFieldOr(modelSpec, 'esc_model_file', ''), repo_root);
if exist(model_file, 'file') ~= 2
    error('plotAutotuningCovarianceValidation:MissingEscModel', ...
        'ESC model file not found: %s', model_file);
end

loaded = load(model_file);
if isfield(loaded, 'nmc30_model')
    model = loaded.nmc30_model;
elseif isfield(loaded, 'model')
    model = loaded.model;
else
    error('plotAutotuningCovarianceValidation:BadEscModel', ...
        'Expected variable "nmc30_model" or "model" in %s.', model_file);
end
end

function [trace, state_labels] = replayEaEkfCovariances(dataset, model, modelSpec, tuning)
time_s = coerceColumn(getRequiredField(dataset, 'time_s', 'dataset'));
current_a = coerceColumn(getRequiredField(dataset, 'current_a', 'dataset'));
voltage_v = coerceColumn(getRequiredField(dataset, 'voltage_v', 'dataset'));
n_samples = numel(time_s);

if numel(current_a) ~= n_samples || numel(voltage_v) ~= n_samples
    error('plotAutotuningCovarianceValidation:SignalLengthMismatch', ...
        'Dataset time/current/voltage lengths must match.');
end

temperature_c = selectTemperatureTrace(dataset, getFieldOr(modelSpec, 'tc', 25));
soc0_percent = inferReferenceSoc0(dataset);
tc = getFieldOr(modelSpec, 'tc', 25);

n_rc = numel(getParamESC('RCParam', tc, model));
SigmaX0 = diag([ ...
    getFieldOr(tuning, 'SigmaX0_rc', 1e-6) * ones(1, n_rc), ...
    getFieldOr(tuning, 'SigmaX0_hk', 1e-6), ...
    getFieldOr(tuning, 'SigmaX0_soc', 1e-3)]);

kfData = initEaEKF( ...
    soc0_percent, tc, SigmaX0, ...
    getFieldOr(tuning, 'sigma_v_esc', 1e-3), ...
    getFieldOr(tuning, 'sigma_w_esc', 1e-3), ...
    model);

state_labels = cellstr([compose("RC%d", 1:n_rc), "h", "SOC"]);
sigma_w_diag = NaN(n_samples, numel(state_labels));
sigma_v = NaN(n_samples, 1);

sigma_w_diag(1, :) = diag(double(kfData.SigmaW)).';
sigma_v(1) = double(extractScalarNoise(kfData.SigmaV));

for k = 2:n_samples
    dt = time_s(k) - time_s(k - 1);
    [~, ~, ~, kfData, ~] = iterEaEKF(voltage_v(k), current_a(k), temperature_c(k), dt, kfData);
    sigma_w_diag(k, :) = diag(double(kfData.SigmaW)).';
    sigma_v(k) = double(extractScalarNoise(kfData.SigmaV));
end

trace = struct();
trace.time_s = time_s;
trace.current_a = current_a;
trace.voltage_v = voltage_v;
trace.temperature_c = temperature_c;
trace.sigma_w_diag = sigma_w_diag;
trace.sigma_v = sigma_v;
trace.sigma_w_init = sigma_w_diag(1, :);
trace.sigma_v_init = sigma_v(1);
trace.sigma_w_final = sigma_w_diag(end, :);
trace.sigma_v_final = sigma_v(end);
end

function stats = buildValidationStats(trace, state_labels)
n_states = size(trace.sigma_w_diag, 2);
process = repmat(struct('state_label', '', 'mean', NaN, 'median', NaN, ...
    'mode', NaN, 'initial', NaN, 'final', NaN), n_states, 1);

for idx = 1:n_states
    values = trace.sigma_w_diag(:, idx);
    process(idx).state_label = state_labels{idx};
    process(idx).mean = mean(values, 'omitnan');
    process(idx).median = median(values, 'omitnan');
    process(idx).mode = mode(values(~isnan(values)));
    process(idx).initial = values(1);
    process(idx).final = values(end);
end

sensor_values = trace.sigma_v(:);
sensor = struct();
sensor.mean = mean(sensor_values, 'omitnan');
sensor.median = median(sensor_values, 'omitnan');
sensor.mode = mode(sensor_values(~isnan(sensor_values)));
sensor.initial = sensor_values(1);
sensor.final = sensor_values(end);

stats = struct();
stats.process = process;
stats.sensor = sensor;
stats.process_table = table( ...
    string({process.state_label}).', ...
    [process.initial].', [process.final].', ...
    [process.mean].', [process.median].', [process.mode].', ...
    'VariableNames', {'State', 'Initial', 'Final', 'Mean', 'Median', 'Mode'});
stats.sensor_table = table( ...
    sensor.initial, sensor.final, sensor.mean, sensor.median, sensor.mode, ...
    'VariableNames', {'Initial', 'Final', 'Mean', 'Median', 'Mode'});
end

function comparison = buildCovarianceComparison(constant_table, stats, state_labels)
comparison = struct();
comparison.process_tables = cell(numel(state_labels), 1);
comparison.sensor_table = table();

if isempty(constant_table) || height(constant_table) == 0
    return;
end

for state_idx = 1:numel(state_labels)
    ref = stats.process(state_idx);
    tuned = constant_table.ProcessNoise;
    comparison.process_tables{state_idx} = table( ...
        constant_table.Estimator, ...
        tuned, ...
        tuned - ref.initial, ...
        tuned - ref.final, ...
        tuned - ref.mean, ...
        tuned - ref.median, ...
        tuned - ref.mode, ...
        'VariableNames', { ...
        'Estimator', 'TunedProcessNoise', ...
        'MinusEaInit', 'MinusEaFinal', 'MinusEaMean', 'MinusEaMedian', 'MinusEaMode'});
end

sensor_tuned = constant_table.SensorNoise;
comparison.sensor_table = table( ...
    constant_table.Estimator, ...
    sensor_tuned, ...
    sensor_tuned - stats.sensor.initial, ...
    sensor_tuned - stats.sensor.final, ...
    sensor_tuned - stats.sensor.mean, ...
    sensor_tuned - stats.sensor.median, ...
    sensor_tuned - stats.sensor.mode, ...
    'VariableNames', { ...
    'Estimator', 'TunedSensorNoise', ...
    'MinusEaInit', 'MinusEaFinal', 'MinusEaMean', 'MinusEaMedian', 'MinusEaMode'});
comparison.state_labels = state_labels;
end

function printCovarianceComparison(comparison)
if ~isfield(comparison, 'process_tables') || isempty(comparison.process_tables)
    return;
end

fprintf('\nEaEKF covariance validation summary\n');
for idx = 1:numel(comparison.process_tables)
    table_in = comparison.process_tables{idx};
    if isempty(table_in) || height(table_in) == 0
        continue;
    end
    fprintf('\nProcess covariance comparison for %s\n', comparison.state_labels{idx});
    disp(table_in);
end

if isfield(comparison, 'sensor_table') && ~isempty(comparison.sensor_table) && height(comparison.sensor_table) > 0
    fprintf('\nSensor covariance comparison\n');
    disp(comparison.sensor_table);
end
end

function constant_table = buildConstantCovarianceTable(esc_runs)
if isempty(esc_runs)
    constant_table = table();
    return;
end

n_runs = numel(esc_runs);
estimator = strings(n_runs, 1);
process_noise = NaN(n_runs, 1);
sensor_noise = NaN(n_runs, 1);
objective_value = NaN(n_runs, 1);

for idx = 1:n_runs
    estimator(idx) = string(getFieldOr(esc_runs(idx), 'estimator_name', ""));
    process_noise(idx) = getFieldOr(esc_runs(idx), 'best_process_noise', NaN);
    sensor_noise(idx) = getFieldOr(esc_runs(idx), 'best_sensor_noise', NaN);
    objective_value(idx) = getFieldOr(esc_runs(idx), 'best_objective', NaN);
end

constant_table = table(estimator, process_noise, sensor_noise, objective_value, ...
    'VariableNames', {'Estimator', 'ProcessNoise', 'SensorNoise', 'ObjectiveValue'});
constant_table = sortrows(constant_table, 'ObjectiveValue', 'ascend');
end

function figures = makeValidationFigures(trace, stats, constant_table, state_labels, scenario_cfg, ea_run, cfg)
[x_values, x_label] = selectXAxis(trace.time_s, cfg.time_unit);
title_prefix = sprintf('%s | %s covariance validation', ...
    getFieldOr(scenario_cfg.datasetSpec, 'title_prefix', getFieldOr(scenario_cfg, 'name', 'Autotuning')), ...
    ea_run.estimator_name);

stat_styles = { ...
    struct('field', 'mean', 'label', 'EaEKF mean', 'style', '--', 'color', [0.10 0.10 0.10]), ...
    struct('field', 'median', 'label', 'EaEKF median', 'style', '-.', 'color', [0.35 0.35 0.35]), ...
    struct('field', 'mode', 'label', 'EaEKF mode', 'style', ':', 'color', [0.55 0.55 0.55])};

est_palette = lines(max(height(constant_table), 1));

process_fig = figure('Name', 'Autotuning Covariance Validation - Process', 'NumberTitle', 'off');
tiledlayout(numel(state_labels), 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for state_idx = 1:numel(state_labels)
    nexttile;
    hold on;
    h_const = gobjects(0);
    for est_idx = 1:height(constant_table)
        h_const(end + 1) = semilogy(x_values([1 end]), ...
            constant_table.ProcessNoise(est_idx) * [1 1], ...
            'LineWidth', 1.0, ...
            'Color', est_palette(est_idx, :), ...
            'DisplayName', sprintf('%s tuned \\sigma_w', char(constant_table.Estimator(est_idx)))); %#ok<AGROW>
    end
    h_trace = semilogy(x_values, trace.sigma_w_diag(:, state_idx), 'k-', ...
        'LineWidth', 1.4, 'DisplayName', 'EaEKF tracked \Sigma_W');
    h_init = semilogy(x_values(1), trace.sigma_w_init(state_idx), 'ko', ...
        'MarkerFaceColor', [0.98 0.73 0.19], ...
        'DisplayName', 'EaEKF init');
    h_stats = gobjects(numel(stat_styles), 1);
    for stat_idx = 1:numel(stat_styles)
        stat_value = stats.process(state_idx).(stat_styles{stat_idx}.field);
        h_stats(stat_idx) = semilogy(x_values([1 end]), stat_value * [1 1], ...
            'LineStyle', stat_styles{stat_idx}.style, ...
            'Color', stat_styles{stat_idx}.color, ...
            'LineWidth', 1.0, ...
            'DisplayName', stat_styles{stat_idx}.label);
    end
    grid on;
    xlabel(x_label);
    ylabel('\Sigma_W diag');
    title(sprintf('%s process covariance (%s)', title_prefix, state_labels{state_idx}), 'Interpreter', 'none');
    if state_idx == 1
        legend([h_trace; h_init; h_stats; h_const(:)], 'Location', 'eastoutside');
    end
end

sensor_fig = figure('Name', 'Autotuning Covariance Validation - Sensor', 'NumberTitle', 'off');
hold on;
h_const = gobjects(0);
for est_idx = 1:height(constant_table)
    h_const(end + 1) = semilogy(x_values([1 end]), ...
        constant_table.SensorNoise(est_idx) * [1 1], ...
        'LineWidth', 1.0, ...
        'Color', est_palette(est_idx, :), ...
        'DisplayName', sprintf('%s tuned \\sigma_v', char(constant_table.Estimator(est_idx)))); %#ok<AGROW>
end
h_trace = semilogy(x_values, trace.sigma_v, 'k-', 'LineWidth', 1.4, ...
    'DisplayName', 'EaEKF tracked \Sigma_V');
h_init = semilogy(x_values(1), trace.sigma_v_init, 'ko', ...
    'MarkerFaceColor', [0.98 0.73 0.19], ...
    'DisplayName', 'EaEKF init');
h_stats = gobjects(numel(stat_styles), 1);
for stat_idx = 1:numel(stat_styles)
    stat_value = stats.sensor.(stat_styles{stat_idx}.field);
    h_stats(stat_idx) = semilogy(x_values([1 end]), stat_value * [1 1], ...
        'LineStyle', stat_styles{stat_idx}.style, ...
        'Color', stat_styles{stat_idx}.color, ...
        'LineWidth', 1.0, ...
        'DisplayName', stat_styles{stat_idx}.label);
end
grid on;
xlabel(x_label);
ylabel('\Sigma_V');
title(sprintf('%s sensor covariance', title_prefix), 'Interpreter', 'none');
legend([h_trace; h_init; h_stats; h_const(:)], 'Location', 'eastoutside');

figures = struct();
figures.process = process_fig;
figures.sensor = sensor_fig;
figures.ea_process_tracking = makeEaTrackingProcessFigure(x_values, x_label, trace, state_labels, title_prefix);
figures.ea_sensor_tracking = makeEaTrackingSensorFigure(x_values, x_label, trace, title_prefix);
end

function fig_handle = makeEaTrackingProcessFigure(x_values, x_label, trace, state_labels, title_prefix)
fig_handle = figure('Name', 'Autotuning Covariance Validation - EaEKF Process Tracking', 'NumberTitle', 'off');
tiledlayout(numel(state_labels), 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for state_idx = 1:numel(state_labels)
    nexttile;
    semilogy(x_values, trace.sigma_w_diag(:, state_idx), 'k-', 'LineWidth', 1.4);
    hold on;
    semilogy(x_values(1), trace.sigma_w_init(state_idx), 'o', ...
        'Color', [0.10 0.45 0.75], ...
        'MarkerFaceColor', [0.10 0.45 0.75], ...
        'DisplayName', 'init');
    semilogy(x_values(end), trace.sigma_w_final(state_idx), 's', ...
        'Color', [0.85 0.33 0.10], ...
        'MarkerFaceColor', [0.85 0.33 0.10], ...
        'DisplayName', 'final');
    grid on;
    xlabel(x_label);
    ylabel('\Sigma_W diag');
    title(sprintf('%s EaEKF process tracking (%s)', title_prefix, state_labels{state_idx}), 'Interpreter', 'none');
    if state_idx == 1
        legend({'track', 'init', 'final'}, 'Location', 'eastoutside');
    end
end
end

function fig_handle = makeEaTrackingSensorFigure(x_values, x_label, trace, title_prefix)
fig_handle = figure('Name', 'Autotuning Covariance Validation - EaEKF Sensor Tracking', 'NumberTitle', 'off');
semilogy(x_values, trace.sigma_v, 'k-', 'LineWidth', 1.4);
hold on;
semilogy(x_values(1), trace.sigma_v_init, 'o', ...
    'Color', [0.10 0.45 0.75], ...
    'MarkerFaceColor', [0.10 0.45 0.75]);
semilogy(x_values(end), trace.sigma_v_final, 's', ...
    'Color', [0.85 0.33 0.10], ...
    'MarkerFaceColor', [0.85 0.33 0.10]);
grid on;
xlabel(x_label);
ylabel('\Sigma_V');
title(sprintf('%s EaEKF sensor tracking', title_prefix), 'Interpreter', 'none');
legend({'track', 'init', 'final'}, 'Location', 'eastoutside');
end

function [x_values, x_label] = selectXAxis(time_s, time_unit)
switch lower(char(time_unit))
    case 'samples'
        x_values = (1:numel(time_s)).';
        x_label = 'Sample index';
    case 'seconds'
        x_values = time_s(:);
        x_label = 'Time [s]';
    otherwise
        x_values = time_s(:) / 3600;
        x_label = 'Time [h]';
end
end

function raw = extractScalarNoise(value)
if isscalar(value)
    raw = value;
elseif isvector(value) && numel(value) == 1
    raw = value(1);
else
    raw = value(1);
end
end

function temperature_c = selectTemperatureTrace(dataset, default_temp)
n_samples = numel(dataset.time_s);
if isfield(dataset, 'temperature_c') && ~isempty(dataset.temperature_c)
    raw = dataset.temperature_c(:);
else
    raw = [];
end

if isempty(raw)
    temperature_c = default_temp * ones(n_samples, 1);
elseif numel(raw) == 1
    temperature_c = raw * ones(n_samples, 1);
elseif numel(raw) == n_samples
    temperature_c = raw;
else
    error('plotAutotuningCovarianceValidation:TemperatureLengthMismatch', ...
        'Dataset temperature length must match dataset.time_s.');
end
end

function soc0 = inferReferenceSoc0(dataset)
if isfield(dataset, 'soc_true') && ~isempty(dataset.soc_true) && isfinite(dataset.soc_true(1))
    soc0 = 100 * dataset.soc_true(1);
elseif isfield(dataset, 'soc_init_percent') && ~isempty(dataset.soc_init_percent) && isfinite(dataset.soc_init_percent)
    soc0 = double(dataset.soc_init_percent);
elseif isfield(dataset, 'source_soc_ref') && ~isempty(dataset.source_soc_ref) && isfinite(dataset.source_soc_ref(1))
    soc0 = 100 * dataset.source_soc_ref(1);
else
    error('plotAutotuningCovarianceValidation:MissingReferenceSoc0', ...
        'No initial SOC was found in dataset.soc_true, dataset.soc_init_percent, or dataset.source_soc_ref.');
end
end

function names = normalizeNameList(raw_names)
if ischar(raw_names)
    names = {raw_names};
elseif isa(raw_names, 'string')
    names = cellstr(raw_names(:));
elseif iscell(raw_names)
    names = raw_names(:);
else
    names = {};
end
end

function value = getRequiredField(s, field_name, struct_name)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    error('plotAutotuningCovarianceValidation:MissingField', ...
        '%s.%s is required.', struct_name, field_name);
end
end

function s = extractSavedStruct(loaded, file_path, variable_name, expected_kind)
if isfield(loaded, variable_name)
    s = loaded.(variable_name);
    return;
end

names = fieldnames(loaded);
for idx = 1:numel(names)
    candidate = loaded.(names{idx});
    if isstruct(candidate)
        s = candidate;
        return;
    end
end

error('plotAutotuningCovarianceValidation:MissingSavedStruct', ...
    'Could not find a %s struct in %s.', expected_kind, file_path);
end

function path_out = resolvePathForReadOrRepo(path_in, repo_root)
if exist(path_in, 'file') == 2
    path_out = path_in;
    return;
end
candidate = fullfile(repo_root, path_in);
if exist(candidate, 'file') == 2
    path_out = candidate;
    return;
end
path_out = path_in;
end

function value = getFieldOr(s, field_name, default_value)
if isstruct(s) && isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end

function handle_out = resolveFunctionHandle(fcn_in)
if isa(fcn_in, 'function_handle')
    handle_out = fcn_in;
else
    handle_out = str2func(char(fcn_in));
end
end

function vec = coerceColumn(value)
vec = double(value(:));
end

function structs = ensureStructArray(raw)
if isempty(raw)
    structs = repmat(struct(), 0, 1);
    return;
end
if isstruct(raw)
    structs = raw(:);
else
    error('plotAutotuningCovarianceValidation:BadStructArray', ...
        'Expected a struct input.');
end
end
