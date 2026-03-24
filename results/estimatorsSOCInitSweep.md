# Estimator Initial-SOC Sweep Results

## Brief description of the scenario

This result summarizes the initial-SOC sensitivity study run with `Evaluation/initSOCs/sweepInitSocStudy.m` on the default ATL desktop-evaluation setup.

Scenario:

| Item | Value |
| --- | --- |
| Study script | `Evaluation/initSOCs/sweepInitSocStudy.m` |
| Dataset | `Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat` |
| Dataset type | ESC-driven BSS synthetic dataset |
| ESC model | `models/ATLmodel.mat` |
| Sweep | initial SOC from `0%` to `100%` in `10%` steps |
| Estimators included | `ESC-SPKF`, `ESC-EKF`, `EaEKF`, `EnacrSPKF`, `EsSPKF`, `EbSPKF`, `Em7SPKF` |

This study is useful to see how strongly each ESC estimator depends on the initial SOC guess when the underlying scenario is the core ATL desktop evaluation.

## Results (tables)

### Aggregate summary across the full sweep

| Estimator | Mean SOC RMSE (%) | Best SOC RMSE (%) | Worst SOC RMSE (%) | Mean Voltage RMSE (mV) | Best Voltage RMSE (mV) | Worst Voltage RMSE (mV) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `ESC-SPKF` | 3.556 | 0.641 | 20.772 | 1.88 | 0.04 | 14.64 |
| `ESC-EKF` | 5.392 | 1.760 | 18.372 | 7.69 | 6.34 | 18.12 |
| `EaEKF` | 2.559 | 1.309 | 13.355 | 0.68 | 0.02 | 6.38 |
| `EnacrSPKF` | 22.375 | 22.360 | 22.386 | 17.32 | 17.31 | 17.33 |
| `EsSPKF` | 6.678 | 0.642 | 15.720 | 3.74 | 0.03 | 10.05 |
| `EbSPKF` | 3.163 | 0.639 | 15.464 | 1.25 | 0.05 | 8.00 |
| `Em7SPKF` | 6.678 | 0.642 | 15.720 | 3.74 | 0.03 | 10.05 |
| `ROM-EKF` | 67.040 | 12.033 | 72.625 | 3948.58 | 46.76 | 20901.53 |

### Best initial-SOC point per estimator

| Estimator | Best initial SOC (%) | SOC RMSE at best point (%) | Voltage RMSE at best point (mV) |
| --- | ---: | ---: | ---: |
| `ESC-SPKF` | 60 | 0.6409 | 0.0375 |
| `ESC-EKF` | 80 | 1.7596 | 6.3409 |
| `EaEKF` | 50 | 1.3093 | 0.0207 |
| `EnacrSPKF` | 40 | 22.3600 | 17.3320 |
| `EsSPKF` | 60 | 0.6418 | 0.0312 |
| `EbSPKF` | 60 | 0.6387 | 0.0487 |
| `Em7SPKF` | 60 | 0.6418 | 0.0312 |
| `ROM-EKF` | 80 | 12.0330 | 46.7610 |

### Selected sweep points

These points capture the main shape of the sweep without repeating the full console dump.

| Initial SOC (%) | Best SOC RMSE estimator | Value (%) | Best Voltage RMSE estimator | Value (mV) |
| ---: | --- | ---: | --- | ---: |
| 0 | `EaEKF` | 1.4416 | `EaEKF` | 0.5149 |
| 50 | `ESC-SPKF` | 0.7577 | `EaEKF` | 0.0207 |
| 60 | `EbSPKF` | 0.6387 | `EaEKF` | 0.0195 |
| 100 | `EsSPKF` / `Em7SPKF` | 6.8173 | `EsSPKF` / `Em7SPKF` | 3.6581 |

### Practical ranking for this study

| Rank | Most robust on SOC RMSE | Why |
| --- | --- | --- |
| 1 | `EaEKF` | Lowest mean SOC RMSE across the whole sweep and also the best voltage behavior. |
| 2 | `EbSPKF` | Best peak SOC RMSE and strong mid-range performance, but degrades more at the edges than `EaEKF`. |
| 3 | `ESC-SPKF` | Strong around the correct initial SOC, but much more sensitive to poor initialization than `EaEKF`. |

| Rank | Best on voltage RMSE | Why |
| --- | --- | --- |
| 1 | `EaEKF` | Best mean voltage RMSE and best pointwise voltage RMSE around the useful operating region. |
| 2 | `ESC-SPKF` | Very low voltage RMSE when initialized near the true SOC. |
| 3 | `EsSPKF` / `Em7SPKF` | Excellent voltage fit near `60%` SOC, but much less robust across the full sweep. |

## Observations

- `EaEKF` is the most robust overall result in this sweep. It does not win the absolute best SOC RMSE point, but it has the best average behavior across the full `0%` to `100%` initialization range and the best voltage fit.
- `EbSPKF` is the best local performer when the initial SOC guess is close to the true case. Its minimum SOC RMSE is the best in the sweep at `60%`, but its edge-case degradation is larger than `EaEKF`.
- `ESC-SPKF`, `EsSPKF`, `EbSPKF`, and `Em7SPKF` all perform well around `50%` to `70%` initial SOC and degrade sharply at `100%`. In practice, these methods want a reasonable starting SOC.
- `ESC-EKF` is consistently worse than the best sigma-point variants on this study and never becomes competitive on voltage RMSE.
- `EnacrSPKF` is effectively insensitive to the initial-SOC sweep here, but that is not a good sign: it stays poor everywhere, with nearly constant SOC RMSE around `22.37%` and voltage RMSE around `17.32 mV`.
- `EsSPKF` and `Em7SPKF` are numerically identical throughout the reported sweep. In this repo, that is consistent with the default bias branch not changing the result in this setup.
- The hardest point in this study is the `100%` initial SOC case. Most estimators deteriorate there, which makes it a good stress point for future tuning comparisons.

## How to regenerate them

Run the default ATL desktop-evaluation initial-SOC sweep:

```matlab
addpath(genpath('.'));

results = sweepInitSocStudy();
results.soc_rmse_table
results.voltage_rmse_table
plotInitSocSweepResults(results.saved_results_file);
```

If you want the figures as well:

```matlab
addpath(genpath('.'));

cfg = struct( ...
    'SweepSummaryfigs', true, ...
    'PlotSocEstimationfigs', true, ...
    'PlotVoltageEstimationfigs', true);

results = sweepInitSocStudy([0 100], 10, cfg);
```

To rerun the same study with an explicit dataset and model path:

```matlab
addpath(genpath('.'));

cfg = struct( ...
    'dataset_mode', 'esc', ...
    'esc_dataset_file', fullfile('Evaluation', 'ESCSimData', 'datasets', 'esc_bus_coreBattery_dataset.mat'), ...
    'raw_bus_file', fullfile('Evaluation', 'OMTLIFE8AHC-HP', 'Bus_CoreBatteryData_Data.mat'), ...
    'esc_model_file', fullfile('models', 'ATLmodel.mat'));

results = sweepInitSocStudy([0 100], 10, cfg);
```

## How to run other estimators

Both `sweepInitSocStudy` and `runInitSocStudy` now accept `cfg.estimator_names`. The selector can use either the study labels such as `EbSPKF` or the iterator-style names such as `iterEbSPKF`.

If you do not set `cfg.estimator_names`, `runInitSocStudy` uses its wrapper default subset:
- `iterEbSPKF`
- `iterESCSPKF`
- `iterEBiSPKF`
- `iterEaEKF`
- `iterEsSPKF`
- `iterEDUKF`

The autotuning profile is only a parameter source. It does not automatically expand the estimator list. The sweep still runs only the estimators listed in `cfg.estimator_names` or, if omitted, the wrapper default subset.

Use the wrapper with a custom estimator subset:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.estimator_names = { ...
    'iterESCSPKF', 'iterESCEKF', 'iterEaEKF', ...
    'iterEacrSPKF', 'iterEnacrSPKF', 'iterEDUKF', ...
    'iterEsSPKF', 'iterEbSPKF', 'iterEBiSPKF', 'iterEm7SPKF'};

results = runInitSocStudy([0 100], 10, cfg);
```

Run the lower-level study directly with a smaller set:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.dataset_mode = 'esc';
cfg.estimator_names = {'EbSPKF', 'ESC-SPKF', 'EBiSPKF', 'EaEKF'};
cfg.SaveResults = true;

results = sweepInitSocStudy([20 80], 5, cfg);
plotInitSocSweepResults(results.saved_results_file);
```

## How to use the autotuning profile

Run the wrapper default subset with tuned covariances from the desktop autotuning file and parallel execution:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.parallel.use_parallel = true;
cfg.parallel.auto_start_pool = true;
cfg.tuning = struct( ...
    'kind', 'autotuning_profile', ...
    'param_file', fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'), ...
    'scenario_name', 'atl_bss_esc', ...
    'selection_policy', 'best_objective', ...
    'fallback_to_default', true);

results = runInitSocStudy([0 100], 10, cfg);
```

Run all tuned desktop-evaluation estimators from the same autotuning profile with parallel execution:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.parallel.use_parallel = true;
cfg.parallel.auto_start_pool = true;
cfg.estimator_names = { ...
    'ROM-EKF', ...
    'ESC-SPKF', 'ESC-EKF', 'EaEKF', ...
    'EacrSPKF', 'EnacrSPKF', 'EDUKF', ...
    'EsSPKF', 'EbSPKF', 'EBiSPKF', 'Em7SPKF'};
cfg.tuning = struct( ...
    'kind', 'autotuning_profile', ...
    'param_file', fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'), ...
    'scenario_name', 'atl_bss_esc', ...
    'selection_policy', 'best_objective', ...
    'fallback_to_default', true);

results = runInitSocStudy([0 100], 10, cfg);
```

If a requested estimator is missing from the tuning file, the resolver warns and falls back to default/shared tuning when `fallback_to_default = true`.

Supported estimator selectors in this layer are:
- `iterEKF` / `iterROMEKF` / `ROM-EKF`
- `iterESCSPKF` / `ESC-SPKF`
- `iterESCEKF` / `ESC-EKF`
- `iterEaEKF` / `EaEKF`
- `iterEacrSPKF` / `EacrSPKF`
- `iterEnacrSPKF` / `EnacrSPKF`
- `iterEDUKF` / `EDUKF`
- `iterEsSPKF` / `EsSPKF`
- `iterEbSPKF` / `EbSPKF`
- `iterEBiSPKF` / `EBiSPKF`
- `iterEm7SPKF` / `Em7SPKF`
