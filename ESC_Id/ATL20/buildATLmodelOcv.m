% script buildATLmodelOcv.m
%   Loads ATL OCV test files from data/Modelling/OCV_Files/ATL20/ATL_OCV,
%   runs the legacy ESC_Id/processOCV, and saves ATLmodel-ocv.mat to
%   ESC_Id/OCV_models.

clearvars
close all
clc

script_dir = fileparts(mfilename('fullpath'));
esc_root = fileparts(script_dir);
repo_root = fileparts(esc_root);
ocv_data_dir = fullfile(repo_root, 'data', 'Modelling', 'OCV_Files', 'ATL20', 'ATL_OCV');
output_dir = fullfile(esc_root, 'OCV_models');
output_file = fullfile(output_dir, 'ATLmodel-ocv.mat');

addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'utility')));
addpath(genpath(esc_root));

temps_degC = [-25 -15 -5 5 15 25 35 45];
data_prefix = 'ATL';
model_name = 'ATL';
min_v = 2.0;
max_v = 3.75;
save_plots = false;

if exist(ocv_data_dir, 'dir') ~= 7
    error('buildATLmodelOcv:MissingFolder', ...
        'OCV data folder not found: %s', ocv_data_dir);
end
if exist(output_dir, 'dir') ~= 7
    mkdir(output_dir);
end

if ~save_plots
    previous_visibility = get(groot, 'defaultFigureVisible');
    restore_visibility = onCleanup(@() set(groot, 'defaultFigureVisible', previous_visibility)); %#ok<NASGU>
    set(groot, 'defaultFigureVisible', 'off');
end

fprintf('\n');
fprintf('============================================================\n');
fprintf('  Build ATL OCV model with legacy processOCV\n');
fprintf('============================================================\n\n');
fprintf('Source folder: %s\n', ocv_data_dir);
fprintf('Output file : %s\n\n', output_file);

data = repmat(struct( ...
    'temp', [], ...
    'script1', [], ...
    'script2', [], ...
    'script3', [], ...
    'script4', []), numel(temps_degC), 1);

for k = 1:numel(temps_degC)
    tc = temps_degC(k);
    if tc < 0
        filename = fullfile(ocv_data_dir, sprintf('%s_OCV_N%02d.mat', data_prefix, abs(tc)));
    else
        filename = fullfile(ocv_data_dir, sprintf('%s_OCV_P%02d.mat', data_prefix, tc));
    end

    if ~exist(filename, 'file')
        error('buildATLmodelOcv:MissingFile', ...
            'Required OCV file not found: %s', filename);
    end

    src = load(filename, 'OCVData');
    if ~isfield(src, 'OCVData')
        error('buildATLmodelOcv:MissingOCVData', ...
            'File does not contain OCVData: %s', filename);
    end

    required_scripts = {'script1', 'script2', 'script3', 'script4'};
    for n = 1:numel(required_scripts)
        if ~isfield(src.OCVData, required_scripts{n})
            error('buildATLmodelOcv:MissingScript', ...
                'File %s is missing OCVData.%s', filename, required_scripts{n});
        end
    end

    data(k).temp = tc;
    data(k).script1 = src.OCVData.script1;
    data(k).script2 = src.OCVData.script2;
    data(k).script3 = src.OCVData.script3;
    data(k).script4 = src.OCVData.script4;

    fprintf('Loaded %s\n', filename);
end

model = processOCV(data, model_name, min_v, max_v, save_plots);
ocv_validation = computeOcvModelMetrics(model, data, struct( ...
    'cell_id', model_name, ...
    'min_v', min_v, ...
    'max_v', max_v, ...
    'ocv_method', 'resistanceBlend'));
model.metrics.ocv = ocv_validation.models(1).metrics;
model.metrics.ocv_summary_table = ocv_validation.models(1).summary_table;

save(output_file, 'model', 'ocv_validation');

fprintf('\nSaved ATL OCV model to:\n  %s\n', output_file);
fprintf('Stored fields: %s\n', strjoin(fieldnames(model).', ', '));
