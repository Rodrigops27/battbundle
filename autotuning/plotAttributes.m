function output = plotAttributes(resultsInput, cfg)
% plotAttributes Plot tuned-estimator attributes from autotuning results.
%
% Usage:
%   plotAttributes(results)
%   plotAttributes('autotuning/results/autotuning_20260324_000225.mat')
%   out = plotAttributes(resultsInput, cfg)
%
% This helper is intended for autotuning post-analysis. It:
%   1. loads an aggregate autotuning result;
%   2. selects one best run per estimator;
%   3. merges each run's saved best benchmark result;
%   4. plots shared estimator attributes through plotEvalResults:
%        - R0 estimates for all estimators that track R0
%        - bias estimates for all estimators that track bias
%   5. plots EaEKF covariance tracking through
%      plotAutotuningCovarianceValidation.
%
% cfg fields:
%   scenario_name         optional scenario filter
%   estimator_names       optional estimator-name subset
%   plot_r0               default true
%   plot_bias             default true
%   plot_ea_covariances   default true
%   covariance_time_unit  default 'hours'
%   ea_estimator_name     default 'EaEKF'
%
% Output:
%   output.figures             figure handles created by plotEvalResults
%   output.covariance          output of plotAutotuningCovarianceValidation
%   output.combined_results    merged xKFeval-style results struct
%   output.selected_runs       autotuning run structs used in the plots

if nargin < 2 || isempty(cfg)
    cfg = struct();
end

cfg = normalizeConfig(cfg);
data = loadAutotuningData(resultsInput);
selected_runs = selectBestRuns(data.runs, cfg);
combined_results = combineBenchmarkResults(selected_runs);

plot_cfg = struct( ...
    'plot_soc', false, ...
    'plot_voltage', false, ...
    'plot_soc_error', false, ...
    'plot_voltage_error', false, ...
    'plot_r0', cfg.plot_r0, ...
    'plot_bias', cfg.plot_bias, ...
    'plot_per_estimator_soc', false, ...
    'plot_per_estimator_v', false);

figures = plotEvalResults(combined_results, plot_cfg);

covariance = struct();
if cfg.plot_ea_covariances
    covariance_cfg = struct( ...
        'scenario_name', cfg.scenario_name, ...
        'ea_estimator_name', cfg.ea_estimator_name, ...
        'time_unit', cfg.covariance_time_unit);
    covariance = plotAutotuningCovarianceValidation(resultsInput, covariance_cfg);
end

output = struct();
output.figures = figures;
output.covariance = covariance;
output.combined_results = combined_results;
output.selected_runs = selected_runs;

if nargout == 0
    assignin('base', 'autotuningAttributeResults', output);
end
end

function cfg = normalizeConfig(cfg)
if ~isfield(cfg, 'scenario_name')
    cfg.scenario_name = '';
end
if ~isfield(cfg, 'estimator_names')
    cfg.estimator_names = {};
end
if ~isfield(cfg, 'plot_r0')
    cfg.plot_r0 = true;
end
if ~isfield(cfg, 'plot_bias')
    cfg.plot_bias = true;
end
if ~isfield(cfg, 'plot_ea_covariances')
    cfg.plot_ea_covariances = true;
end
if ~isfield(cfg, 'covariance_time_unit') || isempty(cfg.covariance_time_unit)
    cfg.covariance_time_unit = 'hours';
end
if ~isfield(cfg, 'ea_estimator_name') || isempty(cfg.ea_estimator_name)
    cfg.ea_estimator_name = 'EaEKF';
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
    error('plotAttributes:NoRunsSelected', ...
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
        warning('plotAttributes:MissingBestBenchmarkResults', ...
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
        warning('plotAttributes:UnexpectedEstimatorCount', ...
            'Expected one estimator in %s but found %d. Using the first.', ...
            results_file, numel(estimators));
    end
    combined_results.estimators(end + 1, 1) = estimators(1); %#ok<AGROW>
end

if isempty(combined_results.estimators)
    error('plotAttributes:NoBenchmarkResultsLoaded', ...
        'Could not load any benchmark result files from the selected autotuning runs.');
end

combined_results.metadata.autotuning_source_files = {selected_runs.best_benchmark_results_file};
combined_results.metadata.autotuning_estimator_names = {selected_runs.estimator_name};
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

error('plotAttributes:NoResultsStruct', ...
    'Could not find an xKFeval-style results struct in %s.', file_path);
end

function assertCompatibleDataset(dataset_ref, dataset_candidate, file_path)
if numel(dataset_ref.time_s) ~= numel(dataset_candidate.time_s) || ...
        any(abs(dataset_ref.time_s(:) - dataset_candidate.time_s(:)) > 0)
    error('plotAttributes:DatasetMismatch', ...
        'Saved benchmark results are not on the same time base: %s', file_path);
end
end

function structs = ensureStructArray(raw)
if isempty(raw)
    structs = repmat(struct(), 0, 1);
elseif isstruct(raw)
    structs = raw(:);
else
    error('plotAttributes:BadInput', 'Expected a struct input.');
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
    error('plotAttributes:BadEstimatorNames', ...
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
