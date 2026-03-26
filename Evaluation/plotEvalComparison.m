function fig_handle = plotEvalComparison(resultsInput, cfg)
% plotEvalComparison Plot SOC and voltage estimation comparisons in one figure.
%
% Usage:
%   plotEvalComparison(results)
%   plotEvalComparison('saved_results.mat')
%   fig = plotEvalComparison(resultsInput, cfg)
%
% Inputs:
%   resultsInput  xKFeval-style results struct or MAT file path containing
%                 a struct with fields "dataset" and "estimators".
%   cfg           Optional struct:
%                   result_variable  preferred MAT variable name
%                   figure_name      custom figure name
%
% Output:
%   fig_handle    Created figure handle.

if nargin < 1 || isempty(resultsInput)
    resultsInput = [];
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end

cfg = normalizeConfig(cfg);
results = loadResultsInput(resultsInput, cfg);
validateResultsStruct(results);

dataset = results.dataset;
estimators = results.estimators;
[t, time_label] = getTimeAxisData(dataset.time_s);
title_prefix = getTitlePrefix(results);

fig_handle = figure( ...
    'Name', cfg.figure_name, ...
    'NumberTitle', 'off');

ax(1) = subplot(2, 1, 1); %#ok<AGROW>
hold(ax(1), 'on');
if isfield(dataset, 'dataset_soc') && ~isempty(dataset.dataset_soc) && any(isfinite(dataset.dataset_soc))
    plot(ax(1), t, 100 * dataset.dataset_soc, 'k-', 'LineWidth', 2.5, ...
        'DisplayName', fieldOr(dataset, 'dataset_soc_name', 'Dataset SOC'));
end
if isfield(dataset, 'reference_soc') && ~isempty(dataset.reference_soc)
    plot(ax(1), t, 100 * dataset.reference_soc, 'k--', 'LineWidth', 1.2, ...
        'DisplayName', fieldOr(dataset, 'reference_name', 'Reference'));
end
for idx = 1:numel(estimators)
    est = estimators(idx);
    soc_rmse_pct = metricOrNaN(est, 'rmse_soc', 100);
    plot(ax(1), t, 100 * est.soc, 'LineStyle', fieldOr(est, 'lineStyle', '-'), ...
        'Color', fieldOr(est, 'color', []), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s (RMSE=%.3f%%)', est.name, soc_rmse_pct));
end
grid(ax(1), 'on');
ylabel(ax(1), 'SOC [%]');
title(ax(1), sprintf('%sSOC Estimation Comparison', title_prefix));
legend(ax(1), 'Location', 'best');

ax(2) = subplot(2, 1, 2); %#ok<AGROW>
hold(ax(2), 'on');
if isfield(dataset, 'metric_voltage') && ~isempty(dataset.metric_voltage) && any(isfinite(dataset.metric_voltage))
    plot(ax(2), t, dataset.metric_voltage, 'k-', 'LineWidth', 2.5, ...
        'DisplayName', fieldOr(dataset, 'metric_voltage_name', 'Metric Voltage'));
end
plot(ax(2), t, dataset.voltage_v, 'k--', 'LineWidth', 1.2, ...
    'DisplayName', fieldOr(dataset, 'voltage_name', 'Measured'));
for idx = 1:numel(estimators)
    est = estimators(idx);
    voltage_rmse_mv = metricOrNaN(est, 'rmse_voltage', 1000);
    plot(ax(2), t, est.voltage, 'LineStyle', fieldOr(est, 'lineStyle', '-'), ...
        'Color', fieldOr(est, 'color', []), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s (RMSE=%.2f mV)', est.name, voltage_rmse_mv));
end
grid(ax(2), 'on');
xlabel(ax(2), time_label);
ylabel(ax(2), 'Voltage [V]');
title(ax(2), sprintf('%sVoltage Estimation Comparison', title_prefix));
legend(ax(2), 'Location', 'best');

linkaxes(ax, 'x');
end

function cfg = normalizeConfig(cfg)
cfg.result_variable = fieldOr(cfg, 'result_variable', '');
cfg.figure_name = fieldOr(cfg, 'figure_name', 'Evaluation Comparison');
end

function results = loadResultsInput(resultsInput, cfg)
if isstruct(resultsInput) && isfield(resultsInput, 'dataset') && isfield(resultsInput, 'estimators')
    results = resultsInput;
    return;
end

if isempty(resultsInput)
    candidates = {'benchmarkResults', 'results', 'evalResults'};
    for idx = 1:numel(candidates)
        if evalin('base', sprintf('exist(''%s'', ''var'')', candidates{idx}))
            results = evalin('base', candidates{idx});
            return;
        end
    end
    error('plotEvalComparison:MissingInput', ...
        'Provide a results struct, MAT file path, or a base-workspace results variable.');
end

if isstring(resultsInput)
    resultsInput = char(resultsInput);
end
if ~ischar(resultsInput)
    error('plotEvalComparison:BadInput', ...
        'resultsInput must be a results struct or a MAT file path.');
end
if exist(resultsInput, 'file') ~= 2
    error('plotEvalComparison:MissingFile', 'Results file not found: %s', resultsInput);
end

loaded = load(resultsInput);
results = extractResultsStruct(loaded, cfg.result_variable, resultsInput);
end

function results = extractResultsStruct(loaded, preferred_name, file_path)
if ~isempty(preferred_name)
    if isfield(loaded, preferred_name)
        results = loaded.(preferred_name);
        return;
    end
    error('plotEvalComparison:MissingVariable', ...
        'Variable "%s" was not found in %s.', preferred_name, file_path);
end

names = fieldnames(loaded);
for idx = 1:numel(names)
    candidate = loaded.(names{idx});
    if isstruct(candidate) && isfield(candidate, 'dataset') && isfield(candidate, 'estimators')
        results = candidate;
        return;
    end
end

error('plotEvalComparison:NoResultsStruct', ...
    'Could not find an xKFeval-style results struct in %s.', file_path);
end

function validateResultsStruct(results)
required = {'dataset', 'estimators'};
for idx = 1:numel(required)
    if ~isfield(results, required{idx})
        error('plotEvalComparison:BadResultsStruct', ...
            'Results struct is missing field "%s".', required{idx});
    end
end
if ~isfield(results.dataset, 'time_s')
    error('plotEvalComparison:MissingTime', ...
        'Results dataset must contain dataset.time_s.');
end
if ~isfield(results.dataset, 'voltage_v')
    error('plotEvalComparison:MissingVoltage', ...
        'Results dataset must contain dataset.voltage_v.');
end
end

function [time_axis, time_label] = getTimeAxisData(time_s)
time_s = time_s(:);
if isempty(time_s)
    time_axis = time_s;
    time_label = 'Time [s]';
    return;
end

duration_s = max(time_s) - min(time_s);
if duration_s >= 3600
    time_axis = time_s / 3600;
    time_label = 'Time [h]';
elseif duration_s >= 120
    time_axis = time_s / 60;
    time_label = 'Time [min]';
else
    time_axis = time_s;
    time_label = 'Time [s]';
end
end

function prefix = getTitlePrefix(results)
prefix = '';
if isfield(results, 'dataset') && isfield(results.dataset, 'title_prefix') && ...
        ~isempty(results.dataset.title_prefix)
    prefix = [char(results.dataset.title_prefix) ' '];
    return;
end
if isfield(results, 'metadata') && isfield(results.metadata, 'modelSpec') && ...
        isfield(results.metadata.modelSpec, 'chemistry_label') && ...
        ~isempty(results.metadata.modelSpec.chemistry_label)
    prefix = [char(results.metadata.modelSpec.chemistry_label) ' '];
end
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end

function value = metricOrNaN(estimator, field_name, scale)
if nargin < 3
    scale = 1;
end
if isfield(estimator, field_name) && ~isempty(estimator.(field_name)) && isfinite(estimator.(field_name))
    value = scale * estimator.(field_name);
else
    value = NaN;
end
end
