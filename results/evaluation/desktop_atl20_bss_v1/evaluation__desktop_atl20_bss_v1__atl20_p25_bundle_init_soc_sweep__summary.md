# Promoted Initial-SOC Sweep Summary

- layer: `evaluation`
- suite: `desktop_atl20_bss_v1`
- scenario: `atl20_p25_bundle_init_soc_sweep`
- generated: `2026-03-31T00:00:00+02:00`
- promoted JSON: `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_init_soc_sweep__summary.json`
- heavy MAT: `Evaluation/initSOCs/results/atl20_p25_bundle_init_soc_sweep.mat`
- extracted summary MAT: `Evaluation/initSOCs/results/atl20_p25_bundle_init_soc_sweep_summary.mat`
- source file: `Evaluation/initSOCs/results/atl20_p25_bundle_init_soc_sweep.mat`
- dataset mode: `esc`
- estimators: `11`
- sweep points: `21`
- initial SOC axis: `0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100`

## Aggregate Summary

| Estimator | MeanSocRmsePct | BestSocRmsePct | WorstSocRmsePct | MeanVoltageRmseMv | BestVoltageRmseMv | WorstVoltageRmseMv |
| --- | --- | --- | --- | --- | --- | --- |
| ROM-EKF | 11.551 | 9.4009 | 13.833 | 51.54 | 50.554 | 55.703 |
| ESC-SPKF | 5.6744 | 2.8339 | 10.481 | 26.173 | 25.393 | 30.119 |
| ESC-EKF | 6.6181 | 0.52869 | 28.129 | 10.523 | 2.0385 | 72.912 |
| EaEKF | 0.67959 | 0.63998 | 0.7572 | 0.068648 | 0.0022467 | 0.54365 |
| EacrSPKF | 12.171 | 2.3452 | 28.766 | 1.0693 | 0.51937 | 3.1256 |
| EnacrSPKF | 13.391 | 13.39 | 13.391 | 30.913 | 30.885 | 31.084 |
| EDUKF | 14.343 | 3.1635 | 34.115 | 55.132 | 11.97 | 305.89 |
| EsSPKF | 4.5433 | 2.0816 | 10.313 | 18.271 | 17.42 | 24.309 |
| EbSPKF | 5.816 | 3.1896 | 10.232 | 26.068 | 25.361 | 29.786 |
| EBiSPKF | 4.8131 | 1.8649 | 11.177 | 18.458 | 17.544 | 23.571 |
| Em7SPKF | 5.8083 | 2.0043 | 12.629 | 23.137 | 21.84 | 29.937 |

## Best Point Per Estimator

| Estimator | BestInitialSocPct | SocRmsePctAtBestPoint | VoltageRmseMvAtBestPoint |
| --- | --- | --- | --- |
| ROM-EKF | 60 | 9.4009 | 50.738 |
| ESC-SPKF | 60 | 2.8339 | 25.409 |
| ESC-EKF | 60 | 0.52869 | 2.0385 |
| EaEKF | 60 | 0.63998 | 0.0023201 |
| EacrSPKF | 60 | 2.3452 | 0.67088 |
| EnacrSPKF | 20 | 13.39 | 31.083 |
| EDUKF | 55 | 3.1635 | 13.77 |
| EsSPKF | 70 | 2.0816 | 17.42 |
| EbSPKF | 65 | 3.1896 | 25.361 |
| EBiSPKF | 65 | 1.8649 | 17.544 |
| Em7SPKF | 65 | 2.0043 | 21.84 |

## Selected Sweep Points

| InitialSocPct | BestSocRmseEstimator | BestSocRmsePct | BestVoltageRmseEstimator | BestVoltageRmseMv |
| --- | --- | --- | --- | --- |
| 0 | EaEKF | 0.72337 | EaEKF | 0.54365 |
| 50 | EaEKF | 0.64537 | EaEKF | 0.0022467 |
| 60 | ESC-EKF | 0.52869 | EaEKF | 0.0023201 |
| 100 | EaEKF | 0.75432 | EaEKF | 0.27725 |
