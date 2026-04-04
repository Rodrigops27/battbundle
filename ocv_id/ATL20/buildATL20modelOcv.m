% script buildATL20modelOcv.m
%   Builds the ATL20 OCV model from ATL OCV test data. This is a
%   chemistry-specific wrapper around ocv_id/runOcvIdentification.m.

close all
clc

script_dir = fileparts(mfilename('fullpath'));
ocv_root = fileparts(script_dir);
repo_root = fileparts(ocv_root);

addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'utility')));
addpath(genpath(ocv_root));

if ~exist('ocv_data_dir', 'var') || isempty(ocv_data_dir)
    ocv_data_dir = fullfile(repo_root, 'data', 'modelling', 'processed', 'ocv', 'atl20');
end
if ~exist('engine', 'var') || isempty(engine)
    engine = 'middleCurve';
end
if ~exist('diag_type', 'var') || isempty(diag_type)
    diag_type = 'useAvg';
end
if ~exist('temperature_scope', 'var') || isempty(temperature_scope)
    if exist('temps_degC', 'var') && ~isempty(temps_degC)
        if isnumeric(temps_degC) && isscalar(temps_degC)
            temperature_scope = 'single';
        else
            temperature_scope = 'selected';
        end
    else
        temperature_scope = 'all';
    end
end
if ~exist('desired_temperature', 'var') || isempty(desired_temperature)
    if exist('temps_degC', 'var') && ~isempty(temps_degC)
        desired_temperature = temps_degC;
    else
        desired_temperature = [];
    end
end
if ~exist('min_v', 'var') || isempty(min_v)
    min_v = 2.0;
end
if ~exist('max_v', 'var') || isempty(max_v)
    max_v = 3.75;
end
if ~exist('save_plots', 'var') || isempty(save_plots)
    save_plots = false;
end
if ~exist('debug_plots', 'var') || isempty(debug_plots)
    debug_plots = false;
end
if ~exist('output_file', 'var') || isempty(output_file)
    output_file = fullfile(repo_root, 'data', 'modelling', 'derived', 'ocv_models', 'atl20', 'ATL20model-ocv-middleCurve.mat');
end
if ~exist('results_file', 'var') || isempty(results_file)
    results_file = fullfile(repo_root, 'data', 'modelling', 'derived', 'identification_results', 'atl20', 'ATL20_ocv_identification_results.mat');
end

cfg = struct();
cfg.run_name = 'ATL20 OCV identification';
cfg.ocv_data_input = ocv_data_dir;
cfg.data_prefix = 'ATL';
cfg.cell_id = 'ATL20';
cfg.engine = engine;
cfg.diag_type = diag_type;
cfg.temperature_scope = temperature_scope;
cfg.desired_temperature = desired_temperature;
cfg.min_v = min_v;
cfg.max_v = max_v;
cfg.save_plots = save_plots;
cfg.debug_plots = debug_plots;
cfg.output = struct( ...
    'save_model', true, ...
    'save_results', false, ...
    'include_model_struct', false, ...
    'model_output_file', output_file, ...
    'results_file', results_file);

build_results = runOcvIdentification(cfg);
save(results_file, 'build_results');

fprintf('Saved ATL20 OCV build results to:\n  %s\n', results_file);
