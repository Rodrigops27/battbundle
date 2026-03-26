# Estimator Initial-SOC Sweep Results With Shared ESC Covariances

## Brief description of the scenario

This result summarizes the initial-SOC sensitivity study run with `Evaluation/initSOCs/runInitSocStudy.m` on the ATL desktop-evaluation setup, using the shared default covariance values rather than a Bayes-fitted tuning profile.

Scenario:

| Item | Value |
| --- | --- |
| Study script | `Evaluation/initSOCs/runInitSocStudy.m` / `Evaluation/initSOCs/sweepInitSocStudy.m` |
| Saved results | `Evaluation/initSOCs/results/Init_Sweep_ATL_BSS_init_soc_sweep_results.mat` |
| Dataset | `Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat` |
| Dataset type | ESC-driven BSS synthetic dataset |
| ESC model | `models/ATLmodel.mat` |
| Sweep | initial SOC from `0%` to `100%` in `10%` steps |
| Estimators included | `ROM-EKF`, `ESC-SPKF`, `ESC-EKF`, `EaEKF`, `EacrSPKF`, `EnacrSPKF`, `EDUKF`, `EsSPKF`, `EbSPKF`, `EBiSPKF`, `Em7SPKF` |

### Filter Covariances

| Parameter | Value |
| --- | ---: |
| `tuning.sigma_x0_rom_tail` | `2e6` |
| `tuning.sigma_w_ekf` | `1e2` |
| `tuning.sigma_v_ekf` | `1e-3` |
| `tuning.SigmaX0_rc` | `1e-6` |
| `tuning.SigmaX0_hk` | `1e-6` |
| `tuning.SigmaX0_soc` | `1e-3` |
| `tuning.sigma_w_esc` | `1e-3` |
| `tuning.sigma_v_esc` | `1e-3` |
| `tuning.SigmaR0` | `1e-6` |
| `tuning.SigmaWR0` | `1e-16` |
| `tuning.current_bias_var0` | `1e-5` |
| `tuning.single_bias_process_var` | `1e-8` |

This study shows how strongly each estimator depends on the initial SOC guess when all ESC-based estimators share the same default covariance settings.

## Results

### Aggregate summary across the full sweep

| Estimator | Mean SOC RMSE (%) | Best SOC RMSE (%) | Worst SOC RMSE (%) | Mean Voltage RMSE (mV) | Best Voltage RMSE (mV) | Worst Voltage RMSE (mV) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `ROM-EKF` | 25.744 | 20.903 | 26.300 | 39.68 | 34.78 | 40.26 |
| `ESC-SPKF` | 3.556 | 0.641 | 20.772 | 1.88 | 0.04 | 14.64 |
| `ESC-EKF` | 5.392 | 1.760 | 18.372 | 7.69 | 6.34 | 18.12 |
| `EaEKF` | 2.559 | 1.309 | 13.355 | 0.68 | 0.02 | 6.38 |
| `EacrSPKF` | 24.588 | 0.665 | 51.891 | 17.61 | 0.43 | 61.26 |
| `EnacrSPKF` | 22.375 | 22.360 | 22.386 | 17.32 | 17.31 | 17.33 |
| `EDUKF` | 5.051 | 0.642 | 11.365 | 2.65 | 0.03 | 7.07 |
| `EsSPKF` | 6.678 | 0.642 | 15.720 | 3.74 | 0.03 | 10.05 |
| `EbSPKF` | 3.163 | 0.639 | 15.464 | 1.25 | 0.05 | 8.00 |
| `EBiSPKF` | 3.556 | 0.641 | 20.772 | 1.88 | 0.04 | 14.64 |
| `Em7SPKF` | 6.678 | 0.642 | 15.720 | 3.74 | 0.03 | 10.05 |

### Best initial-SOC point per estimator

| Estimator | Best initial SOC (%) | SOC RMSE at best point (%) | Voltage RMSE at best point (mV) |
| --- | ---: | ---: | ---: |
| `ROM-EKF` | 100 | 20.9030 | 34.7850 |
| `ESC-SPKF` | 60 | 0.6409 | 0.0375 |
| `ESC-EKF` | 80 | 1.7596 | 6.3409 |
| `EaEKF` | 50 | 1.3093 | 0.0207 |
| `EacrSPKF` | 60 | 0.6648 | 0.6170 |
| `EnacrSPKF` | 40 | 22.3600 | 17.3320 |
| `EDUKF` | 60 | 0.6418 | 0.0313 |
| `EsSPKF` | 60 | 0.6418 | 0.0312 |
| `EbSPKF` | 60 | 0.6387 | 0.0487 |
| `EBiSPKF` | 60 | 0.6409 | 0.0375 |
| `Em7SPKF` | 60 | 0.6418 | 0.0312 |

### Selected sweep points

| Initial SOC (%) | Best SOC RMSE estimator | Value (%) | Best Voltage RMSE estimator | Value (mV) |
| ---: | --- | ---: | --- | ---: |
| 0 | `EaEKF` | 1.4416 | `EaEKF` | 0.5149 |
| 50 | `ESC-SPKF` / `EBiSPKF` | 0.7577 | `EaEKF` | 0.0207 |
| 60 | `EbSPKF` | 0.6387 | `EaEKF` | 0.0195 |
| 100 | `EsSPKF` / `Em7SPKF` | 6.8173 | `EsSPKF` / `Em7SPKF` | 3.6581 |

### Practical ranking for this study

| Rank | Most robust on SOC RMSE | Why |
| --- | --- | --- |
| 1 | `EaEKF` | Lowest mean SOC RMSE across the full sweep, plus the best voltage behavior under the shared-covariance setting. |
| 2 | `EbSPKF` | Best local SOC minimum and good behavior near the useful operating region, though less edge-robust than `EaEKF`. |
| 3 | `ESC-SPKF` / `EBiSPKF` | Strong around the correct initial SOC, but more sensitive to poor initialization than `EaEKF`. |

| Rank | Best on voltage RMSE | Why |
| --- | --- | --- |
| 1 | `EaEKF` | Best mean voltage RMSE and best pointwise voltage fit over the sweep. |
| 2 | `EbSPKF` | Strong overall voltage behavior with a much lower average error than the other shared-covariance sigma-point filters. |
| 3 | `ESC-SPKF` / `EBiSPKF` | Very low voltage RMSE near the correct initialization, but more edge-sensitive than `EaEKF`. |

## Observations

- Under shared default covariances, `EaEKF` is the strongest overall init-SOC result. It is not the absolute best at the single best SOC point, but it is the most balanced across the full sweep.
- `EbSPKF` gives the best local SOC RMSE at `60%` initial SOC and remains competitive across the useful operating region.
- `ESC-SPKF` and `EBiSPKF` are numerically identical in this run. That indicates the extra bias branch is not changing the result under this shared-covariance setup.
- `EsSPKF` and `Em7SPKF` are also numerically identical here, and both degrade sharply at the sweep edges.
- `ESC-EKF` is clearly better than `ROM-EKF` but remains much less robust than `EaEKF`, `EbSPKF`, and `ESC-SPKF`.
- `EacrSPKF` and `EnacrSPKF` are not competitive in this study. `EnacrSPKF` is almost flat with respect to the initialization sweep, but at a poor error level.
- The hardest point remains the `100%` initial SOC case. Many estimators degrade sharply there, which makes it a useful stress point for comparison against tuned-covariance runs.

## How to regenerate them

Run the full desktop-evaluation initial-SOC sweep with parallel execution and shared default covariances:

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

results = runInitSocStudy([0 100], 10, cfg);
```

Reprint the compact summary from the saved MAT file:

```matlab
printInitSocSweepSummary( ...
    fullfile('Evaluation', 'initSOCs', 'results', ...
    'Init_Sweep_ATL_BSS_init_soc_sweep_results.mat'));
```

Regenerate the summary figures from the saved sweep:

```matlab
plotInitSocSweepResults( ...
    fullfile('Evaluation', 'initSOCs', 'results', ...
    'Init_Sweep_ATL_BSS_init_soc_sweep_results.mat'));
```
