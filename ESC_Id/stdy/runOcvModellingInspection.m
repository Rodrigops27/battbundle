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
esc_root = fileparts(study_root);
repo_root = fileparts(esc_root);

addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'utility')));
addpath(genpath(esc_root));

cfg = struct();
cfg.ocv_data_input = fullfile(repo_root, 'data', 'modelling', 'processed', 'ocv', 'atl20');
cfg.data_prefix = 'ATL';
cfg.cell_id = 'ATL20';
cfg.min_v = 2.0;
cfg.max_v = 3.75;
cfg.desired_temperatures = [];
cfg.reference_ocv_method = 'middleCurve';
cfg.plot_diag_methods = false;

ocvInspectionInput = buildOcvInspectionInput(cfg); %#ok<NASGU>
assignin('base', 'ocvInspectionInput', ocvInspectionInput);

run(fullfile(study_root, 'inspectOcvModelling.m'));
