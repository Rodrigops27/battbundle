# Promoted Injection Study Summary

- layer: `evaluation`
- suite: `desktop_atl20_bss_v1`
- scenario: `atl20_p25_bundle_injection_study`
- generated: `2026-04-06T18:27:13+02:00`
- promoted JSON: `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_injection_study__summary.json`
- heavy MAT: `Evaluation/Injection/results/atl20_p25_bundle_injection_study.mat`
- saved MAT: `Evaluation/Injection/results/atl20_p25_bundle_injection_study.mat`
- runs: `3`

## Run Summary

| scenario_name | case_name | injection_mode | case_id | dataset_id | parent_dataset_id | injected_dataset_file | benchmark_results_file | validation_voltage_rmse_mv |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| atl20_p25_injection | additive_measurement_noise | additive_measurement_noise | case_001 | desktop_atl20_bss_v1__additive_measurement_noise__case_001 | esc_bus_coreBattery_dataset | data/evaluation/derived/desktop_atl20_bss_v1/additive_measurement_noise/case_001/dataset.mat | Evaluation/Injection/results/atl20_p25_bundle_injection_study/atl20_p25_injection/additive_measurement_noise_benchmark_results.mat | NaN |
| atl20_p25_injection | sensor_gain_bias_fault | sensor_gain_bias_fault | case_002 | desktop_atl20_bss_v1__sensor_gain_bias_fault__case_002 | esc_bus_coreBattery_dataset | data/evaluation/derived/desktop_atl20_bss_v1/sensor_gain_bias_fault/case_002/dataset.mat | Evaluation/Injection/results/atl20_p25_bundle_injection_study/atl20_p25_injection/sensor_gain_bias_fault_benchmark_results.mat | NaN |
| atl20_p25_injection | hall_bias | composite_measurement_error | case_003 | desktop_atl20_bss_v1__composite_measurement_error__case_003 | esc_bus_coreBattery_dataset | data/evaluation/derived/desktop_atl20_bss_v1/composite_measurement_error/case_003/dataset.mat | Evaluation/Injection/results/atl20_p25_bundle_injection_study/atl20_p25_injection/hall_bias_benchmark_results.mat | NaN |

## Per-Estimator Metrics

| Scenario | InjectionCase | InjectionMode | Estimator | SocRmsePct | SocMePct | SocMssdPct2 | VoltageRmseMv | VoltageMeMv | VoltageMssdMv2 | ValidationCurrentRmseA | ValidationVoltageRmseMv |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| atl20_p25_injection | additive_measurement_noise | additive_measurement_noise | ROM-EKF | 9.50435 | 0.0659867 | 9.83395e-06 | 48.5792 | -4.35683 | 0.0177344 | 0.0824219 | 14.9961 |
| atl20_p25_injection | additive_measurement_noise | additive_measurement_noise | ESC-SPKF | 7.68237 | 7.03349 | 1.94633e-06 | 20.4044 | -1.67949 | 0.298722 | 0.0824219 | 14.9961 |
| atl20_p25_injection | additive_measurement_noise | additive_measurement_noise | ESC-EKF | 8.64663 | 7.70713 | 1.57009e-06 | 12.8873 | -1.48742 | 0.2828 | 0.0824219 | 14.9961 |
| atl20_p25_injection | additive_measurement_noise | additive_measurement_noise | EaEKF | 27.5242 | 17.6936 | 11.0078 | 256.179 | 61.4075 | 213.162 | 0.0824219 | 14.9961 |
| atl20_p25_injection | additive_measurement_noise | additive_measurement_noise | EacrSPKF | 20.3755 | 4.7666 | 55.2735 | 30.3063 | -1.48662 | 1739.63 | 0.0824219 | 14.9961 |
| atl20_p25_injection | additive_measurement_noise | additive_measurement_noise | EnacrSPKF | 13.426 | 9.23404 | 4.86088 | 23.2596 | 17.3904 | 2.02429 | 0.0824219 | 14.9961 |
| atl20_p25_injection | additive_measurement_noise | additive_measurement_noise | EDUKF | 27.4473 | -22.8033 | 0.80678 | 1486.24 | -3.59129 | 1.41228e+06 | 0.0824219 | 14.9961 |
| atl20_p25_injection | additive_measurement_noise | additive_measurement_noise | EsSPKF | 8.29269 | 7.91531 | 1.77989e-06 | 12.5533 | -0.779352 | 0.7255 | 0.0824219 | 14.9961 |
| atl20_p25_injection | additive_measurement_noise | additive_measurement_noise | EbSPKF | 8.4564 | 7.66365 | 2.01765e-06 | 20.3608 | -0.843562 | 0.298416 | 0.0824219 | 14.9961 |
| atl20_p25_injection | additive_measurement_noise | additive_measurement_noise | EBiSPKF | 7.85006 | 7.41152 | 1.71733e-06 | 12.7254 | -1.41519 | 0.298913 | 0.0824219 | 14.9961 |
| atl20_p25_injection | additive_measurement_noise | additive_measurement_noise | Em7SPKF | 7.6195 | 7.15516 | 1.65802e-06 | 16.1431 | -1.45662 | 0.89924 | 0.0824219 | 14.9961 |
| atl20_p25_injection | sensor_gain_bias_fault | sensor_gain_bias_fault | ROM-EKF | 14.4915 | 5.95885 | 1.17136e-05 | 47.9325 | -0.014207 | 0.0133778 | 0.302283 | 3.98796 |
| atl20_p25_injection | sensor_gain_bias_fault | sensor_gain_bias_fault | ESC-SPKF | 7.24942 | 5.87255 | 2.16676e-06 | 19.087 | -2.04637 | 0.13178 | 0.302283 | 3.98796 |
| atl20_p25_injection | sensor_gain_bias_fault | sensor_gain_bias_fault | ESC-EKF | 10.3795 | 8.16461 | 1.82703e-06 | 12.7176 | 1.10418 | 0.113893 | 0.302283 | 3.98796 |
| atl20_p25_injection | sensor_gain_bias_fault | sensor_gain_bias_fault | EaEKF | 9.96375 | 4.41826 | 0.0386527 | 4.14107 | -3.98979 | 2.2646 | 0.302283 | 3.98796 |
| atl20_p25_injection | sensor_gain_bias_fault | sensor_gain_bias_fault | EacrSPKF | 11.565 | 8.53709 | 0.000216324 | 3.85818 | -3.79376 | 0.22035 | 0.302283 | 3.98796 |
| atl20_p25_injection | sensor_gain_bias_fault | sensor_gain_bias_fault | EnacrSPKF | 13.7013 | 9.6573 | 5.92281 | 23.5919 | 19.0407 | 2.16584 | 0.302283 | 3.98796 |
| atl20_p25_injection | sensor_gain_bias_fault | sensor_gain_bias_fault | EDUKF | 11.5887 | 5.29253 | 0.00194925 | 6.65001 | -3.98143 | 30.8535 | 0.302283 | 3.98796 |
| atl20_p25_injection | sensor_gain_bias_fault | sensor_gain_bias_fault | EsSPKF | 6.91597 | 5.63123 | 1.96205e-06 | 12.3534 | -1.94548 | 0.211739 | 0.302283 | 3.98796 |
| atl20_p25_injection | sensor_gain_bias_fault | sensor_gain_bias_fault | EbSPKF | 6.12931 | 4.93947 | 2.21726e-06 | 19.2307 | -3.35967 | 0.130962 | 0.302283 | 3.98796 |
| atl20_p25_injection | sensor_gain_bias_fault | sensor_gain_bias_fault | EBiSPKF | 8.02514 | 6.46651 | 1.908e-06 | 11.7153 | -1.0825 | 0.131731 | 0.302283 | 3.98796 |
| atl20_p25_injection | sensor_gain_bias_fault | sensor_gain_bias_fault | Em7SPKF | 7.55485 | 6.32086 | 1.93201e-06 | 15.7608 | -1.20926 | 0.273956 | 0.302283 | 3.98796 |
| atl20_p25_injection | hall_bias | composite_measurement_error | ROM-EKF | 18.7086 | -16.8201 | 7.12911e-06 | 61.1908 | -29.4393 | 0.0927623 | 0.43 | 0 |
| atl20_p25_injection | hall_bias | composite_measurement_error | ESC-SPKF | 9.14527 | -8.10328 | 1.90668e-06 | 31.628 | -17.1249 | 0.11452 | 0.43 | 0 |
| atl20_p25_injection | hall_bias | composite_measurement_error | ESC-EKF | 15.1991 | -11.9712 | 1.47681e-06 | 145.52 | -84.0657 | 0.105291 | 0.43 | 0 |
| atl20_p25_injection | hall_bias | composite_measurement_error | EaEKF | 6.28176 | 4.70326 | 0.0255974 | 8.45777 | -0.177033 | 18.5479 | 0.43 | 0 |
| atl20_p25_injection | hall_bias | composite_measurement_error | EacrSPKF | 22.5791 | -21.2522 | 9.43028e-05 | 7.93383 | 1.22645 | 0.159062 | 0.43 | 0 |
| atl20_p25_injection | hall_bias | composite_measurement_error | EnacrSPKF | 13.491 | 9.45291 | 5.06602 | 26.2907 | 17.8804 | 1.84263 | 0.43 | 0 |
| atl20_p25_injection | hall_bias | composite_measurement_error | EDUKF | 18.9736 | -17.2299 | 0.000198921 | 483.924 | -0.69127 | 90558.5 | 0.43 | 0 |
| atl20_p25_injection | hall_bias | composite_measurement_error | EsSPKF | 6.95796 | -5.17498 | 1.7536e-06 | 22.3329 | -13.4006 | 0.225587 | 0.43 | 0 |
| atl20_p25_injection | hall_bias | composite_measurement_error | EbSPKF | 4.95597 | -2.80131 | 1.98912e-06 | 25.8852 | -5.26941 | 0.113522 | 0.43 | 0 |
| atl20_p25_injection | hall_bias | composite_measurement_error | EBiSPKF | 11.3291 | -9.12221 | 1.68701e-06 | 31.5754 | -22.3746 | 0.11469 | 0.43 | 0 |
| atl20_p25_injection | hall_bias | composite_measurement_error | Em7SPKF | 10.2815 | -8.86046 | 1.66119e-06 | 31.5939 | -20.4307 | 0.23942 | 0.43 | 0 |
