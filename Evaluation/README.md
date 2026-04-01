# Evaluation Layer

This layer contains the benchmark runner, evaluation dataset builders, and robustness-study wrappers.

## Purpose

Use this layer when you want to:

- benchmark several estimators on the same ESC or ROM-backed dataset
- compare SOC and voltage metrics across estimators
- run initialization, noise, or injection sensitivity studies
- build canonical evaluation datasets from raw application profiles

The default desktop scenario uses:

- ESC model: [`models/ATLmodel.mat`](../models/ATLmodel.mat)
- benchmark dataset: [`data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat`](../data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat)

## Canonical Evaluation Policy

Benchmark/runtime evaluation dataset reads must resolve only under:

- `data/evaluation/processed`
- `data/evaluation/derived`

Source-profile builders and conversion scripts may read from:

- `data/evaluation/raw/...`

Legacy `Evaluation/.../datasets/...` roots are intentionally unsupported.

## Canonical Suites

- ESC desktop nominal dataset:
  `data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat`
- ROM behavioral nominal dataset:
  `data/evaluation/processed/behavioral_nmc30_bss_v1/nominal/rom_bus_coreBattery_dataset.mat`
- Raw source profile for dataset builders:
  `data/evaluation/raw/omtlife8ahc_hp/Bus_CoreBatteryData_Data.mat`
- Synthetic ESC builder assets:
  `data/evaluation/synthetic/ESCSimData/...`
- Synthetic ROM builder assets:
  `data/evaluation/synthetic/ROMSimData/...`

## Main Entry Points

- [`runBenchmark.m`](runBenchmark.m)
  Stable configurable benchmark interface.
- [`mainEval.m`](mainEval.m)
  Fixed example scenario script built on top of `runBenchmark.m`.
- [`data/evaluation/synthetic/ESCSimData/BSSsimESCdata.m`](../data/evaluation/synthetic/ESCSimData/BSSsimESCdata.m)
  ESC-side dataset builder.
- [`data/evaluation/synthetic/ROMSimData/createBusCoreBatterySyntheticDataset.m`](../data/evaluation/synthetic/ROMSimData/createBusCoreBatterySyntheticDataset.m)
  ROM-side dataset builder.
- [`initSOCs/runInitSocStudy.m`](initSOCs/runInitSocStudy.m)
  Initial-SOC sensitivity study.
- [`initSOCs/README.md`](initSOCs/README.md)
  Initial-SOC sweep guide and entry points.
- [`NoiseTuningSweep/sweepNoiseStudy.m`](NoiseTuningSweep/sweepNoiseStudy.m)
  Noise/covariance sweep study.
- [`Injection/runInjectionStudy.m`](Injection/runInjectionStudy.m)
  Derived-case injection study.

## Quick Start

From the repository root:

```matlab
addpath(genpath('.'));

datasetSpec = struct( ...
    'dataset_file', fullfile('data', 'evaluation', 'processed', 'desktop_atl20_bss_v1', 'nominal', 'esc_bus_coreBattery_dataset.mat'), ...
    'dataset_variable', 'dataset');

modelSpec = struct( ...
    'esc_model_file', fullfile('models', 'ATLmodel.mat'), ...
    'rom_model_file', fullfile('models', 'ROM_ATL20_beta.mat'), ...
    'tc', 25, ...
    'chemistry_label', 'ATL');

estimatorSetSpec = struct('registry_name', 'mainEval10');
flags = struct('Summaryfigs', true, 'Verbose', true);

results = runBenchmark(datasetSpec, modelSpec, estimatorSetSpec, flags);
results.metadata.metrics_table
```

For the fixed example scenario:

```matlab
addpath(genpath('.'));
mainEval
```

## Parallel Execution

`runBenchmark.m` forwards optional estimator-level parallel flags to `xKFeval.m`:

- `flags.use_parallel`
- `flags.auto_start_parallel_pool`
- `flags.parallel_pool_size`

Example:

```matlab
flags = struct( ...
    'Summaryfigs', true, ...
    'Verbose', true, ...
    'use_parallel', true, ...
    'auto_start_parallel_pool', true, ...
    'parallel_pool_size', []);
```

This parallelism is across estimators, not across time steps. If `xKFeval.m` is called from inside an already active parallel worker, nested parallel execution is disabled automatically and the estimator loop falls back to serial execution for that call.

## Custom Settings

To benchmark the behavioral NMC30 suite:

```matlab
addpath(genpath('.'));

datasetSpec = struct( ...
    'dataset_file', fullfile('data', 'evaluation', 'processed', 'behavioral_nmc30_bss_v1', 'nominal', 'rom_bus_coreBattery_dataset.mat'), ...
    'dataset_variable', 'dataset', ...
    'dataset_soc_field', 'soc_true', ...
    'metric_soc_field', 'soc_true', ...
    'metric_voltage_field', 'voltage_v', ...
    'reference_name', 'ROM reference', ...
    'voltage_name', 'ROM voltage', ...
    'title_prefix', 'NMC30 ROM');

modelSpec = struct( ...
    'esc_model_file', fullfile('models', 'NMC30model.mat'), ...
    'rom_model_file', fullfile('models', 'ROM_NMC30_HRA12.mat'), ...
    'tc', 25, ...
    'chemistry_label', 'NMC30');

estimatorSetSpec = struct('registry_name', 'mainEval10');
results = runBenchmark(datasetSpec, modelSpec, estimatorSetSpec, struct('Verbose', true));
```

To use tuned estimator covariances from an autotuning MAT file:

```matlab
estimatorSetSpec.tuning = struct( ...
    'kind', 'autotuning_profile', ...
    'param_file', fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'), ...
    'scenario_name', 'atl_bss_esc', ...
    'selection_policy', 'best_objective', ...
    'fallback_to_default', true);
```

Builder-side example:

```matlab
addpath(genpath('.'));

cfg = struct( ...
    'model_file', fullfile('models', 'ATLmodel.mat'), ...
    'profile_file', fullfile('data', 'evaluation', 'raw', 'omtlife8ahc_hp', 'Bus_CoreBatteryData_Data.mat'), ...
    'tc', 25);

BSSsimESCdata( ...
    fullfile('data', 'evaluation', 'processed', 'desktop_atl20_bss_v1', 'nominal', 'esc_bus_coreBattery_dataset.mat'), ...
    cfg);
```

## Dataset Contract

`runBenchmark.m` expects a saved `dataset` struct with at least:

- `current_a`
- `voltage_v`

Common optional fields:

- `time_s`
- `temperature_c`
- `reference_soc`
- `soc_init_reference`
- `capacity_ah`
- `dataset_soc`
- `metric_soc`
- `metric_voltage`
- `reference_name`
- `voltage_name`
- `title_prefix`

## Derived Dataset Manifests

Derived evaluation cases save next to the dataset:

- `dataset.mat`
- `manifest.json`
- optional `manifest.mat`

Use [`utility/dataRegistry/summarizeEvaluationSuiteManifests.m`](../utility/dataRegistry/summarizeEvaluationSuiteManifests.m) to scan a suite and summarize nominal and derived cases.

## Output Artifact Policy

Evaluation outputs are split into:

- summary artifacts:
  small, Git-trackable metrics tables, manifests, metadata, and selected published plots
- heavy artifacts:
  local-only MAT outputs containing full estimator time-series results, merged benchmark result bundles, and detailed study outputs from injection, init-SOC, and noise sweeps

Trackable evaluation summaries should go under:

- `results/evaluation/...`
- `results/figures/...`

Heavy evaluation artifacts should stay in local workflow locations such as:

- `data/evaluation/derived/...`
- `Evaluation/results/...`
- `Evaluation/Injection/results/...`
- `Evaluation/initSOCs/results/...`
- `Evaluation/NoiseTuningSweep/results/...`

Do not commit heavy benchmark-result MAT files by default.

## Notes

- `runBenchmark.m` and the study wrappers resolve canonical paths only.
- Builder scripts may still consume `data/evaluation/raw/...`.