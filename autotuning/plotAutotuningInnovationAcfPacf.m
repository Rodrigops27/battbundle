function output = plotAutotuningInnovationAcfPacf(resultsInput, cfg)
% plotAutotuningInnovationAcfPacf Plot innovation ACF/PACF across autotuned estimators.
%
% Usage:
%   plotAutotuningInnovationAcfPacf(results)
%   plotAutotuningInnovationAcfPacf('autotuning/results/autotuning_20260324_000225.mat')
%   out = plotAutotuningInnovationAcfPacf(resultsInput, cfg)
%
% This helper:
%   1. loads an aggregate autotuning result;
%   2. selects one best run per estimator;
%   3. loads each run's saved best benchmark result;
%   4. merges the estimators into one xKFeval-style results struct;
%   5. calls Evaluation/plotInnovationAcfPacf.m using each estimator's
%      pre-fit innovation trace.
%
% cfg fields:
%   scenario_name   optional scenario filter
%   estimator_names optional estimator-name subset
%   max_lag         optional max lag passed to plotInnovationAcfPacf
%   figure_title    optional figure title
%
% Output:
%   output.combined_results  merged xKFeval-style results struct
%   output.selected_runs     autotuning run structs used in the figure
%   output.innovations       cell array of innovation traces
%   output.labels            estimator labels

if nargin < 2 || isempty(cfg)
    cfg = struct();
end

cfg = normalizeConfig(cfg);
data = loadAutotuningData(resultsInput);
selected_runs = selectBestRuns(data.runs, cfg);
combined_results = combineBenchmarkResults(selected_runs);
[innovations, labels] = extractInnovationSeries(combined_results.estimators);

figure_title = cfg.figure_title;
if isempty(figure_title)
    figure_title = defaultFigureTitle(combined_results);
end

plotInnovationAcfPacf(innovations, labels, cfg.max_lag, figure_title);

output = struct();
output.combined_results = combined_results;
output.selected_runs = selected_runs;
output.innovations = innovations;
output.labels = labels;

if nargout == 0
    assignin('base', 'autotuningInnovationResults', combined_results);
    assignin('base', 'autotuningInnovations', innovations);
end
end

function cfg = normalizeConfig(cfg)
if ~isfield(cfg, 'scenario_name')
    cfg.scenario_name = '';
end
if ~isfield(cfg, 'estimator_names')
    cfg.estimator_names = {};
end
if ~isfield(cfg, 'max_lag')
    cfg.max_lag = [];
end
if ~isfield(cfg, 'figure_title')
    cfg.figure_title = '';
end
end

function selected_runs = selectBestRuns(runs, cfg)
runs = ensureStructArray(runs);
target_names = normalizeNameList(cfg.estimator_names);

best_by_name = struct();
order = {};
for idx = 1:numel(runs)
    run = runs(idx);
    if ~isempty(cfg.scenario_name) && ~strcmpi(getFieldOr(run, 'scenario_name', ''), cfg.scenario_name)
        continue;
    end

    estimator_name = getFieldOr(run, 'estimator_name', '');
    if ~isempty(target_names) && ~any(strcmpi(target_names, estimator_name))
        continue;
    end

    key = matlab.lang.makeValidName(lower(estimator_name));
    if ~isfield(best_by_name, key)
        best_by_name.(key) = run;
        order{end + 1} = estimator_name; %#ok<AGROW>
        continue;
    end

    current = best_by_name.(key);
    if getFieldOr(run, 'best_objective', inf) <= getFieldOr(current, 'best_objective', inf)
        best_by_name.(key) = run;
    end
end

selected_runs = runs([]);
for idx = 1:numel(order)
    key = matlab.lang.makeValidName(lower(order{idx}));
    selected_runs(end + 1, 1) = best_by_name.(key); %#ok<AGROW>
end

if isempty(selected_runs)
    error('plotAutotuningInnovationAcfPacf:NoRunsSelected', ...
        'No autotuning runs matched the requested scenario/estimator filters.');
end
end

function combined_results = combineBenchmarkResults(selected_runs)
combined_results = struct();
combined_results.dataset = struct();
combined_results.estimators = repmat(struct(), 0, 1);
combined_results.flags = struct();
combined_results.metadata = struct();

for idx = 1:numel(selected_runs)
    run = selected_runs(idx);
    results_file = getFieldOr(run, 'best_benchmark_results_file', '');
    if isempty(results_file) || exist(results_file, 'file') ~= 2
        warning('plotAutotuningInnovationAcfPacf:MissingBestBenchmarkResults', ...
            'Skipping %s because best benchmark results file was not found: %s', ...
            getFieldOr(run, 'estimator_name', 'unknown'), results_file);
        continue;
    end

    loaded = load(results_file);
    results = extractResultsStruct(loaded, results_file);
    if idx == 1
        combined_results = results;
        combined_results.estimators = results.estimators([]);
    else
        assertCompatibleDataset(combined_results.dataset, results.dataset, results_file);
    end

    estimators = ensureStructArray(results.estimators);
    if numel(estimators) ~= 1
        warning('plotAutotuningInnovationAcfPacf:UnexpectedEstimatorCount', ...
            'Expected one estimator in %s but found %d. Using the first.', ...
            results_file, numel(estimators));
    end
    combined_results.estimators(end + 1, 1) = estimators(1); %#ok<AGROW>
end

if isempty(combined_results.estimators)
    error('plotAutotuningInnovationAcfPacf:NoBenchmarkResultsLoaded', ...
        'Could not load any benchmark result files from the selected autotuning runs.');
end

combined_results.metadata.autotuning_source_files = {selected_runs.best_benchmark_results_file};
combined_results.metadata.autotuning_estimator_names = {selected_runs.estimator_name};
end

function [innovations, labels] = extractInnovationSeries(estimators)
estimators = ensureStructArray(estimators);
innovations = cell(numel(estimators), 1);
labels = cell(numel(estimators), 1);

for idx = 1:numel(estimators)
    innovations{idx} = getFieldOr(estimators(idx), 'innovation_pre', []);
    labels{idx} = getFieldOr(estimators(idx), 'name', sprintf('Estimator %d', idx));
end
end

function title_out = defaultFigureTitle(results)
prefix = '';
if isfield(results, 'dataset') && isfield(results.dataset, 'title_prefix')
    prefix = strtrim(getFieldOr(results.dataset, 'title_prefix', ''));
end
if isempty(prefix)
    title_out = 'Autotuned Innovation ACF/PACF';
else
    title_out = sprintf('Autotuned Innovation ACF/PACF (%s)', prefix);
end
end

function results = extractResultsStruct(loaded, file_path)
names = fieldnames(loaded);
for idx = 1:numel(names)
    candidate = loaded.(names{idx});
    if isstruct(candidate) && isfield(candidate, 'dataset') && isfield(candidate, 'estimators')
        results = candidate;
        return;
    end
end

error('plotAutotuningInnovationAcfPacf:NoResultsStruct', ...
    'Could not find an xKFeval-style results struct in %s.', file_path);
end

function assertCompatibleDataset(dataset_ref, dataset_candidate, file_path)
if numel(dataset_ref.time_s) ~= numel(dataset_candidate.time_s) || ...
        any(abs(dataset_ref.time_s(:) - dataset_candidate.time_s(:)) > 0)
    error('plotAutotuningInnovationAcfPacf:DatasetMismatch', ...
        'Saved benchmark results are not on the same time base: %s', file_path);
end
end

function structs = ensureStructArray(raw)
if isempty(raw)
    structs = repmat(struct(), 0, 1);
elseif isstruct(raw)
    structs = raw(:);
else
    error('plotAutotuningInnovationAcfPacf:BadInput', ...
        'Expected a struct input.');
end
end

function names = normalizeNameList(raw_names)
if isempty(raw_names)
    names = {};
elseif ischar(raw_names)
    names = {raw_names};
elseif isa(raw_names, 'string')
    names = cellstr(raw_names(:));
elseif iscell(raw_names)
    names = raw_names(:);
else
    error('plotAutotuningInnovationAcfPacf:BadEstimatorNames', ...
        'cfg.estimator_names must be char, string, or cellstr.');
end
end

function value = getFieldOr(s, field_name, default_value)
if isstruct(s) && isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end
