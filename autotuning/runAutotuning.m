function autotuning_results = runAutotuning(cfg)
% runAutotuning Bayesian covariance autotuning entry point for benchmark scenarios.
%
% Example:
%   addpath(genpath('.'));
%   results = runAutotuning();
%
% The autotuning layer reuses runBenchmark for each objective evaluation and
% tunes one estimator at a time. Multiple estimators and scenarios are
% coordinated through cfg.scenarios.

if nargin < 1 || isempty(cfg)
    cfg = defaultAutotuningConfig();
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

repo_root = fileparts(here);
addpath(genpath(repo_root));

[cfg, paths] = normalizeConfig(cfg, here, repo_root);

runs = struct([]);
run_idx = 0;
for scenario_idx = 1:numel(cfg.scenarios)
    scenario_cfg = cfg.scenarios(scenario_idx);
    estimator_names = normalizeNameList(scenario_cfg.estimator_names);
    for estimator_idx = 1:numel(estimator_names)
        estimator_cfg = resolveEstimatorConfig(cfg.estimator_configs, estimator_names{estimator_idx});
        run_idx = run_idx + 1;
        run_result = tuneEstimatorBayesopt(scenario_cfg, estimator_cfg, cfg, paths);
        if run_idx == 1
            runs = run_result;
        else
            runs(run_idx, 1) = run_result; %#ok<AGROW>
        end
    end
end

summary_table = buildAutotuningSummaryTable(runs);

autotuning_results = struct();
autotuning_results.kind = 'autotuning_results';
autotuning_results.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
autotuning_results.repo_root = repo_root;
autotuning_results.config = cfg;
autotuning_results.runs = runs;
autotuning_results.summary_table = summary_table;
autotuning_results.saved_results_file = '';

if cfg.output.save_results
    aggregate_results_file = cfg.output.aggregate_results_file;
    if isempty(aggregate_results_file)
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        aggregate_results_file = fullfile(paths.results_root_abs, ...
            sprintf('%s_%s.mat', sanitizeToken(cfg.run_name), timestamp));
    else
        aggregate_results_file = resolveOutputPath(aggregate_results_file, paths.results_root_abs, repo_root);
    end

    aggregate_dir = fileparts(aggregate_results_file);
    if ~isempty(aggregate_dir) && exist(aggregate_dir, 'dir') ~= 7
        mkdir(aggregate_dir);
    end

    autotuning_results.saved_results_file = aggregate_results_file;
    save(aggregate_results_file, 'autotuning_results');
end

if nargout == 0
    assignin('base', 'autotuningResults', autotuning_results);
end
end

function [cfg, paths] = normalizeConfig(cfg, here, repo_root)
defaults = defaultAutotuningConfig();

cfg = mergeStructDefaults(cfg, defaults);
cfg.objective = mergeStructDefaults(fieldOr(cfg, 'objective', struct()), defaults.objective);
cfg.bayesopt = mergeStructDefaults(fieldOr(cfg, 'bayesopt', struct()), defaults.bayesopt);
cfg.output = mergeStructDefaults(fieldOr(cfg, 'output', struct()), defaults.output);

if ~isfield(cfg, 'estimator_configs') || isempty(cfg.estimator_configs)
    cfg.estimator_configs = defaults.estimator_configs;
end
if ~isfield(cfg, 'scenarios') || isempty(cfg.scenarios)
    cfg.scenarios = defaults.scenarios;
end

paths = struct();
paths.autotuning_root = here;
paths.repo_root = repo_root;
paths.results_root_abs = resolveReadPath(cfg.output.results_root, repo_root);
if exist(paths.results_root_abs, 'dir') ~= 7
    mkdir(paths.results_root_abs);
end

cfg.scenarios = normalizeScenarios(cfg.scenarios, repo_root);
end

function scenarios = normalizeScenarios(scenarios, repo_root)
if ~isstruct(scenarios)
    error('runAutotuning:BadScenarios', 'cfg.scenarios must be a struct array.');
end

estimator_defaults = struct('registry_name', 'all', 'allow_rom_skip', true, 'soc0_percent', [], 'tuning', struct());
objective_flag_defaults = struct( ...
    'SOCfigs', false, ...
    'Vfigs', false, ...
    'Biasfigs', false, ...
    'R0figs', false, ...
    'InnovationACFPACFfigs', false, ...
    'Summaryfigs', false, ...
    'Verbose', false, ...
    'SaveResults', false);
best_flag_defaults = objective_flag_defaults;
best_flag_defaults.SaveResults = true;
best_flag_defaults.results_file = '';

for idx = 1:numel(scenarios)
    scenario = scenarios(idx);
    required = {'name', 'datasetSpec', 'modelSpec'};
    for req_idx = 1:numel(required)
        if ~isfield(scenario, required{req_idx}) || isempty(scenario.(required{req_idx}))
            error('runAutotuning:BadScenario', ...
                'Scenario %d is missing field %s.', idx, required{req_idx});
        end
    end

    if ~isfield(scenario, 'estimator_names') || isempty(scenario.estimator_names)
        error('runAutotuning:MissingEstimators', ...
            'Scenario %s must define at least one estimator name.', scenario.name);
    end
    scenario.estimatorSetSpecBase = mergeStructDefaults( ...
        fieldOr(scenario, 'estimatorSetSpecBase', struct()), estimator_defaults);
    if ~isfield(scenario.estimatorSetSpecBase, 'tuning') || isempty(scenario.estimatorSetSpecBase.tuning)
        scenario.estimatorSetSpecBase.tuning = struct();
    end
    scenario.objectiveFlags = mergeStructDefaults( ...
        fieldOr(scenario, 'objectiveFlags', struct()), objective_flag_defaults);
    scenario.bestResultFlags = mergeStructDefaults( ...
        fieldOr(scenario, 'bestResultFlags', struct()), best_flag_defaults);

    scenario.datasetSpec = normalizeScenarioPaths(scenario.datasetSpec, repo_root);
    scenario.modelSpec = normalizeScenarioPaths(scenario.modelSpec, repo_root);
    scenarios(idx) = scenario;
end
end

function cfg_out = normalizeScenarioPaths(cfg_in, repo_root)
cfg_out = cfg_in;
fields = fieldnames(cfg_out);
for idx = 1:numel(fields)
    value = cfg_out.(fields{idx});
    if ischar(value) || (isstring(value) && isscalar(value))
        value_char = char(value);
        if looksLikePathField(fields{idx}) && ~isempty(value_char)
            cfg_out.(fields{idx}) = resolveReadPath(value_char, repo_root);
        end
    elseif isstruct(value)
        cfg_out.(fields{idx}) = normalizeScenarioPaths(value, repo_root);
    end
end
end

function tf = looksLikePathField(field_name)
tf = endsWith(lower(field_name), '_file') || endsWith(lower(field_name), '_root');
end

function estimator_cfg = resolveEstimatorConfig(estimator_cfgs, estimator_name)
keys = arrayfun(@(s) normalizeNameKey(s.name), estimator_cfgs, 'UniformOutput', false);
match = strcmp(keys, normalizeNameKey(estimator_name));
if ~any(match)
    error('runAutotuning:UnknownEstimatorConfig', ...
        'No estimator config was found for %s.', estimator_name);
end
estimator_cfg = estimator_cfgs(find(match, 1, 'first'));
end

function key = normalizeNameKey(name)
key = regexprep(upper(char(name)), '[^A-Z0-9]', '');
end

function names = normalizeNameList(raw_names)
if ischar(raw_names)
    names = {raw_names};
elseif isa(raw_names, 'string')
    names = cellstr(raw_names(:));
elseif iscell(raw_names)
    names = raw_names(:);
else
    error('runAutotuning:BadEstimatorNames', ...
        'Estimator names must be a char vector, string array, or cell array.');
end
end

function path_out = resolveReadPath(path_in, repo_root)
if exist(path_in, 'file') == 2 || exist(path_in, 'dir') == 7
    path_out = path_in;
    return;
end
if isAbsolutePath(path_in)
    path_out = path_in;
    return;
end
path_out = fullfile(repo_root, path_in);
end

function path_out = resolveOutputPath(path_in, default_root, repo_root)
if isempty(path_in)
    path_out = default_root;
    return;
end
if isAbsolutePath(path_in)
    path_out = path_in;
    return;
end

candidate = fullfile(default_root, path_in);
parent_dir = fileparts(candidate);
if isempty(parent_dir) || exist(parent_dir, 'dir') == 7
    path_out = candidate;
else
    path_out = fullfile(repo_root, path_in);
end
end

function tf = isAbsolutePath(path_in)
path_in = char(path_in);
tf = numel(path_in) >= 2 && path_in(2) == ':';
end

function out = mergeStructDefaults(in, defaults)
out = defaults;
if isempty(in)
    return;
end
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

function token = sanitizeToken(raw_value)
token = lower(char(raw_value));
token = regexprep(token, '[^a-z0-9]+', '_');
token = regexprep(token, '_+', '_');
token = regexprep(token, '^_|_$', '');
if isempty(token)
    token = 'autotuning';
end
end
