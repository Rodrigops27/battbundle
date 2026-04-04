function identification_results = runOcvIdentification(cfg)
% runOcvIdentification Configurable OCV-identification entry point.
%
% This function is the API-style wrapper around the generic OCV engines in
% ocv_id. It loads OCV test data, chooses one engine, optionally restricts
% the output to one selected temperature, computes OCV-fit metrics, and
% saves the intermediate OCV model under data/modelling/derived/ocv_models.
% All OCV engines use the shared smoothdiff-based branch preprocessing in
% prepareOcvBranches.m before estimator-specific processing.
%
% TODO:
%   The current OCV temperature model is still the legacy linear form
%   OCV(SOC,T) = OCV0(SOC) + T*OCVrel(SOC). This may require a better
%   expression, preferably using Kelvin to avoid sign handling and to make
%   the temperature offset explicit, for example:
%     OCV(SOC,T) = OCV(SOC) + (T - 298.15)*dOCV/dT(SOC)
%
% Supported engines:
%   - middleCurve      -> middleOCV (default)
%   - voltageAverage   -> VavgProcessOCV
%   - socAverage       -> SOCavgOCV
%   - diagAverage      -> DiagProcessOCV
%   - resistanceBlend  -> processOCV
%
% Example:
%   cfg = struct();
%   cfg.run_name = 'ATL20 OCV identification';
%   cfg.ocv_data_input = fullfile('data', 'modelling', 'processed', 'ocv', 'atl20');
%   cfg.data_prefix = 'ATL';
%   cfg.cell_id = 'ATL20';
%   cfg.engine = 'middleCurve';
%   cfg.temperature_scope = 'single';
%   cfg.desired_temperature = 25;
%   cfg.reference_ocv_method = 'middleCurve';
%   cfg.output.model_output_file = fullfile('data', 'modelling', 'derived', 'ocv_models', 'atl20', 'ATL20model-ocv-middleCurve.mat');
%   results = runOcvIdentification(cfg);

if nargin < 1 || isempty(cfg)
    cfg = defaultOcvIdentificationConfig();
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
addpath(genpath(here));

[cfg, paths] = normalizeConfig(cfg, here, repo_root);
[all_data, available_temps] = loadOcvInputData(cfg.ocv_data_input, cfg);
[requested_temps, build_temps] = resolveRequestedTemperatures(available_temps, cfg);
data = selectOcvDataByTemperature(all_data, build_temps);

figure_cleanup = [];
if ~(cfg.save_plots || cfg.debug_plots)
    previous_visibility = get(groot, 'defaultFigureVisible');
    figure_cleanup = onCleanup(@() set(groot, 'defaultFigureVisible', previous_visibility)); %#ok<NASGU>
    set(groot, 'defaultFigureVisible', 'off');
end

model = runOcvEngine(data, cfg);
if numel(requested_temps) == 1
    model = collapseModelToSingleTemperature(model, requested_temps(1), cfg.min_v, cfg.max_v);
end

metric_cfg = struct( ...
    'cell_id', cfg.cell_id, ...
    'data_prefix', cfg.data_prefix, ...
    'temps_degC', requested_temps, ...
    'min_v', cfg.min_v, ...
    'max_v', cfg.max_v, ...
    'ocv_method', cfg.reference_ocv_method);
% Metrics use a common reconstructed OCV reference. By default this is the
% per-temperature middle-curve reconstruction, not the candidate engine's
% own OCV0/OCVrel regression output.
ocv_validation = computeOcvModelMetrics(model, selectOcvDataByTemperature(all_data, requested_temps), metric_cfg);
model.metrics.ocv = ocv_validation.models(1).metrics;
model.metrics.ocv_summary_table = ocv_validation.models(1).summary_table;

identification_results = struct();
identification_results.kind = 'ocv_identification_results';
identification_results.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
identification_results.name = cfg.run_name;
identification_results.repo_root = normalizeStoredPath(repo_root, repo_root);
identification_results.config = sanitizeConfigForStorage(cfg, repo_root);
identification_results.available_temperatures_degC = available_temps;
identification_results.requested_temperatures_degC = requested_temps;
identification_results.build_temperatures_degC = build_temps;
identification_results.ocv_data_input = normalizeStoredInput(cfg.ocv_data_input, repo_root);
identification_results.model_output_file = '';
identification_results.results_file = '';
identification_results.model = [];
identification_results.ocv_validation = ocv_validation;
identification_results.metrics = ocv_validation.models(1).metrics;

if cfg.output.include_model_struct
    identification_results.model = model;
end

if cfg.output.save_model
    save(paths.model_output_file_abs, 'model', 'ocv_validation');
    identification_results.model_output_file = normalizeStoredPath(paths.model_output_file_abs, repo_root);
end

if cfg.output.save_results
    identification_results.results_file = normalizeStoredPath(paths.results_file_abs, repo_root);
    save(paths.results_file_abs, 'identification_results');
end

printSummary(identification_results);

if nargout == 0
    assignin('base', 'ocvIdentificationResults', identification_results);
end
end

function defaults = defaultOcvIdentificationConfig()
defaults = struct();
defaults.run_name = 'OCV identification';
defaults.ocv_data_input = '';
defaults.data_prefix = 'ATL';
defaults.cell_id = 'ATL';
defaults.engine = 'middleCurve';
defaults.diag_type = 'useAvg';
defaults.reference_ocv_method = 'middleCurve';
defaults.temperature_scope = 'all';
defaults.desired_temperature = [];
defaults.min_v = 2.0;
defaults.max_v = 3.75;
defaults.save_plots = false;
defaults.debug_plots = false;
defaults.output = struct( ...
    'save_model', true, ...
    'save_results', false, ...
    'include_model_struct', false, ...
    'model_output_file', fullfile('data', 'modelling', 'derived', 'ocv_models', 'misc', 'OCVmodel-ocv.mat'), ...
    'results_file', fullfile('data', 'modelling', 'derived', 'identification_results', 'misc', 'OCV_identification_results.mat'));
end

function [cfg, paths] = normalizeConfig(cfg, ocv_root, repo_root)
defaults = defaultOcvIdentificationConfig();
cfg = mergeStructDefaults(cfg, defaults);
cfg.output = mergeStructDefaults(fieldOr(cfg, 'output', struct()), defaults.output);
cfg.engine = normalizeEngineName(cfg.engine);
cfg.reference_ocv_method = normalizeReferenceOcvMethod( ...
    fieldOr(cfg, 'reference_ocv_method', fieldOr(cfg, 'metric_method', defaults.reference_ocv_method)));
cfg.temperature_scope = lower(char(fieldOr(cfg, 'temperature_scope', 'all')));

if isempty(cfg.ocv_data_input)
    error('runOcvIdentification:MissingOcvData', ...
        'cfg.ocv_data_input is required.');
end

if ischar(cfg.ocv_data_input) || (isstring(cfg.ocv_data_input) && isscalar(cfg.ocv_data_input))
    cfg.ocv_data_input = resolveModellingDatasetPath(char(cfg.ocv_data_input), repo_root, 'must_exist', true);
end

paths = struct();
paths.ocv_root = ocv_root;
paths.repo_root = repo_root;
paths.model_output_file_abs = resolveModellingDatasetPath( ...
    resolveOutputPath(cfg.output.model_output_file, repo_root), repo_root, 'must_exist', false);
paths.results_file_abs = resolveModellingDatasetPath( ...
    resolveOutputPath(cfg.output.results_file, repo_root), repo_root, 'must_exist', false);

cfg.output.model_output_file = paths.model_output_file_abs;
cfg.output.results_file = paths.results_file_abs;

ensureParentDir(paths.model_output_file_abs);
ensureParentDir(paths.results_file_abs);
end

function engine = normalizeEngineName(engine_input)
key = regexprep(lower(char(engine_input)), '[^a-z0-9]', '');
switch key
    case {'voltageaverage', 'vavg', 'vavgprocessocv'}
        engine = 'voltageAverage';
    case {'socaverage', 'socavg', 'socavgcov', 'socavgocv'}
        engine = 'socAverage';
    case {'middlecurve', 'middle', 'middleocv', 'middledtw'}
        engine = 'middleCurve';
    case {'diagaverage', 'diagonalaverage', 'diag', 'diagprocessocv'}
        engine = 'diagAverage';
    case {'resistanceblend', 'legacy', 'processocv'}
        engine = 'resistanceBlend';
    otherwise
        error('runOcvIdentification:UnsupportedEngine', ...
            'Unsupported OCV engine "%s".', char(engine_input));
end
end

function method = normalizeReferenceOcvMethod(method_input)
key = regexprep(lower(char(method_input)), '[^a-z0-9]', '');
switch key
    case {'voltageaverage', 'vavg', 'vavgprocessocv'}
        method = 'voltageAverage';
    case {'socaverage', 'socavg', 'socavgcov', 'socavgocv'}
        method = 'socAverage';
    case {'middlecurve', 'middle', 'middleocv', 'middledtw'}
        method = 'middleCurve';
    case {'diagaverage', 'diagonalaverage', 'diag', 'diagprocessocv'}
        method = 'diagAverage';
    case {'resistanceblend', 'legacy', 'processocv'}
        method = 'resistanceBlend';
    otherwise
        error('runOcvIdentification:UnsupportedReferenceMethod', ...
            'Unsupported OCV reference method "%s".', char(method_input));
end
end

function [data, available_temps] = loadOcvInputData(data_input, cfg)
if isstruct(data_input)
    data = data_input(:);
    available_temps = sort(unique([data.temp]), 'ascend');
    return;
end

if ischar(data_input) || (isstring(data_input) && isscalar(data_input))
    data_dir = char(data_input);
    if exist(data_dir, 'dir') ~= 7
        error('runOcvIdentification:MissingOcvDir', ...
            'OCV data folder not found: %s', data_dir);
    end
    [data, available_temps] = loadOcvDataFromDir(data_dir, cfg.data_prefix);
    return;
end

error('runOcvIdentification:UnsupportedOcvInput', ...
    'cfg.ocv_data_input must be a folder or an OCV struct array.');
end

function [data, temps_degC] = loadOcvDataFromDir(data_dir, data_prefix)
pattern = sprintf('%s_OCV_*.mat', data_prefix);
files = dir(fullfile(data_dir, pattern));
files = files(~[files.isdir]);
if isempty(files)
    error('runOcvIdentification:NoOcvFiles', ...
        'No OCV files matching %s were found in %s.', pattern, data_dir);
end

entries = cell(numel(files), 1);
temps_degC = NaN(numel(files), 1);
for idx = 1:numel(files)
    file_path = fullfile(files(idx).folder, files(idx).name);
    temp_degC = parseTemperatureFromFilename(files(idx).name);
    if isempty(temp_degC)
        error('runOcvIdentification:BadFilename', ...
            'Unexpected OCV filename format: %s', files(idx).name);
    end

    src = load(file_path, 'OCVData');
    if ~isfield(src, 'OCVData')
        error('runOcvIdentification:MissingOcvData', ...
            'File %s does not contain OCVData.', file_path);
    end
    required_scripts = {'script1', 'script2', 'script3', 'script4'};
    for script_idx = 1:numel(required_scripts)
        if ~isfield(src.OCVData, required_scripts{script_idx})
            error('runOcvIdentification:MissingScript', ...
                'File %s is missing OCVData.%s.', file_path, required_scripts{script_idx});
        end
    end

    entry = struct();
    entry.temp = temp_degC;
    entry.source_file = file_path;
    entry.script1 = src.OCVData.script1;
    entry.script2 = src.OCVData.script2;
    entry.script3 = src.OCVData.script3;
    entry.script4 = src.OCVData.script4;
    entries{idx} = entry;
    temps_degC(idx) = temp_degC;
end

[temps_degC, order] = sort(temps_degC, 'ascend');
data = vertcat(entries{order});
end

function [requested_temps, build_temps] = resolveRequestedTemperatures(available_temps, cfg)
switch cfg.temperature_scope
    case 'all'
        requested_temps = available_temps(:).';
    case 'single'
        if isempty(cfg.desired_temperature) || ~isscalar(cfg.desired_temperature)
            error('runOcvIdentification:BadDesiredTemperature', ...
                'cfg.desired_temperature must be a scalar when cfg.temperature_scope = ''single''.');
        end
        requested_temps = cfg.desired_temperature;
    case 'selected'
        if isempty(cfg.desired_temperature)
            error('runOcvIdentification:BadDesiredTemperature', ...
                'cfg.desired_temperature must be provided when cfg.temperature_scope = ''selected''.');
        end
        requested_temps = unique(cfg.desired_temperature(:).', 'stable');
    otherwise
        error('runOcvIdentification:BadTemperatureScope', ...
            'Unsupported cfg.temperature_scope "%s".', cfg.temperature_scope);
end

missing = setdiff(requested_temps, available_temps);
if ~isempty(missing)
    error('runOcvIdentification:UnavailableTemperature', ...
        'Requested OCV temperatures not found: %s.', mat2str(missing));
end

build_temps = requested_temps;
if ~ismember(25, build_temps)
    if ~ismember(25, available_temps)
        error('runOcvIdentification:Missing25degC', ...
            'The selected OCV build requires a 25 degC dataset, but none was found.');
    end
    build_temps = unique([25, build_temps], 'stable');
end
build_temps = sort(build_temps, 'ascend');
requested_temps = sort(requested_temps, 'ascend');
end

function data = selectOcvDataByTemperature(data, temps_degC)
keep = ismember([data.temp], temps_degC);
data = data(keep);
[~, order] = sort([data.temp], 'ascend');
data = data(order);
end

function model = runOcvEngine(data, cfg)
switch cfg.engine
    case 'voltageAverage'
        model = VavgProcessOCV(data, cfg.cell_id, cfg.min_v, cfg.max_v, cfg.save_plots, cfg.debug_plots);
    case 'socAverage'
        model = SOCavgOCV(data, cfg.cell_id, cfg.min_v, cfg.max_v, cfg.save_plots, cfg.debug_plots);
    case 'middleCurve'
        model = middleOCV(data, cfg.cell_id, cfg.min_v, cfg.max_v, cfg.save_plots, cfg.debug_plots);
    case 'diagAverage'
        model = DiagProcessOCV(data, cfg.cell_id, cfg.min_v, cfg.max_v, cfg.save_plots, cfg.debug_plots, cfg.diag_type);
    case 'resistanceBlend'
        model = processOCV(data, cfg.cell_id, cfg.min_v, cfg.max_v, cfg.save_plots);
    otherwise
        error('runOcvIdentification:UnsupportedEngine', ...
            'Unsupported OCV engine "%s".', cfg.engine);
end
end

function model = collapseModelToSingleTemperature(model, temp_degC, min_v, max_v)
soc_grid = model.SOC(:);
ocv_at_temp = model.OCV0(:) + temp_degC * model.OCVrel(:);
model.temps = temp_degC;
model.OCV0 = ocv_at_temp;
model.OCVrel = zeros(size(ocv_at_temp));

[ocv_unique, unique_idx] = unique(ocv_at_temp, 'stable');
soc_unique = soc_grid(unique_idx);
model.OCV = linspace(min_v - 0.01, max_v + 0.01, 201).';
model.SOC0 = interp1(ocv_unique, soc_unique, model.OCV, 'linear', 'extrap');
model.SOCrel = zeros(size(model.OCV));
end

function printSummary(results)
fprintf('\n');
fprintf('============================================================\n');
fprintf('  %s\n', results.name);
fprintf('============================================================\n');
fprintf('OCV input        : %s\n', stringifyInput(results.ocv_data_input));
fprintf('Requested temps  : %s\n', mat2str(results.requested_temperatures_degC));
fprintf('Build temps      : %s\n', mat2str(results.build_temperatures_degC));
fprintf('Mean RMSE        : %.2f mV\n', results.metrics.mean_rmse_mv);
fprintf('Mean ME          : %.2f mV\n', results.metrics.mean_error_mv);
if ~isempty(results.model_output_file)
    fprintf('Model file       : %s\n', results.model_output_file);
end
if ~isempty(results.results_file)
    fprintf('Results file     : %s\n', results.results_file);
end
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

function cfg_out = sanitizeConfigForStorage(cfg_in, repo_root)
cfg_out = cfg_in;
cfg_out.ocv_data_input = normalizeStoredInput(fieldOr(cfg_in, 'ocv_data_input', ''), repo_root);
if isfield(cfg_in, 'output')
    cfg_out.output = cfg_in.output;
    cfg_out.output.model_output_file = normalizeStoredPath(fieldOr(cfg_in.output, 'model_output_file', ''), repo_root);
    cfg_out.output.results_file = normalizeStoredPath(fieldOr(cfg_in.output, 'results_file', ''), repo_root);
end
end

function value_out = normalizeStoredInput(value_in, repo_root)
if ischar(value_in) || (isstring(value_in) && isscalar(value_in))
    value_out = normalizeStoredPath(char(value_in), repo_root);
else
    value_out = value_in;
end
end

function path_out = normalizeStoredPath(path_in, repo_root)
if isempty(path_in)
    path_out = '';
    return;
end

path_out = strrep(char(path_in), '\', '/');
path_out = regexprep(path_out, '/+', '/');
repo_root = strrep(char(repo_root), '\', '/');
repo_root = regexprep(repo_root, '/+', '/');
repo_prefix = [repo_root '/'];
if strcmpi(path_out, repo_root)
    path_out = '.';
elseif strncmpi(path_out, repo_prefix, numel(repo_prefix))
    path_out = path_out(numel(repo_prefix) + 1:end);
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

function temp_degC = parseTemperatureFromFilename(filename)
temp_degC = [];
tokens = regexp(filename, '_OCV_(N|P)(\d+)\.mat$', 'tokens', 'once');
if isempty(tokens)
    return;
end
temp_degC = str2double(tokens{2});
if strcmpi(tokens{1}, 'N')
    temp_degC = -temp_degC;
end
end
