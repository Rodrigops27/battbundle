# Estimator Initial-Covariance Sweep Results

## Brief description of the scenario

This result summarizes the covariance sweep performed on the NMC30 behaviour validation setup.

Scenario:

| Item | Value |
| --- | --- |
| Study layer | `Evaluation/NoiseTuningSweep/` |
| Core script | `Evaluation/NoiseTuningSweep/sweepNoiseStudy.m` |
| Dataset mode | ESC-driven BSS synthetic dataset |
| Dataset | `Evaluation/ROMSimData/datasets/rom_bus_coreBattery_dataset.mat` |
| ESC model | `models/NMC30model.mat` |
| Sweep mode | `grid` |
| `sigma_w` range | `0.001, 0.005, 0.025, 0.125, 0.625, 3.12, 15.6, 78.1, 100` |
| `sigma_v` range | `1e-06, 5e-06, 2.5e-05, 0.000125, 0.000625, 0.00313, 0.0156, 0.0781, 0.2` |

This study is useful to understand how sensitive each estimator is to covariance tuning and whether a method has a broad stable region or only a narrow optimum.

## Results (tables)

### Best point found for each estimator

| Estimator | Best `sigma_w` | Best `sigma_v` | Best SOC RMSE (%) | Best SOC ME (%) | SOC MSSD (%^2) | Voltage RMSE at best SOC (mV) | Voltage ME at best SOC (mV) | Voltage MSSD at best SOC (mV^2) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `ROM-EKF` | 3.125 | 0.2 | 0.0902 | -0.0546 | 0.000017 | 2.3699 | -0.0267 | 0.0332 |
| `ESC-SPKF` | 78.125 | 0.015625 | 0.1748 | -0.0693 | 0.000019 | 2.2061 | -0.2290 | 0.0742 |
| `ESC-EKF` | 100 | 0.078125 | 0.1716 | -0.0985 | 0.000018 | 2.3287 | -0.4798 | 0.0741 |
| `EaEKF` | 0.001 | 0.2 | 0.2973 | -0.0498 | 0.000084 | 0.0976 | 0.0012 | 0.1058 |
| `EacrSPKF` | 0.625 | 1e-06 | 1.3322 | -1.0137 | 0.000020 | 0.0837 | 0.0078 | 0.1445 |
| `EnacrSPKF` | 0.001 | 1e-06 | 0.3353 | 0.0245 | 0.000196 | 1.2200 | 0.6072 | 0.1150 |
| `EDUKF` | 0.125 | 1e-06 | 0.0862 | -0.0556 | 0.000018 | 0.3700 | -0.0517 | 0.1829 |
| `EsSPKF` | 15.625 | 0.000125 | 0.0991 | -0.0548 | 0.000018 | 0.3914 | -0.0511 | 0.1717 |
| `EbSPKF` | 0.001 | 0.003125 | 0.1558 | -0.0498 | 0.000018 | 2.3172 | -0.0379 | 0.0741 |
| `EBiSPKF` | 78.125 | 0.015625 | 0.1748 | -0.0693 | 0.000019 | 2.2061 | -0.2290 | 0.0742 |

### Aggregate robustness summary across the whole sweep

| Estimator | Mean SOC RMSE (%) | Best SOC RMSE (%) | Worst SOC RMSE (%) | Mean Voltage RMSE (mV) | Best Voltage RMSE (mV) | Worst Voltage RMSE (mV) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `ROM-EKF` | 20.542 | 0.090 | 72.286 | extremely unstable | 1.88 | catastrophic divergence |
| `EsSPKF` | 0.314 | 0.099 | 0.877 | 2.26 | 0.27 | 7.41 |
| `EbSPKF` | 0.205 | 0.156 | 0.292 | 1.87 | 0.52 | 2.51 |
| `EDUKF` | 0.307 | 0.086 | 0.877 | 2.25 | 0.23 | 7.41 |
| `EBiSPKF` | 0.382 | 0.175 | 0.889 | 3.14 | 0.52 | 7.87 |
| `ESC-SPKF` | 0.382 | 0.175 | 0.889 | 3.14 | 0.52 | 7.87 |
| `ESC-EKF` | 0.383 | 0.172 | 0.889 | 3.11 | 0.03 | 7.91 |
| `EaEKF` | 0.298 | 0.297 | 0.298 | 0.03 | 0.00 | 0.10 |
| `EacrSPKF` | 1.670 | 1.332 | 1.808 | 0.75 | 0.08 | 1.50 |
| `EnacrSPKF` | 19.213 | 0.335 | 41.378 | 239.39 | 1.22 | 689.30 |

### Practical ranking for this study

| Rank | Most robust on SOC RMSE | Why |
| --- | --- | --- |
| 1 | `EbSPKF` | Lowest mean SOC RMSE among the stable ESC estimators and a narrow best-to-worst spread. |
| 2 | `EaEKF` | Slightly worse SOC RMSE than `EbSPKF`, but essentially flat across the whole grid, as expected. |
| 3 | `EDUKF` | Best absolute SOC RMSE point among the ESC methods and reasonable average robustness. |

| Rank | Best on voltage RMSE | Why |
| --- | --- | --- |
| 1 | `EaEKF` | Dominates voltage RMSE across the full sweep and stays near-constant. |
| 2 | `EacrSPKF` | Strong voltage-fit specialist, but weak on SOC RMSE. |
| 3 | `EDUKF` / `EsSPKF` | Good best-point voltage RMSE with a broader stable region than `EacrSPKF`. |

## Observations

- `EbSPKF` looks like the safest deployment candidate if the exact covariance tuning is uncertain. It does not have the best absolute point, but it stays good over a broad region.
- `EaEKF` is almost insensitive to this covariance grid in the reported run. That makes it attractive when voltage-fit consistency matters more than absolute best SOC RMSE.
- `EDUKF` achieves the best ESC-family SOC RMSE point (`0.0862%`), but its average behavior is slightly less stable than `EbSPKF`.
- `ESC-SPKF` and `EBiSPKF` are again numerically identical in this repo setup, which is consistent with the bias branch staying effectively inactive under the default configuration.
- `ROM-EKF` has a needle optimum. It can be excellent at one point, but its average behavior across the grid is unusable because large parts of the sweep diverge numerically.
- `EnacrSPKF` is not robust on this study. It has a reasonable best point, but its average behavior is dominated by very poor regions.
- `EacrSPKF` is a voltage-fit specialist here: very good voltage RMSE, clearly worse SOC RMSE.

## How to regenerate them

Run the NMC30 behaviour-validation covariance sweep with the same dataset and estimator subset used in this note:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.dataset_mode = 'rom';
cfg.rom_dataset_file = fullfile('Evaluation', 'ROMSimData', 'datasets', 'rom_bus_coreBattery_dataset.mat');
cfg.esc_model_file = fullfile('models', 'NMC30model.mat');
cfg.rom_file = fullfile('models', 'ROM_NMC30_HRA12.mat');
cfg.estimator_names = { ...
    'iterEKF', ...
    'iterESCSPKF', ...
    'iterESCEKF', ...
    'iterEaEKF', ...
    'iterEacrSPKF', ...
    'iterEnacrSPKF', ...
    'iterEDUKF', ...
    'iterEsSPKF', ...
    'iterEbSPKF', ...
    'iterEBiSPKF'};

results = runNoiseCovStudy([], [], [], cfg);
```

Regenerate the figures from the saved result file:

```matlab
S = load(results.saved_results_file);

plotNoiseSweepSummary(S.sweepResults);
plotNoiseSweepHeatmaps(S.sweepResults);
plotEaEkfCovarianceSweeps(S.sweepResults);
```

If you want to avoid rerunning the sweep and already know the saved file path:

```matlab
S = load('Evaluation/NoiseTuningSweep/results/runNoiseCovStudy_YYYYMMDD_HHMMSS.mat');

plotNoiseSweepSummary(S.sweepResults);
plotNoiseSweepHeatmaps(S.sweepResults);
plotEaEkfCovarianceSweeps(S.sweepResults);
```
