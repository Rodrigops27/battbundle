# Promoted Initial-SOC Sweep Summary

- layer: `evaluation`
- suite: `desktop_atl20_bss_v1`
- scenario: `atl20_p25_bundle_init_soc_sweep_shared_cov`
- generated: `2026-04-07T14:58:37+02:00`
- promoted JSON: `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_init_soc_sweep_shared_cov__summary.json`
- heavy MAT: `Evaluation/initSOCs/results/atl20_p25_bundle_init_soc_sweep_shared_cov.mat`
- extracted summary MAT: `Evaluation/initSOCs/results/atl20_p25_bundle_init_soc_sweep_shared_cov_summary.mat`
- source file: `Evaluation/initSOCs/results/atl20_p25_bundle_init_soc_sweep_shared_cov.mat`
- dataset mode: `esc`
- estimators: `11`
- sweep points: `21`
- initial SOC axis: `0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100`

## Aggregate Summary

| Estimator | MeanSocRmsePct | BestSocRmsePct | WorstSocRmsePct | MeanVoltageRmseMv | BestVoltageRmseMv | WorstVoltageRmseMv |
| --- | --- | --- | --- | --- | --- | --- |
| ROM-EKF | 33.6202 | 18.3827 | 53.2572 | 6.86233e+48 | 35.665 | 1.44109e+50 |
| ESC-SPKF | 0.867047 | 0.643638 | 2.9975 | 0.419325 | 0.0321156 | 2.45553 |
| ESC-EKF | 0.857484 | 0.571696 | 3.71046 | 2.16055 | 2.03953 | 3.76167 |
| EaEKF | 0.666854 | 0.640223 | 0.699963 | 0.121604 | 0.000558578 | 0.567442 |
| EacrSPKF | 23.8444 | 0.678882 | 51.7561 | 14.578 | 0.407249 | 52.229 |
| EnacrSPKF | 22.2668 | 22.251 | 22.2861 | 19.2399 | 19.2043 | 19.2776 |
| EDUKF | 2.70393 | 0.644238 | 9.03317 | 2.48198 | 0.0250337 | 10.5776 |
| EsSPKF | 2.37431 | 0.644238 | 5.21861 | 2.19136 | 0.0250337 | 4.82747 |
| EbSPKF | 0.882784 | 0.643969 | 3.25968 | 0.408016 | 0.0321109 | 2.23664 |
| EBiSPKF | 0.867047 | 0.643638 | 2.9975 | 0.419325 | 0.0321156 | 2.45553 |
| Em7SPKF | 2.37431 | 0.644238 | 5.21861 | 2.19136 | 0.0250337 | 4.82747 |

## Best Point Per Estimator

| Estimator | BestInitialSocPct | SocRmsePctAtBestPoint | VoltageRmseMvAtBestPoint |
| --- | --- | --- | --- |
| ROM-EKF | 45 | 18.3827 | 63.359 |
| ESC-SPKF | 60 | 0.643638 | 0.0321156 |
| ESC-EKF | 70 | 0.571696 | 2.04297 |
| EaEKF | 60 | 0.640223 | 0.000558578 |
| EacrSPKF | 60 | 0.678882 | 0.510865 |
| EnacrSPKF | 65 | 22.251 | 19.2525 |
| EDUKF | 60 | 0.644238 | 0.0250337 |
| EsSPKF | 60 | 0.644238 | 0.0250337 |
| EbSPKF | 60 | 0.643969 | 0.0321109 |
| EBiSPKF | 60 | 0.643638 | 0.0321156 |
| Em7SPKF | 60 | 0.644238 | 0.0250337 |

## Selected Sweep Points

| InitialSocPct | BestSocRmseEstimator | BestSocRmsePct | BestVoltageRmseEstimator | BestVoltageRmseMv |
| --- | --- | --- | --- | --- |
| 0 | EaEKF | 0.699963 | EaEKF | 0.567442 |
| 50 | EaEKF | 0.647965 | EaEKF | 0.0279767 |
| 60 | ESC-EKF | 0.585938 | EaEKF | 0.000558578 |
| 100 | EaEKF | 0.696373 | EaEKF | 0.306196 |
