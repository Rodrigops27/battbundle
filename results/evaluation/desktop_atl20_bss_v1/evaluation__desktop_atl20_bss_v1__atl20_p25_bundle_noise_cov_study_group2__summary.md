# Promoted Noise-Covariance Sweep Summary

- layer: `evaluation`
- suite: `desktop_atl20_bss_v1`
- scenario: `atl20_p25_bundle_noise_cov_study_group2`
- generated: `2026-03-31T00:00:00+02:00`
- promoted JSON: `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_noise_cov_study_group2__summary.json`
- heavy MAT: ``
- saved MAT: ``
- dataset mode: `esc`
- sweep mode: `grid`
- estimators: `5`
- total runs: `81`
- sigma_w points: `9`
- sigma_v points: `9`
- sigma_w axis: `0.001, 0.005, 0.025, 0.125, 0.625, 3.12, 15.6, 78.1, 100`
- sigma_v axis: `1e-06, 5e-06, 2.5e-05, 0.000125, 0.000625, 0.00313, 0.0156, 0.0781, 0.2`

## Per-Estimator Best Metrics

| Estimator | BestSigmaW | BestSigmaV | BestSocRmsePct | BestSocMePct | BestSocMssdPct2 | VoltageRmseMvAtBestSoc | VoltageMeMvAtBestSoc | VoltageMssdMv2AtBestSoc |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EDUKF | 0.625 | 0.2 | 0.55113 | 0.4706 | 1.5283e-06 | 2.6035 | -0.080215 | 0.11212 |
| EsSPKF | 0.625 | 0.2 | 0.55113 | 0.4706 | 1.5283e-06 | 2.6035 | -0.080212 | 0.11212 |
| EbSPKF | 0.125 | 0.2 | 0.6274 | 0.54911 | 1.5276e-06 | 0.84519 | -0.0042576 | 0.11099 |
| EBiSPKF | 0.625 | 0.2 | 0.55371 | 0.47385 | 1.5287e-06 | 2.6044 | -0.080062 | 0.11102 |
| Em7SPKF | 0.625 | 0.2 | 0.55113 | 0.4706 | 1.5283e-06 | 2.6035 | -0.080212 | 0.11212 |

## Aggregate Summary

| Estimator | MeanSocRmsePct | BestSocRmsePct | WorstSocRmsePct | MeanSocMssdPct2 | MeanVoltageRmseMv | BestVoltageRmseMv | WorstVoltageRmseMv | MeanVoltageMssdMv2 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EDUKF | 2.237 | 0.551 | 23.844 | 3.9e-05 | 5.65 | 0.02 | 54.91 | 46.2718 |
| EsSPKF | 1.476 | 0.551 | 4.033 | 2e-06 | 4.86 | 0.02 | 23.23 | 0.1736 |
| EbSPKF | 1.864 | 0.627 | 5.612 | 2e-06 | 4.53 | 0.03 | 25.41 | 0.1109 |
| EBiSPKF | 1.744 | 0.554 | 5.416 | 2e-06 | 4.55 | 0.03 | 25.45 | 0.111 |
| Em7SPKF | 1.476 | 0.551 | 4.033 | 2e-06 | 4.86 | 0.02 | 23.23 | 0.1736 |

## Notes

- Recovered from Command Window output, not from the original MATLAB `sweepResults` variable.
- Warning seen during reporting: `EaEKF was not found in the sweep results.`
