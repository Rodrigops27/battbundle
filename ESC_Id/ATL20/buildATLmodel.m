% script buildATLmodel.m
%   Builds the full ATL ESC model from measured ATL dynamic data using the
%   legacy ATL OCV model. This is a chemistry-specific wrapper around
%   ESC_Id/runDynamicIdentification.m.

close all
clc

script_dir = fileparts(mfilename('fullpath'));
esc_root = fileparts(script_dir);
repo_root = fileparts(esc_root);

if ~exist('ocv_file', 'var') || isempty(ocv_file)
    ocv_file = fullfile(esc_root, 'OCV_models', 'ATLmodel-ocv.mat');
end
if ~exist('dyn_data_dir', 'var') || isempty(dyn_data_dir)
    dyn_data_dir = fullfile(repo_root, 'data', 'Modelling', 'DYN_Files', 'ATL_DYN');
end
if ~exist('desired_temperature', 'var')
    desired_temperature = [];
end
if ~exist('numpoles', 'var') || isempty(numpoles)
    numpoles = 2;
end
if ~exist('do_hysteresis', 'var') || isempty(do_hysteresis)
    do_hysteresis = true;
end
if ~exist('enabled_plots', 'var') || isempty(enabled_plots)
    enabled_plots = false;
end
if ~exist('model_output_file', 'var') || isempty(model_output_file)
    model_output_file = fullfile(repo_root, 'models', 'ATLmodel.mat');
end
if ~exist('results_file', 'var') || isempty(results_file)
    results_file = fullfile(esc_root, 'results', 'ATLmodel_identification_results.mat');
end

cfg = struct();
cfg.run_name = 'ATL ESC identification results';
cfg.ocv_model_input = ocv_file;
cfg.ocv_validation_input = fullfile(repo_root, 'data', 'Modelling', 'OCV_Files', 'ATL20', 'ATL_OCV');
cfg.ocv_validation_cfg = struct( ...
    'cell_id', 'ATL', ...
    'data_prefix', 'ATL', ...
    'min_v', 2.0, ...
    'max_v', 3.75, ...
    'ocv_method', 'resistanceBlend');
cfg.dynamic_input = dyn_data_dir;
cfg.desired_temperature = desired_temperature;
cfg.numpoles = numpoles;
cfg.do_hysteresis = do_hysteresis;
cfg.dynamic_file_pattern = 'ATL_DYN_*.mat';
cfg.output = struct( ...
    'save_model', true, ...
    'save_results', false, ...
    'enabled_plots', enabled_plots, ...
    'include_model_struct', false, ...
    'model_output_file', model_output_file, ...
    'results_file', results_file);

build_results = runDynamicIdentification(cfg);
save(results_file, 'build_results');

fprintf('Saved ATL build results to:\n  %s\n', results_file);
