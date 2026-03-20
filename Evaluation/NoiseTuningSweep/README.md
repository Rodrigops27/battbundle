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

- `runNoiseCovStudy.m`
  - wrapper for the multi-estimator covariance study
- `sweepNoiseStudy.m`
  - core multi-estimator noise sweep engine
- `runOneEstSweeNoise.m`
  - wrapper for a single-estimator covariance study
- `oneEstSweeNoise.m`
  - core single-estimator sweep engine
- `plotNoiseSweepSummary.m`
  - aggregate summary plotting helper for saved multi-estimator sweep results
- `plotNoiseSweepHeatmaps.m`
  - per-estimator heatmap and 1D sweep plotting helper for saved multi-estimator sweep results
- `plotEaEkfCovarianceSweeps.m`
  - plotting helper for `EaEKF` covariance evolution from saved sweep results
- `results/`
  - saved wrapper result files and optional exported figures

## Default scenario

The default study scenario is the ATL desktop evaluation:

- dataset mode: `esc`
- dataset: `Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`
- ESC model: `models/ATLmodel.mat`
- ROM model: `models/ROM_ATL20_beta.mat` only if `ROM-EKF` is explicitly selected

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
cfg.estimator_names = { ...
    'iterEbSPKF', 'iterESCSPKF', 'iterEBiSPKF', ...
    'iterEaEKF', 'iterEsSPKF', 'iterEDUKF', 'iterEKF'};

results = runNoiseCovStudy([], [], [], cfg);
```

Plot from a saved multi-estimator sweep:

```matlab
S = load('Evaluation/NoiseTuningSweep/results/runNoiseCovStudy_YYYYMMDD_HHMMSS.mat');

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

## Current limitations

- `runOneEstSweeNoise` / `oneEstSweeNoise` currently support `ROM-EKF` and `Em7SPKF` as the explicit single-estimator choices in code.
- `oneEstSweeNoise` currently supports `dataset_mode = 'rom'` only.
- `runNoiseCovStudy` and `sweepNoiseStudy` are path-independent from the repo root because they derive the repo path from the script location and use repo-relative defaults.

## Outputs

- Multi-estimator study results are returned as a struct in MATLAB.
- `runNoiseCovStudy` saves a `.mat` result file under `Evaluation/NoiseTuningSweep/results/` unless `cfg.SaveResults = false`.
- Use `cfg.results_file` to override the default output path for `runNoiseCovStudy`.
- The wrappers also assign:
  - `noiseCovSweepResults` in the base workspace
  - `oneEstNoiseSweepResults` in the base workspace

## Related documentation

- `Evaluation/README.md`
- `results/estimatorsInitNoiseSweep .md`
- `docs/estimators.md`

## ROM-EKF note

`ROM-EKF` (`iterEKF`) is the most complete estimator in the benchmark set, but it is also the most computationally expensive and the least forgiving when the covariance tuning is poor. For that reason, it is excluded from the default sweep subsets in this layer.

If you want to test it explicitly, paste one of these examples.

Add `ROM-EKF` back into the multi-estimator sweep:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.estimator_names = { ...
    'iterEKF', 'iterEbSPKF', 'iterESCSPKF', ...
    'iterEBiSPKF', 'iterEaEKF', 'iterEsSPKF', 'iterEDUKF'};

results = runNoiseCovStudy([], [], [], cfg);
```

Run `ROM-EKF` by itself in the multi-estimator wrapper:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.estimator_names = {'iterEKF'};

results = runNoiseCovStudy([], [], [], cfg);
```
