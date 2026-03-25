function summary = extractInitSocSweepResults(resultsInput, cfg)
% extractInitSocSweepResults Load a saved initial-SOC sweep and rebuild compact summaries.
%
% Usage:
%   summary = extractInitSocSweepResults()
%   summary = extractInitSocSweepResults('Evaluation/initSOCs/results/file.mat')
%   summary = extractInitSocSweepResults(resultsStruct)
%   summary = extractInitSocSweepResults(resultsInput, cfg)
%
% Inputs:
%   resultsInput  sweepInitSocStudy results struct or MAT file path.
%                 If omitted, the function checks the base workspace for
%                 "initSocSweepResults" or "sweepResults".
%   cfg           Optional struct:
%                   result_variable   default ''
%                   display_tables    default true
%                   save_summary      default false
%                   summary_file      default ''
%                   write_csv         default false
%                   csv_root          default ''
%
% Output:
%   summary       Struct with compact tables and sweep metadata.

if nargin < 1
    resultsInput = [];
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end

cfg = normalizeConfig(cfg);
results = loadResultsInput(resultsInput, cfg);
validateResultsStruct(results);

[aggregate_table, best_point_table, selected_points_table] = buildSummaryTables(results);

summary = struct();
summary.source_file = fieldOr(results, 'saved_results_file', '');
summary.created_on = fieldOr(results, 'created_on', '');
summary.study_script = fieldOr(results, 'study_script', '');
summary.dataset_mode = fieldOr(results, 'dataset_mode', '');
summary.estimator_names = results.estimator_names(:).';
summary.soc0_sweep_percent = results.soc0_sweep_percent(:);
summary.soc_rmse_table = results.soc_rmse_table;
summary.voltage_rmse_table = results.voltage_rmse_table;
summary.aggregate_table = aggregate_table;
summary.best_point_table = best_point_table;
summary.selected_points_table = selected_points_table;

if cfg.display_tables
    printSummary(summary);
end

if cfg.save_summary || cfg.write_csv
    [summary_file, csv_root] = resolveOutputTargets(results, cfg);
    summary.summary_file = summary_file;
    summary.csv_root = csv_root;
else
    summary.summary_file = '';
    summary.csv_root = '';
end

if cfg.save_summary
    saveSummaryFile(summary.summary_file, summary);
end

if cfg.write_csv
    writeSummaryCsv(summary, summary.csv_root);
end

if nargout == 0
    assignin('base', 'initSocSweepSummary', summary);
end
end

function cfg = normalizeConfig(cfg)
cfg.result_variable = fieldOr(cfg, 'result_variable', '');
cfg.display_tables = fieldOr(cfg, 'display_tables', true);
cfg.save_summary = logical(fieldOr(cfg, 'save_summary', false));
cfg.summary_file = fieldOr(cfg, 'summary_file', '');
cfg.write_csv = logical(fieldOr(cfg, 'write_csv', false));
cfg.csv_root = fieldOr(cfg, 'csv_root', '');
end

function results = loadResultsInput(resultsInput, cfg)
if isstruct(resultsInput) && isfield(resultsInput, 'soc_rmse_percent') && isfield(resultsInput, 'voltage_rmse_mv')
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
    error('extractInitSocSweepResults:MissingInput', ...
        'Provide a results struct, MAT file path, or a base-workspace results variable.');
end

if isstring(resultsInput)
    resultsInput = char(resultsInput);
end
if ~ischar(resultsInput)
    error('extractInitSocSweepResults:BadInput', ...
        'resultsInput must be a results struct or a MAT file path.');
end
if exist(resultsInput, 'file') ~= 2
    error('extractInitSocSweepResults:MissingFile', ...
        'Results file not found: %s', resultsInput);
end

loaded = load(resultsInput);
results = extractResultsStruct(loaded, cfg.result_variable, resultsInput);
if ~isfield(results, 'saved_results_file') || isempty(results.saved_results_file)
    results.saved_results_file = resultsInput;
end
end

function results = extractResultsStruct(loaded, preferred_name, file_path)
if ~isempty(preferred_name)
    if isfield(loaded, preferred_name)
        results = loaded.(preferred_name);
        return;
    end
    error('extractInitSocSweepResults:MissingVariable', ...
        'Variable "%s" was not found in %s.', preferred_name, file_path);
end

names = fieldnames(loaded);
for idx = 1:numel(names)
    candidate = loaded.(names{idx});
    if isstruct(candidate) && isfield(candidate, 'soc_rmse_percent') && isfield(candidate, 'voltage_rmse_mv')
        results = candidate;
        return;
    end
end

error('extractInitSocSweepResults:NoResultsStruct', ...
    'Could not find a sweepInitSocStudy results struct in %s.', file_path);
end

function validateResultsStruct(results)
required = {'soc0_sweep_percent', 'soc_rmse_percent', 'voltage_rmse_mv', ...
    'soc_rmse_table', 'voltage_rmse_table', 'estimator_names'};
for idx = 1:numel(required)
    if ~isfield(results, required{idx})
        error('extractInitSocSweepResults:BadResultsStruct', ...
            'Results struct is missing field "%s".', required{idx});
    end
end
end

function [aggregate_table, best_point_table, selected_points_table] = buildSummaryTables(results)
estimator_names = results.estimator_names(:).';
soc_rmse = double(results.soc_rmse_percent);
voltage_rmse = double(results.voltage_rmse_mv);
soc0 = double(results.soc0_sweep_percent(:));
n_estimators = numel(estimator_names);

mean_soc = NaN(n_estimators, 1);
best_soc = NaN(n_estimators, 1);
worst_soc = NaN(n_estimators, 1);
mean_voltage = NaN(n_estimators, 1);
best_voltage = NaN(n_estimators, 1);
worst_voltage = NaN(n_estimators, 1);
best_soc_init = NaN(n_estimators, 1);
best_soc_at_best = NaN(n_estimators, 1);
best_voltage_at_best_soc = NaN(n_estimators, 1);

for est_idx = 1:n_estimators
    mean_soc(est_idx) = finiteMean(soc_rmse(:, est_idx));
    best_soc(est_idx) = finiteMin(soc_rmse(:, est_idx));
    worst_soc(est_idx) = finiteMax(soc_rmse(:, est_idx));
    mean_voltage(est_idx) = finiteMean(voltage_rmse(:, est_idx));
    best_voltage(est_idx) = finiteMin(voltage_rmse(:, est_idx));
    worst_voltage(est_idx) = finiteMax(voltage_rmse(:, est_idx));

    best_idx = firstFiniteMinIndex(soc_rmse(:, est_idx));
    if ~isempty(best_idx)
        best_soc_init(est_idx) = soc0(best_idx);
        best_soc_at_best(est_idx) = soc_rmse(best_idx, est_idx);
        best_voltage_at_best_soc(est_idx) = voltage_rmse(best_idx, est_idx);
    end
end

aggregate_table = table( ...
    estimator_names(:), mean_soc, best_soc, worst_soc, ...
    mean_voltage, best_voltage, worst_voltage, ...
    'VariableNames', {'Estimator', 'MeanSocRmsePct', 'BestSocRmsePct', 'WorstSocRmsePct', ...
    'MeanVoltageRmseMv', 'BestVoltageRmseMv', 'WorstVoltageRmseMv'});

best_point_table = table( ...
    estimator_names(:), best_soc_init, best_soc_at_best, best_voltage_at_best_soc, ...
    'VariableNames', {'Estimator', 'BestInitialSocPct', 'SocRmsePctAtBestPoint', 'VoltageRmseMvAtBestPoint'});

selected_indices = unique([1; nearestSweepIndex(soc0, 50); nearestSweepIndex(soc0, 60); numel(soc0)], 'stable');
best_soc_estimator = cell(numel(selected_indices), 1);
best_soc_value = NaN(numel(selected_indices), 1);
best_voltage_estimator = cell(numel(selected_indices), 1);
best_voltage_value = NaN(numel(selected_indices), 1);

for row_idx = 1:numel(selected_indices)
    sweep_idx = selected_indices(row_idx);
    [best_soc_value(row_idx), best_soc_estimator{row_idx}] = bestEstimatorLabel( ...
        estimator_names, soc_rmse(sweep_idx, :));
    [best_voltage_value(row_idx), best_voltage_estimator{row_idx}] = bestEstimatorLabel( ...
        estimator_names, voltage_rmse(sweep_idx, :));
end

selected_points_table = table( ...
    soc0(selected_indices), best_soc_estimator, best_soc_value, best_voltage_estimator, best_voltage_value, ...
    'VariableNames', {'InitialSocPct', 'BestSocRmseEstimator', 'BestSocRmsePct', ...
    'BestVoltageRmseEstimator', 'BestVoltageRmseMv'});
end

function printSummary(summary)
fprintf('\nInitial-SOC sweep extracted summary (%s dataset)\n', upper(summary.dataset_mode));
if ~isempty(summary.source_file)
    fprintf('Source file: %s\n', summary.source_file);
end
fprintf('SOC RMSE table [%%]\n');
disp(summary.soc_rmse_table);
fprintf('Voltage RMSE table [mV]\n');
disp(summary.voltage_rmse_table);
fprintf('Aggregate summary\n');
disp(summary.aggregate_table);
fprintf('Best initial-SOC point per estimator\n');
disp(summary.best_point_table);
fprintf('Selected sweep points\n');
disp(summary.selected_points_table);
end

function [summary_file, csv_root] = resolveOutputTargets(results, cfg)
source_file = fieldOr(results, 'saved_results_file', '');
if isempty(cfg.summary_file)
    if isempty(source_file)
        error('extractInitSocSweepResults:MissingSummaryFile', ...
            'cfg.summary_file is required when the source results have no saved_results_file.');
    end
    [source_dir, source_name] = fileparts(source_file);
    summary_file = fullfile(source_dir, [source_name '_summary.mat']);
else
    summary_file = cfg.summary_file;
end

if isempty(cfg.csv_root)
    [summary_dir, summary_name] = fileparts(summary_file);
    csv_root = fullfile(summary_dir, summary_name);
else
    csv_root = cfg.csv_root;
end
end

function saveSummaryFile(summary_file, summary)
summary_dir = fileparts(summary_file);
if ~isempty(summary_dir) && exist(summary_dir, 'dir') ~= 7
    mkdir(summary_dir);
end
save(summary_file, 'summary', '-v7.3');
fprintf('\nInitial-SOC sweep summary saved to %s\n', summary_file);
end

function writeSummaryCsv(summary, csv_root)
csv_dir = fileparts(csv_root);
if ~isempty(csv_dir) && exist(csv_dir, 'dir') ~= 7
    mkdir(csv_dir);
end

writetable(summary.aggregate_table, [csv_root '_aggregate.csv']);
writetable(summary.best_point_table, [csv_root '_best_points.csv']);
writetable(summary.selected_points_table, [csv_root '_selected_points.csv']);
writetable(addRowNames(summary.soc_rmse_table), [csv_root '_soc_rmse.csv']);
writetable(addRowNames(summary.voltage_rmse_table), [csv_root '_voltage_rmse.csv']);

fprintf('Initial-SOC sweep CSV summary written with prefix %s\n', csv_root);
end

function tbl = addRowNames(tbl_in)
tbl = tbl_in;
row_names = tbl.Properties.RowNames;
tbl.Properties.RowNames = {};
tbl = addvars(tbl, row_names, 'Before', 1, 'NewVariableNames', 'InitialSocLabel');
end

function idx = nearestSweepIndex(values, target)
[~, idx] = min(abs(values - target));
end

function [best_value, label] = bestEstimatorLabel(estimator_names, metric_values)
best_value = finiteMin(metric_values);
if isnan(best_value)
    label = '';
    return;
end
mask = isfinite(metric_values) & abs(metric_values - best_value) <= 1e-12;
matches = estimator_names(mask);
if isempty(matches)
    label = '';
else
    label = strjoin(matches, ' / ');
end
end

function idx = firstFiniteMinIndex(values)
finite_mask = isfinite(values);
idx = [];
if ~any(finite_mask)
    return;
end
finite_values = values(finite_mask);
best_value = min(finite_values);
finite_indices = find(finite_mask);
idx = finite_indices(find(abs(finite_values - best_value) <= 1e-12, 1, 'first'));
end

function value = finiteMean(values)
mask = isfinite(values);
if any(mask)
    value = mean(values(mask));
else
    value = NaN;
end
end

function value = finiteMin(values)
mask = isfinite(values);
if any(mask)
    value = min(values(mask));
else
    value = NaN;
end
end

function value = finiteMax(values)
mask = isfinite(values);
if any(mask)
    value = max(values(mask));
else
    value = NaN;
end
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end
