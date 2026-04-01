# Promoted Autotuning Summary

- layer: `autotuning`
- suite: `desktop_atl20_bss_v1`
- scenario: `atl20_p25_bundle`
- artifact class: promoted, Git-trackable summary
- promoted JSON: `results/autotuning/desktop_atl20_bss_v1/autotuning__desktop_atl20_bss_v1__atl20_p25_bundle__summary.json`
- heavy MAT: `autotuning/results/atl20_p25_bundle_autotuning_results.mat`
- figures root: `results/figures/autotuning/desktop_atl20_bss_v1/atl20_p25_bundle`

## Best objective result

- best estimator by objective: `EacrSPKF`
- objective metric: `SocRmsePct`
- best objective value: `0.496294`

## Per-estimator metrics

| Estimator | Objective | SOC RMSE (%) | Voltage RMSE (mV) |
| --- | ---: | ---: | ---: |
| ROM-EKF | 9.599976 | 9.599976 | 48.636970 |
| ESC-SPKF | 7.661590 | 7.661590 | 20.404425 |
| ESC-EKF | 8.615502 | 8.615502 | 12.884953 |
| EaEKF | 9.833206 | 9.833206 | 0.048231 |
| EacrSPKF | 0.496294 | 0.496294 | 1.170605 |
| EnacrSPKF | 13.425957 | 13.425957 | 23.035373 |
| EDUKF | 5.646460 | 5.646460 | 7.786473 |
| EsSPKF | 8.261364 | 8.261364 | 12.546356 |
| EbSPKF | 8.441130 | 8.441130 | 20.361539 |
| EBiSPKF | 7.822736 | 7.822736 | 12.724083 |
| Em7SPKF | 7.593645 | 7.593645 | 16.137189 |
