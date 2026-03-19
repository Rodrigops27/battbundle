function results = ESCvalidation(modelFile, data, enabledPlot)
% ESCvalidation Validate an ESC model against a measured current-voltage profile.
%
% Usage:
%   results = ESCvalidation()
%   results = ESCvalidation(modelFile)
%   results = ESCvalidation(modelFile, data)
%   results = ESCvalidation(modelFile, data, enabledPlot)
%
% Inputs:
%   modelFile    ESC model file path, loaded model struct, or [] for default ATL model.
%   data         Validation dataset. Supported forms:
%                  - []: default Bus_CoreBattery real profile
%                  - MAT-file path to a real profile, normalized dataset, or DYNData file
%                  - struct with current/voltage fields
%                  - legacy processDynamic-style struct array with script1 entries
%   enabledPlot  true/false. Default: true
%
% Output:
%   results      Struct with per-case traces and voltage metrics.

if nargin < 1
    modelFile = [];
end
if nargin < 2
    data = [];
end
if nargin < 3 || isempty(enabledPlot)
    enabledPlot = true;
end

script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(script_dir);

addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'utility')));

[model, model_file, model_name] = loadEscModel(modelFile, repo_root);
cases = normalizeValidationCases(data, model, repo_root);

case_results_list = cell(numel(cases), 1);
for idx = 1:numel(cases)
    case_results_list{idx} = runValidationCase(cases(idx), model, model_file, model_name);
end
case_results = [case_results_list{:}]';

results = struct();
results.name = 'ESC model validation';
results.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
results.model_file = model_file;
results.model_name = model_name;
results.enabled_plot = logical(enabledPlot);
results.case_count = numel(case_results);
results.cases = case_results;
results.summary_table = buildSummaryTable(case_results);
results.metrics = summarizeMetrics(case_results);

printSummary(results);
if enabledPlot
    plotEscValidation(results);
end

if nargout == 0
    assignin('base', 'escValidationResults', results);
end
end

function case_result = runValidationCase(case_spec, model, model_file, model_name)
n_rc = numel(getParamESC('RCParam', case_spec.tc, model));
[voltage_est_v, rc_current_a, hysteresis_state, soc_cc, instantaneous_hysteresis, ocv_v] = ...
    simCell(case_spec.current_a(:), case_spec.tc, case_spec.ts, model, case_spec.z0, zeros(n_rc, 1), 0);

voltage_est_v = voltage_est_v(:);
voltage_meas_v = case_spec.voltage_v(:);
voltage_error_v = voltage_meas_v - voltage_est_v;
valid_idx = isfinite(voltage_meas_v) & isfinite(voltage_est_v);

metrics = computeVoltageMetrics(voltage_error_v, voltage_meas_v, voltage_est_v, valid_idx);
window_info = computeLegacyWindowMetrics(case_spec, model, voltage_error_v, valid_idx);

case_result = struct();
case_result.name = case_spec.name;
case_result.source_type = case_spec.source_type;
case_result.source_file = case_spec.source_file;
case_result.model_file = model_file;
case_result.model_name = model_name;
case_result.ts = case_spec.ts;
case_result.tc = case_spec.tc;
case_result.temperature_span_c = case_spec.temperature_span_c;
case_result.initial_soc = case_spec.z0;
case_result.current_sign_multiplier = case_spec.current_sign_multiplier;
case_result.current_sign_source = case_spec.current_sign_source;
case_result.sample_count = numel(case_spec.time_s);
case_result.valid_sample_count = nnz(valid_idx);
case_result.time_s = case_spec.time_s(:);
case_result.current_a = case_spec.current_a(:);
case_result.voltage_v = voltage_meas_v(:);
case_result.voltage_est_v = voltage_est_v(:);
case_result.voltage_error_v = voltage_error_v(:);
case_result.soc_cc = soc_cc(:);
case_result.soc_ref = case_spec.soc_ref(:);
case_result.ocv_v = ocv_v(:);
case_result.rc_current_a = rc_current_a;
case_result.hysteresis_state = hysteresis_state(:);
case_result.instantaneous_hysteresis = instantaneous_hysteresis(:);
case_result.window = window_info;
case_result.metrics = metrics;
case_result.notes = case_spec.notes;

case_result.metrics.legacy_window_rmse_v = window_info.rmse_v;
case_result.metrics.legacy_window_rmse_mv = 1000 * window_info.rmse_v;
case_result.metrics.legacy_window_samples = window_info.sample_count;
end

function metrics = computeVoltageMetrics(voltage_error_v, voltage_meas_v, voltage_est_v, valid_idx)
metrics = struct();
metrics.voltage_rmse_v = NaN;
metrics.voltage_rmse_mv = NaN;
metrics.voltage_mean_error_v = NaN;
metrics.voltage_mean_error_mv = NaN;
metrics.voltage_mae_v = NaN;
metrics.voltage_mae_mv = NaN;
metrics.voltage_max_abs_error_v = NaN;
metrics.voltage_max_abs_error_mv = NaN;
metrics.voltage_corr = NaN;
metrics.voltage_fit = [NaN, NaN];

if ~any(valid_idx)
    return;
end

valid_error = voltage_error_v(valid_idx);
metrics.voltage_rmse_v = sqrt(mean(valid_error .^ 2));
metrics.voltage_rmse_mv = 1000 * metrics.voltage_rmse_v;
metrics.voltage_mean_error_v = mean(valid_error);
metrics.voltage_mean_error_mv = 1000 * metrics.voltage_mean_error_v;
metrics.voltage_mae_v = mean(abs(valid_error));
metrics.voltage_mae_mv = 1000 * metrics.voltage_mae_v;
metrics.voltage_max_abs_error_v = max(abs(valid_error));
metrics.voltage_max_abs_error_mv = 1000 * metrics.voltage_max_abs_error_v;

% Compute correlation and fit for scatter plot
if nnz(valid_idx) >= 2
    corr_matrix = corrcoef(voltage_meas_v(valid_idx), voltage_est_v(valid_idx));
    metrics.voltage_corr = corr_matrix(1, 2);
    metrics.voltage_fit = polyfit(voltage_meas_v(valid_idx), voltage_est_v(valid_idx), 1);
end
end

function window_info = computeLegacyWindowMetrics(case_spec, model, voltage_error_v, valid_idx)
window_info = struct();
window_info.name = 'legacy_95_to_05_ocv_window';
window_info.lower_soc = 0.05;
window_info.upper_soc = 0.95;
window_info.start_index = NaN;
window_info.end_index = NaN;
window_info.sample_count = 0;
window_info.rmse_v = NaN;
window_info.rmse_mv = NaN;

if isempty(case_spec.voltage_v)
    return;
end

v95 = OCVfromSOCtemp(0.95, case_spec.tc, model);
v05 = OCVfromSOCtemp(0.05, case_spec.tc, model);
start_idx = find(case_spec.voltage_v < v95, 1, 'first');
end_idx = find(case_spec.voltage_v < v05, 1, 'first');
if isempty(start_idx)
    start_idx = 1;
end
if isempty(end_idx)
    end_idx = numel(case_spec.voltage_v);
end
if end_idx < start_idx
    end_idx = start_idx;
end

window_idx = false(size(valid_idx));
window_idx(start_idx:end_idx) = true;
window_valid_idx = window_idx & valid_idx;

window_info.start_index = start_idx;
window_info.end_index = end_idx;
window_info.sample_count = nnz(window_valid_idx);
if any(window_valid_idx)
    window_info.rmse_v = sqrt(mean(voltage_error_v(window_valid_idx) .^ 2));
    window_info.rmse_mv = 1000 * window_info.rmse_v;
end
end

function cases = normalizeValidationCases(data_input, model, repo_root)
if nargin < 1 || isempty(data_input)
    data_input = fullfile(repo_root, 'Evaluation', 'OMTLIFE8AHC-HP', 'Bus_CoreBatteryData_Data.mat');
end

if ischar(data_input) || (isstring(data_input) && isscalar(data_input))
    data_file = resolveLocalPath(char(data_input), repo_root);
    raw = load(data_file);
    if isfield(raw, 'dataset') && isstruct(raw.dataset)
        cases = normalizeValidationCases(raw.dataset, model, repo_root);
        for idx = 1:numel(cases)
            if isempty(cases(idx).source_file)
                cases(idx).source_file = data_file;
            end
        end
        return;
    end
    if isfield(raw, 'DYNData')
        cases = normalizeValidationCases(raw.DYNData, model, repo_root);
        for idx = 1:numel(cases)
            cases(idx).source_file = data_file;
        end
        return;
    end
    profile = loadBusCoreBatteryProfile(data_file);
    cases = buildMeasuredProfileCase(profile, model, 'real_profile');
    return;
end

if iscell(data_input)
    cases = repmat(struct(), 0, 1);
    for idx = 1:numel(data_input)
        item_cases = normalizeValidationCases(data_input{idx}, model, repo_root);
        cases = [cases; item_cases(:)]; %#ok<AGROW>
    end
    return;
end

if ~isstruct(data_input)
    error('ESCvalidation:UnsupportedData', ...
        'Unsupported validation input of class %s.', class(data_input));
end

if numel(data_input) > 1 && all(arrayfun(@(s) isfield(s, 'script1'), data_input))
    cases = buildLegacyCases(data_input, model);
    return;
end

if isfield(data_input, 'script1')
    cases = buildLegacyCases(data_input, model);
    return;
end

if isfield(data_input, 'dataset') && isstruct(data_input.dataset)
    cases = normalizeValidationCases(data_input.dataset, model, repo_root);
    return;
end

if isfield(data_input, 'DYNData')
    cases = normalizeValidationCases(data_input.DYNData, model, repo_root);
    return;
end

if hasMeasuredFields(data_input)
    cases = buildNormalizedDatasetCase(data_input, model);
    return;
end

profile = coerceProfileStruct(data_input);
if isempty(profile.current_a) || isempty(profile.voltage_v)
    error('ESCvalidation:MissingSignals', ...
        'Could not derive current and voltage signals from the provided data struct.');
end
cases = buildMeasuredProfileCase(profile, model, 'real_profile_struct');
end

function tf = hasMeasuredFields(data_input)
[current_raw, ~] = extractSignal(data_input, currentAliases());
[voltage_raw, ~] = extractSignal(data_input, measuredVoltageAliases());
tf = ~isempty(current_raw) || ~isempty(voltage_raw);
end

function cases = buildLegacyCases(data_input, model)
data_input = data_input(:);
cases_list = cell(numel(data_input), 1);
for idx = 1:numel(data_input)
    script1 = data_input(idx).script1;
    current_a = extractVectorField(script1, {'current'});
    voltage_v = extractVectorField(script1, {'voltage'});
    if isempty(current_a) || isempty(voltage_v)
        error('ESCvalidation:LegacySignals', ...
            'Legacy script1 entry %d is missing current or voltage.', idx);
    end

    tc = inferLegacyTemperature(data_input(idx), model);
    ts = 1;
    time_s = (0:numel(current_a)-1).' * ts;
    notes = {};
    notes{end+1} = 'Legacy script1 validation uses z0 = 1 to match utility/DYN_eg/runProcessDynamic.m.';

    cases_list{idx} = makeCaseSpec( ...
        sprintf('legacy_script1_case_%d', idx), ...
        'legacy_script1', ...
        '', ...
        time_s, ...
        current_a(:), ...
        voltage_v(:), ...
        NaN(numel(current_a), 1), ...
        tc, ...
        0, ...
        1, ...
        1, ...
        'legacy_script1_assumption', ...
        notes);
end
cases = [cases_list{:}]';
end

function tc = inferLegacyTemperature(data_entry, model)
if isfield(data_entry, 'temp') && ~isempty(data_entry.temp)
    tc = double(data_entry.temp);
    return;
end
tc = defaultValidationTemperature(model);
end

function cases = buildMeasuredProfileCase(profile, model, source_type)
if nargin < 3 || isempty(source_type)
    source_type = 'real_profile';
end

profile.current_a = profile.current_a(:);
profile.voltage_v = profile.voltage_v(:);
profile.time_s = ensureTimeVector(profile.time_s, numel(profile.current_a));
if ~isfield(profile, 'soc_ref') || isempty(profile.soc_ref)
    profile.soc_ref = NaN(numel(profile.current_a), 1);
else
    profile.soc_ref = normalizeSocSignal(profile.soc_ref(:));
end
if ~isfield(profile, 'temperature_c') || isempty(profile.temperature_c)
    profile.temperature_c = NaN(numel(profile.current_a), 1);
else
    profile.temperature_c = profile.temperature_c(:);
end

profile = resampleProfile(profile, inferSampleTime(profile.time_s));
cfg = struct();
cfg.current_sign = [];
if isfield(profile, 'current_sign') && ~isempty(profile.current_sign)
    cfg.current_sign = profile.current_sign;
end
if isfield(profile, 'current_sign_multiplier') && ~isempty(profile.current_sign_multiplier)
    cfg.current_sign = profile.current_sign_multiplier;
end

[current_a, sign_multiplier, sign_source] = orientCurrentToDischargePositive( ...
    profile.current_a, profile.time_s, profile.soc_ref, cfg);
profile.current_a = current_a(:);

tc = inferProfileTemperature(profile, model);
z0 = determineInitialSoc(profile.voltage_v, profile.current_a, profile.soc_ref, tc, model);
notes = profileNotes(profile, tc);

case_name = fieldOr(profile, 'profile_name', source_type);
source_file = fieldOr(profile, 'profile_file', '');
cases = makeCaseSpec(case_name, source_type, source_file, ...
    profile.time_s, profile.current_a, profile.voltage_v, profile.soc_ref, ...
    tc, temperatureSpan(profile.temperature_c), z0, sign_multiplier, sign_source, notes);
end

function cases = buildNormalizedDatasetCase(data_input, model)
current_a = extractVectorField(data_input, currentAliases());
voltage_v = extractVectorField(data_input, measuredVoltageAliases());
if isempty(current_a) || isempty(voltage_v)
    error('ESCvalidation:DatasetSignals', ...
        'Normalized dataset must provide current and measured voltage signals.');
end

time_s = extractVectorField(data_input, timeAliases());
if isempty(time_s)
    ts = extractScalarField(data_input, {'ts', 'sample_time_s', 'simulation_sample_time_s'});
    if isempty(ts) || ~isfinite(ts) || ts <= 0
        ts = 1;
    end
    time_s = (0:numel(current_a)-1).' * ts;
else
    time_s = ensureTimeVector(time_s, numel(current_a));
end

soc_ref = extractVectorField(data_input, socAliases());
if isempty(soc_ref)
    soc_ref = NaN(numel(current_a), 1);
end
soc_ref = normalizeSocSignal(soc_ref(:));

temperature_c = extractVectorField(data_input, temperatureAliases());
if isempty(temperature_c)
    scalar_tc = extractScalarField(data_input, {'assumed_temperature_c', 'tc'});
    if isempty(scalar_tc)
        temperature_c = NaN(numel(current_a), 1);
    else
        temperature_c = repmat(double(scalar_tc), numel(current_a), 1);
    end
end

profile = struct();
profile.profile_name = fieldOr(data_input, 'name', 'normalized_dataset');
profile.profile_file = fieldOr(data_input, 'source_profile_file', '');
profile.current_a = current_a(:);
profile.voltage_v = voltage_v(:);
profile.time_s = time_s(:);
profile.soc_ref = soc_ref(:);
profile.temperature_c = temperature_c(:);
if isfield(data_input, 'current_sign')
    profile.current_sign = data_input.current_sign;
elseif isfield(data_input, 'current_sign_multiplier')
    profile.current_sign_multiplier = data_input.current_sign_multiplier;
end

cases = buildMeasuredProfileCase(profile, model, 'normalized_dataset');
end

function case_spec = makeCaseSpec(name, source_type, source_file, time_s, current_a, voltage_v, soc_ref, tc, temperature_span_c, z0, sign_multiplier, sign_source, notes)
case_spec = struct();
case_spec.name = name;
case_spec.source_type = source_type;
case_spec.source_file = source_file;
case_spec.time_s = time_s(:);
case_spec.current_a = current_a(:);
case_spec.voltage_v = voltage_v(:);
case_spec.soc_ref = soc_ref(:);
case_spec.ts = inferSampleTime(case_spec.time_s);
case_spec.tc = tc;
case_spec.temperature_span_c = temperature_span_c;
case_spec.z0 = z0;
case_spec.current_sign_multiplier = sign_multiplier;
case_spec.current_sign_source = sign_source;
case_spec.notes = notes;
end

function notes = profileNotes(profile, tc)
notes = {};
if all(~isfinite(profile.temperature_c))
    notes{end+1} = sprintf('Validation temperature defaulted to %.1f degC because the dataset has no explicit temperature trace.', tc);
elseif temperatureSpan(profile.temperature_c) > 2
    notes{end+1} = sprintf('simCell uses a single temperature of %.2f degC while the dataset spans %.2f degC.', ...
        tc, temperatureSpan(profile.temperature_c));
end
end

function tc = inferProfileTemperature(profile, model)
finite_temp = profile.temperature_c(isfinite(profile.temperature_c));
if isempty(finite_temp)
    tc = defaultValidationTemperature(model);
else
    tc = double(median(finite_temp));
end
end

function tc = defaultValidationTemperature(model)
tc = 25;
if isfield(model, 'temps') && ~isempty(model.temps)
    temps = double(model.temps(:));
    temps = temps(isfinite(temps));
    if ~isempty(temps)
        [~, idx] = min(abs(temps - 25));
        tc = temps(idx);
    end
end
end

function span = temperatureSpan(temperature_c)
finite_temp = temperature_c(isfinite(temperature_c));
if isempty(finite_temp)
    span = 0;
else
    span = max(finite_temp) - min(finite_temp);
end
end

function printSummary(results)
fprintf('\n%s\n', results.name);
fprintf('  Model: %s\n', results.model_file);
fprintf('  Cases: %d\n', results.case_count);
for idx = 1:numel(results.cases)
    case_result = results.cases(idx);
    fprintf('  [%d] %s | RMSE %.2f mV | Mean %.2f mV | Max abs %.2f mV', ...
        idx, case_result.name, ...
        case_result.metrics.voltage_rmse_mv, ...
        case_result.metrics.voltage_mean_error_mv, ...
        case_result.metrics.voltage_max_abs_error_mv);
    if isfinite(case_result.metrics.legacy_window_rmse_mv)
        fprintf(' | Legacy window RMSE %.2f mV', case_result.metrics.legacy_window_rmse_mv);
    end
    fprintf('\n');
end
fprintf('\n');
end

function summary_table = buildSummaryTable(case_results)
names = cell(numel(case_results), 1);
source_types = cell(numel(case_results), 1);
source_files = cell(numel(case_results), 1);
rmse_mv = NaN(numel(case_results), 1);
legacy_rmse_mv = NaN(numel(case_results), 1);
mean_error_mv = NaN(numel(case_results), 1);
max_abs_error_mv = NaN(numel(case_results), 1);
samples = NaN(numel(case_results), 1);
tc = NaN(numel(case_results), 1);

for idx = 1:numel(case_results)
    names{idx} = case_results(idx).name;
    source_types{idx} = case_results(idx).source_type;
    source_files{idx} = case_results(idx).source_file;
    rmse_mv(idx) = case_results(idx).metrics.voltage_rmse_mv;
    legacy_rmse_mv(idx) = case_results(idx).metrics.legacy_window_rmse_mv;
    mean_error_mv(idx) = case_results(idx).metrics.voltage_mean_error_mv;
    max_abs_error_mv(idx) = case_results(idx).metrics.voltage_max_abs_error_mv;
    samples(idx) = case_results(idx).sample_count;
    tc(idx) = case_results(idx).tc;
end

summary_table = table(names, source_types, source_files, tc, samples, rmse_mv, ...
    legacy_rmse_mv, mean_error_mv, max_abs_error_mv, ...
    'VariableNames', {'case_name', 'source_type', 'source_file', 'tc_degC', ...
    'samples', 'voltage_rmse_mv', 'legacy_window_rmse_mv', ...
    'voltage_mean_error_mv', 'voltage_max_abs_error_mv'});
end

function metrics = summarizeMetrics(case_results)
metrics = struct();
all_rmse = arrayfun(@(c) c.metrics.voltage_rmse_v, case_results);
metrics.case_voltage_rmse_v = all_rmse(:);
metrics.case_voltage_rmse_mv = 1000 * all_rmse(:);
metrics.mean_voltage_rmse_v = mean(all_rmse, 'omitnan');
metrics.mean_voltage_rmse_mv = 1000 * metrics.mean_voltage_rmse_v;
metrics.max_voltage_rmse_v = max(all_rmse, [], 'omitnan');
metrics.max_voltage_rmse_mv = 1000 * metrics.max_voltage_rmse_v;
end

function [model, model_file, model_name] = loadEscModel(model_input, repo_root)
if nargin < 1 || isempty(model_input)
    model_file = firstExistingFile({ ...
        fullfile(repo_root, 'models', 'ATLmodel.mat'), ...
        fullfile(repo_root, 'ESC_Id', 'FullESCmodels', 'LFP', 'ATLmodel.mat'), ...
        fullfile(repo_root, 'ESC_Id', 'OMTLIFE8AHC-HP', 'OMTLIFEmodel.mat')}, ...
        'ESCvalidation:MissingDefaultModel', ...
        'No default ATL-family ESC model file was found.');
    raw = load(model_file);
elseif ischar(model_input) || (isstring(model_input) && isscalar(model_input))
    model_file = resolveLocalPath(char(model_input), repo_root);
    raw = load(model_file);
elseif isstruct(model_input)
    raw = model_input;
    model_file = '<struct>';
else
    error('ESCvalidation:UnsupportedModel', ...
        'Unsupported model input of class %s.', class(model_input));
end

model = extractEscModelStruct(raw);
model_name = modelDisplayName(model_file);

required = {'QParam', 'RCParam', 'RParam', 'R0Param', 'MParam', 'M0Param', 'GParam', 'etaParam'};
for idx = 1:numel(required)
    if ~isfield(model, required{idx})
        error('ESCvalidation:IncompleteModel', ...
            'ESC model %s is missing field %s required by simCell.', ...
            model_file, required{idx});
    end
end
end

function model = extractEscModelStruct(raw)
if isfield(raw, 'model')
    model = raw.model;
    return;
end
if isfield(raw, 'nmc30_model')
    model = raw.nmc30_model;
    return;
end

names = fieldnames(raw);
if numel(names) == 1 && isstruct(raw.(names{1}))
    model = raw.(names{1});
    return;
end

error('ESCvalidation:AmbiguousModelStruct', ...
    'Could not infer an ESC model struct from the provided input.');
end

function name = modelDisplayName(model_file)
if strcmp(model_file, '<struct>')
    name = 'struct_model';
    return;
end
[~, name, ext] = fileparts(model_file);
name = [name, ext];
end

function path_out = resolveLocalPath(input_path, repo_root)
if exist(input_path, 'file') == 2
    path_out = input_path;
    return;
end

script_dir = fullfile(repo_root, 'ESC_Id');
candidates = { ...
    fullfile(script_dir, input_path), ...
    fullfile(repo_root, input_path), ...
    fullfile(repo_root, 'Evaluation', input_path), ...
    fullfile(repo_root, 'utility', input_path)};

path_out = input_path;
for idx = 1:numel(candidates)
    if exist(candidates{idx}, 'file') == 2
        path_out = candidates{idx};
        return;
    end
end

error('ESCvalidation:MissingFile', 'File not found: %s', input_path);
end

function file_path = firstExistingFile(candidates, error_id, error_msg)
file_path = '';
for idx = 1:numel(candidates)
    if exist(candidates{idx}, 'file') == 2
        file_path = candidates{idx};
        break;
    end
end
if isempty(file_path)
    searched = sprintf('\n  - %s', candidates{:});
    error(error_id, '%s Searched:%s', error_msg, searched);
end
end

function value = fieldOr(s, field_name, default_value)
if isstruct(s) && isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end

function value = extractVectorField(s, field_names)
value = [];
[raw_value, ~] = extractSignal(s, field_names);
if ~isempty(raw_value)
    value = coerceNumericVector(raw_value, false);
end
end

function value = extractScalarField(s, field_names)
value = [];
[raw_value, ~] = extractSignal(s, field_names);
if ~isempty(raw_value)
    value = coerceNumericScalar(raw_value);
end
end

function z0 = determineInitialSoc(voltage_v, current_a, soc_ref, tc_test, model)
if ~isempty(soc_ref)
    first_idx = find(isfinite(soc_ref), 1, 'first');
    if ~isempty(first_idx)
        z0 = clamp01(double(soc_ref(first_idx)));
        return;
    end
end

Q = abs(getParamESC('QParam', tc_test, model));
rest_idx = find(abs(current_a(:)) <= 0.02 * Q, min(60, numel(current_a)));
if isempty(rest_idx)
    v0 = voltage_v(1);
else
    v0 = median(voltage_v(rest_idx), 'omitnan');
end
z0 = clamp01(double(SOCfromOCVtemp(v0, tc_test, model)));
end

function x = clamp01(x)
x = min(max(x, 0), 1);
end

function profile = loadBusCoreBatteryProfile(profile_file)
if exist(profile_file, 'file') ~= 2
    error('ESCvalidation:MissingProfile', ...
        'Profile file not found: %s', profile_file);
end

raw = load(profile_file);
primary = choosePrimaryNode(raw);

profile = struct();
profile.profile_file = profile_file;
[~, name, ext] = fileparts(profile_file);
profile.profile_name = [name, ext];
profile.signal_paths = struct();

[current_raw, profile.signal_paths.current] = extractSignal(primary, currentAliases());
[voltage_raw, profile.signal_paths.voltage] = extractSignal(primary, measuredVoltageAliases());
[soc_raw, profile.signal_paths.soc] = extractSignal(primary, socAliases());
[temp_raw, profile.signal_paths.temperature] = extractSignal(primary, temperatureAliases());
[capacity_raw, profile.signal_paths.capacity] = extractSignal(primary, ...
    {'capacity_ah', 'capacity', 'qparam', 'nominalcapacityah', 'ratedcapacityah'});

profile.current_a = coerceNumericVector(current_raw, false);
profile.voltage_v = normalizeOptionalSignal(voltage_raw, numel(profile.current_a), 'voltage');
profile.soc_ref = normalizeSocSignal(normalizeOptionalSignal(soc_raw, numel(profile.current_a), 'soc'));
profile.temperature_c = normalizeOptionalSignal(temp_raw, numel(profile.current_a), 'temperature');
profile.detected_capacity_ah = coerceNumericScalar(capacity_raw);

if isempty(profile.current_a)
    error('ESCvalidation:MissingCurrent', ...
        'Could not locate current signal in %s.', profile_file);
end
if isempty(profile.voltage_v)
    error('ESCvalidation:MissingVoltage', ...
        'Could not locate voltage signal in %s.', profile_file);
end

if isa(current_raw, 'timeseries')
    profile.time_s = normalizeTimeVector(current_raw.Time, numel(profile.current_a), 'current.Time');
else
    [time_raw, ~] = extractSignal(primary, timeAliases());
    if isempty(time_raw)
        profile.time_s = (0:numel(profile.current_a)-1).';
    else
        profile.time_s = ensureTimeVector(coerceNumericVector(time_raw, false), numel(profile.current_a));
    end
end
end

function profile = coerceProfileStruct(raw)
primary = choosePrimaryNode(raw);
profile = struct();
profile.profile_name = fieldOr(primary, 'name', 'struct_profile');
profile.profile_file = fieldOr(primary, 'profile_file', '');

[current_raw, ~] = extractSignal(primary, currentAliases());
[voltage_raw, ~] = extractSignal(primary, measuredVoltageAliases());
[soc_raw, ~] = extractSignal(primary, socAliases());
[temp_raw, ~] = extractSignal(primary, temperatureAliases());
[time_raw, ~] = extractSignal(primary, timeAliases());

profile.current_a = coerceNumericVector(current_raw, false);
profile.voltage_v = coerceNumericVector(voltage_raw, false);
profile.soc_ref = normalizeSocSignal(coerceNumericVector(soc_raw, false));
profile.temperature_c = coerceNumericVector(temp_raw, false);

if isempty(profile.current_a)
    profile.current_a = extractVectorField(primary, currentAliases());
end
if isempty(profile.voltage_v)
    profile.voltage_v = extractVectorField(primary, measuredVoltageAliases());
end
if isempty(profile.temperature_c)
    profile.temperature_c = extractVectorField(primary, temperatureAliases());
end

if isempty(time_raw)
    profile.time_s = (0:max(numel(profile.current_a), 1)-1).';
else
    profile.time_s = ensureTimeVector(coerceNumericVector(time_raw, false), numel(profile.current_a));
end
end

function primary = choosePrimaryNode(raw)
names = fieldnames(raw);
if numel(names) == 1 && isstruct(raw.(names{1}))
    primary = raw.(names{1});
else
    primary = raw;
end
end

function [value, path_used] = extractSignal(node, selectors)
[value, path_used] = extractSignalRecursive(node, selectors, '');
end

function [value, path_used] = extractSignalRecursive(node, selectors, path_prefix)
value = [];
path_used = '';

if isa(node, 'timeseries')
    path_used = path_prefix;
    value = node;
    return;
end

if ~isstruct(node)
    return;
end

fields = fieldnames(node);
selector_map = lower(selectors(:));

for idx = 1:numel(fields)
    field_name = fields{idx};
    if any(strcmpi(field_name, selector_map))
        value = node.(field_name);
        path_used = joinPath(path_prefix, field_name);
        return;
    end
end

for idx = 1:numel(fields)
    field_name = fields{idx};
    child = node.(field_name);
    child_path = joinPath(path_prefix, field_name);
    if isstruct(child)
        [value, path_used] = extractSignalRecursive(child, selectors, child_path);
        if ~isempty(path_used)
            return;
        end
    elseif isa(child, 'timeseries') && any(strcmpi(field_name, selector_map))
        value = child;
        path_used = child_path;
        return;
    end
end
end

function path_out = joinPath(path_prefix, field_name)
if isempty(path_prefix)
    path_out = field_name;
else
    path_out = [path_prefix '.', field_name];
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
    error('ESCvalidation:SignalLengthMismatch', ...
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

function value = coerceNumericScalar(raw_value)
value = [];
if isempty(raw_value)
    return;
end
if isa(raw_value, 'timeseries')
    data = coerceTimeseriesData(raw_value, true);
    if isnumeric(data) && isscalar(data) && isfinite(data)
        value = double(data);
    end
    return;
end
if isnumeric(raw_value) && isscalar(raw_value) && isfinite(raw_value)
    value = double(raw_value);
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
    error('ESCvalidation:TimeLengthMismatch', ...
        'Source %s vector has %d samples, expected %d.', signal_name, numel(time_raw), n_expected);
end
time_s = double(time_raw(:) - time_raw(1));
end

function time_s = ensureTimeVector(time_s, n_expected)
time_s = double(time_s(:));
if numel(time_s) ~= n_expected
    error('ESCvalidation:TimeSize', ...
        'Time vector has %d samples, expected %d.', numel(time_s), n_expected);
end
time_s = time_s - time_s(1);
end

function soc = normalizeSocSignal(soc)
if isempty(soc)
    return;
end
soc = soc(:);
if any(abs(soc) > 1.5)
    soc = soc / 100;
end
soc = clamp01(soc);
end

function ts = inferSampleTime(time_s)
time_s = time_s(:);
if numel(time_s) < 2
    ts = 1;
    return;
end

[~, unique_idx] = unique(time_s, 'stable');
time_s = time_s(unique_idx);
dt = diff(time_s);
dt = dt(isfinite(dt) & dt > 0);
if isempty(dt)
    ts = 1;
    return;
end

ts = median(dt);
ts = max(ts, eps);
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

function [current_a, sign_multiplier, sign_source] = orientCurrentToDischargePositive(current_a, time_s, soc_ref, cfg)
current_a = current_a(:);
sign_multiplier = 1;
sign_source = 'assumed_discharge_positive';

if isfield(cfg, 'current_sign') && ~isempty(cfg.current_sign)
    sign_multiplier = sign(double(cfg.current_sign));
    if sign_multiplier == 0
        sign_multiplier = 1;
    end
    current_a = sign_multiplier * current_a;
    sign_source = 'cfg.current_sign';
    return;
end

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
    sign_multiplier = -1;
end
current_a = sign_multiplier * current_a;
sign_source = 'auto_from_soc_trend';
end

function aliases = currentAliases()
aliases = {'current_a', 'current', 'i', 'i_a', 'measured_current_a', 'current_meas_a', ...
    'measuredcurrenta', 'pack_current_a', 'packcurrenta', 'battery_current_a', ...
    'cell_current_a', 'cellcurrenta', 'total_current_a', 'current_vector_a', ...
    'source_current_a'};
end

function aliases = measuredVoltageAliases()
aliases = {'metric_voltage_v', 'metric_voltage', 'source_voltage_v', 'measured_voltage_v', ...
    'terminal_voltage_v', 'pack_voltage_v', 'battery_voltage_v', 'cell_voltage_v', ...
    'voltage_v', 'voltage', 'v', 'measuredvoltagev', 'terminalvoltagev', ...
    'packvoltagev', 'total_voltage_v', 'voltage_vector_v'};
end

function aliases = socAliases()
aliases = {'metric_soc', 'reference_soc', 'soc_true', 'soc_ref', 'soc', ...
    'soc_vector_percent', 'soc_percent', 'soc_pct', 'soc_percentage'};
end

function aliases = temperatureAliases()
aliases = {'temperature_c', 'temperature', 'temp_c', 'temp', 'temperature_degc', ...
    'temp_degc', 'temperature_vector_degc'};
end

function aliases = timeAliases()
aliases = {'time_s', 'time', 't', 'time_sec', 'timestamp_s', 'timestamp', ...
    'timestamps', 'seconds'};
end
