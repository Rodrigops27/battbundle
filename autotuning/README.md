# Autotuning Layer

This layer adds Bayesian covariance autotuning on top of the benchmark framework.

Initial scope:
- optimization engine: MATLAB `bayesopt`
- plotting: optimization history
- plotting: tuned benchmark results via `plotEvalResults`
- summary/result reporting
- API/configuration for multiple scenarios and estimators
- checkpointed runs that can be inspected while optimization is still running

## Purpose

Use this layer when you want to tune process-noise and sensor-noise covariance parameters for one or more estimators against a benchmark dataset without rewriting the evaluation loop.

The autotuning layer reuses [`runBenchmark.m`](../Evaluation/runBenchmark.m), so tuned results stay aligned with the standard evaluation contract and metrics table.

## Default Example

The built-in default scenario is:
- ESC model: [`models/ATLmodel.mat`](../models/ATLmodel.mat)
- dataset: [`Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`](../Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat)
- estimator list: `{'ROM-EKF'}` (`iterEKF`)
- objective: `SocRmsePct`

## Main Files

- [`runAutotuning.m`](runAutotuning.m)
  Main entry point. Coordinates scenarios and estimators.
- [`defaultAutotuningConfig.m`](defaultAutotuningConfig.m)
  Default scenario, estimator search-space definitions, and BayesOpt settings.
- [`tuneEstimatorBayesopt.m`](tuneEstimatorBayesopt.m)
  BayesOpt engine for one estimator.
- [`plotAutotuningHistory.m`](plotAutotuningHistory.m)
  Plots objective and covariance traces from a final result or checkpoint file.
- [`plotAutotunedResults.m`](plotAutotunedResults.m)
  Re-plots the saved best benchmark result using [`plotEvalResults.m`](../Evaluation/plotEvalResults.m).
- [`plotAutotuningErrors.m`](plotAutotuningErrors.m)
  Merges the saved best benchmark result of each autotuned estimator and calls [`plotEvalResults.m`](../Evaluation/plotEvalResults.m) to plot combined SOC-error and voltage-error figures across all tuned estimators.
- [`plotAutotuningInnovationAcfPacf.m`](plotAutotuningInnovationAcfPacf.m)
  Merges the saved best benchmark result of each autotuned estimator and calls [`plotInnovationAcfPacf.m`](../Evaluation/plotInnovationAcfPacf.m) to plot combined innovation ACF/PACF figures across all tuned estimators.
- [`plotAttributes.m`](plotAttributes.m)
  Merges the saved best benchmark result of each autotuned estimator and plots shared estimator attributes: combined `R0` traces, combined bias traces, and the `EaEKF` covariance plots from the autotuning validation helper.
- [`plotAutotuningCovarianceValidation.m`](plotAutotuningCovarianceValidation.m)
  Replays the tuned `EaEKF` on the saved desktop-evaluation dataset and compares its tracked `SigmaW`/`SigmaV` against the constant tuned ESC-estimator covariances.
- [`printAutotuningSummary.m`](printAutotuningSummary.m)
  Prints the compact summary table.

## Quick Start

From the repository root:

```matlab
addpath(genpath('.'));

results = runAutotuning();
printAutotuningSummary(results);
```

If you call `runAutotuning` with no output, it also assigns `autotuningResults` in the base workspace.

If you already have the per-run struct array and want the summary as a MATLAB table without printing:

```matlab
summary_table = buildAutotuningSummaryTable(autotuning_results.runs);
```

Difference between the two summary helpers:
- `buildAutotuningSummaryTable(...)` returns a table and does not print anything. Use it when you want to sort, filter, export, or compare rows in code.
- `printAutotuningSummary(...)` loads or normalizes the input, builds that same summary table, and prints it to the Command Window. Use it for a quick human-readable check.

## Plot Anytime

Each estimator run writes:
- `autotuning_checkpoint.mat`
- `bayesopt_checkpoint.mat`
- `best_benchmark_results.mat`

The checkpoint file is updated during optimization, so you can inspect progress before the whole run completes:

```matlab
plotAutotuningHistory(fullfile( ...
    'autotuning', 'results', 'atl_bss_esc', 'eaekf', 'autotuning_checkpoint.mat'));
```

After a run completes:

```matlab
plotAutotuningHistory(results);
plotAutotunedResults(results);
```

To reproduce the standard combined SOC-error figure across all autotuned estimators:

```matlab
plotAutotuningErrors( ...
    fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'));
```

To add the voltage-error figure as well:

```matlab
plotAutotuningErrors( ...
    fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'), ...
    struct('plot_voltage_error', true));
```

This helper loads each run's `best_benchmark_results.mat`, merges the estimators into one xKFeval-style results struct, and then reuses [`Evaluation/plotEvalResults.m`](../Evaluation/plotEvalResults.m). Use it when you want the same multi-estimator error figures as the evaluation layer.

To plot innovation ACF/PACF across all autotuned estimators:

```matlab
plotAutotuningInnovationAcfPacf( ...
    fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'));
```

To limit the lag range:

```matlab
plotAutotuningInnovationAcfPacf( ...
    fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'), ...
    struct('max_lag', 40));
```

This helper loads each run's `best_benchmark_results.mat`, merges the estimators into one xKFeval-style results struct, extracts `innovation_pre` from each estimator, and then reuses [`Evaluation/plotInnovationAcfPacf.m`](../Evaluation/plotInnovationAcfPacf.m).

To plot attribute figures from the autotuning aggregate:

```matlab
plotAttributes( ...
    fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'));
```

This wrapper can create:
- one combined `R0` figure for all estimators that track `R0`
- one combined bias figure for all estimators that track bias states
- the `EaEKF` covariance-validation figures

To disable the covariance plots and keep only `R0` and bias:

```matlab
plotAttributes( ...
    fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'), ...
    struct('plot_ea_covariances', false));
```

To validate the tuned ESC covariance levels against the adaptive `EaEKF` covariance trace on the desktop dataset:

```matlab
validation = plotAutotuningCovarianceValidation( ...
    fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'));
```

Use this when the autotuning run has already finished and you want to reopen the saved aggregate MAT file as the single entry point, instead of keeping the original `results` struct in memory.

This plot:
- uses the aggregate autotuning MAT file as the single entry point
- replays the tuned `EaEKF` on [`Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`](../Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat)
- plots the `EaEKF` tracked `SigmaW` diagonal and `SigmaV`
- adds EaEKF-only tracking figures for process and sensor covariance evolution
- overlays the constant tuned ESC-estimator covariances as horizontal lines
- overlays the `EaEKF` mean, median, and mode as horizontal reference lines
- marks the `EaEKF` initial `SigmaW` and `SigmaV`
- prints summary tables comparing the tuned ESC covariances against the EaEKF initial, final, mean, median, and mode values

During a live run, `tuneEstimatorBayesopt` also opens a waitbar when the MATLAB UI is available. It shows completed evaluations, the current optimizer state, elapsed time, and the best objective found so far.

## Tuning Multiple Estimators

Add more names under `cfg.scenarios(k).estimator_names`:

```matlab
cfg = defaultAutotuningConfig();
cfg.scenarios(1).estimator_names = {'EaEKF', 'ESC-EKF', 'ESC-SPKF'};
cfg.bayesopt.max_objective_evals = 20;

results = runAutotuning(cfg);
```

Estimators are tuned independently, one benchmark run per BayesOpt objective evaluation.

If you want BayesOpt to evaluate objective points in parallel:

```matlab
cfg = defaultAutotuningConfig();
cfg.bayesopt.use_parallel = true;
cfg.bayesopt.auto_start_parallel_pool = true;
```

When parallel execution is unavailable, the layer falls back to serial mode and prints the reason. In serial mode, repeated objective points are cached to avoid re-running identical benchmark evaluations.

## Adding A Different Dataset / Model Scenario

Each scenario uses `runBenchmark`-compatible pieces:
- `datasetSpec`
- `modelSpec`
- `estimatorSetSpecBase`
- `objectiveFlags`
- `bestResultFlags`
- `estimator_names`

Example:

```matlab
cfg = defaultAutotuningConfig();

cfg.scenarios(1).name = 'nmc30_rom';
cfg.scenarios(1).datasetSpec = struct( ...
    'dataset_file', fullfile('Evaluation', 'ROMSimData', 'datasets', 'rom_bus_coreBattery_dataset.mat'), ...
    'dataset_variable', 'dataset', ...
    'dataset_soc_field', 'soc_true', ...
    'metric_soc_field', 'soc_true', ...
    'metric_voltage_field', 'voltage_v', ...
    'reference_name', 'ROM reference', ...
    'voltage_name', 'ROM voltage', ...
    'title_prefix', 'NMC30 ROM');

cfg.scenarios(1).modelSpec = struct( ...
    'esc_model_file', fullfile('models', 'NMC30model.mat'), ...
    'rom_model_file', fullfile('models', 'ROM_NMC30_HRA12.mat'), ...
    'tc', 25, ...
    'chemistry_label', 'NMC30', ...
    'require_rom_match', true);

cfg.scenarios(1).estimator_names = {'ROM-EKF'};
results = runAutotuning(cfg);
```

## External Data Registry / Custom Paths

If datasets or source benchmark assets live outside the default `Evaluation/...` layout, point the scenario fields at those paths explicitly.

Example using an external top-level `data/` registry:

```matlab
cfg = defaultAutotuningConfig();

cfg.scenarios(1).name = 'atl_bss_external';
cfg.scenarios(1).datasetSpec = struct( ...
    'dataset_file', fullfile('data', 'Evaluation', 'ESCSimData', 'datasets', 'esc_bus_coreBattery_dataset.mat'), ...
    'dataset_variable', 'dataset', ...
    'dataset_soc_field', 'soc_true', ...
    'metric_soc_field', 'soc_true', ...
    'metric_voltage_field', 'voltage_v', ...
    'reference_name', 'ESC reference', ...
    'voltage_name', 'ESC voltage', ...
    'title_prefix', 'ATL BSS External');

cfg.scenarios(1).modelSpec = struct( ...
    'esc_model_file', fullfile('models', 'ATLmodel.mat'), ...
    'rom_model_file', fullfile('models', 'ROM_ATL20_beta.mat'), ...
    'tc', 25, ...
    'chemistry_label', 'ATL', ...
    'require_rom_match', true);

cfg.scenarios(1).estimator_names = {'ESC-EKF', 'EsSPKF'};

results = runAutotuning(cfg);
```

Notes:
- [`runAutotuning.m`](runAutotuning.m) normalizes scenario path fields recursively for names ending in `_file` or `_root`.
- The most important override points are `cfg.scenarios(k).datasetSpec.*` and `cfg.scenarios(k).modelSpec.*`.
- If you use custom builder configs with extra path fields, prefer names ending in `_file` or `_root` so they are normalized automatically.

## Choosing The Objective

The default objective is `SocRmsePct`.

Change it with:

```matlab
cfg = defaultAutotuningConfig();
cfg.objective.metric = 'VoltageRmseMv';
```

Valid names come from `results.metadata.metrics_table` returned by `runBenchmark`, such as:
- `SocRmsePct`
- `SocMePct`
- `SocMssdPct2`
- `VoltageRmseMv`
- `VoltageMeMv`
- `VoltageMssdMv2`

## Estimator Search Spaces

Search-space definitions live in `cfg.estimator_configs`.

The default mapping is:
- `ROM-EKF`: tunes `sigma_w_ekf` and `sigma_v_ekf`
- ESC-family estimators: tunes `sigma_w_esc` and `sigma_v_esc`

Override them if a future estimator needs different tuning fields or bounds:

```matlab
cfg = defaultAutotuningConfig();
match = strcmp({cfg.estimator_configs.name}, 'EaEKF');
cfg.estimator_configs(match).process_noise_bounds = [1e-7 1e-1];
cfg.estimator_configs(match).sensor_noise_bounds = [1e-7 1e-2];
```

## Outputs

By default the layer saves under `autotuning/results/`.

The aggregate result file contains:
- config snapshot
- per-estimator run structs
- summary table

Each per-estimator run folder contains:
- checkpoint MAT file for plotting during optimization
- BayesOpt checkpoint MAT file
- best benchmark result MAT file
- final per-estimator autotuning MAT file

## Notes

- `bayesopt` requires the Statistics and Machine Learning Toolbox.
- The current engine tunes two variables per estimator: process noise and sensor noise.
- The objective run disables benchmark plotting for speed.
- The final best candidate is re-run through `runBenchmark` and saved so existing plotting tools can be reused.
