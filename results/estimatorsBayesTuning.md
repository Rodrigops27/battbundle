# Estimator Benchmark Results

## Description of the scenario

This summary reports the results obtain through a Bayes optimization to tune the Kalman.

Scenario details:
- chemistry / scenario: `ATL` / `atl_bss_esc`
- dataset: `Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`
- ESC model: `models/ATLmodel.mat`
- ROM model: `models/ROM_ATL20_beta.mat`
- optimization objective: `SocRmsePct`
- BayesOpt budget: `30` objective evaluations with `8` seed points
- parallel execution: enabled


## Results

### Best Tuning

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

### Benchmark

| Estimator | SOC RMSE (%) | SOC ME (%) | Voltage RMSE (mV) | Voltage ME (mV) |
| --- | ---: | ---: | ---: | ---: |
| `ESC-EKF` | 0.5955 | -0.1094 | 6.2947 | -0.2932 |
| `EsSPKF` | 0.6246 | 0.5405 | 0.0881 | 0.0003 |
| `EbSPKF` | 0.6261 | 0.5230 | 0.2681 | -0.0006 |
| `ESC-SPKF` | 0.6263 | 0.5397 | 0.1824 | -0.0005 |
| `EBiSPKF` | 0.6268 | 0.5342 | 0.0507 | 0.0005 |
| `Em7SPKF` | 0.6275 | 0.5480 | 0.0912 | 0.0004 |
| `EDUKF` | 0.6287 | 0.5388 | 0.0351 | 0.0006 |
| `EacrSPKF` | 0.6567 | 0.5694 | 0.6172 | 0.1445 |
| `EaEKF` | 0.7271 | 0.5501 | 0.0059 | 0.0000 |
| `ROM-EKF` | 9.1362 | -0.0651 | 47.4744 | -3.8803 |
| `EnacrSPKF` | 10.4370 | 7.5156 | 3.8352 | -0.7517 |

### Practical ranking for this study

| Rank | Best by SOC RMSE | Value | Best by Voltage RMSE | Value |
| --- | --- | ---: | --- | ---: |
| 1 | `ESC-EKF` | 0.5955% | `EaEKF` | 0.0059 mV |
| 2 | `EsSPKF` | 0.6246% | `EDUKF` | 0.0351 mV |
| 3 | `EbSPKF` | 0.6261% | `EBiSPKF` | 0.0507 mV |

## Observations

- Under the `SocRmsePct` Bayes tuning objective, `ESC-EKF` is the best overall SOC estimator on this ATL desktop run.
    - `ESC-EKF` show more even bias, the other estimators presents a positively increasing residual.
- `EaEKF` is not the SOC winner, but it is the strongest voltage-fit estimator by a large margin.
- `EsSPKF`, `EbSPKF`, `ESC-SPKF`, `EBiSPKF`, `Em7SPKF`, and `EDUKF` form a very tight SOC-RMSE cluster around `0.625%` to `0.629%`.
    - Their tuning clusters too, they share the same assumptions.
- `ROM-EKF` and `EnacrSPKF` remain far behind the top ESC estimators even after Bayes tuning on this saved run.

## How to regenerate them

```matlab
addpath(genpath('.'));

cfg = defaultAutotuningConfig();
cfg.scenarios(1).estimator_names = { ...
    'ROM-EKF', ...
    'ESC-SPKF', ...
    'ESC-EKF', ...
    'EaEKF', ...
    'EDUKF', ...
    'EsSPKF', ...
    'EbSPKF', ...
    'EBiSPKF', ...
    'Em7SPKF', ...
    'EacrSPKF', ...
    'EnacrSPKF'};

cfg.objective.metric = 'SocRmsePct';
cfg.bayesopt.max_objective_evals = 30;
cfg.bayesopt.num_seed_points = 8;
cfg.bayesopt.use_parallel = true;
cfg.bayesopt.auto_start_parallel_pool = true;

results = runAutotuning(cfg);
printAutotuningSummary(results);
plotAutotuningHistory(results);
plotAutotunedResults(results);
```

## Tuned Covariance Analysis

### EaEKF tracked covariance reference

| Quantity | Initial | Final | Mean | Median | Mode |
| --- | ---: | ---: | ---: | ---: | ---: |
| `SigmaW(RC1)` | 1.0135e-06 | 9.3880e-07 | 9.6396e-07 | 9.5204e-07 | 1.0135e-06 |
| `SigmaW(RC2)` | 1.0135e-06 | 2.1400e-08 | 3.6843e-07 | 1.6600e-08 | 1.0135e-06 |
| `SigmaW(h)` | 1.0135e-06 | 7.2080e-08 | 8.3400e-08 | 1.0000e-10 | 1.0135e-06 |
| `SigmaW(SOC)` | 1.0135e-06 | 7.7170e-08 | 8.8880e-08 | 1.0000e-10 | 1.0135e-06 |
| `SigmaV` | 1.8652e-08 | 3.8000e-11 | 1.0000e-10 | ~0 | 1.8652e-08 |

### Tuned ESC covariance set

| Estimator | Tuned `sigma_w_esc` | Tuned `sigma_v_esc` |
| --- | ---: | ---: |
| `ESC-EKF` | 0.0127887 | 0.199838 |
| `EsSPKF` | 0.0765040 | 4.9287e-08 |
| `EbSPKF` | 0.0210635 | 4.1610e-05 |
| `ESC-SPKF` | 0.1283510 | 2.9555e-06 |
| `EBiSPKF` | 0.0285229 | 1.0085e-08 |
| `Em7SPKF` | 0.0830619 | 1.0013e-08 |
| `EDUKF` | 0.0172961 | 1.1831e-08 |
| `EacrSPKF` | 1.0251e-06 | 0.199504 |
| `EnacrSPKF` | 1.0309e-06 | 1.0226e-08 |

### Difference To EaEKF Final Tracked Covariance

| Estimator | `sigma_w_esc - SigmaW(RC1)_final` | `sigma_w_esc - SigmaW(RC2)_final` | `sigma_w_esc - SigmaW(h)_final` | `sigma_w_esc - SigmaW(SOC)_final` | `sigma_v_esc - SigmaV_final` |
| --- | ---: | ---: | ---: | ---: | ---: |
| `ESC-EKF` | 0.012788 | 0.012789 | 0.012789 | 0.012789 | 0.19984 |
| `EsSPKF` | 0.076503 | 0.076504 | 0.076504 | 0.076504 | 4.9249e-08 |
| `EbSPKF` | 0.021063 | 0.021064 | 0.021063 | 0.021063 | 4.1610e-05 |
| `ESC-SPKF` | 0.12835 | 0.12835 | 0.12835 | 0.12835 | 2.9555e-06 |
| `EBiSPKF` | 0.028522 | 0.028523 | 0.028523 | 0.028523 | 1.0047e-08 |
| `Em7SPKF` | 0.083061 | 0.083062 | 0.083062 | 0.083062 | 9.9758e-09 |
| `EDUKF` | 0.017295 | 0.017296 | 0.017296 | 0.017296 | 1.1794e-08 |
| `EacrSPKF` | 8.6302e-08 | 1.0037e-06 | 9.5302e-07 | 9.4793e-07 | 0.19950 |
| `EnacrSPKF` | 9.2142e-08 | 1.0096e-06 | 9.5886e-07 | 9.5377e-07 | 1.0188e-08 |

### Observations

- Most tuned ESC estimators settle on process-noise levels that are orders of magnitude larger than the EaEKF final tracked `SigmaW`, especially for `RC2`, `h`, and `SOC`.
- `EacrSPKF` and `EnacrSPKF` are the only process-noise tunings that remain close to the EaEKF process-covariance scale; all other tuned `sigma_w_esc` values are much larger.
- On the sensor side, `EBiSPKF`, `Em7SPKF`, `EDUKF`, and `EnacrSPKF` stay near the EaEKF sensor-covariance scale, while `ESC-EKF` and `EacrSPKF` tune to a much larger `sigma_v_esc`.
