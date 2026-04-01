# Autotuning Layer

This layer adds Bayesian covariance autotuning on top of the benchmark framework.

## Purpose

Use this layer when you want to tune process-noise and sensor-noise covariance parameters for one or more estimators against a benchmark dataset without rewriting the evaluation loop.

The autotuning layer reuses [`runBenchmark.m`](../Evaluation/runBenchmark.m), so tuned results stay aligned with the standard evaluation contract and metrics table.

The default scenario targets:

- ESC model: [`models/ATLmodel.mat`](../models/ATLmodel.mat)
- dataset: [`data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat`](../data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat)
- builder source profile: [`data/evaluation/raw/omtlife8ahc_hp/Bus_CoreBatteryData_Data.mat`](../data/evaluation/raw/omtlife8ahc_hp/Bus_CoreBatteryData_Data.mat)
- estimator list: `{'ROM-EKF'}`
- objective: `SocRmsePct`

## Main Files

- [`runAutotuning.m`](runAutotuning.m)
  Main entry point. Coordinates scenarios and estimators.
- [`defaultAutotuningConfig.m`](defaultAutotuningConfig.m)
  Default scenario, estimator search-space definitions, and BayesOpt settings.
- `tuneEstimatorBayesopt.m`
  BayesOpt engine for one estimator.
- `plotAutotuningHistory.m`
  Plots objective and covariance traces from a final result or checkpoint file.
- `plotAutotunedResults.m`
  Re-plots the saved best benchmark result.
- `printAutotuningSummary.m`
  Prints the compact summary table.

## Quick Start

From the repository root:

```matlab
addpath(genpath('.'));

results = runAutotuning();
printAutotuningSummary(results);
```

If you call `runAutotuning` with no output, it also assigns `autotuningResults` in the base workspace.

To get the summary table without printing:

```matlab
summary_table = buildAutotuningSummaryTable(results.runs);
```

## Parallel Execution

BayesOpt objective evaluations can run in parallel:

```matlab
cfg = defaultAutotuningConfig();
cfg.bayesopt.use_parallel = true;
cfg.bayesopt.auto_start_parallel_pool = true;
cfg.bayesopt.parallel_pool_size = [];

results = runAutotuning(cfg);
```

When parallel execution is unavailable, the layer falls back to serial mode and prints the reason. In serial mode, repeated objective points are cached by default to avoid re-running identical benchmark evaluations.

## Custom Settings

To tune multiple estimators in the same scenario:

```matlab
cfg = defaultAutotuningConfig();
cfg.scenarios(1).estimator_names = {'EaEKF', 'ESC-EKF', 'ESC-SPKF'};
cfg.bayesopt.max_objective_evals = 20;

results = runAutotuning(cfg);
```

To change the objective metric:

```matlab
cfg = defaultAutotuningConfig();
cfg.objective.metric = 'VoltageRmseMv';
```

To point a scenario at a different canonical evaluation dataset and model bundle:

```matlab
cfg = defaultAutotuningConfig();

cfg.scenarios(1).name = 'nmc30_rom';
cfg.scenarios(1).datasetSpec = struct( ...
    'dataset_file', fullfile('data', 'evaluation', 'processed', 'behavioral_nmc30_bss_v1', 'nominal', 'rom_bus_coreBattery_dataset.mat'), ...
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

Search-space definitions live in `cfg.estimator_configs`. Override them when an estimator needs different noise fields or bounds:

```matlab
cfg = defaultAutotuningConfig();
match = strcmp({cfg.estimator_configs.name}, 'EaEKF');
cfg.estimator_configs(match).process_noise_bounds = [1e-7 1e-1];
cfg.estimator_configs(match).sensor_noise_bounds = [1e-7 1e-2];
```

## Output Artifact Policy

Autotuning outputs are split into:

- summary artifacts:
  lightweight, Git-trackable metrics tables, manifests, metadata, and selected published plots
- heavy artifacts:
  local-only aggregate MAT bundles, checkpoint MAT files, BayesOpt checkpoint MAT files, and per-estimator best benchmark result MAT files

Trackable autotuning summaries belong under:

- `results/autotuning/...`
- `results/figures/...`

Use stable promoted summary stems under `results/autotuning/<suite_version>/...`:

- `autotuning__<suite_version>__<scenario_or_model_id>__summary.md`
- `autotuning__<suite_version>__<scenario_or_model_id>__summary.json`
- `autotuning__<suite_version>__<scenario_or_model_id>__tuned_params.json`

Heavy autotuning artifacts stay local under:

- `autotuning/results/...`

Each estimator run may write:

- `autotuning_checkpoint.mat`
- `bayesopt_checkpoint.mat`
- `best_benchmark_results.mat`

Do not commit those heavy MAT files by default.
