function fig_handles = plotInitSocSweepResults(resultsInput, cfg)
% plotInitSocSweepResults Regenerate initial-SOC sweep figures from saved results.
%
% Usage:
%   plotInitSocSweepResults(results)
%   plotInitSocSweepResults('saved_results.mat')
%   figs = plotInitSocSweepResults(results, cfg)
%
% Inputs:
%   resultsInput  sweepInitSocStudy results struct or MAT file path.
%   cfg           Optional struct:
%                   result_variable          default ''
%                   plot_summary             default true
%                   plot_both_convergence    default false
%                   plot_soc_convergence     default false
%                   plot_voltage_convergence default false
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

fig_handles = struct();

if cfg.plot_summary
    [fig_handles.soc_rmse, fig_handles.voltage_rmse] = plotSweepRmseFigures( ...
        results.soc0_sweep_percent(:), ...
        results.soc_rmse_percent, ...
        results.voltage_rmse_mv, ...
        results.estimator_names(:).', ...
        fieldOr(results, 'dataset_mode', 'unknown'));
end

if cfg.plot_soc_convergence
    fig_handles.soc_convergence = plotPerEstimatorSocConvergence( ...
        results.all_results, results.soc0_sweep_percent(:), results.estimator_names(:).');
end

if cfg.plot_voltage_convergence
    fig_handles.voltage_convergence = plotPerEstimatorVoltageConvergence( ...
        results.all_results, results.soc0_sweep_percent(:), results.estimator_names(:).');
end
end

function cfg = normalizeConfig(cfg)
cfg.result_variable = fieldOr(cfg, 'result_variable', '');
cfg.plot_summary = fieldOr(cfg, 'plot_summary', true);
cfg.plot_both_convergence = fieldOr(cfg, 'plot_both_convergence', false);
cfg.plot_soc_convergence = fieldOr(cfg, 'plot_soc_convergence', false);
cfg.plot_voltage_convergence = fieldOr(cfg, 'plot_voltage_convergence', false);
if cfg.plot_both_convergence
    cfg.plot_soc_convergence = true;
    cfg.plot_voltage_convergence = true;
end
end

function results = loadResultsInput(resultsInput, cfg)
if isstruct(resultsInput) && isfield(resultsInput, 'soc_rmse_percent') && isfield(resultsInput, 'all_results')
    results = resultsInput;
    return;
end

if isempty(resultsInput)
    candidates = {'initSocSweepResults', 'sweepResults'};
    for idx = 1:numel(candidates)
        if evalin('base', sprintf('exist(''%s'', ''var'')', candidates{idx}))
            results = evalin('base', candidates{idx});
            return;
        end
    end
    error('plotInitSocSweepResults:MissingInput', ...
        'Provide a results struct, MAT file path, or a base-workspace results variable.');
end

if isstring(resultsInput)
    resultsInput = char(resultsInput);
end
if ~ischar(resultsInput)
    error('plotInitSocSweepResults:BadInput', ...
        'resultsInput must be a results struct or a MAT file path.');
end
if exist(resultsInput, 'file') ~= 2
    error('plotInitSocSweepResults:MissingFile', 'Results file not found: %s', resultsInput);
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
    error('plotInitSocSweepResults:MissingVariable', ...
        'Variable "%s" was not found in %s.', preferred_name, file_path);
end

names = fieldnames(loaded);
for idx = 1:numel(names)
    candidate = loaded.(names{idx});
    if isstruct(candidate) && isfield(candidate, 'soc_rmse_percent') && isfield(candidate, 'all_results')
        results = candidate;
        return;
    end
end

error('plotInitSocSweepResults:NoResultsStruct', ...
    'Could not find a sweepInitSocStudy results struct in %s.', file_path);
end

function validateResultsStruct(results)
required = {'soc0_sweep_percent', 'soc_rmse_percent', 'voltage_rmse_mv', 'estimator_names', 'all_results'};
for idx = 1:numel(required)
    if ~isfield(results, required{idx})
        error('plotInitSocSweepResults:BadResultsStruct', ...
            'Results struct is missing field "%s".', required{idx});
    end
end
end

function [fig_soc, fig_voltage] = plotSweepRmseFigures(soc0_sweep_percent, soc_rmse, voltage_rmse, estimator_names, dataset_mode)
palette = lines(numel(estimator_names));

fig_soc = figure('Name', 'Initial SOC Sweep - SOC RMSE', 'NumberTitle', 'off');
hold on;
for est_idx = 1:numel(estimator_names)
    plot(soc0_sweep_percent, soc_rmse(:, est_idx), '-o', ...
        'LineWidth', 1.4, 'Color', palette(est_idx, :), ...
        'DisplayName', estimator_names{est_idx});
end
grid on;
xlabel('Initial SOC [%]');
ylabel('SOC RMSE [%]');
title(sprintf('Initial SOC Sweep SOC RMSE (%s)', upper(dataset_mode)));
legend('Location', 'best');

fig_voltage = figure('Name', 'Initial SOC Sweep - Voltage RMSE', 'NumberTitle', 'off');
hold on;
for est_idx = 1:numel(estimator_names)
    plot(soc0_sweep_percent, voltage_rmse(:, est_idx), '-o', ...
        'LineWidth', 1.4, 'Color', palette(est_idx, :), ...
        'DisplayName', estimator_names{est_idx});
end
grid on;
xlabel('Initial SOC [%]');
ylabel('Voltage RMSE [mV]');
title(sprintf('Initial SOC Sweep Voltage RMSE (%s)', upper(dataset_mode)));
legend('Location', 'best');
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end
