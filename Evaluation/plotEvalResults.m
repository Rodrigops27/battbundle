function fig_handles = plotEvalResults(resultsInput, cfg)
% plotEvalResults Regenerate evaluation figures from saved results data.
%
% Usage:
%   plotEvalResults(results)
%   plotEvalResults('saved_results.mat')
%   figs = plotEvalResults(results, cfg)
%
% Inputs:
%   resultsInput  xKFeval-style results struct or MAT file path containing
%                 a struct with fields "dataset" and "estimators".
%   cfg           Optional struct:
%                   result_variable         preferred MAT variable name
%                   plot_soc                default true
%                   plot_voltage            default true
%                   plot_soc_error          default true
%                   plot_voltage_error      default true
%                   plot_r0                 default true
%                   plot_bias               default true
%                   plot_per_estimator_soc  default false
%                   plot_per_estimator_v    default false
%
% Output:
%   fig_handles   Struct of created figure handles.

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

fig_handles = struct();

if cfg.plot_voltage
    fig_handles.voltage = figure( ...
        'Name', sprintf('%sCell Voltage', title_prefix), ...
        'NumberTitle', 'off');
    hold on;
    if isfield(dataset, 'metric_voltage') && ~isempty(dataset.metric_voltage) && any(isfinite(dataset.metric_voltage))
        plot(t, dataset.metric_voltage, 'k-', 'LineWidth', 2.5, ...
            'DisplayName', fieldOr(dataset, 'metric_voltage_name', 'Metric Voltage'));
    end
    plot(t, dataset.voltage_v, 'k--', 'LineWidth', 1.2, ...
        'DisplayName', fieldOr(dataset, 'voltage_name', 'Measured'));
    for idx = 1:numel(estimators)
        est = estimators(idx);
        plot(t, est.voltage, 'LineStyle', fieldOr(est, 'lineStyle', '-'), ...
            'Color', fieldOr(est, 'color', []), 'LineWidth', 1.5, ...
            'DisplayName', est.name);
    end
    grid on;
    xlabel(time_label);
    ylabel('Voltage [V]');
    title(sprintf('%sCell Voltage', title_prefix));
    legend('Location', 'best');
end

if cfg.plot_soc
    fig_handles.soc = figure( ...
        'Name', sprintf('%sSOC Comparison', title_prefix), ...
        'NumberTitle', 'off');
    hold on;
    if isfield(dataset, 'dataset_soc') && ~isempty(dataset.dataset_soc) && any(isfinite(dataset.dataset_soc))
        plot(t, 100 * dataset.dataset_soc, 'k-', 'LineWidth', 2.5, ...
            'DisplayName', fieldOr(dataset, 'dataset_soc_name', 'Dataset SOC'));
    end
    if isfield(dataset, 'reference_soc') && ~isempty(dataset.reference_soc)
        plot(t, 100 * dataset.reference_soc, 'k--', 'LineWidth', 1.2, ...
            'DisplayName', fieldOr(dataset, 'reference_name', 'Reference'));
    end
    for idx = 1:numel(estimators)
        est = estimators(idx);
        soc_rmse_pct = metricOrNaN(est, 'rmse_soc', 100);
        plot(t, 100 * est.soc, 'LineStyle', fieldOr(est, 'lineStyle', '-'), ...
            'Color', fieldOr(est, 'color', []), 'LineWidth', 1.5, ...
            'DisplayName', sprintf('%s (RMSE=%.3f%%)', est.name, soc_rmse_pct));
    end
    grid on;
    xlabel(time_label);
    ylabel('SOC [%]');
    title(sprintf('%sSOC Estimation Comparison', title_prefix));
    legend('Location', 'best');
end

if cfg.plot_soc_error
    fig_handles.soc_error = figure( ...
        'Name', sprintf('%sSOC Errors', title_prefix), ...
        'NumberTitle', 'off');
    hold on;
    for idx = 1:numel(estimators)
        est = estimators(idx);
        soc_rmse_pct = metricOrNaN(est, 'rmse_soc', 100);
        plot(t, 100 * est.error_soc, 'LineStyle', fieldOr(est, 'lineStyle', '-'), ...
            'Color', fieldOr(est, 'color', []), 'LineWidth', 1.5, ...
            'DisplayName', sprintf('%s (RMSE=%.3f%%)', est.name, soc_rmse_pct));
    end
    grid on;
    xlabel(time_label);
    ylabel('SOC Error [%]');
    title(sprintf('%sSOC Estimation Errors vs %s', title_prefix, ...
        fieldOr(dataset, 'metric_soc_name', 'Metric SOC')));
    legend('Location', 'best');
end

if cfg.plot_voltage_error
    fig_handles.voltage_error = figure( ...
        'Name', sprintf('%sVoltage Errors', title_prefix), ...
        'NumberTitle', 'off');
    hold on;
    for idx = 1:numel(estimators)
        est = estimators(idx);
        voltage_rmse_mv = metricOrNaN(est, 'rmse_voltage', 1000);
        plot(t, est.error_voltage, 'LineStyle', fieldOr(est, 'lineStyle', '-'), ...
            'Color', fieldOr(est, 'color', []), 'LineWidth', 1.5, ...
            'DisplayName', sprintf('%s (RMSE=%.2f mV)', est.name, voltage_rmse_mv));
    end
    grid on;
    xlabel(time_label);
    ylabel('Voltage Error [V]');
    title(sprintf('%sVoltage Estimation Errors vs %s', title_prefix, ...
        fieldOr(dataset, 'metric_voltage_name', 'Metric Voltage')));
    legend('Location', 'best');
end

if cfg.plot_r0 && any(arrayfun(@(e) fieldOr(e, 'has_r0', false), estimators))
    fig_handles.r0 = figure( ...
        'Name', sprintf('%sR0 Comparison', title_prefix), ...
        'NumberTitle', 'off');
    hold on;
    if isfield(dataset, 'r0_reference') && ~isempty(dataset.r0_reference)
        if isscalar(dataset.r0_reference)
            plot(t, 1000 * dataset.r0_reference * ones(size(t)), 'k-', ...
                'LineWidth', 2, 'DisplayName', 'Model R0');
        else
            plot(t, 1000 * dataset.r0_reference(:), 'k-', ...
                'LineWidth', 2, 'DisplayName', 'Model R0');
        end
    end
    for idx = 1:numel(estimators)
        est = estimators(idx);
        if ~fieldOr(est, 'has_r0', false)
            continue;
        end
        plot(t, 1000 * est.r0, 'LineStyle', fieldOr(est, 'lineStyle', '-'), ...
            'Color', fieldOr(est, 'color', []), 'LineWidth', 1.5, ...
            'DisplayName', sprintf('%s R0', est.name));
        if isfield(est, 'r0_bnd') && ~isempty(est.r0_bnd)
            plot(t, 1000 * (est.r0 + est.r0_bnd), ':', 'Color', fieldOr(est, 'color', []), ...
                'LineWidth', 1.0, 'DisplayName', sprintf('%s +3\\sigma', est.name));
            plot(t, 1000 * (est.r0 - est.r0_bnd), ':', 'Color', fieldOr(est, 'color', []), ...
                'LineWidth', 1.0, 'HandleVisibility', 'off');
        end
    end
    grid on;
    xlabel(time_label);
    ylabel('R0 [m\Omega]');
    title(sprintf('%sR0 Estimates and Bounds', title_prefix));
    legend('Location', 'best');
end

if cfg.plot_bias && any(arrayfun(@(e) fieldOr(e, 'has_bias', false), estimators))
    bias_dim = max(arrayfun(@(e) sizeSafe(fieldOr(e, 'bias', []), 2), estimators));
    bias_names = {'Current Bias', 'Output Bias'};
    bias_units = {'A', 'V'};
    fig_handles.bias = figure( ...
        'Name', sprintf('%sBias Estimates', title_prefix), ...
        'NumberTitle', 'off');
    tiledlayout(bias_dim, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    for bias_idx = 1:bias_dim
        nexttile;
        hold on;
        for est_idx = 1:numel(estimators)
            est = estimators(est_idx);
            if ~fieldOr(est, 'has_bias', false) || sizeSafe(fieldOr(est, 'bias', []), 2) < bias_idx
                continue;
            end
            plot(t, est.bias(:, bias_idx), 'LineStyle', fieldOr(est, 'lineStyle', '-'), ...
                'Color', fieldOr(est, 'color', []), 'LineWidth', 1.5, ...
                'DisplayName', est.name);
            if isfield(est, 'bias_bnd') && sizeSafe(est.bias_bnd, 2) >= bias_idx
                plot(t, est.bias(:, bias_idx) + est.bias_bnd(:, bias_idx), ':', ...
                    'Color', fieldOr(est, 'color', []), 'LineWidth', 1.0, ...
                    'DisplayName', sprintf('%s +3\\sigma', est.name));
                plot(t, est.bias(:, bias_idx) - est.bias_bnd(:, bias_idx), ':', ...
                    'Color', fieldOr(est, 'color', []), 'LineWidth', 1.0, ...
                    'HandleVisibility', 'off');
            end
        end
        grid on;
        ylabel(sprintf('%s [%s]', bias_names{min(bias_idx, numel(bias_names))}, ...
            bias_units{min(bias_idx, numel(bias_units))}));
        title(sprintf('%sEstimate', bias_names{min(bias_idx, numel(bias_names))}));
        legend('Location', 'best');
    end
    xlabel(time_label);
end

if cfg.plot_per_estimator_soc
    fig_handles.soc_estimator = gobjects(numel(estimators), 1);
    for idx = 1:numel(estimators)
        est = estimators(idx);
        fig_handles.soc_estimator(idx) = figure( ...
            'Name', ['SOC Error (' est.name ')'], ...
            'NumberTitle', 'off');
        plot(t, 100 * est.error_soc, 'LineWidth', 1.3);
        hold on;
        grid on;
        if isfield(est, 'soc_bnd') && ~isempty(est.soc_bnd)
            set(gca, 'colororderindex', 1);
            plot(t, 100 * est.soc_bnd, ':');
            set(gca, 'colororderindex', 1);
            plot(t, -100 * est.soc_bnd, ':');
        end
        title(sprintf('SOC estimation error (percent, %s)', est.name));
        xlabel(time_label);
        legend('Error', '+3\sigma', '-3\sigma', 'Location', 'best');
    end
end

if cfg.plot_per_estimator_v
    fig_handles.voltage_estimator = gobjects(numel(estimators), 1);
    for idx = 1:numel(estimators)
        est = estimators(idx);
        fig_handles.voltage_estimator(idx) = figure( ...
            'Name', ['Voltage Error (' est.name ')'], ...
            'NumberTitle', 'off');
        plot(t, est.error_voltage, 'LineWidth', 1.3);
        hold on;
        grid on;
        if isfield(est, 'voltage_bnd') && ~isempty(est.voltage_bnd)
            set(gca, 'colororderindex', 1);
            plot(t, est.voltage_bnd, ':');
            set(gca, 'colororderindex', 1);
            plot(t, -est.voltage_bnd, ':');
        end
        title(sprintf('Voltage estimation error (%s)', est.name));
        xlabel(time_label);
        legend('Error', '+3\sigma', '-3\sigma', 'Location', 'best');
    end
end
end

function cfg = normalizeConfig(cfg)
cfg.plot_soc = fieldOr(cfg, 'plot_soc', true);
cfg.plot_voltage = fieldOr(cfg, 'plot_voltage', true);
cfg.plot_soc_error = fieldOr(cfg, 'plot_soc_error', true);
cfg.plot_voltage_error = fieldOr(cfg, 'plot_voltage_error', true);
cfg.plot_r0 = fieldOr(cfg, 'plot_r0', true);
cfg.plot_bias = fieldOr(cfg, 'plot_bias', true);
cfg.plot_per_estimator_soc = fieldOr(cfg, 'plot_per_estimator_soc', false);
cfg.plot_per_estimator_v = fieldOr(cfg, 'plot_per_estimator_v', false);
cfg.result_variable = fieldOr(cfg, 'result_variable', '');
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
    error('plotEvalResults:MissingInput', ...
        'Provide a results struct, MAT file path, or a base-workspace results variable.');
end

if isstring(resultsInput)
    resultsInput = char(resultsInput);
end
if ~ischar(resultsInput)
    error('plotEvalResults:BadInput', ...
        'resultsInput must be a results struct or a MAT file path.');
end
if exist(resultsInput, 'file') ~= 2
    error('plotEvalResults:MissingFile', 'Results file not found: %s', resultsInput);
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
    error('plotEvalResults:MissingVariable', ...
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

error('plotEvalResults:NoResultsStruct', ...
    'Could not find an xKFeval-style results struct in %s.', file_path);
end

function validateResultsStruct(results)
required = {'dataset', 'estimators'};
for idx = 1:numel(required)
    if ~isfield(results, required{idx})
        error('plotEvalResults:BadResultsStruct', ...
            'Results struct is missing field "%s".', required{idx});
    end
end
if ~isfield(results.dataset, 'time_s')
    error('plotEvalResults:MissingTime', ...
        'Results dataset must contain dataset.time_s.');
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

function value = sizeSafe(array_value, dim)
if isempty(array_value)
    value = 0;
else
    value = size(array_value, dim);
end
end
