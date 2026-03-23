function summary_table = buildInjectionSummaryTable(runs)
% buildInjectionSummaryTable Build per-estimator summary rows for injection studies.

if nargin < 1 || isempty(runs)
    summary_table = table();
    return;
end

rows = struct([]);
row_idx = 0;
for run_idx = 1:numel(runs)
    run = runs(run_idx);
    metrics_table = fieldOr(run, 'metrics_table', table());
    if isempty(metrics_table)
        continue;
    end
    for est_idx = 1:height(metrics_table)
        row_idx = row_idx + 1;
        metric_row = table2struct(metrics_table(est_idx, :));
        rows(row_idx, 1).Scenario = string(run.scenario_name);
        rows(row_idx, 1).InjectionCase = string(run.case_name);
        rows(row_idx, 1).InjectionMode = string(run.injection_mode);
        rows(row_idx, 1).Estimator = string(metric_row.Estimator);
        rows(row_idx, 1).SocRmsePct = metric_row.SocRmsePct;
        rows(row_idx, 1).SocMePct = metric_row.SocMePct;
        rows(row_idx, 1).SocMssdPct2 = metric_row.SocMssdPct2;
        rows(row_idx, 1).VoltageRmseMv = metric_row.VoltageRmseMv;
        rows(row_idx, 1).VoltageMeMv = metric_row.VoltageMeMv;
        rows(row_idx, 1).VoltageMssdMv2 = metric_row.VoltageMssdMv2;
        rows(row_idx, 1).ValidationCurrentRmseA = fieldOr(run.validation, 'current_rmse_a', NaN);
        rows(row_idx, 1).ValidationVoltageRmseMv = fieldOr(run.validation, 'voltage_rmse_mv', NaN);
        rows(row_idx, 1).InjectedDatasetFile = string(run.injected_dataset_file);
        rows(row_idx, 1).BenchmarkResultsFile = string(run.benchmark_results_file);
    end
end

if isempty(rows)
    summary_table = table();
    return;
end

summary_table = struct2table(rows);
end

function value = fieldOr(s, field_name, default_value)
if isstruct(s) && isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end
