# Promoted Noise-Covariance Sweep Summary

- layer: `evaluation`
- suite: `desktop_atl20_bss_v1`
- scenario: `atl20_p25_bundle_noise_cov_study_group1`
- generated: `2026-03-31T00:00:00+02:00`
- promoted JSON: `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_noise_cov_study_group1__summary.json`
- heavy MAT: `Evaluation/NoiseTuningSweep/results/atl20_p25_bundle_noise_cov_study_group1.mat`
- saved MAT: `Evaluation/NoiseTuningSweep/results/atl20_p25_bundle_noise_cov_study_group1.mat`
- dataset mode: `esc`
- sweep mode: `grid`
- estimators: `6`
- total runs: `81`
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

## Aggregate Summary

| Estimator | MeanSocRmsePct | BestSocRmsePct | WorstSocRmsePct | MeanSocMssdPct2 | MeanVoltageRmseMv | BestVoltageRmseMv | WorstVoltageRmseMv | MeanVoltageMssdMv2 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ROM-EKF | 39.953 | 8.497 | 72.601 | 0.002776 | 3.64823e+14 | 34.11 | 2.95507e+16 | 2.27747e+31 |
| ESC-SPKF | 1.744 | 0.554 | 5.416 | 2e-06 | 4.55 | 0.03 | 25.45 | 0.111 |
| ESC-EKF | 0.943 | 0.529 | 4.383 | 0.00134 | 1.52 | 0.1 | 2.04 | 0.097 |
| EaEKF | 0.64 | 0.639 | 0.647 | 9e-06 | 0 | 0 | 0 | 0.1114 |
| EacrSPKF | 1.101 | 0.311 | 4.757 | 7.1e-05 | 0.61 | 0.38 | 1.47 | 0.1571 |
| EnacrSPKF | 20.833 | 13.389 | 29.626 | 101.188739 | 64.63 | 9.21 | 277.58 | 16429.593 |

## Notes
