# Promoted Injection Study Summary

- layer: `evaluation`
- suite: `desktop_atl20_bss_v1`
- scenario: `atl20_p25_bundle_injection_study`
- generated: `2026-03-31T20:08:40+02:00`
- promoted JSON: `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_injection_study__summary.json`
- heavy MAT: `Evaluation/Injection/results/atl20_p25_bundle_injection_study.mat`
- saved MAT: `Evaluation/Injection/results/atl20_p25_bundle_injection_study.mat`
- runs: `2`

## Run Summary

| scenario_name | case_name | injection_mode | case_id | dataset_id | parent_dataset_id | injected_dataset_file | benchmark_results_file | validation_voltage_rmse_mv |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| atl20_p25_injection | noise | noise | case_001 | desktop_atl20_bss_v1__stochastic_sensor__case_001 | esc_bus_coreBattery_dataset | data/evaluation/derived/desktop_atl20_bss_v1/stochastic_sensor/case_001/dataset.mat | Evaluation/Injection/results/atl20_p25_bundle_injection_study/atl20_p25_injection/noise_benchmark_results.mat | NaN |
| atl20_p25_injection | perturbance | perturbance | case_002 | desktop_atl20_bss_v1__perturbance__case_002 | esc_bus_coreBattery_dataset | data/evaluation/derived/desktop_atl20_bss_v1/perturbance/case_002/dataset.mat | Evaluation/Injection/results/atl20_p25_bundle_injection_study/atl20_p25_injection/perturbance_benchmark_results.mat | NaN |

## Per-Estimator Metrics

| Scenario | InjectionCase | InjectionMode | Estimator | SocRmsePct | SocMePct | SocMssdPct2 | VoltageRmseMv | VoltageMeMv | VoltageMssdMv2 | ValidationCurrentRmseA | ValidationVoltageRmseMv |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| atl20_p25_injection | noise | noise | ROM-EKF | 9.50435 | 0.0659867 | 9.83395e-06 | 48.5792 | -4.35683 | 0.0177344 | 0.0824219 | 14.9961 |
| atl20_p25_injection | noise | noise | ESC-SPKF | 7.68237 | 7.03349 | 1.94633e-06 | 20.4044 | -1.67949 | 0.298722 | 0.0824219 | 14.9961 |
| atl20_p25_injection | noise | noise | ESC-EKF | 8.64663 | 7.70713 | 1.57009e-06 | 12.8873 | -1.48742 | 0.2828 | 0.0824219 | 14.9961 |
| atl20_p25_injection | noise | noise | EaEKF | 27.5242 | 17.6936 | 11.0078 | 256.179 | 61.4075 | 213.162 | 0.0824219 | 14.9961 |
| atl20_p25_injection | noise | noise | EacrSPKF | 20.3755 | 4.7666 | 55.2735 | 30.3063 | -1.48662 | 1739.63 | 0.0824219 | 14.9961 |
| atl20_p25_injection | noise | noise | EnacrSPKF | 13.426 | 9.23404 | 4.86088 | 23.2596 | 17.3904 | 2.02429 | 0.0824219 | 14.9961 |
| atl20_p25_injection | noise | noise | EDUKF | 27.4473 | -22.8033 | 0.80678 | 1486.24 | -3.59129 | 1.41228e+06 | 0.0824219 | 14.9961 |
| atl20_p25_injection | noise | noise | EsSPKF | 8.29269 | 7.91531 | 1.77989e-06 | 12.5533 | -0.779352 | 0.7255 | 0.0824219 | 14.9961 |
| atl20_p25_injection | noise | noise | EbSPKF | 8.4564 | 7.66365 | 2.01765e-06 | 20.3608 | -0.843562 | 0.298416 | 0.0824219 | 14.9961 |
| atl20_p25_injection | noise | noise | EBiSPKF | 7.85006 | 7.41152 | 1.71733e-06 | 12.7254 | -1.41519 | 0.298913 | 0.0824219 | 14.9961 |
| atl20_p25_injection | noise | noise | Em7SPKF | 7.6195 | 7.15516 | 1.65802e-06 | 16.1431 | -1.45662 | 0.89924 | 0.0824219 | 14.9961 |
| atl20_p25_injection | perturbance | perturbance | ROM-EKF | 14.4915 | 5.95885 | 1.17136e-05 | 47.9325 | -0.014207 | 0.0133778 | 0.302283 | 3.98796 |
| atl20_p25_injection | perturbance | perturbance | ESC-SPKF | 7.24942 | 5.87255 | 2.16676e-06 | 19.087 | -2.04637 | 0.13178 | 0.302283 | 3.98796 |
| atl20_p25_injection | perturbance | perturbance | ESC-EKF | 10.3795 | 8.16461 | 1.82703e-06 | 12.7176 | 1.10418 | 0.113893 | 0.302283 | 3.98796 |
| atl20_p25_injection | perturbance | perturbance | EaEKF | 9.96375 | 4.41826 | 0.0386527 | 4.14107 | -3.98979 | 2.2646 | 0.302283 | 3.98796 |
| atl20_p25_injection | perturbance | perturbance | EacrSPKF | 11.565 | 8.53709 | 0.000216324 | 3.85818 | -3.79376 | 0.22035 | 0.302283 | 3.98796 |
| atl20_p25_injection | perturbance | perturbance | EnacrSPKF | 13.7013 | 9.6573 | 5.92281 | 23.5919 | 19.0407 | 2.16584 | 0.302283 | 3.98796 |
| atl20_p25_injection | perturbance | perturbance | EDUKF | 11.5887 | 5.29253 | 0.00194925 | 6.65001 | -3.98143 | 30.8535 | 0.302283 | 3.98796 |
| atl20_p25_injection | perturbance | perturbance | EsSPKF | 6.91597 | 5.63123 | 1.96205e-06 | 12.3534 | -1.94548 | 0.211739 | 0.302283 | 3.98796 |
| atl20_p25_injection | perturbance | perturbance | EbSPKF | 6.12931 | 4.93947 | 2.21726e-06 | 19.2307 | -3.35967 | 0.130962 | 0.302283 | 3.98796 |
| atl20_p25_injection | perturbance | perturbance | EBiSPKF | 8.02514 | 6.46651 | 1.908e-06 | 11.7153 | -1.0825 | 0.131731 | 0.302283 | 3.98796 |
| atl20_p25_injection | perturbance | perturbance | Em7SPKF | 7.55485 | 6.32086 | 1.93201e-06 | 15.7608 | -1.20926 | 0.273956 | 0.302283 | 3.98796 |

### Practical ranking for this study

This ranking combines both injected cases and prioritizes estimators that remain usable under the harsher stochastic-sensor corruption without collapsing on the perturbance case:

1. `EbSPKF`
2. `ESC-SPKF`
3. `Em7SPKF`
4. `EsSPKF`
5. `EBiSPKF`
6. `ESC-EKF`
7. `ROM-EKF`
8. `EnacrSPKF`
9. `EacrSPKF`
10. `EaEKF`
11. `EDUKF`

## Observations

- This study is the main transfer-robustness check for the tuned bundle because it evaluates the estimators on explicitly corrupted datasets rather than only on the nominal scenario.
- `EbSPKF`, `ESC-SPKF`, `Em7SPKF`, `EsSPKF`, and `EBiSPKF` form the strongest practical group here. None of them wins every metric, but all remain usable under both injected cases.
- The stochastic-sensor case is the harsher test. It is what separates the practically robust estimators from those that only look strong on the nominal benchmark.
- `EacrSPKF` is the clearest example of nominal strength not transferring cleanly to corrupted data. It dominates the nominal benchmark but degrades badly under noise injection.
- `EaEKF` and `EDUKF` also fail the transfer test in practical terms because their noise-injection behavior becomes severe despite their strengths in other studies.
- `ROM-EKF` is not competitive on the nominal benchmark, but it avoids the catastrophic breakdown seen in some tuned filters under injection, which makes it less fragile than its nominal ranking alone suggests.
- `EnacrSPKF` remains poor, but it is still preferable to the clearly unstable injected behavior of `EaEKF`, `EacrSPKF`, and `EDUKF` in this study.
