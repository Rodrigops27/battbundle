# Initial-SOC Sweep Layer

This layer runs initial-SOC robustness studies by sweeping the estimator initial SOC over a configurable range on a canonical evaluation dataset.

## Purpose

Use this layer when you want to:

- measure convergence sensitivity to initial SOC mismatch
- compare SOC and voltage RMSE across estimators over a sweep
- benchmark the same estimator set against `esc` or `rom` dataset modes
- promote lightweight sweep summaries while keeping heavy run outputs local

The default desktop scenario uses:

- ESC dataset: [`data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat`](../../data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat)
- behavioral ROM dataset: [`data/evaluation/processed/behavioral_nmc30_bss_v1/nominal/rom_bus_coreBattery_dataset.mat`](../../data/evaluation/processed/behavioral_nmc30_bss_v1/nominal/rom_bus_coreBattery_dataset.mat)
- ESC model: [`models/ATLmodel.mat`](../../models/ATLmodel.mat)
- ROM model for `ROM-EKF`: [`models/ROM_ATL20_beta.mat`](../../models/ROM_ATL20_beta.mat)

## Main Files

- [`runInitSocStudy.m`](runInitSocStudy.m)
  Wrapper entry point with default estimator selection and tuning.
- [`sweepInitSocStudy.m`](sweepInitSocStudy.m)
  Core sweep runner.
- [`printInitSocSweepSummary.m`](printInitSocSweepSummary.m)
  Console summary helper.
- [`extractInitSocSweepResults.m`](extractInitSocSweepResults.m)
  Rebuilds compact summaries from a saved sweep result.
- [`plotInitSocSweepResults.m`](plotInitSocSweepResults.m)
  Regenerates sweep figures from saved results.
- [`writeInitSocPromotedSummary.m`](writeInitSocPromotedSummary.m)
  Writes promoted JSON and Markdown summaries under `results/evaluation/...`.

## Quick Start

```matlab
addpath(genpath('.'));

results = runInitSocStudy();
printInitSocSweepSummary(results);
```

To choose a narrower range:

```matlab
cfg = struct();
results = runInitSocStudy([45 80], 2, cfg);
```

## Parallel Execution

Independent sweep points can run in parallel:

```matlab
cfg = struct();
cfg.parallel.use_parallel = true;
cfg.parallel.auto_start_pool = true;
cfg.parallel.pool_size = [];

results = runInitSocStudy([0 100], 10, cfg);
```

When parallel execution is unavailable, the layer falls back to serial mode and prints the reason.

## Custom Settings

To benchmark the behavioral ROM dataset mode instead of the default ESC dataset:

```matlab
cfg = struct();
cfg.dataset_mode = 'rom';
cfg.rom_dataset_file = fullfile('data', 'evaluation', 'processed', ...
    'behavioral_nmc30_bss_v1', 'nominal', 'rom_bus_coreBattery_dataset.mat');
cfg.rom_file = fullfile('models', 'ROM_ATL20_beta.mat');

results = runInitSocStudy([0 100], 10, cfg);
```

To select a custom estimator subset:

```matlab
cfg = struct();
cfg.estimator_names = {'ROM-EKF', 'EaEKF', 'ESC-SPKF'};

results = runInitSocStudy([0 100], 10, cfg);
```

To use tuned covariances from an autotuning MAT file:

```matlab
cfg = struct();
cfg.estimatorSetSpec = struct();
cfg.estimatorSetSpec.tuning = struct( ...
    'kind', 'autotuning_profile', ...
    'param_file', fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'), ...
    'scenario_name', 'atl_bss_esc', ...
    'selection_policy', 'best_objective', ...
    'fallback_to_default', true);

results = runInitSocStudy([0 100], 10, cfg);
```

The wrapper also accepts `cfg.estimatorSetSpec.estimator_names` and compatibility-style scenario fields when you want to reuse a benchmark or injection configuration shape.

## Output Artifact Policy

Initial-SOC sweep outputs are split into:

- summary artifacts:
  lightweight sweep summaries and promoted Markdown/JSON reports under `results/evaluation/...`
- heavy artifacts:
  local-only MAT files under `Evaluation/initSOCs/results/...`

Use `writeInitSocPromotedSummary.m` to export a saved sweep MAT file into promoted summary artifacts.

## Notes

- Benchmark/runtime dataset reads still use canonical `data/evaluation/processed/...` paths.
- This study is built on top of the same estimator/evaluation contract used by `runBenchmark.m` and `xKFeval.m`.
- Heavy sweep MAT files are local workflow artifacts and should not be committed by default.
