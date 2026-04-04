function identification_results = runDynamicIdentification(cfg)
% runDynamicIdentification Configurable ESC dynamic-identification entry point.
%
% This function is the API-style wrapper around processDynamic. It accepts
% an OCV model plus one or more dynamic-identification datasets, optionally
% filters by temperature, runs processDynamic, saves a light ESC model, and
% stores reusable dynamic-fit metrics/results under data/modelling/derived.
%
% Example:
%   cfg = struct();
%   cfg.run_name = 'ATL20 P25 ESC identification';
%   cfg.ocv_model_input = fullfile('data', 'modelling', 'derived', 'ocv_models', 'atl20', 'ATL20model-ocv-vavgFT.mat');
%   cfg.dynamic_input = fullfile('data', 'modelling', 'processed', 'dynamic', 'atl20');
%   cfg.desired_temperature = 25;
%   cfg.numpoles = 2;
%   cfg.do_hysteresis = true;
%   cfg.output.model_output_file = fullfile('models', 'ATL20model_P25.mat');
%   cfg.output.results_file = fullfile('data', 'modelling', 'derived', 'identification_results', 'atl20', 'ATL20model_P25_identification_results.mat');
%   results = runDynamicIdentification(cfg);

if nargin < 1 || isempty(cfg)
    cfg = defaultDynamicIdentificationConfig();
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

repo_root = fileparts(here);
addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'utility')));
addpath(genpath(fullfile(repo_root, 'ocv_id')));
addpath(genpath(here));

[cfg, paths] = normalizeConfig(cfg, here, repo_root);

ocv_source = loadModelInput(cfg.ocv_model_input);
model_ocv = extractModelStruct(ocv_source);
data = loadDynamicInput(cfg.dynamic_input, cfg);
data = filterDynamicDataByTemperature(data, cfg.desired_temperature);
validateDynamicData(data);

figure_cleanup = [];
if ~cfg.output.enabled_plots
    previous_visibility = get(groot, 'defaultFigureVisible');
    figure_cleanup = onCleanup(@() set(groot, 'defaultFigureVisible', previous_visibility)); %#ok<NASGU>
    set(groot, 'defaultFigureVisible', 'off');
end

model_full = processDynamic(data, model_ocv, cfg.numpoles, cfg.do_hysteresis);
model_light = stripAuxiliaryFields(model_full);
dynamic_validation = computeDynamicModelMetrics(model_light, data, struct( ...
    'enabled_plot', cfg.output.enabled_plots));
ocv_validation = extractOptionalOcvValidation(ocv_source);
if isempty(ocv_validation) && ~isempty(cfg.ocv_validation_input)
    ocv_validation = computeOcvModelMetrics(model_ocv, cfg.ocv_validation_input, cfg.ocv_validation_cfg);
end

identification_results = struct();
identification_results.kind = 'dynamic_identification_results';
identification_results.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
identification_results.name = cfg.run_name;
identification_results.repo_root = repo_root;
identification_results.config = cfg;
identification_results.model_output_file = '';
identification_results.results_file = '';
identification_results.ocv_model_name = resolveModelName(model_ocv);
identification_results.ocv_model_input = cfg.ocv_model_input;
identification_results.dynamic_input = cfg.dynamic_input;
identification_results.selected_temperatures_degC = unique([data.temp]);
identification_results.metrics = summarizeDynamicValidation(dynamic_validation);
identification_results.dynamic_validation = dynamic_validation;
identification_results.ocv_validation = ocv_validation;
identification_results.model = [];

if cfg.output.include_model_struct
    identification_results.model = model_light;
end

if cfg.output.save_model
    model = model_light; %#ok<NASGU>
    save(paths.model_output_file_abs, 'model');
    identification_results.model_output_file = paths.model_output_file_abs;
end

if cfg.output.save_results
    identification_results.results_file = paths.results_file_abs;
    save(paths.results_file_abs, 'identification_results');
end

printSummary(identification_results);

if nargout == 0
    assignin('base', 'dynamicIdentificationResults', identification_results);
end
end

function defaults = defaultDynamicIdentificationConfig()
defaults = struct();
defaults.run_name = 'ESC dynamic identification';
defaults.ocv_model_input = '';
defaults.ocv_validation_input = [];
defaults.ocv_validation_cfg = struct();
defaults.dynamic_input = '';
defaults.desired_temperature = [];
defaults.numpoles = 2;
defaults.do_hysteresis = true;
defaults.dynamic_file_pattern = '*.mat';
defaults.output = struct( ...
    'save_model', true, ...
    'save_results', true, ...
    'enabled_plots', false, ...
    'include_model_struct', false, ...
    'model_output_file', fullfile('models', 'ESCmodel.mat'), ...
    'results_file', fullfile('data', 'modelling', 'derived', 'identification_results', 'misc', 'ESCmodel_identification_results.mat'));
end

function [cfg, paths] = normalizeConfig(cfg, esc_root, repo_root)
defaults = defaultDynamicIdentificationConfig();
cfg = mergeStructDefaults(cfg, defaults);
cfg.output = mergeStructDefaults(fieldOr(cfg, 'output', struct()), defaults.output);

if isempty(cfg.ocv_model_input)
    error('runDynamicIdentification:MissingOCVModel', ...
        'cfg.ocv_model_input is required.');
end
if isempty(cfg.dynamic_input)
    error('runDynamicIdentification:MissingDynamicInput', ...
        'cfg.dynamic_input is required.');
end

if ischar(cfg.ocv_model_input) || (isstring(cfg.ocv_model_input) && isscalar(cfg.ocv_model_input))
    cfg.ocv_model_input = resolveModellingDatasetPath(char(cfg.ocv_model_input), repo_root, 'must_exist', true);
end
if ischar(cfg.dynamic_input) || (isstring(cfg.dynamic_input) && isscalar(cfg.dynamic_input))
    cfg.dynamic_input = resolveModellingDatasetPath(char(cfg.dynamic_input), repo_root, 'must_exist', true);
end
if ischar(cfg.ocv_validation_input) || (isstring(cfg.ocv_validation_input) && isscalar(cfg.ocv_validation_input))
    cfg.ocv_validation_input = resolveModellingDatasetPath(char(cfg.ocv_validation_input), repo_root, 'must_exist', true);
end

paths = struct();
paths.esc_root = esc_root;
paths.repo_root = repo_root;
paths.model_output_file_abs = resolveOutputPath(cfg.output.model_output_file, repo_root);
paths.results_file_abs = resolveModellingDatasetPath( ...
    resolveOutputPath(cfg.output.results_file, repo_root), repo_root, 'must_exist', false);

cfg.output.model_output_file = paths.model_output_file_abs;
cfg.output.results_file = paths.results_file_abs;

ensureParentDir(paths.model_output_file_abs);
ensureParentDir(paths.results_file_abs);
end

function source = loadModelInput(model_input)
if ischar(model_input) || (isstring(model_input) && isscalar(model_input))
    model_path = char(model_input);
    if exist(model_path, 'file') ~= 2
        error('runDynamicIdentification:MissingModelFile', ...
            'OCV model file not found: %s', model_path);
    end
    source = load(model_path);
    return;
end

if isstruct(model_input)
    source = model_input;
    return;
end

error('runDynamicIdentification:UnsupportedModelInput', ...
    'cfg.ocv_model_input must be a file path or a struct.');
end

function model = extractModelStruct(source)
if isfield(source, 'model') && isstruct(source.model)
    model = source.model;
    return;
end

if isstruct(source) && all(isfield(source, {'SOC', 'OCV0', 'OCVrel'}))
    model = source;
    return;
end

names = fieldnames(source);
for idx = 1:numel(names)
    value = source.(names{idx});
    if isstruct(value) && all(isfield(value, {'SOC', 'OCV0', 'OCVrel'}))
        model = value;
        return;
    end
end

error('runDynamicIdentification:MissingModelStruct', ...
    'No ESC-compatible OCV model struct found in cfg.ocv_model_input.');
end

function data = loadDynamicInput(dynamic_input, cfg)
if ischar(dynamic_input) || (isstring(dynamic_input) && isscalar(dynamic_input))
    dynamic_path = char(dynamic_input);
    if exist(dynamic_path, 'dir') == 7
        data = loadDynamicFolder(dynamic_path, cfg);
        return;
    end
    if exist(dynamic_path, 'file') == 2
        data = loadDynamicFile(dynamic_path, cfg.desired_temperature);
        return;
    end
    error('runDynamicIdentification:MissingDynamicInput', ...
        'Dynamic input path not found: %s', dynamic_path);
end

if isstruct(dynamic_input)
    if isfield(dynamic_input, 'DYNData')
        data = normalizeDynDataStruct(dynamic_input.DYNData, cfg.desired_temperature, '');
    else
        data = normalizeLegacyDynamicStruct(dynamic_input, cfg.desired_temperature);
    end
    return;
end

error('runDynamicIdentification:UnsupportedDynamicInput', ...
    'cfg.dynamic_input must be a folder, file path, DYNData struct, or legacy struct array.');
end

function data = loadDynamicFolder(dynamic_dir, cfg)
files = dir(fullfile(dynamic_dir, cfg.dynamic_file_pattern));
files = files(~[files.isdir]);
if isempty(files)
    error('runDynamicIdentification:NoDynamicFiles', ...
        'No dynamic files matching %s were found in %s.', cfg.dynamic_file_pattern, dynamic_dir);
end

data_list = cell(numel(files), 1);
for idx = 1:numel(files)
    data_list{idx} = loadDynamicFile(fullfile(files(idx).folder, files(idx).name), cfg.desired_temperature);
end
data = vertcat(data_list{:});
data = sortDynamicData(data);
end

function data = loadDynamicFile(file_path, desired_temperature)
src = load(file_path);
temp_hint = parseTemperatureFromFilename(file_path);
if isempty(temp_hint) && isnumeric(desired_temperature) && isscalar(desired_temperature)
    temp_hint = desired_temperature;
end

if isfield(src, 'DYNData')
    data = normalizeDynDataStruct(src.DYNData, temp_hint, file_path);
    return;
end

if isstruct(src) && all(isfield(src, {'temp', 'script1', 'script2', 'script3'}))
    data = normalizeLegacyDynamicStruct(src, temp_hint);
    return;
end

names = fieldnames(src);
for idx = 1:numel(names)
    value = src.(names{idx});
    if isstruct(value) && all(isfield(value, {'temp', 'script1', 'script2', 'script3'}))
        data = normalizeLegacyDynamicStruct(value, temp_hint);
        return;
    end
end

error('runDynamicIdentification:MissingDYNData', ...
    'File %s does not contain DYNData or a legacy dynamic struct array.', file_path);
end

function data = normalizeDynDataStruct(dyn_data, temp_hint, source_label)
if isfield(dyn_data, 'temp') && all(~cellfun(@isempty, num2cell([dyn_data.temp])))
    temp_hint = [];
end
if isfield(dyn_data, 'script1') && isfield(dyn_data, 'script2') && isfield(dyn_data, 'script3')
    data = dyn_data;
    if ~isfield(data, 'temp') || isempty([data.temp])
        if isempty(temp_hint)
            if isempty(source_label)
                source_label = 'in-memory DYNData';
            end
            error('runDynamicIdentification:MissingTemperature', ...
                'Dynamic data from %s is missing temp. Use standard *_P25.mat naming or set cfg.desired_temperature.', source_label);
        end
        if numel(data) ~= 1
            error('runDynamicIdentification:MissingTemperatureArray', ...
                'Cannot assign one temperature hint to multiple DYNData entries.');
        end
        data.temp = temp_hint;
    end
    data = data(:);
    return;
end

error('runDynamicIdentification:BadDYNData', ...
    'DYNData must contain script1, script2, and script3.');
end

function data = normalizeLegacyDynamicStruct(data, temp_hint)
if ~isstruct(data) || ~all(isfield(data, {'script1', 'script2', 'script3'}))
    error('runDynamicIdentification:BadLegacyData', ...
        'Dynamic structs must contain temp, script1, script2, and script3.');
end

data = data(:);
has_temp = isfield(data, 'temp') && all(arrayfun(@(s) ~isempty(s.temp), data));
if ~has_temp
    if isempty(temp_hint)
        error('runDynamicIdentification:MissingTemperature', ...
            'Dynamic structs are missing temp. Use standard *_P25.mat naming or set cfg.desired_temperature.');
    end
    if numel(data) ~= 1
        error('runDynamicIdentification:MissingTemperatureArray', ...
            'Cannot assign one temperature hint to multiple dynamic struct entries.');
    end
    data.temp = temp_hint;
end
end

function data = filterDynamicDataByTemperature(data, desired_temperature)
if isempty(desired_temperature)
    return;
end

temps = [data.temp];
keep = ismember(temps, desired_temperature);
if ~any(keep)
    error('runDynamicIdentification:TemperatureSelection', ...
        'No dynamic datasets matched cfg.desired_temperature = %s.', mat2str(desired_temperature));
end
data = data(keep);
data = sortDynamicData(data);
end

function validateDynamicData(data)
if isempty(data)
    error('runDynamicIdentification:NoDynamicData', ...
        'No dynamic data remained after normalization/filtering.');
end
if ~any([data.temp] == 25)
    error('runDynamicIdentification:Missing25degC', ...
        'processDynamic requires at least one 25 degC dataset.');
end
end

function data = sortDynamicData(data)
[~, order] = sort([data.temp], 'ascend');
data = data(order);
end

function ocv_validation = extractOptionalOcvValidation(source)
ocv_validation = [];
if isstruct(source) && isfield(source, 'ocv_validation') && isstruct(source.ocv_validation)
    ocv_validation = source.ocv_validation;
end
end

function model_light = stripAuxiliaryFields(model_full)
model_light = model_full;
if isfield(model_light, 'metrics')
    model_light = rmfield(model_light, 'metrics');
end
end

function metrics = summarizeDynamicValidation(dynamic_validation)
summary_table = dynamic_validation.summary_table;
metrics = struct();
metrics.mean_rmse_mv = mean(summary_table.voltage_rmse_mv, 'omitnan');
metrics.max_rmse_mv = max(summary_table.voltage_rmse_mv, [], 'omitnan');
metrics.mean_error_mv = mean(summary_table.voltage_mean_error_mv, 'omitnan');
metrics.max_abs_error_mv = max(summary_table.voltage_max_abs_error_mv, [], 'omitnan');
metrics.case_count = height(summary_table);
end

function name = resolveModelName(model)
name = '';
if isfield(model, 'name') && ~isempty(model.name)
    name = char(model.name);
end
end

function printSummary(results)
fprintf('\n');
fprintf('============================================================\n');
fprintf('  %s\n', results.name);
fprintf('============================================================\n');
fprintf('OCV model        : %s\n', stringifyInput(results.ocv_model_input));
fprintf('Dynamic input    : %s\n', stringifyInput(results.dynamic_input));
fprintf('Temperatures (C) : %s\n', mat2str(results.selected_temperatures_degC));
if ~isempty(results.model_output_file)
    fprintf('Model file       : %s\n', results.model_output_file);
end
if ~isempty(results.results_file)
    fprintf('Results file     : %s\n', results.results_file);
end
fprintf('Mean RMSE        : %.2f mV\n', results.metrics.mean_rmse_mv);
fprintf('Mean ME          : %.2f mV\n', results.metrics.mean_error_mv);
fprintf('\n');
end

function text = stringifyInput(value)
if ischar(value)
    text = value;
elseif isstring(value) && isscalar(value)
    text = char(value);
elseif isstruct(value)
    text = '[struct input]';
else
    text = '[in-memory input]';
end
end

function out = mergeStructDefaults(in, defaults)
out = defaults;
if isempty(in)
    return;
end
names = fieldnames(in);
for idx = 1:numel(names)
    out.(names{idx}) = in.(names{idx});
end
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end

function path_out = resolveAbsolutePath(path_in, repo_root)
if isempty(path_in)
    path_out = path_in;
    return;
end
if isAbsolutePath(path_in)
    path_out = path_in;
    return;
end
path_out = fullfile(repo_root, path_in);
end

function path_out = resolveOutputPath(path_in, repo_root)
if isempty(path_in)
    path_out = '';
    return;
end
if isAbsolutePath(path_in)
    path_out = path_in;
else
    path_out = fullfile(repo_root, path_in);
end
end

function tf = isAbsolutePath(path_in)
path_in = char(path_in);
tf = numel(path_in) >= 2 && path_in(2) == ':';
end

function ensureParentDir(file_path)
if isempty(file_path)
    return;
end
parent_dir = fileparts(file_path);
if ~isempty(parent_dir) && exist(parent_dir, 'dir') ~= 7
    mkdir(parent_dir);
end
end

function temp_degC = parseTemperatureFromFilename(file_path)
temp_degC = [];
[~, name, ext] = fileparts(file_path);
tokens = regexp([name ext], '_(N|P)(\d+)\.mat$', 'tokens', 'once');
if isempty(tokens)
    return;
end
temp_degC = str2double(tokens{2});
if strcmpi(tokens{1}, 'N')
    temp_degC = -temp_degC;
end
end
