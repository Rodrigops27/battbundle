function injection_results = runInjectionStudy(cfg)
% runInjectionStudy Run configurable noise and perturbance injection studies.

if nargin < 1 || isempty(cfg)
    cfg = defaultInjectionConfig();
end

if ~isdeployed
    here = fileparts(which(mfilename));
    if isempty(here)
        here = fileparts(mfilename('fullpath'));
    end
    if isempty(here)
        here = pwd;
    end
else
    here = fileparts(mfilename('fullpath'));
end

evaluation_root = fileparts(here);
repo_root = fileparts(evaluation_root);
addpath(genpath(repo_root));

[cfg, paths] = normalizeConfig(cfg, here, repo_root);
plan = buildPlan(cfg, paths);
[use_parallel, parallel_message] = resolveParallelMode(cfg.parallel);

if ~isempty(parallel_message)
    fprintf('%s\n', parallel_message);
elseif use_parallel
    fprintf('Injection study parallel execution enabled.\n');
end

n_runs = numel(plan);
run_outputs = cell(n_runs, 1);
if use_parallel
    parfor idx = 1:n_runs
        run_outputs{idx} = executePlan(plan(idx), cfg.validation);
    end
else
    for idx = 1:n_runs
        run_outputs{idx} = executePlan(plan(idx), cfg.validation);
    end
end

runs = vertcat(run_outputs{:});
summary_table = buildInjectionSummaryTable(runs);

injection_results = struct();
injection_results.kind = 'injection_results';
injection_results.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
injection_results.config = cfg;
injection_results.runs = runs;
injection_results.summary_table = summary_table;
injection_results.saved_results_file = '';

if cfg.output.save_results
    aggregate_results_file = cfg.output.aggregate_results_file;
    if isempty(aggregate_results_file)
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        aggregate_results_file = fullfile(paths.results_root_abs, ...
            sprintf('%s_%s.mat', sanitizeToken(cfg.run_name), timestamp));
    end
    aggregate_results_file = resolveOutputPath(aggregate_results_file, paths.results_root_abs, repo_root);
    ensureParentFolder(aggregate_results_file);
    injection_results.saved_results_file = aggregate_results_file;
    save(aggregate_results_file, 'injection_results');
end

if nargout == 0
    assignin('base', 'injectionResults', injection_results);
end
end

function [cfg, paths] = normalizeConfig(cfg, injection_root, repo_root)
defaults = defaultInjectionConfig();
cfg = mergeStructDefaults(cfg, defaults);
cfg.parallel = mergeStructDefaults(fieldOr(cfg, 'parallel', struct()), defaults.parallel);
cfg.validation = mergeStructDefaults(fieldOr(cfg, 'validation', struct()), defaults.validation);
cfg.output = mergeStructDefaults(fieldOr(cfg, 'output', struct()), defaults.output);
if ~isfield(cfg, 'scenarios') || isempty(cfg.scenarios)
    cfg.scenarios = defaults.scenarios;
end

paths = struct();
paths.injection_root = injection_root;
paths.repo_root = repo_root;
paths.results_root_abs = resolveAbsolutePath(cfg.output.results_root, repo_root);
paths.datasets_root_abs = resolveAbsolutePath(cfg.output.datasets_root, repo_root);
if exist(paths.results_root_abs, 'dir') ~= 7, mkdir(paths.results_root_abs); end
if exist(paths.datasets_root_abs, 'dir') ~= 7, mkdir(paths.datasets_root_abs); end
cfg.output.results_root = paths.results_root_abs;
cfg.output.datasets_root = paths.datasets_root_abs;
if ~isempty(cfg.output.aggregate_results_file)
    cfg.output.aggregate_results_file = resolveOutputPath( ...
        cfg.output.aggregate_results_file, paths.results_root_abs, repo_root);
end
end

function plan = buildPlan(cfg, paths)
plan = struct([]);
plan_idx = 0;
for scenario_idx = 1:numel(cfg.scenarios)
    scenario = cfg.scenarios(scenario_idx);
    source_dataset = loadOrBuildSourceDataset(scenario, paths.repo_root);
    for case_idx = 1:numel(scenario.injection_cases)
        case_cfg = scenario.injection_cases(case_idx);
        plan_idx = plan_idx + 1;
        plan(plan_idx, 1).scenario_name = scenario.name; %#ok<AGROW>
        plan(plan_idx, 1).case_cfg = case_cfg;
        plan(plan_idx, 1).source_dataset = source_dataset;
        plan(plan_idx, 1).dataset_file = buildInjectedDatasetPath(paths.datasets_root_abs, scenario.name, case_cfg.name);
        plan(plan_idx, 1).benchmark_results_file = buildBenchmarkResultsPath(paths.results_root_abs, scenario.name, case_cfg.name);
        plan(plan_idx, 1).benchmark_dataset_template = scenario.benchmark_dataset_template;
        plan(plan_idx, 1).modelSpec = scenario.modelSpec;
        plan(plan_idx, 1).estimatorSetSpec = scenario.estimatorSetSpec;
        plan(plan_idx, 1).benchmarkFlags = scenario.benchmarkFlags;
    end
end
end

function run_output = executePlan(plan_item, validation_cfg)
[dataset, metadata] = generateInjectedDataset(plan_item.source_dataset, plan_item.dataset_file, plan_item.case_cfg); %#ok<ASGLU>

validation = struct();
if validation_cfg.run_validation
    validation = validateInjectedDataset(dataset, struct( ...
        'show_plots', validation_cfg.show_plots, ...
        'validation_name', sprintf('%s | %s', plan_item.scenario_name, plan_item.case_cfg.name)));
end

dataset_spec = plan_item.benchmark_dataset_template;
dataset_spec.dataset_file = plan_item.dataset_file;
dataset_spec.title_prefix = sprintf('%s %s', dataset_spec.title_prefix, prettyCaseName(plan_item.case_cfg.name));
dataset_spec.voltage_name = getFieldOr(dataset, 'voltage_name', fieldOr(dataset_spec, 'voltage_name', 'Injected voltage'));

flags = plan_item.benchmarkFlags;
flags.results_file = plan_item.benchmark_results_file;
flags.SaveResults = true;

results = runBenchmark(dataset_spec, plan_item.modelSpec, plan_item.estimatorSetSpec, flags);

run_output = struct();
run_output.scenario_name = plan_item.scenario_name;
run_output.case_name = plan_item.case_cfg.name;
run_output.injection_mode = plan_item.case_cfg.mode;
run_output.injected_dataset_file = plan_item.dataset_file;
run_output.benchmark_results_file = results.metadata.saved_results_file;
run_output.validation = validation;
run_output.metrics_table = results.metadata.metrics_table;
run_output.results = results;
end

function source_dataset = loadOrBuildSourceDataset(scenario, repo_root)
spec = scenario.source_dataset;
dataset_file = resolveReadPath(spec.dataset_file, repo_root);
if getCfg(spec, 'rebuild_dataset', false) || exist(dataset_file, 'file') ~= 2
    if ~isfield(spec, 'builder_fcn') || isempty(spec.builder_fcn)
        error('runInjectionStudy:MissingSourceDataset', ...
            'Source dataset file not found and no builder was provided: %s', dataset_file);
    end
    builder_fcn = resolveFunctionHandle(spec.builder_fcn);
    builder_cfg = getCfg(spec, 'builder_cfg', struct());
    source_dataset = builder_fcn(dataset_file, builder_cfg);
    if ~isstruct(source_dataset)
        loaded = load(dataset_file);
        source_dataset = loaded.(getCfg(spec, 'dataset_variable', 'dataset'));
    end
    return;
end

loaded = load(dataset_file);
dataset_var = getCfg(spec, 'dataset_variable', 'dataset');
source_dataset = loaded.(dataset_var);
end

function path_out = buildInjectedDatasetPath(datasets_root, scenario_name, case_name)
path_out = fullfile(datasets_root, sanitizeToken(scenario_name), [sanitizeToken(case_name) '.mat']);
end

function path_out = buildBenchmarkResultsPath(results_root, scenario_name, case_name)
path_out = fullfile(results_root, sanitizeToken(scenario_name), [sanitizeToken(case_name) '_benchmark_results.mat']);
end

function [use_parallel, message] = resolveParallelMode(parallel_cfg)
use_parallel = false;
message = '';
if ~fieldOr(parallel_cfg, 'use_parallel', false)
    return;
end
if exist('gcp', 'file') ~= 2 || exist('parpool', 'file') ~= 2
    message = 'Parallel injection execution requested but Parallel Computing Toolbox functions are unavailable. Falling back to serial execution.';
    return;
end
if ~license('test', 'Distrib_Computing_Toolbox')
    message = 'Parallel injection execution requested but Parallel Computing Toolbox is not licensed. Falling back to serial execution.';
    return;
end

pool = gcp('nocreate');
if isempty(pool) && fieldOr(parallel_cfg, 'auto_start_pool', true)
    try
        pool_size = fieldOr(parallel_cfg, 'pool_size', []);
        if isempty(pool_size)
            parpool('local');
        else
            parpool('local', pool_size);
        end
    catch ME
        message = sprintf('Parallel injection execution requested but a pool could not be started (%s). Falling back to serial execution.', ME.message);
        return;
    end
elseif isempty(pool)
    message = 'Parallel injection execution requested but no pool exists and auto_start_pool is false. Falling back to serial execution.';
    return;
end

use_parallel = true;
end

function pretty_name = prettyCaseName(case_name)
pretty_name = strrep(char(case_name), '_', ' ');
end

function fcn = resolveFunctionHandle(raw_fcn)
if isa(raw_fcn, 'function_handle')
    fcn = raw_fcn;
else
    fcn = str2func(char(raw_fcn));
end
end

function path_out = resolveReadPath(path_in, repo_root)
if exist(path_in, 'file') == 2 || exist(path_in, 'dir') == 7
    path_out = path_in;
elseif isAbsolutePath(path_in)
    path_out = path_in;
else
    path_out = fullfile(repo_root, path_in);
end
end

function path_out = resolveAbsolutePath(path_in, repo_root)
path_in = char(path_in);
if isempty(path_in)
    path_out = path_in;
    return;
end
if isAbsolutePath(path_in)
    path_out = path_in;
    return;
end

repo_candidate = fullfile(repo_root, path_in);
if exist(repo_candidate, 'file') == 2 || exist(repo_candidate, 'dir') == 7
    path_out = repo_candidate;
    return;
end

path_out = fullfile(repo_root, path_in);
end

function path_out = resolveOutputPath(path_in, default_root, repo_root)
if isempty(path_in)
    path_out = default_root;
elseif isAbsolutePath(path_in)
    path_out = path_in;
else
    candidate = fullfile(default_root, path_in);
    if isAbsolutePath(candidate)
        path_out = candidate;
    else
        path_out = fullfile(repo_root, path_in);
    end
end
end

function tf = isAbsolutePath(path_in)
path_in = char(path_in);
tf = numel(path_in) >= 2 && path_in(2) == ':';
end

function ensureParentFolder(file_path)
folder_path = fileparts(file_path);
if ~isempty(folder_path) && exist(folder_path, 'dir') ~= 7
    mkdir(folder_path);
end
end

function out = mergeStructDefaults(in, defaults)
out = defaults;
if isempty(in), return; end
names = fieldnames(in);
for idx = 1:numel(names)
    out.(names{idx}) = in.(names{idx});
end
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end

function value = getFieldOr(s, field_name, default_value)
if isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end

function value = getCfg(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end

function token = sanitizeToken(raw_value)
token = lower(char(raw_value));
token = regexprep(token, '[^a-z0-9]+', '_');
token = regexprep(token, '_+', '_');
token = regexprep(token, '^_|_$', '');
if isempty(token)
    token = 'case';
end
end
