# Perturbance And Noise Injection Results

## Description of the scenario

This summary reports the ATL desktop-evaluation injection study saved in `Evaluation/Injection/results/injection_20260324_135341.mat`.

The run uses the tuned estimator profile resolved from:
- `autotuning/results/autotuning_20260324_000225.mat`

Scenario:

| Item | Value |
| --- | --- |
| Study layer | `Evaluation/Injection/` |
| Core script | `Evaluation/Injection/runInjectionStudy.m` |
| Source dataset | `Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat` |
| ESC model | `models/ATLmodel.mat` |
| ROM model | `models/ROM_ATL20_beta.mat` |
| Injection cases reported here | `noise`, `perturbance` |
| Estimators reported here | `ROM-EKF`, `ESC-SPKF`, `ESC-EKF`, `EaEKF`, `EacrSPKF`, `EnacrSPKF`, `EDUKF`, `EsSPKF`, `EbSPKF`, `EBiSPKF`, `Em7SPKF` |
| Tuning source | `autotuning_profile` |

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

The two injected cases represented here are:
- `noise`: `15 mV` voltage noise target standard deviation and `+-5%` samplewise current scaling
- `perturbance`: current gain `1.1`, current offset `0.1 A`, voltage gain fault `6e-4`, and voltage offset `2 mV`


## Results

### Injected-dataset validation summary

| Injection case | Current RMSE [A] | Voltage RMSE [mV] | Interpretation |
| --- | ---: | ---: | --- |
| `noise` | 0.0824 | 14.9961 | Moderate random sensor corruption with small current distortion and visible voltage noise |
| `perturbance` | 0.3023 | 3.9880 | Stronger current-channel distortion with smaller direct voltage mismatch |

### Noise case

| Estimator | SOC RMSE [%] | SOC ME [%] | Voltage RMSE [mV] | Voltage ME [mV] |
| --- | ---: | ---: | ---: | ---: |
| `ESC-EKF` | 0.5856 | -0.0728 | 6.2933 | -0.2601 |
| `EacrSPKF` | 0.6501 | 0.5607 | 10.0576 | 0.1722 |
| `ROM-EKF` | 9.1433 | -0.0533 | 47.4661 | -3.8670 |
| `ESC-SPKF` | 18.0674 | 2.4663 | 175.1011 | -19.2501 |
| `EbSPKF` | 20.5826 | 13.2252 | 15.5173 | -0.4506 |
| `EBiSPKF` | 22.1885 | 2.0957 | 240.5872 | -27.8861 |
| `EaEKF` | 23.2400 | 7.2222 | 489.6643 | -52.1860 |
| `EnacrSPKF` | 28.4529 | 2.6454 | 301.6489 | -40.8777 |
| `Em7SPKF` | 34.5565 | 10.4294 | 50.8378 | -0.8469 |
| `EsSPKF` | 38.2149 | 10.2927 | 56.8663 | -1.3345 |
| `EDUKF` | 40.6825 | 9.6847 | 123.1506 | -6.7658 |

### Perturbance case

| Estimator | SOC RMSE [%] | SOC ME [%] | Voltage RMSE [mV] | Voltage ME [mV] |
| --- | ---: | ---: | ---: | ---: |
| `ESC-EKF` | 3.5536 | 1.0503 | 5.6296 | 2.0211 |
| `Em7SPKF` | 9.4621 | -7.6263 | 4.4637 | -4.0026 |
| `EsSPKF` | 9.6963 | -7.8138 | 4.5373 | -4.0163 |
| `EBiSPKF` | 9.9932 | -8.3390 | 4.9476 | -3.9756 |
| `ESC-SPKF` | 10.0354 | -8.4923 | 4.1639 | -4.0037 |
| `EbSPKF` | 10.0521 | -8.2139 | 5.6021 | -4.4130 |
| `EDUKF` | 11.1123 | -9.2649 | 9.1652 | -4.0341 |
| `EacrSPKF` | 13.9024 | 11.9065 | 3.9459 | -3.9159 |
| `ROM-EKF` | 14.2554 | 5.6736 | 47.4785 | -0.1594 |
| `EnacrSPKF` | 14.9684 | 8.4594 | 9.4253 | -4.9254 |
| `EaEKF` | 22.0835 | -19.9095 | 167.8129 | -24.4568 |

### Practical ranking for this study

| Case | Rank | Best on SOC RMSE | Value | Best on Voltage RMSE | Value |
| --- | ---: | --- | ---: | --- | ---: |
| `noise` | 1 | `ESC-EKF` | 0.5856 | `ESC-EKF` | 6.2933 |
| `noise` | 2 | `EacrSPKF` | 0.6501 | `EacrSPKF` | 10.0576 |
| `noise` | 3 | `ROM-EKF` | 9.1433 | `EbSPKF` | 15.5173 |
| `perturbance` | 1 | `ESC-EKF` | 3.5536 | `EacrSPKF` | 3.9459 |
| `perturbance` | 2 | `Em7SPKF` | 9.4621 | `ESC-SPKF` | 4.1639 |
| `perturbance` | 3 | `EsSPKF` | 9.6963 | `Em7SPKF` | 4.4637 |

## Observations

- `ESC-EKF` is the strongest overall estimator in this saved study. It is best on SOC RMSE in both `noise` and `perturbance`, and it is also best on voltage RMSE in the `noise` case.
- `EacrSPKF` becomes a strong tuned alternative here. It is second-best on SOC RMSE in the `noise` case and best on voltage RMSE in the `perturbance` case.
- `ROM-EKF` is no longer the worst estimator in the tuned `noise` case, but it is still clearly behind the best ESC estimators and remains unusable on voltage RMSE in the `perturbance` case.
- Several SPKF-family estimators that were previously top performers in the untuned ATL injection study now degrade badly under this tuned-profile run, especially `EDUKF`, `EsSPKF`, and `Em7SPKF` in the `noise` case.
- `EaEKF` remains unstable in both injected cases for this saved run, with very large voltage RMSE.

## How to regenerate them

To regenerate the tuned-profile ATL injection study with the same eleven reported estimators:

```matlab
addpath(genpath('.'));

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
printInjectionSummary(results);
plotInjectionResults(results);
```
