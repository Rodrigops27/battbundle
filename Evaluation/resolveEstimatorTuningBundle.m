function bundle = resolveEstimatorTuningBundle(tuning_spec, estimator_names, default_tuning, repo_root)
% resolveEstimatorTuningBundle Resolve shared or profile-based estimator tuning.

if nargin < 1
    tuning_spec = [];
end
if nargin < 2 || isempty(estimator_names)
    estimator_names = {};
end
if nargin < 3 || isempty(default_tuning)
    default_tuning = struct();
end
if nargin < 4
    repo_root = '';
end

estimator_names = normalizeNameList(estimator_names);
bundle = initBundle(tuning_spec, estimator_names, default_tuning);

if isempty(tuning_spec)
    bundle.resolved_estimators = buildDefaultEntries(estimator_names, default_tuning, 'default');
    return;
end

if ~isstruct(tuning_spec)
    error('runBenchmark:BadTuningSpec', ...
        'estimatorSetSpec.tuning must be empty or a struct.');
end

if ~isProfileSpec(tuning_spec)
    shared_tuning = mergeStructDefaults(tuning_spec, default_tuning);
    bundle.shared_tuning = shared_tuning;
    bundle.requested_tuning = tuning_spec;
    bundle.resolved_estimators = buildDefaultEntries(estimator_names, shared_tuning, 'shared_struct');
    return;
end

[profile_cfg, shared_overrides] = normalizeProfileConfig(tuning_spec, repo_root);
bundle.profile_requested = true;
bundle.profile_file = profile_cfg.param_file;
bundle.profile_scenario_name = profile_cfg.scenario_name;
bundle.selection_policy = profile_cfg.selection_policy;
bundle.shared_tuning = mergeStructDefaults(shared_overrides, default_tuning);
bundle.requested_tuning = tuning_spec;

if isempty(profile_cfg.param_file) || exist(profile_cfg.param_file, 'file') ~= 2
    if profile_cfg.fallback_to_default
        if profile_cfg.warn_on_missing_param_file
            warning('runBenchmark:TuningProfileMissing', ...
                'Tuning param file was not found: %s. Falling back to default/shared tuning.', ...
                profile_cfg.param_file);
        end
        bundle.resolved_estimators = buildDefaultEntries( ...
            estimator_names, bundle.shared_tuning, 'profile_missing_file_fallback');
        bundle.fallback_used = true;
        return;
    end
    error('runBenchmark:TuningProfileMissing', ...
        'Tuning param file was not found: %s.', profile_cfg.param_file);
end

runs = loadAutotuningRuns(profile_cfg.param_file);
bundle.profile_found = true;

resolved = repmat(resolvedEntryTemplate(), numel(estimator_names), 1);
used_profile = false;
used_fallback = false;

for idx = 1:numel(estimator_names)
    estimator_name = estimator_names{idx};
    matches = selectMatchingRuns(runs, estimator_name, profile_cfg.scenario_name);
    if isempty(matches)
        if ~profile_cfg.fallback_to_default
            error('runBenchmark:TuningProfileMissingEstimator', ...
                'Estimator %s was not found in tuning param file %s.', ...
                estimator_name, profile_cfg.param_file);
        end
        if profile_cfg.warn_on_missing_estimator
            warning('runBenchmark:TuningProfileMissingEstimator', ...
                'Estimator %s was not found in tuning param file %s. Falling back to default/shared tuning.', ...
                estimator_name, profile_cfg.param_file);
        end
        resolved(idx) = makeResolvedEntry( ...
            estimator_name, bundle.shared_tuning, 'profile_missing_estimator_fallback', ...
            profile_cfg.param_file, profile_cfg.scenario_name, '', false, true);
        used_fallback = true;
        continue;
    end

    selected_run = chooseRun(matches, profile_cfg.selection_policy);
    selected_tuning = extractRunTuning(selected_run, default_tuning);
    selected_tuning = mergeStructDefaults(shared_overrides, selected_tuning);
    resolved(idx) = makeResolvedEntry( ...
        estimator_name, selected_tuning, 'profile', ...
        profile_cfg.param_file, getFieldOr(selected_run, 'scenario_name', ''), ...
        getFieldOr(selected_run, 'objective_metric', ''), true, false);
    used_profile = true;
end

bundle.resolved_estimators = resolved;
bundle.profile_used = used_profile;
bundle.fallback_used = used_fallback;
end

function bundle = initBundle(tuning_spec, estimator_names, default_tuning)
bundle = struct();
bundle.kind = 'resolved_estimator_tuning_bundle';
bundle.requested_tuning = tuning_spec;
bundle.default_tuning = default_tuning;
bundle.shared_tuning = default_tuning;
bundle.profile_requested = false;
bundle.profile_used = false;
bundle.profile_found = false;
bundle.profile_file = '';
bundle.profile_scenario_name = '';
bundle.selection_policy = 'best_objective';
bundle.fallback_used = false;
bundle.resolved_estimators = buildDefaultEntries(estimator_names, default_tuning, 'default');
end

function tf = isProfileSpec(tuning_spec)
tf = isfield(tuning_spec, 'param_file') || ...
    (isfield(tuning_spec, 'kind') && strcmpi(char(tuning_spec.kind), 'autotuning_profile'));
end

function [profile_cfg, shared_overrides] = normalizeProfileConfig(tuning_spec, repo_root)
reserved = { ...
    'kind', 'param_file', 'scenario_name', 'selection_policy', ...
    'fallback_to_default', 'warn_on_missing_param_file', ...
    'warn_on_missing_estimator', 'shared_overrides'};

profile_cfg = struct();
profile_cfg.kind = getFieldOr(tuning_spec, 'kind', 'autotuning_profile');
profile_cfg.param_file = resolvePathForRead(getFieldOr(tuning_spec, 'param_file', ''), repo_root);
profile_cfg.scenario_name = char(getFieldOr(tuning_spec, 'scenario_name', ''));
profile_cfg.selection_policy = lower(char(getFieldOr(tuning_spec, 'selection_policy', 'best_objective')));
profile_cfg.fallback_to_default = logical(getFieldOr(tuning_spec, 'fallback_to_default', true));
profile_cfg.warn_on_missing_param_file = logical(getFieldOr(tuning_spec, 'warn_on_missing_param_file', true));
profile_cfg.warn_on_missing_estimator = logical(getFieldOr(tuning_spec, 'warn_on_missing_estimator', true));

shared_overrides = struct();
if isfield(tuning_spec, 'shared_overrides') && ~isempty(tuning_spec.shared_overrides)
    shared_overrides = tuning_spec.shared_overrides;
end

names = fieldnames(tuning_spec);
for idx = 1:numel(names)
    name = names{idx};
    if any(strcmp(name, reserved))
        continue;
    end
    shared_overrides.(name) = tuning_spec.(name);
end
end

function entries = buildDefaultEntries(estimator_names, tuning, source_kind)
entries = repmat(resolvedEntryTemplate(), numel(estimator_names), 1);
for idx = 1:numel(estimator_names)
    entries(idx) = makeResolvedEntry(estimator_names{idx}, tuning, source_kind, '', '', '', false, false);
end
end

function entry = makeResolvedEntry(estimator_name, tuning, source_kind, source_file, source_scenario, objective_metric, used_profile, fallback_used)
entry = resolvedEntryTemplate();
entry.estimator_name = estimator_name;
entry.tuning = tuning;
entry.source_kind = source_kind;
entry.source_file = source_file;
entry.source_scenario_name = source_scenario;
entry.objective_metric = objective_metric;
entry.used_profile = used_profile;
entry.fallback_used = fallback_used;
end

function entry = resolvedEntryTemplate()
entry = struct( ...
    'estimator_name', '', ...
    'tuning', struct(), ...
    'source_kind', '', ...
    'source_file', '', ...
    'source_scenario_name', '', ...
    'objective_metric', '', ...
    'used_profile', false, ...
    'fallback_used', false);
end

function runs = loadAutotuningRuns(param_file)
loaded = load(param_file);
names = fieldnames(loaded);
for idx = 1:numel(names)
    candidate = loaded.(names{idx});
    if isstruct(candidate) && isfield(candidate, 'runs')
        runs = candidate.runs;
        return;
    end
end
for idx = 1:numel(names)
    candidate = loaded.(names{idx});
    if isstruct(candidate) && isfield(candidate, 'estimator_name') && isfield(candidate, 'best_tuning')
        runs = candidate;
        return;
    end
end
error('runBenchmark:BadTuningProfile', ...
    'Could not find autotuning runs in param file %s.', param_file);
end

function matches = selectMatchingRuns(runs, estimator_name, scenario_name)
runs = runs(:);
keep = false(size(runs));
for idx = 1:numel(runs)
    run = runs(idx);
    if ~isfield(run, 'estimator_name') || ~strcmpi(char(run.estimator_name), estimator_name)
        continue;
    end
    if ~isempty(scenario_name)
        if ~isfield(run, 'scenario_name') || ~strcmpi(char(run.scenario_name), scenario_name)
            continue;
        end
    end
    keep(idx) = true;
end
matches = runs(keep);
end

function run = chooseRun(runs, selection_policy)
runs = runs(:);
switch lower(selection_policy)
    case {'best', 'best_objective'}
        objectives = inf(numel(runs), 1);
        for idx = 1:numel(runs)
            if isfield(runs(idx), 'best_objective') && ~isempty(runs(idx).best_objective)
                objectives(idx) = double(runs(idx).best_objective);
            end
        end
        [~, best_idx] = min(objectives);
        run = runs(best_idx);
    case {'last', 'latest'}
        run = runs(end);
    case 'first'
        run = runs(1);
    otherwise
        error('runBenchmark:BadTuningSelectionPolicy', ...
            'Unknown tuning selection policy "%s".', selection_policy);
end
end

function tuning = extractRunTuning(run, default_tuning)
if isfield(run, 'best_tuning') && ~isempty(run.best_tuning)
    tuning = mergeStructDefaults(run.best_tuning, default_tuning);
    return;
end

tuning = default_tuning;
if isfield(run, 'process_noise_field') && isfield(run, 'best_process_noise')
    tuning.(run.process_noise_field) = run.best_process_noise;
end
if isfield(run, 'sensor_noise_field') && isfield(run, 'best_sensor_noise')
    tuning.(run.sensor_noise_field) = run.best_sensor_noise;
end
end

function names = normalizeNameList(raw_names)
if ischar(raw_names)
    names = {raw_names};
elseif isa(raw_names, 'string')
    names = cellstr(raw_names(:));
elseif iscell(raw_names)
    names = raw_names(:);
else
    error('runBenchmark:BadEstimatorNames', ...
        'estimator_names must be a char vector, string array, or cell array.');
end
end

function path_out = resolvePathForRead(path_in, repo_root)
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
if exist(repo_candidate, 'file') == 2
    path_out = repo_candidate;
    return;
end

if exist(path_in, 'file') == 2
    path_out = path_in;
else
    path_out = repo_candidate;
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

function value = getFieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end
