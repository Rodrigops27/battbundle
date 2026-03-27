% script buildATLmodel.m
%   Builds the full ATL ESC model from measured ATL dynamic data using the
%   legacy ATL OCV model, saves a light parameter-only model to models/,
%   and keeps OCV plus dynamic validation results in ESC_Id/results.

clearvars
close all
clc

script_dir = fileparts(mfilename('fullpath'));
esc_root = fileparts(script_dir);
repo_root = fileparts(esc_root);

ocv_file = fullfile(esc_root, 'OCV_models', 'ATLmodel-ocv.mat');
dyn_data_dir = fullfile(repo_root, 'data', 'Modelling', 'DYN_Files', 'ATL_DYN');
model_output_file = fullfile(repo_root, 'models', 'ATLmodel.mat');
results_file = fullfile(esc_root, 'results', 'ATLmodel_identification_results.mat');

addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'utility')));
addpath(genpath(esc_root));

numpoles = 2;
do_hysteresis = 1;
enabled_plots = false;

if exist(ocv_file, 'file') ~= 2
    error('buildATLmodel:MissingOcvModel', ...
        'OCV model not found: %s\nRun buildATLmodelOcv.m first.', ocv_file);
end
if exist(dyn_data_dir, 'dir') ~= 7
    error('buildATLmodel:MissingDynFolder', ...
        'Dynamic data folder not found: %s', dyn_data_dir);
end

results_dir = fileparts(results_file);
if exist(results_dir, 'dir') ~= 7
    mkdir(results_dir);
end

if ~enabled_plots
    previous_visibility = get(groot, 'defaultFigureVisible');
    restore_visibility = onCleanup(@() set(groot, 'defaultFigureVisible', previous_visibility)); %#ok<NASGU>
    set(groot, 'defaultFigureVisible', 'off');
end

fprintf('\n');
fprintf('============================================================\n');
fprintf('  Build ATL full ESC model with processDynamic\n');
fprintf('============================================================\n\n');
fprintf('OCV model  : %s\n', ocv_file);
fprintf('DYN folder : %s\n', dyn_data_dir);
fprintf('Model file : %s\n', model_output_file);
fprintf('Results    : %s\n\n', results_file);

ocv_src = load(ocv_file);
model_ocv = extractModelStruct(ocv_src);
ocv_validation = extractOcvValidation(ocv_src, model_ocv, repo_root);

data = loadAtlDynData(dyn_data_dir);
fprintf('Loaded %d ATL DYN file(s)\n', numel(data));

model_full = processDynamic(data, model_ocv, numpoles, do_hysteresis);
model_light = stripAuxiliaryFields(model_full);

model = model_light; %#ok<NASGU>
save(model_output_file, 'model');
dynamic_validation = computeDynamicModelMetrics(model_output_file, data, struct( ...
    'enabled_plot', false));

build_results = struct();
build_results.name = 'ATL ESC identification results';
build_results.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
build_results.model_output_file = model_output_file;
build_results.ocv_file = ocv_file;
build_results.dyn_data_dir = dyn_data_dir;
build_results.config = struct( ...
    'numpoles', numpoles, ...
    'do_hysteresis', do_hysteresis, ...
    'enabled_plots', enabled_plots);
build_results.metrics = struct( ...
    'ocv', ocv_validation.models(1).metrics, ...
    'dynamic', summarizeDynamicValidation(dynamic_validation));
build_results.ocv_validation = ocv_validation;
build_results.dynamic_validation = dynamic_validation;

save(results_file, 'build_results');

fprintf('\nSaved light ATL ESC model to:\n  %s\n', model_output_file);
fprintf('Saved ATL validation results to:\n  %s\n', results_file);
fprintf('Dynamic mean RMSE: %.2f mV\n', build_results.metrics.dynamic.mean_rmse_mv);
fprintf('Dynamic mean ME  : %.2f mV\n', build_results.metrics.dynamic.mean_error_mv);

function data = loadAtlDynData(dyn_data_dir)
files = dir(fullfile(dyn_data_dir, 'ATL_DYN_*.mat'));
if isempty(files)
    error('buildATLmodel:NoDynFiles', ...
        'No ATL DYN files found in %s', dyn_data_dir);
end

data = repmat(struct( ...
    'temp', [], ...
    'script1', [], ...
    'script2', [], ...
    'script3', []), numel(files), 1);
temps = NaN(numel(files), 1);

for idx = 1:numel(files)
    filename = files(idx).name;
    tokens = regexp(filename, '^ATL_DYN_(\d+)_(N|P)(\d+)\.mat$', 'tokens', 'once');
    if isempty(tokens)
        error('buildATLmodel:BadFilename', ...
            'Unexpected ATL DYN filename format: %s', filename);
    end

    temp_degC = str2double(tokens{3});
    if strcmpi(tokens{2}, 'N')
        temp_degC = -temp_degC;
    end

    src = load(fullfile(files(idx).folder, filename), 'DYNData');
    if ~isfield(src, 'DYNData')
        error('buildATLmodel:MissingDYNData', ...
            'File %s does not contain DYNData.', filename);
    end

    data(idx).temp = temp_degC;
    data(idx).script1 = src.DYNData.script1;
    data(idx).script2 = src.DYNData.script2;
    data(idx).script3 = src.DYNData.script3;
    temps(idx) = temp_degC;
end

[~, order] = sort(temps, 'ascend');
data = data(order);
end

function model = extractModelStruct(src)
if isfield(src, 'model') && isstruct(src.model)
    model = src.model;
    return;
end

names = fieldnames(src);
for idx = 1:numel(names)
    value = src.(names{idx});
    if isstruct(value) && all(isfield(value, {'SOC', 'OCV0', 'OCVrel'}))
        model = value;
        return;
    end
end

error('buildATLmodel:MissingModelStruct', ...
    'No OCV model struct found in loaded OCV file.');
end

function ocv_validation = extractOcvValidation(src, model_ocv, repo_root)
if isfield(src, 'ocv_validation') && isstruct(src.ocv_validation)
    ocv_validation = src.ocv_validation;
    return;
end

ocv_validation = computeOcvModelMetrics(model_ocv, ...
    fullfile(repo_root, 'data', 'Modelling', 'OCV_Files', 'ATL20', 'ATL_OCV'), ...
    struct( ...
        'cell_id', 'ATL', ...
        'data_prefix', 'ATL', ...
        'min_v', 2.0, ...
        'max_v', 3.75, ...
        'ocv_method', 'resistanceBlend'));
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
