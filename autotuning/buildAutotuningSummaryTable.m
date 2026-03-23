function summary_table = buildAutotuningSummaryTable(runs)
% buildAutotuningSummaryTable Build a compact summary table for autotuning runs.

if nargin < 1 || isempty(runs)
    summary_table = table();
    return;
end

n_runs = numel(runs);
scenario = strings(n_runs, 1);
estimator = strings(n_runs, 1);
objective_metric = strings(n_runs, 1);
objective_value = NaN(n_runs, 1);
process_noise_field = strings(n_runs, 1);
process_noise = NaN(n_runs, 1);
sensor_noise_field = strings(n_runs, 1);
sensor_noise = NaN(n_runs, 1);
soc_rmse_pct = NaN(n_runs, 1);
soc_me_pct = NaN(n_runs, 1);
soc_mssd_pct2 = NaN(n_runs, 1);
voltage_rmse_mv = NaN(n_runs, 1);
voltage_me_mv = NaN(n_runs, 1);
voltage_mssd_mv2 = NaN(n_runs, 1);
best_results_file = strings(n_runs, 1);
checkpoint_file = strings(n_runs, 1);

for idx = 1:n_runs
    run = runs(idx);
    scenario(idx) = string(fieldOr(run, 'scenario_name', ""));
    estimator(idx) = string(fieldOr(run, 'estimator_name', ""));
    objective_metric(idx) = string(fieldOr(run, 'objective_metric', ""));
    objective_value(idx) = fieldOr(run, 'best_objective', NaN);
    process_noise_field(idx) = string(fieldOr(run, 'process_noise_field', ""));
    process_noise(idx) = fieldOr(run, 'best_process_noise', NaN);
    sensor_noise_field(idx) = string(fieldOr(run, 'sensor_noise_field', ""));
    sensor_noise(idx) = fieldOr(run, 'best_sensor_noise', NaN);
    checkpoint_file(idx) = string(fieldOr(run, 'checkpoint_file', ""));
    best_results_file(idx) = string(fieldOr(run, 'best_benchmark_results_file', ""));

    if isfield(run, 'best_metrics') && ~isempty(run.best_metrics)
        metrics = run.best_metrics;
        soc_rmse_pct(idx) = fieldOr(metrics, 'SocRmsePct', NaN);
        soc_me_pct(idx) = fieldOr(metrics, 'SocMePct', NaN);
        soc_mssd_pct2(idx) = fieldOr(metrics, 'SocMssdPct2', NaN);
        voltage_rmse_mv(idx) = fieldOr(metrics, 'VoltageRmseMv', NaN);
        voltage_me_mv(idx) = fieldOr(metrics, 'VoltageMeMv', NaN);
        voltage_mssd_mv2(idx) = fieldOr(metrics, 'VoltageMssdMv2', NaN);
    end
end

summary_table = table( ...
    scenario, estimator, objective_metric, objective_value, ...
    process_noise_field, process_noise, sensor_noise_field, sensor_noise, ...
    soc_rmse_pct, soc_me_pct, soc_mssd_pct2, ...
    voltage_rmse_mv, voltage_me_mv, voltage_mssd_mv2, ...
    best_results_file, checkpoint_file, ...
    'VariableNames', { ...
    'Scenario', 'Estimator', 'ObjectiveMetric', 'ObjectiveValue', ...
    'ProcessNoiseField', 'ProcessNoise', 'SensorNoiseField', 'SensorNoise', ...
    'SocRmsePct', 'SocMePct', 'SocMssdPct2', ...
    'VoltageRmseMv', 'VoltageMeMv', 'VoltageMssdMv2', ...
    'BestBenchmarkResultsFile', 'CheckpointFile'});
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end
