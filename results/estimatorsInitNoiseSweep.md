# Estimator Noise-Covariance Sweep Results

## Brief description of the scenario

This result summarizes the multi-estimator noise-covariance sweep on the ATL desktop-evaluation setup. The study varies process noise `sigma_w` and sensor noise `sigma_v` on the ESC-driven BSS dataset to see which estimators are robust to tuning and which only work in a narrow region.

| Item | Value |
| --- | --- |
| Study layer | `Evaluation/NoiseTuningSweep/` |
| Core scripts | `runNoiseCovStudy.m`, `sweepNoiseStudy.m` |
| Dataset mode | ESC-driven BSS synthetic dataset |
| Dataset | `data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat` |
| ESC model | `models/ATLmodel.mat` |
| Sweep mode | `grid` |
| `sigma_w` range | `0.001, 0.005, 0.025, 0.125, 0.625, 3.12, 15.6, 78.1, 100` |
| `sigma_v` range | `1e-06, 5e-06, 2.5e-05, 0.000125, 0.000625, 0.00313, 0.0156, 0.0781, 0.2` |
| Estimators included | `ROM-EKF`, `ESC-SPKF`, `ESC-EKF`, `EaEKF`, `EacrSPKF`, `EnacrSPKF`, `EDUKF`, `EsSPKF`, `EbSPKF`, `EBiSPKF`, `Em7SPKF` |

## Results

### Best point found in the sweep

| Estimator | Best `sigma_w` | Best `sigma_v` | Best SOC RMSE [%] | Best SOC ME [%] | Best Voltage RMSE [mV] | Best Voltage ME [mV] |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `ROM-EKF` | `100` | `0.2` | 9.2297 | -0.2496 | 48.6450 | -4.6980 |
| `ESC-SPKF` | `0.125` | `5e-06` | 0.6253 | 0.5393 | 0.2074 | -0.0008 |
| `ESC-EKF` | `0.001` | `0.2` | 0.5958 | -0.1099 | 6.2947 | -0.2932 |
| `EaEKF` | `0.025` | `0.015625` | 1.0694 | 0.5810 | 0.0066 | 0.0001 |
| `EacrSPKF` | `100` | `5e-06` | 0.5965 | 0.5452 | 0.9961 | 0.2235 |
| `EnacrSPKF` | `0.001` | `5e-06` | 15.4640 | 10.4630 | 6.0730 | 3.1660 |
| `EDUKF` | `0.125` | `1e-06` | 0.6237 | 0.5426 | 0.1435 | 0.0006 |
| `EsSPKF` | `0.125` | `1e-06` | 0.6236 | 0.5412 | 0.1436 | 0.0005 |
| `EbSPKF` | `0.025` | `0.000125` | 0.6214 | 0.5216 | 0.3033 | -0.0025 |
| `EBiSPKF` | `0.125` | `5e-06` | 0.6253 | 0.5393 | 0.2074 | -0.0008 |
| `Em7SPKF` | `0.125` | `1e-06` | 0.6236 | 0.5412 | 0.1436 | 0.0005 |

### Aggregate behavior across the full sweep

| Estimator | Mean SOC RMSE [%] | Worst SOC RMSE [%] | Mean Voltage RMSE [mV] | Worst Voltage RMSE [mV] | Mean Voltage MSSD [mV^2] |
| --- | ---: | ---: | ---: | ---: | ---: |
| `ROM-EKF` | 39.688 | 72.601 | 2.823e15 | 2.286e17 | 1.516e33 |
| `ESC-SPKF` | 1.861 | 6.024 | 4.49 | 23.10 | 0.2402 |
| `ESC-EKF` | 5.899 | 19.740 | 20.52 | 229.92 | 4112.8302 |
| `EaEKF` | 7.519 | 23.463 | 4.50 | 35.38 | 44.0561 |
| `EacrSPKF` | 1.693 | 15.503 | 0.75 | 1.80 | 0.2876 |
| `EnacrSPKF` | 42.572 | 72.634 | 670.34 | 1974.25 | 474577.6516 |
| `EDUKF` | 3.065 | 39.073 | 6.44 | 90.49 | 125.2032 |
| `EsSPKF` | 1.458 | 4.035 | 4.57 | 19.77 | 0.3144 |
| `EbSPKF` | 2.609 | 49.176 | 4.55 | 23.10 | 0.2381 |
| `EBiSPKF` | 1.861 | 6.024 | 4.49 | 23.10 | 0.2402 |
| `Em7SPKF` | 1.458 | 4.035 | 4.57 | 19.77 | 0.3144 |

### Practical reading of the sweep

| Group | Estimators | What the table says |
| --- | --- | --- |
| Best broad-tuning robustness | `EsSPKF`, `Em7SPKF`, `ESC-SPKF`, `EBiSPKF` | Low mean SOC RMSE and relatively low worst-case degradation over the full grid. |
| Best single-point SOC optimum | `ESC-EKF`, `EacrSPKF`, `EbSPKF` | These reach the lowest best-point SOC RMSE values, but some are much more fragile away from the optimum. |
| Best voltage-fit behavior | `EaEKF`, `EDUKF`, `EsSPKF`, `Em7SPKF` | `EaEKF` gives the best pointwise voltage RMSE, while `EsSPKF` and `Em7SPKF` remain more stable over the full sweep. |
| Boundary-sensitive solutions | `ROM-EKF`, `EacrSPKF`, `ESC-EKF` | Their best points sit on sweep boundaries or their worst-case metrics are much larger than their optima, which suggests strong tuning sensitivity. |
| Poor overall candidates in this study | `EnacrSPKF` | High error across the grid with no competitive region in this dataset. |

## Observations

- `EsSPKF` and `Em7SPKF` are the cleanest overall performers in this sweep. They have the lowest mean SOC RMSE among the competitive ESC estimators and relatively mild worst-case degradation.
- `ESC-SPKF` and `EBiSPKF` are numerically identical here. Under this tuning study, the extra bias branch is not changing the result.
- `EbSPKF` reaches one of the best single-point SOC optima, but its worst-case SOC RMSE is much larger than `EsSPKF` or `ESC-SPKF`, so it is less robust to poor tuning choices.
- `EacrSPKF` is interesting: it reaches a near-best SOC optimum and keeps very low voltage RMSE across the sweep, but the best point occurs at the `sigma_w = 100` boundary, which suggests the useful region may lie beyond or at the edge of the current search box.
- `EaEKF` gives the best pointwise voltage RMSE by far, but its mean SOC RMSE and worst-case behavior show that it is much more tuning-sensitive than the best sigma-point filters.
- `ESC-EKF` reaches the best absolute SOC RMSE in the sweep, but its average and worst-case behavior are much weaker than the more robust sigma-point filters.
- `ROM-EKF` diverges badly over large parts of the grid. The enormous mean and worst-case voltage errors are telling you that many covariance combinations are unusable for that estimator in this setup.
- `EnacrSPKF` is not competitive on this dataset. Its mean SOC RMSE and voltage RMSE remain poor even at its best point.
- The `EaEKF` covariance results suggest a mixed adaptation picture:
  - `Q(2,2)` and `Q(3,3)` appear to track the input `sigma_w` almost directly.
  - `Q(1,1)` increases with `sigma_w`, but more moderately.
  - `Q(4,4)` collapses near zero, which looks like a weakly identifiable or effectively clamped state-noise channel.

## How to regenerate them

Run the default ATL multi-estimator covariance sweep:

```matlab
addpath(genpath('.'));

results = runNoiseCovStudy();
printNoiseSweepSummary(results);
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
