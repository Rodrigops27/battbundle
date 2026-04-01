# Injection Study Layer

This layer generates derived evaluation datasets from a nominal benchmark dataset, validates the generated case, and runs [`runBenchmark.m`](../runBenchmark.m) on the derived output.

## Purpose

Use this layer when you want to:

- generate injected datasets from a clean benchmark dataset
- validate the injected dataset against the clean source trace
- benchmark one or more estimators on the injected dataset
- summarize saved injection-study results later

The default desktop scenario uses:

- source dataset: [`data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat`](../../data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat)
- ESC model: [`models/ATLmodel.mat`](../../models/ATLmodel.mat)
- ROM model: [`models/ROM_ATL20_beta.mat`](../../models/ROM_ATL20_beta.mat)
- default estimator set:
  `EsSPKF`, `ESC-SPKF`, `EaEKF`, `EbSPKF`, `EBiSPKF`, `EDUKF`, `Em7SPKF`, `ESC-EKF`
- default cases: `noise` and `perturbance`

## Canonical Output Layout

Generated evaluation cases save under:

`data/evaluation/derived/<suite_version>/<dataset_family>/<case_id>/`

Each case directory contains:

- `dataset.mat`
- `manifest.json`
- optional `manifest.mat`

Example:

`data/evaluation/derived/desktop_atl20_bss_v1/stochastic_sensor/case_001/`

## Main Files

- [`runInjectionStudy.m`](runInjectionStudy.m)
  Main API/configuration entry point.
- [`defaultInjectionConfig.m`](defaultInjectionConfig.m)
  Default ATL desktop scenario and default injection cases.
- [`generateInjectedDataset.m`](generateInjectedDataset.m)
  Dataset-generation helper for noise and perturbance cases.
- [`validateInjectedDataset.m`](validateInjectedDataset.m)
  Validation helper for clean-vs-injected traces.
- `printInjectionSummary.m`
  Console summary helper.

## Quick Start

```matlab
addpath(genpath('.'));

cfg = defaultInjectionConfig();
cfg.validation.show_plots = false;
results = runInjectionStudy(cfg);
```

## Parallel Execution

Independent injection cases can run in parallel:

```matlab
cfg = defaultInjectionConfig();
cfg.parallel.use_parallel = true;
cfg.parallel.auto_start_pool = true;
cfg.parallel.pool_size = [];

results = runInjectionStudy(cfg);
```

When parallel execution is unavailable, the layer falls back to serial mode and prints the reason.

## Custom Settings

For a custom `noise` case, the main configurable inputs are:

- `name`
- `mode = 'noise'`
- `dataset_family = 'stochastic_sensor'`
- `voltage_std_mv`
- `current_error_percent`
- `random_seed`
- `overwrite`

Example:

```matlab
cfg = defaultInjectionConfig();
cfg.scenarios(1).injection_cases = struct( ...
    'name', 'noise_special', ...
    'mode', 'noise', ...
    'dataset_family', 'stochastic_sensor', ...
    'augmentation_type', 'noise', ...
    'voltage_std_mv', 8, ...
    'current_error_percent', 2.5, ...
    'random_seed', 21, ...
    'overwrite', true);

results = runInjectionStudy(cfg);
```

For a custom `perturbance` case, the main configurable inputs are:

- `name`
- `mode = 'perturbance'`
- `dataset_family = 'perturbance'`
- `current_gain`
- `current_offset_a`
- `voltage_gain_fault`
- `voltage_offset_mv`
- `random_seed`
- `overwrite`

Example:

```matlab
cfg = defaultInjectionConfig();
cfg.scenarios(1).injection_cases = struct( ...
    'name', 'perturbance_special', ...
    'mode', 'perturbance', ...
    'dataset_family', 'perturbance', ...
    'augmentation_type', 'perturbance', ...
    'current_gain', 1.05, ...
    'current_offset_a', 0.05, ...
    'voltage_gain_fault', 4e-4, ...
    'voltage_offset_mv', 1.5, ...
    'random_seed', 22, ...
    'overwrite', true);

results = runInjectionStudy(cfg);
```

To benchmark injected cases with tuned covariances resolved from an autotuning MAT file:

```matlab
cfg = defaultInjectionConfig();
cfg.scenarios(1).estimatorSetSpec.tuning = struct( ...
    'kind', 'autotuning_profile', ...
    'param_file', fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'), ...
    'scenario_name', 'atl_bss_esc', ...
    'selection_policy', 'best_objective', ...
    'fallback_to_default', true);

results = runInjectionStudy(cfg);
```

## Manifest Semantics

`runInjectionStudy.m` writes case metadata with stable identifiers:

- `dataset_id`
- `parent_dataset_id`
- `suite_version`
- `dataset_family`
- `augmentation_type`
- `case_id`
- `source_dataset_path`
- `resolved_output_path`
- `random_seed`
- `benchmark_contract_version`
- `injection_config`

Example dataset id:

`desktop_atl20_bss_v1__stochastic_sensor__case_001`

## Notes

- The benchmark engine is still `runBenchmark` / `xKFeval`.
- Dataset validation runs before the benchmark by default.
- The default metric-voltage comparison uses the clean voltage trace stored as `voltage_v_true`.
- Derived `dataset.mat` files are reproducible workflow artifacts and are Git-ignored by default; lightweight manifests remain trackable.
