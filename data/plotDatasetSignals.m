function fig_handles = plotDatasetSignals(datasetInput, cfg)
% plotDatasetSignals Plot current, voltage, SOC, and correlation views from a dataset.
%
% Usage:
%   plotDatasetSignals(dataset)
%   plotDatasetSignals('path_to_dataset.mat')
%   figs = plotDatasetSignals(datasetInput, cfg)
%
% Inputs:
%   datasetInput  Dataset struct or MAT file path containing a struct named
%                 "dataset" or a single struct variable.
%   cfg          Optional struct:
%                  dataset_variable  preferred MAT variable name, default 'dataset'
%                  figure_name       custom figure name
%                  title_prefix      custom title prefix
%                  show_normalized_correlations  create normalized
%                               voltage/SOC and current/SOC figures with a
%                               unity line, default false
%
% Output:
%   fig_handles  Struct with created figure handles.

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
valid_corr = isfinite(dataset.current_a(:)) & isfinite(dataset.voltage_v(:)) & isfinite(soc_data(:));

fig_handles = struct();

fig_handles.signals = figure( ...
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

fig_handles.voltage_soc = figure( ...
    'Name', sprintf('%s - Voltage vs SOC', buildBaseFigureName(dataset, cfg)), ...
    'NumberTitle', 'off');
if any(valid_corr)
    plotCorrelationWithTrend( ...
        100 * soc_data(valid_corr), ...
        dataset.voltage_v(valid_corr), ...
        time_data(valid_corr), ...
        'SOC [%]', ...
        'Voltage [V]', ...
        sprintf('%sVoltage vs SOC', buildTitlePrefix(dataset, cfg)), ...
        time_label);
else
    text(0.1, 0.5, 'No finite voltage/SOC pairs available', 'Units', 'normalized');
    axis off;
end

fig_handles.current_soc = figure( ...
    'Name', sprintf('%s - Current vs SOC', buildBaseFigureName(dataset, cfg)), ...
    'NumberTitle', 'off');
if any(valid_corr)
    plotCorrelationWithTrend( ...
        100 * soc_data(valid_corr), ...
        dataset.current_a(valid_corr), ...
        time_data(valid_corr), ...
        'SOC [%]', ...
        'Current [A]', ...
        sprintf('%sCurrent vs SOC', buildTitlePrefix(dataset, cfg)), ...
        time_label);
else
    text(0.1, 0.5, 'No finite current/SOC pairs available', 'Units', 'normalized');
    axis off;
end

if cfg.show_normalized_correlations
    fig_handles.voltage_soc_normalized = figure( ...
        'Name', sprintf('%s - Voltage vs SOC (normalized)', buildBaseFigureName(dataset, cfg)), ...
        'NumberTitle', 'off');
    if any(valid_corr)
        plotNormalizedCorrelation( ...
            100 * soc_data(valid_corr), ...
            dataset.voltage_v(valid_corr), ...
            time_data(valid_corr), ...
            'Normalized SOC', ...
            'Normalized Voltage', ...
            sprintf('%sVoltage vs SOC (normalized)', buildTitlePrefix(dataset, cfg)), ...
            time_label);
    else
        text(0.1, 0.5, 'No finite voltage/SOC pairs available', 'Units', 'normalized');
        axis off;
    end

    fig_handles.current_soc_normalized = figure( ...
        'Name', sprintf('%s - Current vs SOC (normalized)', buildBaseFigureName(dataset, cfg)), ...
        'NumberTitle', 'off');
    if any(valid_corr)
        plotNormalizedCorrelation( ...
            100 * soc_data(valid_corr), ...
            dataset.current_a(valid_corr), ...
            time_data(valid_corr), ...
            'Normalized SOC', ...
            'Normalized Current', ...
            sprintf('%sCurrent vs SOC (normalized)', buildTitlePrefix(dataset, cfg)), ...
            time_label);
    else
        text(0.1, 0.5, 'No finite current/SOC pairs available', 'Units', 'normalized');
        axis off;
    end
end
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
if ~isfield(cfg, 'show_normalized_correlations') || isempty(cfg.show_normalized_correlations)
    cfg.show_normalized_correlations = false;
end
end

function plotCorrelationWithTrend(x_data, y_data, color_data, x_label, y_label, plot_title, color_label)
scatter(x_data, y_data, 10, color_data, 'filled');
grid on;
xlabel(x_label);
ylabel(y_label);
title(plot_title);
cb = colorbar;
cb.Label.String = color_label;
hold on;
addLinearTrendLine(x_data, y_data);
hold off;
end

function plotNormalizedCorrelation(x_data, y_data, color_data, x_label, y_label, plot_title, color_label)
x_norm = minMaxNormalize(x_data);
y_norm = minMaxNormalize(y_data);

scatter(x_norm, y_norm, 10, color_data, 'filled');
grid on;
xlabel(x_label);
ylabel(y_label);
title(plot_title);
cb = colorbar;
cb.Label.String = color_label;
hold on;
plot([0 1], [0 1], '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.1);
addLinearTrendLine(x_norm, y_norm);
hold off;
xlim([0 1]);
ylim([0 1]);
end

function addLinearTrendLine(x_data, y_data)
valid_fit = isfinite(x_data) & isfinite(y_data);
x_fit = x_data(valid_fit);
y_fit = y_data(valid_fit);
if numel(x_fit) < 2 || all(x_fit == x_fit(1))
    return;
end

coeffs = polyfit(x_fit, y_fit, 1);
x_line = linspace(min(x_fit), max(x_fit), 100);
y_line = polyval(coeffs, x_line);
plot(x_line, y_line, 'k-', 'LineWidth', 1.4);
end

function data_norm = minMaxNormalize(data)
data_min = min(data);
data_max = max(data);
if ~isfinite(data_min) || ~isfinite(data_max) || data_max <= data_min
    data_norm = zeros(size(data));
else
    data_norm = (data - data_min) ./ (data_max - data_min);
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
fig_name = sprintf('%s - Signals', buildBaseFigureName(dataset, cfg));
end

function fig_name = buildBaseFigureName(dataset, cfg)
if ~isempty(cfg.figure_name)
    fig_name = cfg.figure_name;
elseif isfield(dataset, 'name') && ~isempty(dataset.name)
    fig_name = char(dataset.name);
else
    fig_name = 'Dataset';
end
end

function title_text = buildAxisTitle(dataset, cfg)
title_text = sprintf('%sSignals', buildTitlePrefix(dataset, cfg));
end

function prefix = buildTitlePrefix(dataset, cfg)
if ~isempty(cfg.title_prefix)
    prefix = [cfg.title_prefix ' '];
elseif isfield(dataset, 'title_prefix') && ~isempty(dataset.title_prefix)
    prefix = sprintf('%s Dataset ', dataset.title_prefix);
elseif isfield(dataset, 'name') && ~isempty(dataset.name)
    prefix = sprintf('%s Dataset ', dataset.name);
else
    prefix = 'Dataset ';
end
end
