% runOcvModellingInspection.m
% Study entry point for batch OCV identification and visual inspection.
%
% This script:
%   1. runs runOcvIdentification for all ATL20 OCV temperatures
%   2. builds models for all supported OCV estimators
%   3. stores the inspection input in the base workspace
%   4. calls inspectOcvModelling.m to plot all temperatures

clearvars
close all
clc

script_dir = fileparts(mfilename('fullpath'));
study_root = script_dir;
ocv_root = fileparts(study_root);
repo_root = fileparts(ocv_root);

addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'utility')));
addpath(genpath(ocv_root));

cfg = struct();
cfg.ocv_data_input = fullfile(repo_root, 'data', 'modelling', 'processed', 'ocv', 'atl20');
cfg.data_prefix = 'ATL';
cfg.cell_id = 'ATL20';
cfg.min_v = 2.0;
cfg.max_v = 3.75;
cfg.desired_temperatures = [];
cfg.reference_ocv_method = 'middleCurve';
cfg.plot_diag_methods = false;
cfg.selected_method = '';
cfg.selected_diag_type = '';
cfg.save_inspection_figures = true;
cfg.inspection_figure_format = 'png';
cfg.report_scenario_id = 'ocv_modelling_inspection';

ocvInspectionInput = buildOcvInspectionInput(cfg); %#ok<NASGU>
assignin('base', 'ocvInspectionInput', ocvInspectionInput);

run(fullfile(study_root, 'inspectOcvModelling.m'));

if exist('ocvInspectionResults', 'var') && ~isempty(ocvInspectionResults)
  inspection_results = ocvInspectionResults;
else
  inspection_results = ocvInspectionInput;
end

ocvInspectionReport = writeOcvInspectionArtifacts(inspection_results); %#ok<NASGU>
assignin('base', 'ocvInspectionReport', ocvInspectionReport);

fprintf('\nSaved OCV inspection summary to:\n');
fprintf('  %s\n', ocvInspectionReport.summary_json_file);
fprintf('  %s\n', ocvInspectionReport.summary_markdown_file);
