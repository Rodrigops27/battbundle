function output = plotAutotuningErrors(resultsInput, cfg)
% plotAutotuningErrors Plot SOC/voltage error figures across autotuned estimators.
%
% Usage:
%   plotAutotuningErrors(results)
%   plotAutotuningErrors('autotuning/results/autotuning_20260324_000225.mat')
%   out = plotAutotuningErrors(resultsInput, cfg)
%
% This helper:
%   1. loads an aggregate autotuning result;
%   2. picks one best run per estimator (lowest objective);
%   3. loads each run's saved best benchmark result;
%   4. merges all estimators into one xKFeval-style results struct;
%   5. calls Evaluation/plotEvalResults so the figures match the standard
%      evaluation plotting style.
%
% cfg fields:
%   scenario_name        optional scenario filter
%   estimator_names      optional estimator-name subset
%   plot_soc_error       default true
%   plot_voltage_error   default false
%   plot_soc             default false
%   plot_voltage         default false
%   plot_r0              default false
%   plot_bias            default false
%   plot_per_estimator_soc default false
%   plot_per_estimator_v default false
%
% Output:
%   output.figures           figure handles returned by plotEvalResults
%   output.combined_results  merged xKFeval-style results struct
%   output.selected_runs     autotuning run structs used in the figure

if nargin < 2 || isempty(cfg)
    cfg = struct();
end

cfg = normalizeConfig(cfg);
data = loadAutotuningData(resultsInput);
selected_runs = selectBestRuns(data.runs, cfg);
combined_results = combineBenchmarkResults(selected_runs);
plot_cfg = buildPlotConfig(cfg);
figures = plotEvalResults(combined_results, plot_cfg);

output = struct();
output.figures = figures;
output.combined_results = combined_results;
output.selected_runs = selected_runs;

if nargout == 0
    assignin('base', 'autotuningCombinedResults', combined_results);
    assignin('base', 'autotuningErrorFigures', figures);
end
end

function cfg = normalizeConfig(cfg)
if ~isfield(cfg, 'scenario_name')
    cfg.scenario_name = '';
end
if ~isfield(cfg, 'estimator_names')
    cfg.estimator_names = {};
end
if ~isfield(cfg, 'plot_soc_error')
    cfg.plot_soc_error = true;
end
if ~isfield(cfg, 'plot_voltage_error')
    cfg.plot_voltage_error = false;
end
if ~isfield(cfg, 'plot_soc')
    cfg.plot_soc = false;
end
if ~isfield(cfg, 'plot_voltage')
    cfg.plot_voltage = false;
end
if ~isfield(cfg, 'plot_r0')
    cfg.plot_r0 = false;
end
if ~isfield(cfg, 'plot_bias')
    cfg.plot_bias = false;
end
if ~isfield(cfg, 'plot_per_estimator_soc')
    cfg.plot_per_estimator_soc = false;
end
if ~isfield(cfg, 'plot_per_estimator_v')
    cfg.plot_per_estimator_v = false;
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
    error('plotAutotuningErrors:NoRunsSelected', ...
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
        warning('plotAutotuningErrors:MissingBestBenchmarkResults', ...
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
        warning('plotAutotuningErrors:UnexpectedEstimatorCount', ...
            'Expected one estimator in %s but found %d. Using the first.', ...
            results_file, numel(estimators));
    end
    combined_results.estimators(end + 1, 1) = estimators(1); %#ok<AGROW>
end

if isempty(combined_results.estimators)
    error('plotAutotuningErrors:NoBenchmarkResultsLoaded', ...
        'Could not load any benchmark result files from the selected autotuning runs.');
end

combined_results.metadata.autotuning_source_files = {selected_runs.best_benchmark_results_file};
combined_results.metadata.autotuning_estimator_names = {selected_runs.estimator_name};
end

function plot_cfg = buildPlotConfig(cfg)
plot_cfg = struct();
plot_cfg.plot_soc_error = cfg.plot_soc_error;
plot_cfg.plot_voltage_error = cfg.plot_voltage_error;
plot_cfg.plot_soc = cfg.plot_soc;
plot_cfg.plot_voltage = cfg.plot_voltage;
plot_cfg.plot_r0 = cfg.plot_r0;
plot_cfg.plot_bias = cfg.plot_bias;
plot_cfg.plot_per_estimator_soc = cfg.plot_per_estimator_soc;
plot_cfg.plot_per_estimator_v = cfg.plot_per_estimator_v;
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

error('plotAutotuningErrors:NoResultsStruct', ...
    'Could not find an xKFeval-style results struct in %s.', file_path);
end

function assertCompatibleDataset(dataset_ref, dataset_candidate, file_path)
if numel(dataset_ref.time_s) ~= numel(dataset_candidate.time_s) || ...
        any(abs(dataset_ref.time_s(:) - dataset_candidate.time_s(:)) > 0)
    error('plotAutotuningErrors:DatasetMismatch', ...
        'Saved benchmark results are not on the same time base: %s', file_path);
end
end

function structs = ensureStructArray(raw)
if isempty(raw)
    structs = repmat(struct(), 0, 1);
elseif isstruct(raw)
    structs = raw(:);
else
    error('plotAutotuningErrors:BadInput', ...
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
    error('plotAutotuningErrors:BadEstimatorNames', ...
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
