function fig_handle = plotDatasetSignals(datasetInput, cfg)
% plotDatasetSignals Plot current, voltage, and SOC from a dataset.
%
% Usage:
%   plotDatasetSignals(dataset)
%   plotDatasetSignals('path_to_dataset.mat')
%   fig = plotDatasetSignals(datasetInput, cfg)
%
% Inputs:
%   datasetInput  Dataset struct or MAT file path containing a struct named
%                 "dataset" or a single struct variable.
%   cfg          Optional struct:
%                  dataset_variable  preferred MAT variable name, default 'dataset'
%                  figure_name       custom figure name
%                  title_prefix      custom title prefix
%
% Output:
%   fig_handle   Figure handle.

if nargin < 1 || isempty(datasetInput)
    error('plotDatasetSignals:MissingInput', ...
        'A dataset struct or MAT file path is required.');
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end

cfg = normalizeConfig(cfg);
dataset = loadDatasetInput(datasetInput, cfg.dataset_variable);

[time_data, time_label] = getTimeAxis(dataset);
soc_data = selectSocSignal(dataset);

fig_handle = figure( ...
    'Name', buildFigureName(dataset, cfg), ...
    'NumberTitle', 'off');

ax(1) = subplot(3, 1, 1); %#ok<AGROW>
plot(time_data, dataset.current_a(:), 'LineWidth', 1.2);
grid on;
ylabel('Current [A]');
title(buildAxisTitle(dataset, cfg));

ax(2) = subplot(3, 1, 2); %#ok<AGROW>
plot(time_data, dataset.voltage_v(:), 'LineWidth', 1.2);
grid on;
ylabel('Voltage [V]');

ax(3) = subplot(3, 1, 3); %#ok<AGROW>
plot(time_data, 100 * soc_data(:), 'LineWidth', 1.2);
grid on;
xlabel(time_label);
ylabel('SOC [%]');

linkaxes(ax, 'x');
end

function cfg = normalizeConfig(cfg)
if ~isfield(cfg, 'dataset_variable') || isempty(cfg.dataset_variable)
    cfg.dataset_variable = 'dataset';
end
if ~isfield(cfg, 'figure_name')
    cfg.figure_name = '';
end
if ~isfield(cfg, 'title_prefix')
    cfg.title_prefix = '';
end
end

function dataset = loadDatasetInput(datasetInput, datasetVariable)
if isstruct(datasetInput)
    dataset = datasetInput;
    return;
end

if ~(ischar(datasetInput) || (isstring(datasetInput) && isscalar(datasetInput)))
    error('plotDatasetSignals:BadInput', ...
        'datasetInput must be a struct or MAT file path.');
end

datasetPath = char(datasetInput);
if exist(datasetPath, 'file') ~= 2
    error('plotDatasetSignals:MissingFile', ...
        'Dataset file not found: %s', datasetPath);
end

loaded = load(datasetPath);
if isfield(loaded, datasetVariable) && isstruct(loaded.(datasetVariable))
    dataset = loaded.(datasetVariable);
    return;
end

names = fieldnames(loaded);
if numel(names) == 1 && isstruct(loaded.(names{1}))
    dataset = loaded.(names{1});
    return;
end

error('plotDatasetSignals:MissingDataset', ...
    'Could not find a dataset struct in %s.', datasetPath);
end

function [time_data, time_label] = getTimeAxis(dataset)
if isfield(dataset, 'time_s') && ~isempty(dataset.time_s)
    time_s = dataset.time_s(:);
    duration_s = max(time_s) - min(time_s);
    if duration_s >= 2 * 3600
        time_data = time_s / 3600;
        time_label = 'Time [h]';
    elseif duration_s >= 2 * 60
        time_data = time_s / 60;
        time_label = 'Time [min]';
    else
        time_data = time_s;
        time_label = 'Time [s]';
    end
else
    n_samples = numel(dataset.current_a);
    time_data = (0:n_samples-1).';
    time_label = 'Sample';
end
end

function soc_data = selectSocSignal(dataset)
candidate_fields = {'soc_true', 'reference_soc', 'dataset_soc', 'source_soc_ref', 'soc_cc'};
for idx = 1:numel(candidate_fields)
    field_name = candidate_fields{idx};
    if isfield(dataset, field_name) && ~isempty(dataset.(field_name))
        soc_data = dataset.(field_name);
        return;
    end
end

error('plotDatasetSignals:MissingSoc', ...
    'Dataset does not contain a recognized SOC field.');
end

function fig_name = buildFigureName(dataset, cfg)
if ~isempty(cfg.figure_name)
    fig_name = cfg.figure_name;
elseif isfield(dataset, 'name') && ~isempty(dataset.name)
    fig_name = sprintf('Dataset Signals - %s', dataset.name);
else
    fig_name = 'Dataset Signals';
end
end

function title_text = buildAxisTitle(dataset, cfg)
if ~isempty(cfg.title_prefix)
    title_text = cfg.title_prefix;
elseif isfield(dataset, 'title_prefix') && ~isempty(dataset.title_prefix)
    title_text = sprintf('%s Dataset Signals', dataset.title_prefix);
elseif isfield(dataset, 'name') && ~isempty(dataset.name)
    title_text = sprintf('%s Dataset Signals', dataset.name);
else
    title_text = 'Dataset Signals';
end
end
