# Promoted Injection Study Summary

- layer: `evaluation`
- suite: `desktop_atl20_bss_v1`
- scenario: `atl20_p25_bundle_injection_study_shared_cov`
- generated: `2026-04-07T16:35:51+02:00`
- promoted JSON: `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_injection_study_shared_cov__summary.json`
- heavy MAT: `Evaluation/Injection/results/atl20_p25_bundle_injection_study_shared_cov.mat`
- saved MAT: `Evaluation/Injection/results/atl20_p25_bundle_injection_study_shared_cov.mat`
- runs: `3`

## Run Summary

| scenario_name | case_name | injection_mode | case_id | dataset_id | parent_dataset_id | injected_dataset_file | benchmark_results_file | validation_voltage_rmse_mv |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| atl20_p25_injection_shared_cov | additive_measurement_noise | additive_measurement_noise | case_001 | desktop_atl20_bss_v1__additive_measurement_noise__case_001 | esc_bus_coreBattery_dataset | data/evaluation/derived/desktop_atl20_bss_v1/additive_measurement_noise/case_001/dataset.mat | Evaluation/Injection/results/atl20_p25_bundle_injection_study_shared_cov/atl20_p25_injection_shared_cov/additive_measurement_noise_benchmark_results.mat | NaN |
| atl20_p25_injection_shared_cov | sensor_gain_bias_fault | sensor_gain_bias_fault | case_002 | desktop_atl20_bss_v1__sensor_gain_bias_fault__case_002 | esc_bus_coreBattery_dataset | data/evaluation/derived/desktop_atl20_bss_v1/sensor_gain_bias_fault/case_002/dataset.mat | Evaluation/Injection/results/atl20_p25_bundle_injection_study_shared_cov/atl20_p25_injection_shared_cov/sensor_gain_bias_fault_benchmark_results.mat | NaN |
| atl20_p25_injection_shared_cov | hall_bias | composite_measurement_error | case_003 | desktop_atl20_bss_v1__composite_measurement_error__case_003 | esc_bus_coreBattery_dataset | data/evaluation/derived/desktop_atl20_bss_v1/composite_measurement_error/case_003/dataset.mat | Evaluation/Injection/results/atl20_p25_bundle_injection_study_shared_cov/atl20_p25_injection_shared_cov/hall_bias_benchmark_results.mat | NaN |

## Per-Estimator Metrics

| Scenario | InjectionCase | InjectionMode | Estimator | SocRmsePct | SocMePct | SocMssdPct2 | VoltageRmseMv | VoltageMeMv | VoltageMssdMv2 | ValidationCurrentRmseA | ValidationVoltageRmseMv |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| atl20_p25_injection_shared_cov | additive_measurement_noise | additive_measurement_noise | ROM-EKF | 22.9668 | -2.40097 | 0.00209704 | 70.1983 | -0.550299 | 7517.74 | 0.0824219 | 14.9961 |
| atl20_p25_injection_shared_cov | additive_measurement_noise | additive_measurement_noise | ESC-SPKF | 9.75323 | 8.70074 | 5.97249e-06 | 12.2609 | -0.681462 | 0.29923 | 0.0824219 | 14.9961 |
| atl20_p25_injection_shared_cov | additive_measurement_noise | additive_measurement_noise | ESC-EKF | 9.41195 | 8.40131 | 6.04329e-06 | 12.7225 | -0.863583 | 0.28281 | 0.0824219 | 14.9961 |
| atl20_p25_injection_shared_cov | additive_measurement_noise | additive_measurement_noise | EaEKF | 16.2545 | 8.26303 | 13.4817 | 8.45722 | -0.187602 | 76.1552 | 0.0824219 | 14.9961 |
| atl20_p25_injection_shared_cov | additive_measurement_noise | additive_measurement_noise | EacrSPKF | 0.655235 | 0.566123 | 1.52985e-06 | 10.0515 | 0.153361 | 124.772 | 0.0824219 | 14.9961 |
| atl20_p25_injection_shared_cov | additive_measurement_noise | additive_measurement_noise | EnacrSPKF | 22.8278 | 20.198 | 35.0835 | 14.8768 | -10.0314 | 36.1531 | 0.0824219 | 14.9961 |
| atl20_p25_injection_shared_cov | additive_measurement_noise | additive_measurement_noise | EDUKF | 9.68793 | 8.55301 | 5.66519e-06 | 12.2845 | -0.755764 | 0.274178 | 0.0824219 | 14.9961 |
| atl20_p25_injection_shared_cov | additive_measurement_noise | additive_measurement_noise | EsSPKF | 9.68797 | 8.55322 | 5.66558e-06 | 12.2845 | -0.755621 | 0.274175 | 0.0824219 | 14.9961 |
| atl20_p25_injection_shared_cov | additive_measurement_noise | additive_measurement_noise | EbSPKF | 9.87999 | 8.79683 | 6.03639e-06 | 11.6043 | -0.0560543 | 0.299386 | 0.0824219 | 14.9961 |
| atl20_p25_injection_shared_cov | additive_measurement_noise | additive_measurement_noise | EBiSPKF | 9.75323 | 8.70074 | 5.97249e-06 | 12.2609 | -0.681462 | 0.29923 | 0.0824219 | 14.9961 |
| atl20_p25_injection_shared_cov | additive_measurement_noise | additive_measurement_noise | Em7SPKF | 9.68797 | 8.55322 | 5.66558e-06 | 12.2845 | -0.755621 | 0.274175 | 0.0824219 | 14.9961 |
| atl20_p25_injection_shared_cov | sensor_gain_bias_fault | sensor_gain_bias_fault | ROM-EKF | 24.9191 | 12.6206 | 0.000160292 | 39.4389 | 8.48129 | 0.945943 | 0.302283 | 3.98796 |
| atl20_p25_injection_shared_cov | sensor_gain_bias_fault | sensor_gain_bias_fault | ESC-SPKF | 10.9469 | 6.72932 | 2.09855e-06 | 13.1228 | -0.00467457 | 0.131674 | 0.302283 | 3.98796 |
| atl20_p25_injection_shared_cov | sensor_gain_bias_fault | sensor_gain_bias_fault | ESC-EKF | 10.9216 | 6.91143 | 2.1832e-06 | 13.0673 | 0.095745 | 0.113899 | 0.302283 | 3.98796 |
| atl20_p25_injection_shared_cov | sensor_gain_bias_fault | sensor_gain_bias_fault | EaEKF | 12.9526 | 3.09271 | 0.107282 | 4.02624 | -4.00134 | 0.402637 | 0.302283 | 3.98796 |
| atl20_p25_injection_shared_cov | sensor_gain_bias_fault | sensor_gain_bias_fault | EacrSPKF | 13.9271 | 11.935 | 1.85351e-06 | 3.95189 | -3.92753 | 0.237736 | 0.302283 | 3.98796 |
| atl20_p25_injection_shared_cov | sensor_gain_bias_fault | sensor_gain_bias_fault | EnacrSPKF | 22.8379 | 20.7627 | 14.5112 | 21.6063 | -19.2211 | 12.5134 | 0.302283 | 3.98796 |
| atl20_p25_injection_shared_cov | sensor_gain_bias_fault | sensor_gain_bias_fault | EDUKF | 10.7613 | 7.27772 | 1.95038e-06 | 12.7071 | 0.397157 | 0.0830134 | 0.302283 | 3.98796 |
| atl20_p25_injection_shared_cov | sensor_gain_bias_fault | sensor_gain_bias_fault | EsSPKF | 10.7614 | 7.2776 | 1.9504e-06 | 12.7071 | 0.397076 | 0.0830167 | 0.302283 | 3.98796 |
| atl20_p25_injection_shared_cov | sensor_gain_bias_fault | sensor_gain_bias_fault | EbSPKF | 7.33893 | 3.78455 | 2.11166e-06 | 12.1916 | -4.13142 | 0.131562 | 0.302283 | 3.98796 |
| atl20_p25_injection_shared_cov | sensor_gain_bias_fault | sensor_gain_bias_fault | EBiSPKF | 10.9469 | 6.72932 | 2.09855e-06 | 13.1228 | -0.00467457 | 0.131674 | 0.302283 | 3.98796 |
| atl20_p25_injection_shared_cov | sensor_gain_bias_fault | sensor_gain_bias_fault | Em7SPKF | 10.7614 | 7.2776 | 1.9504e-06 | 12.7071 | 0.397076 | 0.0830167 | 0.302283 | 3.98796 |
| atl20_p25_injection_shared_cov | hall_bias | composite_measurement_error | ROM-EKF | 21.9887 | 4.73287 | 0.000121178 | 40.8616 | 9.35741 | 2.86311 | 0.43 | 0 |
| atl20_p25_injection_shared_cov | hall_bias | composite_measurement_error | ESC-SPKF | 9.81718 | -6.37912 | 1.6751e-06 | 26.1258 | -22.4803 | 0.114427 | 0.43 | 0 |
| atl20_p25_injection_shared_cov | hall_bias | composite_measurement_error | ESC-EKF | 7.79459 | -4.89209 | 1.90056e-06 | 22.6313 | -19.5815 | 0.0931176 | 0.43 | 0 |
| atl20_p25_injection_shared_cov | hall_bias | composite_measurement_error | EaEKF | 12.5425 | 10.1038 | 0.0275086 | 0.101395 | 0.00471994 | 0.112109 | 0.43 | 0 |
| atl20_p25_injection_shared_cov | hall_bias | composite_measurement_error | EacrSPKF | 22.8303 | -21.2754 | 7.17572e-07 | 51.7642 | 30.5795 | 0.155001 | 0.43 | 0 |
| atl20_p25_injection_shared_cov | hall_bias | composite_measurement_error | EnacrSPKF | 22.3417 | 20.2669 | 17.387 | 19.0545 | -11.5727 | 13.3518 | 0.43 | 0 |
| atl20_p25_injection_shared_cov | hall_bias | composite_measurement_error | EDUKF | 7.37366 | -4.24495 | 1.69824e-06 | 21.436 | -18.4078 | 0.104293 | 0.43 | 0 |
| atl20_p25_injection_shared_cov | hall_bias | composite_measurement_error | EsSPKF | 11.5921 | -7.32632 | 1.64086e-06 | 27.0532 | -23.1357 | 0.0813787 | 0.43 | 0 |
| atl20_p25_injection_shared_cov | hall_bias | composite_measurement_error | EbSPKF | 1.31045 | 1.08852 | 1.61096e-06 | 1.12357 | -0.111317 | 0.1114 | 0.43 | 0 |
| atl20_p25_injection_shared_cov | hall_bias | composite_measurement_error | EBiSPKF | 9.81718 | -6.37912 | 1.6751e-06 | 26.1258 | -22.4803 | 0.114427 | 0.43 | 0 |
| atl20_p25_injection_shared_cov | hall_bias | composite_measurement_error | Em7SPKF | 11.5921 | -7.32632 | 1.64086e-06 | 27.0532 | -23.1357 | 0.0813787 | 0.43 | 0 |
