function estimator_result = tuneEstimatorBayesopt(scenario_cfg, estimator_cfg, global_cfg, paths)
% tuneEstimatorBayesopt Tune one estimator with MATLAB bayesopt.

ensureBayesoptAvailable();

run_dir = fullfile(paths.results_root_abs, sanitizeToken(scenario_cfg.name), sanitizeToken(estimator_cfg.name));
if exist(run_dir, 'dir') ~= 7
    mkdir(run_dir);
end

checkpoint_file = fullfile(run_dir, 'autotuning_checkpoint.mat');
bayesopt_checkpoint_file = fullfile(run_dir, 'bayesopt_checkpoint.mat');
best_benchmark_results_file = fullfile(run_dir, 'best_benchmark_results.mat');
estimator_result_file = fullfile(run_dir, 'autotuning_result.mat');

process_var = optimizableVariable( ...
    'process_noise', estimator_cfg.process_noise_bounds, ...
    'Transform', 'log');
sensor_var = optimizableVariable( ...
    'sensor_noise', estimator_cfg.sensor_noise_bounds, ...
    'Transform', 'log');

objective_cfg = global_cfg.objective;
bayesopt_cfg = global_cfg.bayesopt;
[use_parallel, parallel_message] = resolveParallelMode(bayesopt_cfg);
cache_enabled = fieldOr(bayesopt_cfg, 'cache_objective_evaluations', true) && ~use_parallel;
objective_cache = [];
if cache_enabled
    objective_cache = containers.Map('KeyType', 'char', 'ValueType', 'double');
end

progress = struct();
progress.max_evals = bayesopt_cfg.max_objective_evals;
progress.start_tic = tic;
progress.waitbar = [];
progress.show_waitbar = fieldOr(bayesopt_cfg, 'show_waitbar', true);

if progress.show_waitbar
    progress.waitbar = createProgressWaitbar(scenario_cfg.name, estimator_cfg.name, objective_cfg.metric);
end
cleanup_waitbar = onCleanup(@() closeProgressWaitbar(progress.waitbar)); %#ok<NASGU>

fprintf('\nAutotuning %s | %s with objective %s\n', ...
    scenario_cfg.name, estimator_cfg.name, objective_cfg.metric);
if ~isempty(parallel_message)
    fprintf('%s\n', parallel_message);
elseif use_parallel
    fprintf('BayesOpt parallel evaluation enabled.\n');
end

    function objective = evaluateCandidate(X)
        candidate = convertCandidate(X);
        cache_key = '';
        if cache_enabled
            cache_key = candidateKey(candidate);
            if isKey(objective_cache, cache_key)
                objective = objective_cache(cache_key);
                return;
            end
        end
        try
            run_results = evaluateBenchmarkCandidate(candidate);
            metrics = extractMetricsStruct(run_results, estimator_cfg.name);
            objective = extractObjective(metrics, objective_cfg.metric);
        catch ME
            objective = objective_cfg.failure_objective;
            fprintf('Autotuning penalty for %s | %s: %s\n', ...
                scenario_cfg.name, estimator_cfg.name, ME.message);
        end
        if cache_enabled
            objective_cache(cache_key) = objective;
        end
    end

    function stop = saveCheckpoint(opt_results, state)
        stop = false;
        snapshot = buildCheckpointStruct(opt_results, state);
        save(checkpoint_file, 'snapshot');
        updateProgressWaitbar(progress.waitbar, snapshot);
    end

results = bayesopt( ...
    @evaluateCandidate, ...
    [process_var, sensor_var], ...
    'MaxObjectiveEvaluations', bayesopt_cfg.max_objective_evals, ...
    'NumSeedPoints', bayesopt_cfg.num_seed_points, ...
    'IsObjectiveDeterministic', bayesopt_cfg.is_objective_deterministic, ...
    'AcquisitionFunctionName', bayesopt_cfg.acquisition_function_name, ...
    'UseParallel', use_parallel, ...
    'Verbose', bayesopt_cfg.verbose, ...
    'PlotFcn', {}, ...
    'OutputFcn', @saveCheckpoint, ...
    'SaveFileName', bayesopt_checkpoint_file);

best_candidate = convertCandidate(results.XAtMinObjective);
best_tuning = scenario_cfg.estimatorSetSpecBase.tuning;
best_tuning.(estimator_cfg.process_noise_field) = best_candidate.process_noise;
best_tuning.(estimator_cfg.sensor_noise_field) = best_candidate.sensor_noise;

best_metrics = struct();
best_benchmark_results = struct();
if global_cfg.output.generate_best_benchmark_results
    [best_benchmark_results, best_metrics] = rerunBestCandidate(best_candidate, best_benchmark_results_file);
else
    best_benchmark_results = evaluateBenchmarkCandidate(best_candidate);
    best_metrics = extractMetricsStruct(best_benchmark_results, estimator_cfg.name);
end

history_table = buildHistoryTable(results);

estimator_result = struct();
estimator_result.kind = 'autotuning_estimator_result';
estimator_result.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
estimator_result.scenario_name = scenario_cfg.name;
estimator_result.estimator_name = estimator_cfg.name;
estimator_result.objective_metric = objective_cfg.metric;
estimator_result.best_objective = results.MinObjective;
estimator_result.process_noise_field = estimator_cfg.process_noise_field;
estimator_result.sensor_noise_field = estimator_cfg.sensor_noise_field;
estimator_result.best_process_noise = best_candidate.process_noise;
estimator_result.best_sensor_noise = best_candidate.sensor_noise;
estimator_result.best_tuning = best_tuning;
estimator_result.best_metrics = best_metrics;
estimator_result.history_table = history_table;
estimator_result.checkpoint_file = checkpoint_file;
estimator_result.bayesopt_checkpoint_file = bayesopt_checkpoint_file;
estimator_result.best_benchmark_results_file = best_benchmark_results_file;
estimator_result.bayesopt_min_objective_trace = safeColumn(results, 'MinObjectiveTrace');
estimator_result.bayesopt_objective_trace = safeColumn(results, 'ObjectiveTrace');
estimator_result.best_benchmark_metadata = fieldOr(best_benchmark_results, 'metadata', struct());

if global_cfg.output.save_estimator_result_files
    estimator_result.estimator_result_file = estimator_result_file;
    save(estimator_result_file, 'estimator_result');
end

saveCheckpoint(results, 'done');

    function run_results = evaluateBenchmarkCandidate(candidate)
        tuning = scenario_cfg.estimatorSetSpecBase.tuning;
        tuning.(estimator_cfg.process_noise_field) = candidate.process_noise;
        tuning.(estimator_cfg.sensor_noise_field) = candidate.sensor_noise;

        estimator_set_spec = scenario_cfg.estimatorSetSpecBase;
        estimator_set_spec.estimator_names = {estimator_cfg.name};
        estimator_set_spec.tuning = tuning;

        objective_flags = scenario_cfg.objectiveFlags;
        objective_flags.SaveResults = false;
        if isfield(objective_flags, 'results_file')
            objective_flags.results_file = '';
        end

        run_results = runBenchmark( ...
            scenario_cfg.datasetSpec, ...
            scenario_cfg.modelSpec, ...
            estimator_set_spec, ...
            objective_flags);
    end

    function [run_results, metrics] = rerunBestCandidate(candidate, results_file)
        tuning = scenario_cfg.estimatorSetSpecBase.tuning;
        tuning.(estimator_cfg.process_noise_field) = candidate.process_noise;
        tuning.(estimator_cfg.sensor_noise_field) = candidate.sensor_noise;

        estimator_set_spec = scenario_cfg.estimatorSetSpecBase;
        estimator_set_spec.estimator_names = {estimator_cfg.name};
        estimator_set_spec.tuning = tuning;

        best_flags = scenario_cfg.bestResultFlags;
        best_flags.SaveResults = true;
        best_flags.results_file = results_file;

        run_results = runBenchmark( ...
            scenario_cfg.datasetSpec, ...
            scenario_cfg.modelSpec, ...
            estimator_set_spec, ...
            best_flags);
        metrics = extractMetricsStruct(run_results, estimator_cfg.name);
    end

    function snapshot = buildCheckpointStruct(opt_results, state)
        snapshot = struct();
        snapshot.kind = 'autotuning_estimator_result';
        snapshot.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        snapshot.scenario_name = scenario_cfg.name;
        snapshot.estimator_name = estimator_cfg.name;
        snapshot.objective_metric = objective_cfg.metric;
        snapshot.process_noise_field = estimator_cfg.process_noise_field;
        snapshot.sensor_noise_field = estimator_cfg.sensor_noise_field;
        snapshot.best_objective = safeScalar(opt_results, 'MinObjective');
        snapshot.best_process_noise = NaN;
        snapshot.best_sensor_noise = NaN;
        snapshot.history_table = buildHistoryTable(opt_results);
        snapshot.checkpoint_file = checkpoint_file;
        snapshot.bayesopt_checkpoint_file = bayesopt_checkpoint_file;
        snapshot.best_benchmark_results_file = best_benchmark_results_file;
        snapshot.optimizer_state = state;
        snapshot.parallel_enabled = use_parallel;
        snapshot.parallel_message = parallel_message;
        snapshot.elapsed_seconds = toc(progress.start_tic);
        snapshot.max_objective_evals = progress.max_evals;
        snapshot.completed_evaluations = height(snapshot.history_table);

        if ~isempty(snapshot.history_table)
            snapshot.best_process_noise = snapshot.history_table.BestProcessNoise(end);
            snapshot.best_sensor_noise = snapshot.history_table.BestSensorNoise(end);
        end
    end
end

function ensureBayesoptAvailable()
if exist('bayesopt', 'file') ~= 2
    error('tuneEstimatorBayesopt:MissingBayesopt', ...
        ['MATLAB bayesopt was not found. Install or license the Statistics and ', ...
        'Machine Learning Toolbox before using the autotuning layer.']);
end
end

function history_table = buildHistoryTable(opt_results)
x_trace = safeTraceTable(opt_results);
if isempty(x_trace)
    history_table = table();
    return;
end

objective = safeColumn(opt_results, 'ObjectiveTrace');
best_objective = safeColumn(opt_results, 'MinObjectiveTrace');
if isempty(best_objective) && ~isempty(objective)
    best_objective = runningMinimum(objective);
end

best_index = runningMinIndex(best_objective, objective);
process_noise = x_trace.process_noise(:);
sensor_noise = x_trace.sensor_noise(:);
best_process_noise = process_noise(best_index);
best_sensor_noise = sensor_noise(best_index);

history_table = table( ...
    (1:height(x_trace)).', ...
    process_noise, ...
    sensor_noise, ...
    objective(:), ...
    best_objective(:), ...
    best_process_noise(:), ...
    best_sensor_noise(:), ...
    'VariableNames', { ...
    'Evaluation', 'ProcessNoise', 'SensorNoise', 'Objective', ...
    'BestObjective', 'BestProcessNoise', 'BestSensorNoise'});
end

function idx = runningMinIndex(best_objective, objective)
n = numel(best_objective);
idx = ones(n, 1);
if n == 0
    return;
end

current_idx = 1;
current_best = objective(1);
for k = 1:n
    if objective(k) <= current_best || (~isfinite(current_best) && isfinite(objective(k)))
        current_best = objective(k);
        current_idx = k;
    end
    if isfinite(best_objective(k))
        current_best = best_objective(k);
    end
    idx(k) = current_idx;
end
end

function values = runningMinimum(values_in)
values = values_in(:);
if isempty(values)
    return;
end
for idx = 2:numel(values)
    values(idx) = min(values(idx), values(idx - 1));
end
end

function x_trace = safeTraceTable(opt_results)
x_trace = table();
if ~isprop(opt_results, 'XTrace')
    return;
end
if isempty(opt_results.XTrace)
    return;
end

x_trace = opt_results.XTrace;
if ~istable(x_trace)
    x_trace = struct2table(x_trace);
end
end

function values = safeColumn(opt_results, property_name)
values = [];
if isprop(opt_results, property_name)
    values = opt_results.(property_name);
end
if isempty(values)
    values = [];
end
end

function value = safeScalar(opt_results, property_name)
value = NaN;
if isprop(opt_results, property_name) && ~isempty(opt_results.(property_name))
    value = opt_results.(property_name);
end
end

function candidate = convertCandidate(raw_candidate)
candidate = struct();
if istable(raw_candidate)
    if height(raw_candidate) ~= 1
        error('tuneEstimatorBayesopt:BadCandidate', ...
            'Expected a single-row candidate table.');
    end
    candidate.process_noise = raw_candidate.process_noise(1);
    candidate.sensor_noise = raw_candidate.sensor_noise(1);
elseif isstruct(raw_candidate)
    candidate.process_noise = raw_candidate.process_noise;
    candidate.sensor_noise = raw_candidate.sensor_noise;
else
    error('tuneEstimatorBayesopt:BadCandidate', ...
        'Unsupported candidate type returned by bayesopt.');
end
end

function metrics = extractMetricsStruct(run_results, estimator_name)
metrics_table = run_results.metadata.metrics_table;
match = strcmp(metrics_table.Estimator, estimator_name);
if ~any(match)
    error('tuneEstimatorBayesopt:MissingMetrics', ...
        'Estimator %s was not found in the benchmark metrics table.', estimator_name);
end

row = metrics_table(find(match, 1, 'first'), :);
metrics = table2struct(row);
end

function objective = extractObjective(metrics, metric_name)
if ~isfield(metrics, metric_name)
    error('tuneEstimatorBayesopt:BadObjectiveMetric', ...
        'Objective metric %s is not available in the benchmark metrics table.', metric_name);
end
objective = metrics.(metric_name);
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
    token = 'run';
end
end

function key = candidateKey(candidate)
key = sprintf('w=%.16g|v=%.16g', candidate.process_noise, candidate.sensor_noise);
end

function [use_parallel, message] = resolveParallelMode(bayesopt_cfg)
use_parallel = false;
message = '';
if ~fieldOr(bayesopt_cfg, 'use_parallel', false)
    return;
end

if exist('gcp', 'file') ~= 2 || exist('parpool', 'file') ~= 2
    message = 'Parallel BayesOpt requested but Parallel Computing Toolbox functions are unavailable. Falling back to serial execution.';
    return;
end

if ~license('test', 'Distrib_Computing_Toolbox')
    message = 'Parallel BayesOpt requested but Parallel Computing Toolbox is not licensed. Falling back to serial execution.';
    return;
end

pool = gcp('nocreate');
if isempty(pool) && fieldOr(bayesopt_cfg, 'auto_start_parallel_pool', true)
    try
        pool_size = fieldOr(bayesopt_cfg, 'parallel_pool_size', []);
        if isempty(pool_size)
            parpool('local');
        else
            parpool('local', pool_size);
        end
    catch ME
        message = sprintf('Parallel BayesOpt requested but a pool could not be started (%s). Falling back to serial execution.', ME.message);
        return;
    end
elseif isempty(pool)
    message = 'Parallel BayesOpt requested but no pool exists and auto_start_parallel_pool is false. Falling back to serial execution.';
    return;
end

use_parallel = true;
end

function hwait = createProgressWaitbar(scenario_name, estimator_name, metric_name)
hwait = [];
try
    hwait = waitbar(0, 'Initializing Bayesian optimization...', ...
        'Name', sprintf('Autotuning | %s | %s | %s', scenario_name, estimator_name, metric_name));
catch
    hwait = [];
end
end

function updateProgressWaitbar(hwait, snapshot)
if isempty(hwait) || ~ishandle(hwait)
    return;
end

completed = fieldOr(snapshot, 'completed_evaluations', 0);
max_evals = max(fieldOr(snapshot, 'max_objective_evals', 1), 1);
fraction = min(completed / max_evals, 1);
elapsed_seconds = fieldOr(snapshot, 'elapsed_seconds', NaN);
elapsed_min = elapsed_seconds / 60;
best_objective = fieldOr(snapshot, 'best_objective', NaN);

message = sprintf('Eval %d/%d | state=%s | best=%g | elapsed=%.1f min', ...
    completed, max_evals, fieldOr(snapshot, 'optimizer_state', 'iteration'), best_objective, elapsed_min);
waitbar(fraction, hwait, message);
drawnow limitrate;
end

function closeProgressWaitbar(hwait)
if ~isempty(hwait) && ishandle(hwait)
    close(hwait);
end
end
