# NoiseTuningSweep Layer

## Purpose

This sublayer runs covariance-tuning studies for the evaluation harness.

Use it when you want to:
- sweep process noise `sigma_w`
- sweep sensor noise `sigma_v`
- compare how estimator performance changes with covariance tuning
- tune one estimator in isolation before folding the setting back into a larger benchmark

## Scope

This folder owns:
- multi-estimator covariance sweeps
- single-estimator covariance sweeps
- sweep-specific plotting helpers
- saved multi-estimator sweep results under `Evaluation/NoiseTuningSweep/results/`

Out of scope:
- ESC model fitting
- ROM fitting
- general estimator benchmarking outside covariance studies

## Main files

- [`runNoiseCovStudy.m`](runNoiseCovStudy.m)
  - wrapper for the multi-estimator covariance study
- [`sweepNoiseStudy.m`](sweepNoiseStudy.m)
  - core multi-estimator noise sweep engine
- [`runOneEstSweeNoise.m`](runOneEstSweeNoise.m)
  - wrapper for a single-estimator covariance study
- [`oneEstSweeNoise.m`](oneEstSweeNoise.m)
  - core single-estimator sweep engine
- [`plotNoiseSweepSummary.m`](plotNoiseSweepSummary.m)
  - aggregate summary plotting helper for saved multi-estimator sweep results
- [`plotNoiseSweepHeatmaps.m`](plotNoiseSweepHeatmaps.m)
  - per-estimator heatmap and 1D sweep plotting helper for saved multi-estimator sweep results
- [`printNoiseSweepSummary.m`](printNoiseSweepSummary.m)
  - console summary helper for saved multi-estimator sweep results
- [`plotEaEkfCovarianceSweeps.m`](plotEaEkfCovarianceSweeps.m)
  - plotting helper for `EaEKF` covariance evolution from saved sweep results
- `results/`
  - saved wrapper result files and optional exported figures

## Default scenario

The default study scenario is the ATL desktop evaluation:

- dataset mode: `esc`
- dataset: [`Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`](../ESCSimData/datasets/esc_bus_coreBattery_dataset.mat)
- ESC model: [`models/ATLmodel.mat`](../../models/ATLmodel.mat)
- ROM model: [`models/ROM_ATL20_beta.mat`](../../models/ROM_ATL20_beta.mat) only if `ROM-EKF` is explicitly selected

Default `runNoiseCovStudy` estimator subset:

- `iterEbSPKF`
- `iterESCSPKF`
- `iterEBiSPKF`
- `iterEaEKF`
- `iterEsSPKF`
- `iterEDUKF`

Default `runNoiseCovStudy` sweep settings:

- sweep mode: `grid`
- process-noise range: `[1e-3 1e2]`
- sensor-noise range: `[1e-6 2e-1]`
- step multiplier: `5`
- parallel: disabled unless requested
- save results: enabled

## How to run

Run the default multi-estimator grid sweep:

```matlab
addpath(genpath('.'));
results = runNoiseCovStudy();
```

Run only the `sigma_w` sweep:

```matlab
addpath(genpath('.'));
results = runNoiseCovStudy([], [], [], struct('sweep_mode', 'sigma_w'));
```

Run the multi-estimator sweep with a custom estimator list:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.estimatorSetSpec.estimator_names = { ...
    'ROM-EKF', ...
    'ESC-SPKF', 'ESC-EKF', 'EaEKF', ...
    'EacrSPKF', 'EnacrSPKF', 'EDUKF', ...
    'EsSPKF', 'EbSPKF', 'EBiSPKF', 'Em7SPKF'};

results = runNoiseCovStudy([], [], [], cfg);
```

Run the full desktop estimator set with parallel execution:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.parallel.use_parallel = true;
cfg.parallel.auto_start_pool = true;
cfg.estimatorSetSpec.estimator_names = { ...
    'ROM-EKF', ...
    'ESC-SPKF', 'ESC-EKF', 'EaEKF', ...
    'EacrSPKF', 'EnacrSPKF', 'EDUKF', ...
    'EsSPKF', 'EbSPKF', 'EBiSPKF', 'Em7SPKF'};

results = runNoiseCovStudy([], [], [], cfg);
```

Run the full desktop estimator set with an autotuning profile:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.parallel.use_parallel = true;
cfg.parallel.auto_start_pool = true;
cfg.estimatorSetSpec.estimator_names = { ...
    'ROM-EKF', ...
    'ESC-SPKF', 'ESC-EKF', 'EaEKF', ...
    'EacrSPKF', 'EnacrSPKF', 'EDUKF', ...
    'EsSPKF', 'EbSPKF', 'EBiSPKF', 'Em7SPKF'};
cfg.estimatorSetSpec.tuning = struct( ...
    'kind', 'autotuning_profile', ...
    'param_file', fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'), ...
    'scenario_name', 'atl_bss_esc', ...
    'selection_policy', 'best_objective', ...
    'fallback_to_default', true);

results = runNoiseCovStudy([], [], [], cfg);
```

Plot from a saved multi-estimator sweep:

```matlab
S = load('Evaluation/NoiseTuningSweep/results/runNoiseCovStudy_YYYYMMDD_HHMMSS.mat');

printNoiseSweepSummary(S.sweepResults);
plotNoiseSweepSummary(S.sweepResults);
plotNoiseSweepHeatmaps(S.sweepResults);
plotEaEkfCovarianceSweeps(S.sweepResults);
```

Run a single-estimator sweep:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.estimator_name = 'Em7SPKF';
cfg.sweep_mode = 'grid';

results = runOneEstSweeNoise([], [], [], cfg);
```

Run a single-estimator sweep on the ESC synthetic dataset:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.estimator_name = 'Em7SPKF';
cfg.dataset_mode = 'esc';
cfg.esc_dataset_file = fullfile('Evaluation', 'ESCSimData', 'datasets', 'esc_bus_coreBattery_dataset.mat');
cfg.esc_model_file = fullfile('models', 'ATLmodel.mat');
cfg.sweep_mode = 'grid';

results = runOneEstSweeNoise([], [], [], cfg);
```

Run a single-estimator sweep on the raw bus profile:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.estimator_name = 'Em7SPKF';
cfg.dataset_mode = 'bus_raw';
cfg.raw_bus_file = fullfile('Evaluation', 'OMTLIFE8AHC-HP', 'Bus_CoreBatteryData_Data.mat');
cfg.esc_model_file = fullfile('models', 'ATLmodel.mat');
cfg.sweep_mode = 'sigma_w';

results = runOneEstSweeNoise([], [], [], cfg);
```

## Current limitations

- [`runOneEstSweeNoise.m`](runOneEstSweeNoise.m) / [`oneEstSweeNoise.m`](oneEstSweeNoise.m) currently support `ROM-EKF` and `Em7SPKF` as the explicit single-estimator choices in code.
- [`oneEstSweeNoise.m`](oneEstSweeNoise.m) now supports `dataset_mode = 'esc'`, `dataset_mode = 'rom'`, and `dataset_mode = 'bus_raw'`.
- [`runNoiseCovStudy.m`](runNoiseCovStudy.m) and [`sweepNoiseStudy.m`](sweepNoiseStudy.m) are path-independent from the repo root because they derive the repo path from the script location and use repo-relative defaults.
- [`runNoiseCovStudy.m`](runNoiseCovStudy.m) now accepts:
  - `cfg.parallel.use_parallel`
  - `cfg.parallel.auto_start_pool`
  - `cfg.parallel.pool_size`
  - `cfg.estimatorSetSpec.estimator_names`
  - `cfg.estimatorSetSpec.tuning`
  - compatibility shim: `cfg.scenarios(1).estimatorSetSpec.*`
- `cfg.estimatorSetSpec.registry_name = 'all'` expands to the full desktop 11-estimator set in the wrapper.

## Outputs

- Multi-estimator study results are returned as a struct in MATLAB.
- [`runNoiseCovStudy.m`](runNoiseCovStudy.m) saves a `.mat` result file under `Evaluation/NoiseTuningSweep/results/` unless `cfg.SaveResults = false`.
- Use `cfg.results_file` to override the default output path for [`runNoiseCovStudy.m`](runNoiseCovStudy.m).
- The wrappers also assign:
  - `noiseCovSweepResults` in the base workspace
  - `oneEstNoiseSweepResults` in the base workspace

## Related documentation

- [`Evaluation/README.md`](../README.md)
- [`results/estimatorsInitNoiseSweep.md`](../../results/estimatorsInitNoiseSweep.md)
- [`docs/Estimators Design.md`](../../docs/Estimators%20Design.md)

## ROM-EKF note

`ROM-EKF` (`iterEKF`) is the most complete estimator in the benchmark set, but it is also the most computationally expensive and the least forgiving when the covariance tuning is poor. For that reason, it is excluded from the default sweep subsets in this layer.

If you want to test it explicitly, paste one of these examples.

Add `ROM-EKF` back into the multi-estimator sweep:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.estimatorSetSpec.estimator_names = { ...
    'ROM-EKF', 'EbSPKF', 'ESC-SPKF', ...
    'EBiSPKF', 'EaEKF', 'EsSPKF', 'EDUKF'};

results = runNoiseCovStudy([], [], [], cfg);
```

Run `ROM-EKF` by itself in the multi-estimator wrapper:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.estimatorSetSpec.estimator_names = {'ROM-EKF'};

results = runNoiseCovStudy([], [], [], cfg);
```
