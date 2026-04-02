# Promoted Noise-Covariance Sweep Summary

- layer: `evaluation`
- suite: `desktop_atl20_bss_v1`
- scenario: `atl20_p25_bundle_noise_cov_study`
- generated: `2026-03-31T00:00:00+02:00`
- promoted JSON: `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_noise_cov_study__summary.json`
- heavy MATs:
  `Evaluation/NoiseTuningSweep/results/atl20_p25_bundle_noise_cov_study_group1.mat`
  `Evaluation/NoiseTuningSweep/results/atl20_p25_bundle_noise_cov_study_group2.mat`
- dataset mode: `esc`
- sweep mode: `grid`
- estimator count: `11`
- group count: `2`
- runs per group: `81`
- combined group runs: `162`
- sigma_w points: `9`
- sigma_v points: `9`
- sigma_w axis: `0.001, 0.005, 0.025, 0.125, 0.625, 3.12, 15.6, 78.1, 100`
- sigma_v axis: `1e-06, 5e-06, 2.5e-05, 0.000125, 0.000625, 0.00313, 0.0156, 0.0781, 0.2`

## Per-Estimator Best Metrics

| Estimator | BestSigmaW | BestSigmaV | BestSocRmsePct | BestSocMePct | BestSocMssdPct2 | VoltageRmseMvAtBestSoc | VoltageMeMvAtBestSoc | VoltageMssdMv2AtBestSoc |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ROM-EKF | 100 | 0.000125 | 8.4974 | 0.46651 | 0.0014453 | 41.129 | 0.18639 | 5001.6 |
| ESC-SPKF | 0.625 | 0.2 | 0.55371 | 0.47385 | 1.5287e-06 | 2.6044 | -0.080062 | 0.11102 |
| ESC-EKF | 0.001 | 0.2 | 0.52869 | 0.37933 | 1.5509e-06 | 2.0385 | -0.13346 | 0.094638 |
| EaEKF | 15.625 | 1e-06 | 0.63925 | 0.54631 | 7.1772e-06 | 0.0023097 | 4.4583e-05 | 0.11138 |
| EacrSPKF | 100 | 5e-06 | 0.31096 | 0.28806 | 1.5331e-06 | 0.82543 | 0.21531 | 0.1218 |
| EnacrSPKF | 100 | 0.2 | 13.389 | 9.1994 | 4.7693 | 30.881 | 26.01 | 1.7655 |
| EDUKF | 0.625 | 0.2 | 0.55113 | 0.4706 | 1.5283e-06 | 2.6035 | -0.080215 | 0.11212 |
| EsSPKF | 0.625 | 0.2 | 0.55113 | 0.4706 | 1.5283e-06 | 2.6035 | -0.080212 | 0.11212 |
| EbSPKF | 0.125 | 0.2 | 0.6274 | 0.54911 | 1.5276e-06 | 0.84519 | -0.0042576 | 0.11099 |
| EBiSPKF | 0.625 | 0.2 | 0.55371 | 0.47385 | 1.5287e-06 | 2.6044 | -0.080062 | 0.11102 |
| Em7SPKF | 0.625 | 0.2 | 0.55113 | 0.4706 | 1.5283e-06 | 2.6035 | -0.080212 | 0.11212 |

## Aggregate Summary

| Estimator | MeanSocRmsePct | BestSocRmsePct | WorstSocRmsePct | MeanSocMssdPct2 | MeanVoltageRmseMv | BestVoltageRmseMv | WorstVoltageRmseMv | MeanVoltageMssdMv2 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ROM-EKF | 39.953 | 8.497 | 72.601 | 0.002776 | 3.64823e+14 | 34.11 | 2.95507e+16 | 2.27747e+31 |
| ESC-SPKF | 1.744 | 0.554 | 5.416 | 2e-06 | 4.55 | 0.03 | 25.45 | 0.111 |
| ESC-EKF | 0.943 | 0.529 | 4.383 | 0.00134 | 1.52 | 0.1 | 2.04 | 0.097 |
| EaEKF | 0.64 | 0.639 | 0.647 | 9e-06 | 0 | 0 | 0 | 0.1114 |
| EacrSPKF | 1.101 | 0.311 | 4.757 | 7.1e-05 | 0.61 | 0.38 | 1.47 | 0.1571 |
| EnacrSPKF | 20.833 | 13.389 | 29.626 | 101.188739 | 64.63 | 9.21 | 277.58 | 16429.593 |
| EDUKF | 2.237 | 0.551 | 23.844 | 3.9e-05 | 5.65 | 0.02 | 54.91 | 46.2718 |
| EsSPKF | 1.476 | 0.551 | 4.033 | 2e-06 | 4.86 | 0.02 | 23.23 | 0.1736 |
| EbSPKF | 1.864 | 0.627 | 5.612 | 2e-06 | 4.53 | 0.03 | 25.41 | 0.1109 |
| EBiSPKF | 1.744 | 0.554 | 5.416 | 2e-06 | 4.55 | 0.03 | 25.45 | 0.111 |
| Em7SPKF | 1.476 | 0.551 | 4.033 | 2e-06 | 4.86 | 0.02 | 23.23 | 0.1736 |

## Notes

- Combined from the split group1 and group2 promoted summaries.
- Both groups cover the same 9x9 sigma_w/sigma_v grid; estimator sets were split for hardware/runtime reasons.

### Practical ranking for this study

This ranking uses the full-grid robustness evidence, prioritizing low mean SOC RMSE and low worst-case SOC RMSE over the entire covariance sweep:

1. `EaEKF`
2. `ESC-EKF`
3. `EacrSPKF`
4. `EsSPKF`
5. `Em7SPKF`
6. `ESC-SPKF`
7. `EBiSPKF`
8. `EbSPKF`
9. `EDUKF`
10. `ROM-EKF`
11. `EnacrSPKF`

## Observations

- This is the strongest artifact for covariance-robustness analysis because it explores the full 9x9 process-noise and sensor-noise grid.
- `EaEKF` is the standout robust estimator in this study. Its mean, best, and worst SOC-RMSE values are all tightly grouped, which indicates an unusually flat and forgiving tuning surface.
- `ESC-EKF` also looks strong here. It combines a very low best point with a much better mean and worst-case profile than the nominal benchmark alone would suggest.
- `EacrSPKF` has the best single covariance point in the full grid, but its average robustness is still weaker than `EaEKF` and `ESC-EKF`.
- `EsSPKF` and `Em7SPKF` are the most attractive SPKF-family compromise filters in this sweep because they pair good best-point performance with relatively good mean and worst-case behavior.
- `EDUKF` is not robust in this study. Its best point is competitive, but its mean and worst-case metrics show severe sensitivity to covariance mismatch.
- `ROM-EKF` and `EnacrSPKF` are dominated across the grid and are not practical choices from this robustness view.
