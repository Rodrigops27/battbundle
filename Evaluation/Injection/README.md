# Injection Layer

This layer owns noise and perturbance injection studies for the evaluation framework.

It replaces the old `Evaluation/tests` workflow as the primary user-facing injection layer, while keeping the benchmark engine aligned with [`xKFeval.m`](bnchmrk/Evaluation/xKFeval.m) through [`runBenchmark.m`](bnchmrk/Evaluation/runBenchmark.m).

## Purpose

Use this layer when you want to:
- generate injected datasets from a clean benchmark dataset
- validate the injected dataset against the clean source trace
- benchmark one or more estimators on the injected dataset
- summarize and re-plot saved injection-study results later

The estimator benchmark step is delegated to `runBenchmark.m`, so `scenario.estimatorSetSpec.tuning` may now be either:
- a plain shared tuning struct
- an autotuning profile spec pointing at a saved MAT file from `autotuning/results/`

## Default Scenario

The default desktop-evaluation scenario is:
- source dataset: `Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`
- ESC model: `models/ATLmodel.mat`
- ROM model: `models/ROM_ATL20_beta.mat`
- default estimator set:
  `EsSPKF`, `ESC-SPKF`, `EaEKF`, `EbSPKF`, `EBiSPKF`, `EDUKF`, `Em7SPKF`, `ESC-EKF`
- injection cases: `noise` and `perturbance`

The injected datasets are generated under `Evaluation/Injection/datasets/`.

## Default Injection Cases

The built-in default `noise` case applies:
- voltage noise with target standard deviation `15 mV`
- samplewise current scaling bounded by `+-5%`
- random seed `7`

The built-in default `perturbance` case applies:
- current gain `1.1`
- current offset `0.1 A`
- voltage gain fault `6e-4`
- voltage offset `2 mV`
- random seed `11`

In both cases, the layer stores the clean source traces as `current_a_true` / `voltage_v_true` and validates the generated injected dataset before benchmarking.

## Main Files

- [`runInjectionStudy.m`](bnchmrk/Evaluation/Injection/runInjectionStudy.m)
  Main API/configuration entry point.
- [`defaultInjectionConfig.m`](bnchmrk/Evaluation/Injection/defaultInjectionConfig.m)
  Default ATL desktop scenario and default injection cases.
- [`generateInjectedDataset.m`](bnchmrk/Evaluation/Injection/generateInjectedDataset.m)
  Dataset-generation helper for noise and perturbance cases.
- [`validateInjectedDataset.m`](bnchmrk/Evaluation/Injection/validateInjectedDataset.m)
  Validation helper for clean-vs-injected traces.
- [`printInjectionSummary.m`](bnchmrk/Evaluation/Injection/printInjectionSummary.m)
  Console summary helper.
- [`plotInjectionResults.m`](bnchmrk/Evaluation/Injection/plotInjectionResults.m)
  Re-plots saved benchmark results with [`plotEvalResults.m`](bnchmrk/Evaluation/plotEvalResults.m).

## Quick Start

```matlab
addpath(genpath('.'));

results = runInjectionStudy();
printInjectionSummary(results);
```

## Special Noise Or Perturbance Inputs

For a custom `noise` case, the main configurable inputs are:
- `name`
- `mode = 'noise'`
- `voltage_std_mv`
- `current_error_percent`
- `random_seed`
- `overwrite`

For a custom `perturbance` case, the main configurable inputs are:
- `name`
- `mode = 'perturbance'`
- `current_gain`
- `current_offset_a`
- `voltage_gain_fault`
- `voltage_offset_mv`
- `random_seed`
- `overwrite`

If you want reuse-only behavior, set `overwrite = false` for the case.

Example custom noise case:

```matlab
cfg = defaultInjectionConfig();
cfg.scenarios(1).injection_cases = struct( ...
    'name', 'noise_special', ...
    'mode', 'noise', ...
    'voltage_std_mv', 8, ...
    'current_error_percent', 2.5, ...
    'random_seed', 21, ...
    'overwrite', true);

results = runInjectionStudy(cfg);
```

## Using A Tuned Estimator Profile

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

This is resolved per estimator inside `runBenchmark.m`. If the param file or an estimator entry is missing, `runBenchmark.m` warns and falls back to default/shared tuning when `fallback_to_default = true`.

The autotuning profile is only a parameter source. It does not automatically expand the estimator list. `runInjectionStudy.m` still benchmarks only the estimators listed in `cfg.scenarios(1).estimatorSetSpec.estimator_names`, or the default Injection-layer subset if that field is left unchanged.

Example custom perturbance case:

```matlab
cfg = defaultInjectionConfig();
cfg.scenarios(1).injection_cases = struct( ...
    'name', 'perturbance_special', ...
    'mode', 'perturbance', ...
    'current_gain', 1.05, ...
    'current_offset_a', 0.05, ...
    'voltage_gain_fault', 4e-4, ...
    'voltage_offset_mv', 1.5, ...
    'random_seed', 22, ...
    'overwrite', true);

results = runInjectionStudy(cfg);
```

## External Data Registry / Custom Paths

If your clean benchmark datasets or source application profiles live outside the default `Evaluation/...` layout, set the scenario paths explicitly.

Example using an external top-level `data/` registry:

```matlab
cfg = defaultInjectionConfig();

cfg.scenarios(1).source_dataset = struct( ...
    'dataset_file', fullfile('data', 'Evaluation', 'ESCSimData', 'datasets', 'esc_bus_coreBattery_dataset.mat'), ...
    'dataset_variable', 'dataset', ...
    'builder_fcn', [], ...
    'builder_cfg', struct());

cfg.scenarios(1).modelSpec = struct( ...
    'esc_model_file', fullfile('models', 'ATLmodel.mat'), ...
    'rom_model_file', fullfile('models', 'ROM_ATL20_beta.mat'), ...
    'tc', 25, ...
    'chemistry_label', 'ATL', ...
    'require_rom_match', true);

cfg.scenarios(1).benchmark_dataset_template = struct( ...
    'dataset_variable', 'dataset', ...
    'dataset_soc_field', 'soc_true', ...
    'metric_soc_field', 'soc_true', ...
    'metric_voltage_field', 'voltage_v_true', ...
    'reference_name', 'ESC reference', ...
    'voltage_name', 'Injected voltage', ...
    'title_prefix', 'ATL BSS Injection');

results = runInjectionStudy(cfg);
```

Notes:
- `cfg.scenarios(1).source_dataset.dataset_file` is the clean dataset used to generate the injected cases.
- `cfg.scenarios(1).modelSpec.*` is forwarded to `runBenchmark.m` for the post-injection estimator benchmark.
- If you want the dataset to be rebuilt instead of loaded, provide `builder_fcn` and `builder_cfg` in `source_dataset`.
- If your source application profile also moved, point the chosen builder configuration at that new external path as well.

## Parallel Execution

Independent injection cases can run in parallel:

```matlab
cfg = defaultInjectionConfig();
cfg.parallel.use_parallel = true;
cfg.parallel.auto_start_pool = true;
cfg.scenarios(1).estimatorSetSpec.tuning = struct( ...
    'kind', 'autotuning_profile', ...
    'param_file', fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'), ...
    'scenario_name', 'atl_bss_esc', ...
    'selection_policy', 'best_objective', ...
    'fallback_to_default', true);

results = runInjectionStudy(cfg);
```

When parallel execution is unavailable, the layer falls back to serial mode and prints the reason.

To run the default injection cases with the full tuned desktop-evaluation estimator profile and parallel execution:

```matlab
cfg = defaultInjectionConfig();
cfg.parallel.use_parallel = true;
cfg.parallel.auto_start_pool = true;
cfg.scenarios(1).estimatorSetSpec.estimator_names = { ...
    'ROM-EKF', ...
    'ESC-SPKF', 'ESC-EKF', 'EaEKF', ...
    'EacrSPKF', 'EnacrSPKF', 'EDUKF', ...
    'EsSPKF', 'EbSPKF', 'EBiSPKF', 'Em7SPKF'};
cfg.scenarios(1).estimatorSetSpec.tuning = struct( ...
    'kind', 'autotuning_profile', ...
    'param_file', fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'), ...
    'scenario_name', 'atl_bss_esc', ...
    'selection_policy', 'best_objective', ...
    'fallback_to_default', true);

results = runInjectionStudy(cfg);
```

To run the default study but benchmark only `iterEKF` (`ROM-EKF`) with parallel execution enabled:

```matlab
cfg = defaultInjectionConfig();
cfg.parallel.use_parallel = true;
cfg.parallel.auto_start_pool = true;
cfg.scenarios(1).estimatorSetSpec.estimator_names = {'ROM-EKF'};

results = runInjectionStudy(cfg);
```

If you want to keep the default injection cases and include `iterEKF` together with the default ESC-side set:

```matlab
cfg = defaultInjectionConfig();
cfg.parallel.use_parallel = true;
cfg.parallel.auto_start_pool = true;
cfg.scenarios(1).estimatorSetSpec.estimator_names = { ...
    'ROM-EKF', ...
    'EsSPKF', 'ESC-SPKF', 'EaEKF', 'EbSPKF', ...
    'EBiSPKF', 'EDUKF', 'Em7SPKF', 'ESC-EKF'};

results = runInjectionStudy(cfg);
```

## Plotting Saved Results

```matlab
plotInjectionResults(results);
```

Or from a saved aggregate MAT file:

```matlab
S = load('Evaluation/Injection/results/injection_YYYYMMDD_HHMMSS.mat');
printInjectionSummary(S.injection_results);
plotInjectionResults(S.injection_results);
```

## Custom Scenario Example

```matlab
cfg = defaultInjectionConfig();
cfg.scenarios(1).estimatorSetSpec = struct( ...
    'registry_name', 'all', ...
    'estimator_names', {{'ROM-EKF', 'EaEKF', 'ESC-SPKF'}}, ...
    'allow_rom_skip', true);
cfg.scenarios(1).injection_cases = struct( ...
    'name', 'noise_light', ...
    'mode', 'noise', ...
    'voltage_std_mv', 10, ...
    'current_error_percent', 2, ...
    'random_seed', 3, ...
    'overwrite', true);

results = runInjectionStudy(cfg);
```

## Notes

- The benchmark engine is still `runBenchmark` / `xKFeval`.
- Dataset validation runs before the benchmark by default.
- The default metric-voltage comparison uses the clean voltage trace stored as `voltage_v_true`.
- Tuning-profile warnings and fallback behavior come from `runBenchmark.m`.
