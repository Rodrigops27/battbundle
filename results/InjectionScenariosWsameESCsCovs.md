# Canonical Injection Scenario Results With Shared ESC Covariances

## Description of the scenario

This summary reports the ATL desktop-evaluation injection study. The source dataset is the ESC-driven BSS synthetic dataset, and the estimators were benchmarked with one shared benchmark covariance setting rather than estimator-specific autotuned covariances.

| Item | Value |
| --- | --- |
| Study layer | `Evaluation/Injection/` |
| Saved run | `Evaluation/Injection/results/injection_20260324_154523.mat` |
| Scenario name | `atl_bss_desktop` |
| Source dataset | `data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat` |
| ESC model | `models/ATLmodel.mat` |
| ROM model | `models/ROM_ATL20_beta.mat` |
| Injection cases reported here | `additive_measurement_noise`, `sensor_gain_bias_fault` |
| Estimators reported here | `ROM-EKF`, `ESC-SPKF`, `ESC-EKF`, `EaEKF`, `EacrSPKF`, `EnacrSPKF`, `EDUKF`, `EsSPKF`, `EbSPKF`, `EBiSPKF`, `Em7SPKF` |

### Tuned Covariances

The benchmark uses the shared tuning values:

| Parameter | Value |
| --- | ---: |
| tuning.sigma_x0_rom_tail | 2e6 |
| tuning.sigma_w_ekf | 1e2 |
| tuning.sigma_v_ekf | 1e-3 |
| tuning.SigmaX0_rc | 1e-6 |
| tuning.SigmaX0_hk | 1e-6 |
| tuning.SigmaX0_soc | 1e-3 |
| tuning.sigma_w_esc | 1e-3 |
| tuning.sigma_v_esc | 1e-3 |
| tuning.SigmaR0 | 1e-6 |
| tuning.SigmaWR0 | 1e-16 |
| tuning.current_bias_var0 | 1e-5 |
| tuning.single_bias_process_var | 1e-8 |


So this document is the correct untuned or shared-covariance injection reference for the ATL bundle.

The injected cases in this saved run are:
- `additive_measurement_noise`: `15 mV` voltage noise standard deviation and `+-5%` samplewise current scaling
- `sensor_gain_bias_fault`: current gain `1.1`, current offset `0.1 A`, voltage gain fault `6e-4`, and voltage offset `2 mV`

## Results

### Injected-dataset validation summary

| Injection case | Current RMSE [A] | Current ME [A] | Voltage RMSE [mV] | Voltage ME [mV] | Interpretation |
| --- | ---: | ---: | ---: | ---: | --- |
| `additive_measurement_noise` | 0.0824 | 0.0000 | 14.9961 | 0.0277 | Moderate random sensor corruption with visible voltage noise |
| `sensor_gain_bias_fault` | 0.3023 | -0.1006 | 3.9880 | -3.9879 | Deterministic sensor fault with stronger current-channel distortion |

### Additive-Measurement-Noise Case

| Estimator | SOC RMSE [%] | SOC ME [%] | Voltage RMSE [mV] | Voltage ME [mV] |
| --- | ---: | ---: | ---: | ---: |
| `EacrSPKF` | 0.6475 | 0.5574 | 10.0563 | 0.1721 |
| `EbSPKF` | 0.6592 | 0.5626 | 0.4404 | 0.0207 |
| `ESC-SPKF` | 0.6767 | 0.5752 | 0.3999 | 0.0332 |
| `EBiSPKF` | 0.6767 | 0.5752 | 0.3999 | 0.0332 |
| `EDUKF` | 0.6903 | 0.6121 | 0.4078 | 0.0444 |
| `EsSPKF` | 0.6903 | 0.6121 | 0.4078 | 0.0444 |
| `Em7SPKF` | 0.6903 | 0.6121 | 0.4078 | 0.0444 |
| `ESC-EKF` | 2.9934 | 1.7801 | 6.4371 | 0.6248 |
| `EaEKF` | 15.3895 | 0.2197 | 279.5265 | -42.5654 |
| `EnacrSPKF` | 22.3838 | 19.5720 | 15.7156 | -7.0706 |
| `ROM-EKF` | 22.9668 | -2.4010 | 70.1983 | -0.5503 |

### Sensor-Gain-Bias-Fault Case

| Estimator | SOC RMSE [%] | SOC ME [%] | Voltage RMSE [mV] | Voltage ME [mV] |
| --- | ---: | ---: | ---: | ---: |
| `EbSPKF` | 8.1612 | -6.4820 | 5.5456 | -4.2536 |
| `EsSPKF` | 8.5478 | -4.6531 | 5.7821 | -2.0230 |
| `Em7SPKF` | 8.5478 | -4.6531 | 5.7821 | -2.0230 |
| `EDUKF` | 8.5532 | -4.6572 | 5.7834 | -2.0253 |
| `ESC-EKF` | 8.7884 | -4.9318 | 7.1640 | -2.3663 |
| `ESC-SPKF` | 9.1967 | -5.0926 | 6.1740 | -2.0552 |
| `EBiSPKF` | 9.1967 | -5.0926 | 6.1740 | -2.0552 |
| `EacrSPKF` | 13.9070 | 11.9116 | 3.9461 | -3.9161 |
| `EaEKF` | 20.9355 | -17.5882 | 339.4915 | -79.7754 |
| `EnacrSPKF` | 22.4136 | 19.9441 | 19.8799 | -12.9120 |
| `ROM-EKF` | 24.9191 | 12.6206 | 39.4389 | 8.4813 |

### Practical ranking for this study

| Case | Rank | Best on SOC RMSE | Value | Best on Voltage RMSE | Value |
| --- | ---: | --- | ---: | --- | ---: |
| `additive_measurement_noise` | 1 | `EacrSPKF` | 0.6475 | `ESC-SPKF` / `EBiSPKF` | 0.3999 |
| `additive_measurement_noise` | 2 | `EbSPKF` | 0.6592 | `EDUKF` / `EsSPKF` / `Em7SPKF` | 0.4078 |
| `additive_measurement_noise` | 3 | `ESC-SPKF` / `EBiSPKF` | 0.6767 | `EbSPKF` | 0.4404 |
| `sensor_gain_bias_fault` | 1 | `EbSPKF` | 8.1612 | `EacrSPKF` | 3.9461 |
| `sensor_gain_bias_fault` | 2 | `EsSPKF` / `Em7SPKF` | 8.5478 | `EbSPKF` | 5.5456 |
| `sensor_gain_bias_fault` | 3 | `EDUKF` | 8.5532 | `EsSPKF` / `Em7SPKF` | 5.7821 |

## Observations

- This is the correct shared-covariance reference run for the ATL injection study. Unlike the tuned-profile injection report, all estimators here use the same baseline covariance settings.
- In the `additive_measurement_noise` case, `EacrSPKF` is best on SOC RMSE, while `ESC-SPKF` and `EBiSPKF` are best on voltage RMSE.
- In the `sensor_gain_bias_fault` case, `EbSPKF` is best on SOC RMSE, but `EacrSPKF` is best on voltage RMSE.
- `EDUKF`, `EsSPKF`, and `Em7SPKF` remain nearly identical in both cases.
- `EnacrSPKF` performs poorly in both injected cases under this shared-covariance setup.
- `EaEKF` and `ROM-EKF` remain weak under these untuned/shared covariance conditions, especially in voltage fit.

## How to regenerate them

To regenerate the same eleven-estimator ATL injection study with shared benchmark covariances:

```matlab
addpath(genpath('.'));

cfg = defaultInjectionConfig();
cfg.scenarios(1).estimatorSetSpec.estimator_names = { ...
    'ROM-EKF', ...
    'ESC-SPKF', 'ESC-EKF', 'EaEKF', ...
    'EacrSPKF', 'EnacrSPKF', 'EDUKF', ...
    'EsSPKF', 'EbSPKF', 'EBiSPKF', 'Em7SPKF'};
cfg.scenarios(1).estimatorSetSpec.tuning = struct( ...
    'sigma_w_esc', 1e-3, ...
    'sigma_v_esc', 1e-3, ...
    'sigma_w_ekf', 1e2, ...
    'sigma_v_ekf', 1e-3);

results = runInjectionStudy(cfg);
printInjectionSummary(results);
plotInjectionResults(results);
```

