# Estimator Initial-SOC Sweep Results

## Brief description of the scenario

This result summarizes the initial-SOC sensitivity study run with `Evaluation/initSOCs/runInitSocStudy.m` on the ATL desktop-evaluation setup.

Scenario:

| Item | Value |
| --- | --- |
| Study script | `Evaluation/initSOCs/runInitSocStudy.m` / `Evaluation/initSOCs/sweepInitSocStudy.m` |
| Saved results | `Evaluation/initSOCs/results/Init_Sweep_ATL_BSS_init_soc_sweep_results.mat` |
| Dataset | `data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat` |
| Dataset type | ESC-driven BSS synthetic dataset |
| ESC model | `models/ATLmodel.mat` |
| Sweep | initial SOC from `0%` to `100%` in `10%` steps |
| Estimators included | `ROM-EKF`, `ESC-SPKF`, `ESC-EKF`, `EaEKF`, `EacrSPKF`, `EnacrSPKF`, `EDUKF`, `EsSPKF`, `EbSPKF`, `EBiSPKF`, `Em7SPKF` |

### Tuned Covariances

| Estimator | Process field | Best process noise | Sensor field | Best sensor noise | Best objective |
| --- | --- | ---: | --- | ---: | ---: |
| `ROM-EKF` | `sigma_w_ekf` | 88.2064 | `sigma_v_ekf` | 0.144378 | 9.1362 |
| `ESC-SPKF` | `sigma_w_esc` | 0.128351 | `sigma_v_esc` | 2.9555e-06 | 0.6263 |
| `ESC-EKF` | `sigma_w_esc` | 0.0127887 | `sigma_v_esc` | 0.199838 | 0.5955 |
| `EaEKF` | `sigma_w_esc` | 1.0136e-06 | `sigma_v_esc` | 1.8651e-08 | 0.7271 |
| `EDUKF` | `sigma_w_esc` | 0.0172961 | `sigma_v_esc` | 1.1831e-08 | 0.6287 |
| `EsSPKF` | `sigma_w_esc` | 0.076504 | `sigma_v_esc` | 4.9287e-08 | 0.6246 |
| `EbSPKF` | `sigma_w_esc` | 0.0210635 | `sigma_v_esc` | 4.1610e-05 | 0.6261 |
| `EBiSPKF` | `sigma_w_esc` | 0.0285229 | `sigma_v_esc` | 1.0085e-08 | 0.6268 |
| `Em7SPKF` | `sigma_w_esc` | 0.0830619 | `sigma_v_esc` | 1.0013e-08 | 0.6275 |
| `EacrSPKF` | `sigma_w_esc` | 1.0251e-06 | `sigma_v_esc` | 0.199504 | 0.6567 |
| `EnacrSPKF` | `sigma_w_esc` | 1.0309e-06 | `sigma_v_esc` | 1.0226e-08 | 10.4370 |


This study shows how strongly each estimator depends on the initial SOC guess under the core ATL desktop-evaluation bundle.

## Results


### Aggregate summary across the full sweep

| Estimator | Mean SOC RMSE (%) | Best SOC RMSE (%) | Worst SOC RMSE (%) | Mean Voltage RMSE (mV) | Best Voltage RMSE (mV) | Worst Voltage RMSE (mV) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `ROM-EKF` | 11.214 | 9.137 | 13.483 | 48.31 | 47.21 | 51.91 |
| `ESC-SPKF` | 0.633 | 0.626 | 0.653 | 0.21 | 0.18 | 0.47 |
| `ESC-EKF` | 12.601 | 0.596 | 33.448 | 22.28 | 6.29 | 135.53 |
| `EaEKF` | 0.891 | 0.707 | 1.221 | 0.33 | 0.00 | 2.87 |
| `EacrSPKF` | 25.199 | 0.656 | 52.523 | 40.15 | 0.43 | 129.02 |
| `EnacrSPKF` | 10.537 | 10.436 | 10.662 | 3.71 | 3.56 | 3.95 |
| `EDUKF` | 2.405 | 0.628 | 4.245 | 0.69 | 0.04 | 2.72 |
| `EsSPKF` | 12.184 | 0.624 | 45.891 | 6.18 | 0.09 | 35.41 |
| `EbSPKF` | 0.665 | 0.626 | 0.736 | 0.30 | 0.27 | 0.49 |
| `EBiSPKF` | 0.633 | 0.626 | 0.652 | 0.10 | 0.05 | 0.43 |
| `Em7SPKF` | 11.859 | 0.627 | 45.899 | 6.08 | 0.09 | 35.56 |

### Best initial-SOC point per estimator

| Estimator | Best initial SOC (%) | SOC RMSE at best point (%) | Voltage RMSE at best point (mV) |
| --- | ---: | ---: | ---: |
| `ROM-EKF` | 60 | 9.1368 | 47.4740 |
| `ESC-SPKF` | 60 | 0.6259 | 0.1824 |
| `ESC-EKF` | 60 | 0.5960 | 6.2947 |
| `EaEKF` | 40 | 0.7074 | 0.0052 |
| `EacrSPKF` | 60 | 0.6563 | 0.6172 |
| `EnacrSPKF` | 60 | 10.4360 | 3.8352 |
| `EDUKF` | 60 | 0.6282 | 0.0351 |
| `EsSPKF` | 60 | 0.6241 | 0.0881 |
| `EbSPKF` | 60 | 0.6256 | 0.2681 |
| `EBiSPKF` | 60 | 0.6263 | 0.0507 |
| `Em7SPKF` | 60 | 0.6271 | 0.0912 |

### Selected sweep points

| Initial SOC (%) | Best SOC RMSE estimator | Value (%) | Best Voltage RMSE estimator | Value (mV) |
| ---: | --- | ---: | --- | ---: |
| 0 | `EBiSPKF` | 0.6521 | `EBiSPKF` | 0.4335 |
| 50 | `EBiSPKF` | 0.6265 | `EaEKF` | 0.0044 |
| 60 | `EsSPKF` | 0.6241 | `EaEKF` | 0.0059 |
| 100 | `ESC-SPKF` | 0.6436 | `EBiSPKF` | 0.1170 |

### Practical ranking for this study

| Rank | Most robust on SOC RMSE | Why |
| --- | --- | --- |
| 1 | `EBiSPKF` | Lowest mean SOC RMSE in the sweep, low worst-case degradation, and stable behavior from `0%` to `100%` initial SOC. |
| 2 | `ESC-SPKF` | Nearly identical average SOC performance to `EBiSPKF`, with similarly strong robustness across the full sweep. |
| 3 | `EbSPKF` | Slightly worse average RMSE than `EBiSPKF` and `ESC-SPKF`, but still clearly robust and stable over the full range. |

| Rank | Best on voltage RMSE | Why |
| --- | --- | --- |
| 1 | `EBiSPKF` | Best mean voltage RMSE and best high-mismatch edge behavior among the robust estimators. |
| 2 | `ESC-SPKF` | Very low voltage RMSE across the entire sweep, with a similarly flat response to initialization error. |
| 3 | `EbSPKF` | Good voltage stability across the whole sweep, though not as accurate as `EBiSPKF` or `ESC-SPKF`. |

## Observations

- The strongest init-SOC robustness in this run comes from `EBiSPKF`, `ESC-SPKF`, and `EbSPKF`. Their SOC RMSE curves remain flat across the entire sweep, which is the main result of this study.
- `EaEKF` is still strong, especially on voltage RMSE and around the center of the sweep, but it is less initialization-invariant than the best sigma-point filters here.
- `ESC-EKF`, `EacrSPKF`, `EsSPKF`, and `Em7SPKF` show good behavior near the correct initialization and then degrade sharply at the sweep edges, especially at low or high initial SOC.
- `EnacrSPKF` is almost insensitive to the initialization sweep, but at a poor error level. Its flat curve is not a robustness win.
- `ROM-EKF` remains much worse than the ESC-based estimators in this study, both on SOC and on voltage.
- The best operating region for most estimators is still near `60%` initial SOC, which is where almost every method reaches its minimum SOC RMSE.

## How to regenerate them

Run the full desktop-evaluation initial-SOC sweep with parallel execution and a tuned estimator profile:

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
