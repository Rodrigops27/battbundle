function comparison = compareEscModels(model_a_input, model_b_input, data_input, cfg)
% compareEscModels Compare two ESC models on the same validation dataset.
%
% Usage:
%   comparison = compareEscModels(model_a_input, model_b_input, data_input)
%   comparison = compareEscModels(model_a_input, model_b_input, data_input, cfg)
%
% Inputs:
%   model_a_input  ESC model MAT-file path, loaded model struct, or wrapper
%                  struct accepted by ESCvalidation().
%   model_b_input  ESC model MAT-file path, loaded model struct, or wrapper
%                  struct accepted by ESCvalidation().
%   data_input     Validation dataset accepted by ESCvalidation().
%   cfg            Optional struct with fields:
%                    enabled_plot: true/false, default true
%                    model_a_name: custom label for model A
%                    model_b_name: custom label for model B
%
% Output:
%   comparison     Struct containing both ESCvalidation() outputs, per-case
%                  comparison metrics, aggregate model ranking, and the
%                  comparison figure handle when plotting is enabled.

if nargin < 4 || isempty(cfg)
    cfg = struct();
end

enabled_plot = true;
if isfield(cfg, 'enabled_plot') && ~isempty(cfg.enabled_plot)
    enabled_plot = logical(cfg.enabled_plot);
end

model_a_input = normalizeModelInput(model_a_input);
model_b_input = normalizeModelInput(model_b_input);

result_a = ESCvalidation(model_a_input, data_input, false);
result_b = ESCvalidation(model_b_input, data_input, false);

validateComparableResults(result_a, result_b);

model_a_label = resolveModelLabel(result_a, 'Model A', cfg, 'model_a_name');
model_b_label = resolveModelLabel(result_b, 'Model B', cfg, 'model_b_name');

[case_comparisons, case_summary_table] = buildCaseComparisons(result_a, result_b, model_a_label, model_b_label);
model_summary_table = buildModelSummary(case_comparisons, model_a_label, model_b_label);

comparison = struct();
comparison.name = 'ESC model comparison';
comparison.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
comparison.enabled_plot = enabled_plot;
comparison.data_input = data_input;
comparison.model_a = struct('label', model_a_label, 'results', result_a);
comparison.model_b = struct('label', model_b_label, 'results', result_b);
comparison.case_count = numel(case_comparisons);
comparison.case_comparisons = case_comparisons;
comparison.case_summary_table = case_summary_table;
comparison.model_summary_table = model_summary_table;
comparison.figure_handle = [];

printComparisonSummary(comparison);
if enabled_plot
    comparison.figure_handle = plotEscModelComparison(comparison);
end

if nargout == 0
    assignin('base', 'escModelComparison', comparison);
end
end

function model_input = normalizeModelInput(model_input)
if ~isstruct(model_input)
    return;
end

if isfield(model_input, 'model') || isfield(model_input, 'nmc30_model')
    return;
end

required = {'QParam', 'RCParam', 'RParam', 'R0Param', 'MParam', 'M0Param', 'GParam', 'etaParam'};
if all(isfield(model_input, required))
    model_input = struct('model', model_input);
end
end

function validateComparableResults(result_a, result_b)
if result_a.case_count ~= result_b.case_count
    error('compareEscModels:CaseCountMismatch', ...
        'Model results are not comparable because they produced %d and %d cases.', ...
        result_a.case_count, result_b.case_count);
end

for idx = 1:result_a.case_count
    time_a = result_a.cases(idx).time_s(:);
    time_b = result_b.cases(idx).time_s(:);
    n_a = numel(time_a);
    n_b = numel(time_b);
    if n_a ~= n_b
        error('compareEscModels:SampleCountMismatch', ...
            'Case %d has %d samples for model A and %d samples for model B.', ...
            idx, n_a, n_b);
    end
    if any(abs(time_a - time_b) > max(1e-9, 1e-9 * max([1; abs(time_a); abs(time_b)])))
        error('compareEscModels:TimeBaseMismatch', ...
            'Case %d does not share the same time vector between both model runs.', idx);
    end
end
end

function [case_comparisons, summary_table] = buildCaseComparisons(result_a, result_b, model_a_label, model_b_label)
case_count = result_a.case_count;
case_cells = cell(case_count, 1);

case_names = cell(case_count, 1);
source_types = cell(case_count, 1);
source_files = cell(case_count, 1);
model_a_rmse_mv = NaN(case_count, 1);
model_b_rmse_mv = NaN(case_count, 1);
delta_rmse_mv = NaN(case_count, 1);
model_a_mae_mv = NaN(case_count, 1);
model_b_mae_mv = NaN(case_count, 1);
delta_mae_mv = NaN(case_count, 1);
model_a_max_abs_mv = NaN(case_count, 1);
model_b_max_abs_mv = NaN(case_count, 1);
delta_max_abs_mv = NaN(case_count, 1);
winner_rmse = cell(case_count, 1);
winner_mae = cell(case_count, 1);
winner_max_abs = cell(case_count, 1);

for idx = 1:case_count
    case_a = result_a.cases(idx);
    case_b = result_b.cases(idx);
    case_name = selectCaseName(case_a, case_b, idx);

    rmse_pair = [case_a.metrics.voltage_rmse_mv, case_b.metrics.voltage_rmse_mv];
    mae_pair = [case_a.metrics.voltage_mae_mv, case_b.metrics.voltage_mae_mv];
    max_pair = [case_a.metrics.voltage_max_abs_error_mv, case_b.metrics.voltage_max_abs_error_mv];

    comparison_entry = struct();
    comparison_entry.index = idx;
    comparison_entry.case_name = case_name;
    comparison_entry.source_type = case_a.source_type;
    comparison_entry.source_file = case_a.source_file;
    comparison_entry.model_a_case = case_a;
    comparison_entry.model_b_case = case_b;
    comparison_entry.metrics = struct( ...
        'model_a_rmse_mv', rmse_pair(1), ...
        'model_b_rmse_mv', rmse_pair(2), ...
        'delta_rmse_mv', rmse_pair(2) - rmse_pair(1), ...
        'model_a_mae_mv', mae_pair(1), ...
        'model_b_mae_mv', mae_pair(2), ...
        'delta_mae_mv', mae_pair(2) - mae_pair(1), ...
        'model_a_max_abs_error_mv', max_pair(1), ...
        'model_b_max_abs_error_mv', max_pair(2), ...
        'delta_max_abs_error_mv', max_pair(2) - max_pair(1), ...
        'winner_rmse', selectWinner(rmse_pair, model_a_label, model_b_label), ...
        'winner_mae', selectWinner(mae_pair, model_a_label, model_b_label), ...
        'winner_max_abs_error', selectWinner(max_pair, model_a_label, model_b_label));
    case_cells{idx} = comparison_entry;

    case_names{idx} = case_name;
    source_types{idx} = case_a.source_type;
    source_files{idx} = case_a.source_file;
    model_a_rmse_mv(idx) = rmse_pair(1);
    model_b_rmse_mv(idx) = rmse_pair(2);
    delta_rmse_mv(idx) = rmse_pair(2) - rmse_pair(1);
    model_a_mae_mv(idx) = mae_pair(1);
    model_b_mae_mv(idx) = mae_pair(2);
    delta_mae_mv(idx) = mae_pair(2) - mae_pair(1);
    model_a_max_abs_mv(idx) = max_pair(1);
    model_b_max_abs_mv(idx) = max_pair(2);
    delta_max_abs_mv(idx) = max_pair(2) - max_pair(1);
    winner_rmse{idx} = comparison_entry.metrics.winner_rmse;
    winner_mae{idx} = comparison_entry.metrics.winner_mae;
    winner_max_abs{idx} = comparison_entry.metrics.winner_max_abs_error;
end

case_comparisons = [case_cells{:}]';
summary_table = table(case_names, source_types, source_files, ...
    model_a_rmse_mv, model_b_rmse_mv, delta_rmse_mv, ...
    model_a_mae_mv, model_b_mae_mv, delta_mae_mv, ...
    model_a_max_abs_mv, model_b_max_abs_mv, delta_max_abs_mv, ...
    winner_rmse, winner_mae, winner_max_abs, ...
    'VariableNames', {'case_name', 'source_type', 'source_file', ...
    'model_a_rmse_mv', 'model_b_rmse_mv', 'delta_rmse_mv', ...
    'model_a_mae_mv', 'model_b_mae_mv', 'delta_mae_mv', ...
    'model_a_max_abs_error_mv', 'model_b_max_abs_error_mv', 'delta_max_abs_error_mv', ...
    'winner_rmse', 'winner_mae', 'winner_max_abs_error'});
end

function summary_table = buildModelSummary(case_comparisons, model_a_label, model_b_label)
rmse_a = arrayfun(@(c) c.metrics.model_a_rmse_mv, case_comparisons);
rmse_b = arrayfun(@(c) c.metrics.model_b_rmse_mv, case_comparisons);
mae_a = arrayfun(@(c) c.metrics.model_a_mae_mv, case_comparisons);
mae_b = arrayfun(@(c) c.metrics.model_b_mae_mv, case_comparisons);
max_a = arrayfun(@(c) c.metrics.model_a_max_abs_error_mv, case_comparisons);
max_b = arrayfun(@(c) c.metrics.model_b_max_abs_error_mv, case_comparisons);

model_name = {model_a_label; model_b_label};
mean_rmse_mv = [mean(rmse_a, 'omitnan'); mean(rmse_b, 'omitnan')];
mean_mae_mv = [mean(mae_a, 'omitnan'); mean(mae_b, 'omitnan')];
max_abs_error_mv = [max(max_a, [], 'omitnan'); max(max_b, [], 'omitnan')];
rmse_case_wins = [countMetricWinners(case_comparisons, 'winner_rmse', model_a_label); ...
    countMetricWinners(case_comparisons, 'winner_rmse', model_b_label)];
mae_case_wins = [countMetricWinners(case_comparisons, 'winner_mae', model_a_label); ...
    countMetricWinners(case_comparisons, 'winner_mae', model_b_label)];
max_abs_case_wins = [countMetricWinners(case_comparisons, 'winner_max_abs_error', model_a_label); ...
    countMetricWinners(case_comparisons, 'winner_max_abs_error', model_b_label)];

summary_table = table(model_name, mean_rmse_mv, mean_mae_mv, max_abs_error_mv, ...
    rmse_case_wins, mae_case_wins, max_abs_case_wins, ...
    'VariableNames', {'model_name', 'mean_rmse_mv', 'mean_mae_mv', 'max_abs_error_mv', ...
    'rmse_case_wins', 'mae_case_wins', 'max_abs_case_wins'});
summary_table = sortrows(summary_table, {'mean_rmse_mv', 'mean_mae_mv'}, {'ascend', 'ascend'});
end

function wins = countMetricWinners(case_comparisons, field_name, model_label)
wins = 0;
for idx = 1:numel(case_comparisons)
    if strcmp(case_comparisons(idx).metrics.(field_name), model_label)
        wins = wins + 1;
    end
end
end

function winner = selectWinner(metric_pair, model_a_label, model_b_label)
if ~all(isfinite(metric_pair))
    winner = 'undetermined';
elseif abs(metric_pair(1) - metric_pair(2)) <= 1e-9
    winner = 'tie';
elseif metric_pair(1) < metric_pair(2)
    winner = model_a_label;
else
    winner = model_b_label;
end
end

function case_name = selectCaseName(case_a, case_b, idx)
if isfield(case_a, 'name') && isfield(case_b, 'name') && strcmp(case_a.name, case_b.name)
    case_name = case_a.name;
elseif isfield(case_a, 'name') && ~isempty(case_a.name)
    case_name = case_a.name;
elseif isfield(case_b, 'name') && ~isempty(case_b.name)
    case_name = case_b.name;
else
    case_name = sprintf('case_%d', idx);
end
end

function label = resolveModelLabel(results, fallback_label, cfg, cfg_field)
label = '';
if isfield(cfg, cfg_field) && ~isempty(cfg.(cfg_field))
    label = char(cfg.(cfg_field));
elseif isfield(results, 'model_name') && ~isempty(results.model_name)
    label = normalizeModelToken(results.model_name);
end

if isempty(label)
    label = fallback_label;
end
end

function printComparisonSummary(comparison)
fprintf('\n%s\n', comparison.name);
fprintf('  %s vs %s\n', comparison.model_a.label, comparison.model_b.label);
fprintf('  Cases: %d\n', comparison.case_count);
disp(comparison.case_summary_table);
fprintf('\nAggregate ranking\n');
disp(comparison.model_summary_table);
fprintf('\n');
end

function fig = plotEscModelComparison(comparison)
case_count = comparison.case_count;
fig_height = max(360, 260 * case_count);
fig = figure('Name', sprintf('%s vs %s', comparison.model_a.label, comparison.model_b.label), ...
    'Color', 'w', 'Position', [100 100 1400 fig_height]);
layout = tiledlayout(case_count, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf('ESC Comparison: %s vs %s', comparison.model_a.label, comparison.model_b.label));

for idx = 1:case_count
    case_info = comparison.case_comparisons(idx);
    plotVoltageOverlay(case_info, comparison.model_a.label, comparison.model_b.label);
    plotErrorOverlay(case_info, comparison.model_a.label, comparison.model_b.label);
    plotMetricBars(case_info, comparison.model_a.label, comparison.model_b.label);
end
end

function plotVoltageOverlay(case_info, model_a_label, model_b_label)
case_a = case_info.model_a_case;
case_b = case_info.model_b_case;
time_s = case_a.time_s(:);

nexttile
plot(time_s, case_a.voltage_v, 'k', 'LineWidth', 1.1, 'DisplayName', 'Measured');
hold on
plot(time_s, case_a.voltage_est_v, 'LineWidth', 1.1, 'DisplayName', model_a_label);
plot(time_s, case_b.voltage_est_v, 'LineWidth', 1.1, 'DisplayName', model_b_label);
grid on
xlabel('Time (s)');
ylabel('Voltage (V)');
title(sprintf('%s | RMSE %.2f vs %.2f mV', ...
    case_info.case_name, case_info.metrics.model_a_rmse_mv, case_info.metrics.model_b_rmse_mv), ...
    'Interpreter', 'none');
legend('Location', 'best');
end

function plotErrorOverlay(case_info, model_a_label, model_b_label)
case_a = case_info.model_a_case;
case_b = case_info.model_b_case;
time_s = case_a.time_s(:);

nexttile
plot(time_s, 1000 * case_a.voltage_error_v, 'LineWidth', 1.1, 'DisplayName', model_a_label);
hold on
plot(time_s, 1000 * case_b.voltage_error_v, 'LineWidth', 1.1, 'DisplayName', model_b_label);
yline(0, 'k--', 'HandleVisibility', 'off');
grid on
xlabel('Time (s)');
ylabel('Voltage Error (mV)');
title(sprintf('Error traces | Better RMSE: %s', case_info.metrics.winner_rmse), ...
    'Interpreter', 'none');
legend('Location', 'best');
end

function plotMetricBars(case_info, model_a_label, model_b_label)
nexttile
metric_values = [ ...
    case_info.metrics.model_a_rmse_mv, case_info.metrics.model_b_rmse_mv; ...
    case_info.metrics.model_a_mae_mv, case_info.metrics.model_b_mae_mv; ...
    case_info.metrics.model_a_max_abs_error_mv, case_info.metrics.model_b_max_abs_error_mv];
bar(metric_values);
grid on
set(gca, 'XTickLabel', {'RMSE', 'MAE', 'MaxAbs'});
ylabel('Error (mV)');
title('Per-case metrics');
legend({model_a_label, model_b_label}, 'Location', 'best');
end

function label = normalizeModelToken(raw_label)
label = cleanupLabel(raw_label);
label_upper = upper(label);
if contains(label_upper, 'OMTLIFE') || contains(label_upper, 'OMT8')
    label = 'OMT8';
elseif contains(label_upper, 'ATL20')
    label = 'ATL20';
elseif contains(label_upper, 'ATL')
    label = 'ATL';
elseif contains(label_upper, 'NMC30')
    label = 'NMC30';
elseif startsWith(label_upper, 'ROM ')
    label = strtrim(extractAfter(label, 4));
end
end

function label = cleanupLabel(raw_label)
label = charOrEmpty(raw_label);
[~, label, ~] = fileparts(label);
label = strrep(label, 'ROM_', '');
label = strrep(label, 'model', '');
label = strrep(label, 'Model', '');
label = strrep(label, '_beta', '');
label = strrep(label, '_', ' ');
label = strtrim(regexprep(label, '\s+', ' '));
end

function out = charOrEmpty(value)
if isempty(value)
    out = '';
elseif isstring(value)
    out = char(value);
else
    out = value;
end
end
