# Estimator Selection For The ATL Desktop Evaluation Bundle

## Purpose

This note defines a practical criterion to decide which ESC-based Kalman filter is the best overall choice for the ATL desktop-evaluation bundle:
- chemistry: `ATL`
- dataset: `data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat`
- dataset type: ESC-driven BSS synthetic dataset

The intent is to balance:
- best tuned desktop-evaluation performance
- robustness to untuned injected `sensor_gain_bias_fault`/`additive_measurement_noise`
- sensitivity to wrong initial SOC
- robustness after deploying tuned covariances

## Weighting used

The initial weighting ranking is set as:

- `40%` from  the results at the Noise Covariance Sweep.
- `30%` from  the results at the bayes optimization (autotuning).

- `4.2%` from the shared-covariance `additive_measurement_noise` injection results
- `9.8%` from the shared-covariance `sensor_gain_bias_fault` injection results
- `1.8%` from the tuned `additive_measurement_noise` injection results
- `4.2%` from the tuned `sensor_gain_bias_fault` injection results

- `7%` from the sweep SOC initialization results with shared Covariances.
- `3%` from the sweep SOC initialization results with the bayes fitted filters.

## Source provenance and status

| Weighted source | Backing results file | Status |
| --- | --- | --- |
| Noise covariance sweep robustness (`40%`) | `results/estimatorsInitNoiseSweep.md` | Present, complete, and used in the score |
| Bayes-tuned desktop benchmark (`30%`) | `results/estimatorsBayesTuning.md` | Present, complete, and used in the score |
| Shared-covariance injected `additive_measurement_noise` (`4.2%`) | `results/InjectionScenariosWsameESCsCovs.md` | Present, complete, and used in the score |
| Shared-covariance injected `sensor_gain_bias_fault` (`9.8%`) | `results/InjectionScenariosWsameESCsCovs.md` | Present, complete, and used in the score |
| Tuned-covariance injected `additive_measurement_noise` (`1.8%`) | `results/InjectionScenariosBayesFitted.md` | Present, complete, and used in the score |
| Tuned-covariance injected `sensor_gain_bias_fault` (`4.2%`) | `results/InjectionScenariosBayesFitted.md` | Present, complete, and used in the score |
| Shared-covariance init-SOC sweep (`7%`) | `results/estimatorsSOCInitSweepSameESCsCovs.md` | Present, complete, and used in the score |
| Tuned-covariance init-SOC sweep (`3%`) | `results/estimatorsSOCInitSweepBayesFitted.md` | Present, complete, and used in the score |


## Scoring rule


The overall score is:

```text
score(estimator) =
0.40 * rank_noise_sweep_mean_soc_rmse +
0.30 * rank_bayes_soc_rmse +
0.042 * rank_shared_additive_measurement_noise_soc_rmse +
0.098 * rank_shared_sensor_gain_bias_fault_soc_rmse +
0.018 * rank_tuned_additive_measurement_noise_soc_rmse +
0.042 * rank_tuned_sensor_gain_bias_fault_soc_rmse +
0.07 * rank_shared_init_soc_mean_soc_rmse +
0.03 * rank_tuned_init_soc_mean_soc_rmse
```

Rules used in the computation:
- lower SOC RMSE is always better
- lower rank is always better
- lower final weighted score is the better overall estimator
- exact numeric ties use average rank, so tied estimators receive the same fractional rank


### Metric used inside each source

- Noise covariance sweep: mean SOC RMSE rank across the full covariance grid
- Bayes tuning: SOC RMSE rank from the tuned desktop-evaluation benchmark
- Injection with same ESC covariances, `additive_measurement_noise`: SOC RMSE rank in the `additive_measurement_noise` case
- Injection with same ESC covariances, `sensor_gain_bias_fault`: SOC RMSE rank in the `sensor_gain_bias_fault` case
- Initial-SOC sweep with shared covariances: mean SOC RMSE rank across the full sweep
- Injection with tuned covariances, `additive_measurement_noise`: SOC RMSE rank in the `additive_measurement_noise` case
- Injection with tuned covariances, `sensor_gain_bias_fault`: SOC RMSE rank in the `sensor_gain_bias_fault` case
- Initial-SOC sweep with tuned covariances: mean SOC RMSE rank across the full sweep

Voltage RMSE remains a supporting diagnostic and tie-break context, not the primary selection metric.

## Comparable estimator set

The comparable set is the estimator intersection that appears in all eight weighted sources:

`ROM-EKF`, `ESC-SPKF`, `ESC-EKF`, `EaEKF`, `EacrSPKF`, `EnacrSPKF`, `EDUKF`, `EsSPKF`, `EbSPKF`, `EBiSPKF`, `Em7SPKF`


## Source ranks used in the calculation

| Estimator | Noise sweep rank | Bayes tuning rank | Shared-additive-measurement-noise rank | Shared-sensor-gain-bias-fault rank | Tuned-additive-measurement-noise rank | Tuned-sensor-gain-bias-fault rank | Shared init-SOC rank | Tuned init-SOC rank |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `ROM-EKF` | 10.0 | 10.0 | 11.0 | 11.0 | 3.0 | 9.0 | 11.0 | 7.0 |
| `ESC-SPKF` | 4.5 | 4.0 | 3.5 | 6.5 | 4.0 | 5.0 | 3.5 | 1.5 |
| `ESC-EKF` | 8.0 | 1.0 | 8.0 | 5.0 | 1.0 | 1.0 | 6.0 | 10.0 |
| `EaEKF` | 9.0 | 9.0 | 9.0 | 9.0 | 7.0 | 11.0 | 1.0 | 4.0 |
| `EacrSPKF` | 3.0 | 8.0 | 1.0 | 8.0 | 2.0 | 8.0 | 10.0 | 11.0 |
| `EnacrSPKF` | 11.0 | 11.0 | 10.0 | 10.0 | 8.0 | 10.0 | 9.0 | 6.0 |
| `EDUKF` | 7.0 | 7.0 | 6.0 | 4.0 | 11.0 | 7.0 | 5.0 | 5.0 |
| `EsSPKF` | 1.5 | 2.0 | 6.0 | 2.5 | 10.0 | 3.0 | 7.5 | 9.0 |
| `EbSPKF` | 6.0 | 3.0 | 2.0 | 1.0 | 5.0 | 6.0 | 2.0 | 3.0 |
| `EBiSPKF` | 4.5 | 5.0 | 3.5 | 6.5 | 6.0 | 4.0 | 3.5 | 1.5 |
| `Em7SPKF` | 1.5 | 6.0 | 6.0 | 2.5 | 9.0 | 2.0 | 7.5 | 8.0 |




## Weighted selection result

| Rank | Estimator | Noise sweep contribution | Bayes contribution | Default injection contribution | Init-SOC contribution | Tuned injection contribution | Final score |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | `EsSPKF` | 0.600 | 0.600 | 0.497 | 0.795 | 0.306 | 2.798 |
| 2 | `Em7SPKF` | 0.600 | 1.800 | 0.497 | 0.765 | 0.246 | 3.908 |
| 3 | `EbSPKF` | 2.400 | 0.900 | 0.182 | 0.230 | 0.342 | 4.054 |
| 4 | `ESC-SPKF` | 1.800 | 1.200 | 0.784 | 0.290 | 0.282 | 4.356 |
| 5 | `EBiSPKF` | 1.800 | 1.500 | 0.784 | 0.290 | 0.276 | 4.650 |
| 6 | `ESC-EKF` | 3.200 | 0.300 | 0.826 | 0.720 | 0.060 | 5.106 |
| 7 | `EacrSPKF` | 1.200 | 2.400 | 0.826 | 1.030 | 0.372 | 5.828 |
| 8 | `EDUKF` | 2.800 | 2.100 | 0.644 | 0.500 | 0.492 | 6.536 |
| 9 | `EaEKF` | 3.600 | 2.700 | 1.260 | 0.190 | 0.588 | 8.338 |
| 10 | `ROM-EKF` | 4.000 | 3.000 | 1.540 | 0.980 | 0.432 | 9.952 |
| 11 | `EnacrSPKF` | 4.400 | 3.300 | 1.400 | 0.810 | 0.564 | 10.474 |

## Decision

Under the updated weighting, the best ESC-based Kalman filter for the ATL BSS desktop-evaluation bundle is:

`EsSPKF`


## Interpretation of the top candidates

- `EsSPKF` wins because the weighting is dominated by the `40%` covariance-sweep robustness term, where it ties for the best mean SOC RMSE, and it also places second in the `30%` Bayes-tuned benchmark.
- `Em7SPKF` finishes second for nearly the same reason: it ties `EsSPKF` in the covariance sweep and stays strong in the shared-covariance `sensor_gain_bias_fault` study, but it loses ground in the Bayes benchmark.
- `EbSPKF` is the best robustness challenger. It wins the shared-covariance sensor_gain_bias_fault case, is third in Bayes tuning, and is strong in both init-SOC studies, but its weaker covariance-sweep rank keeps it behind `EsSPKF`.
- `ESC-SPKF` and `EBiSPKF` are the most balanced all-round alternatives. They avoid major failure modes across the bundle, but neither is dominant enough in the heavily weighted studies to take first place.
- `ESC-EKF` is the best estimator on the Bayes-tuned desktop benchmark and the tuned injection study, but the present weighting penalizes its weaker covariance-sweep robustness and its poor tuned init-SOC robustness.

## Side notes on fairness

### `ROM-EKF`

This criterion intentionally keeps `ROM-EKF` in the comparable set, even though the main question is about ESC-based filters. That is useful as a fairness check:
- the selection logic should not exclude the ROM filter a priori
- on this ATL ESC-driven desktop bundle, `ROM-EKF` does not challenge the best ESC filters under the current weighting

### `EacrSPKF` and `EnacrSPKF`

These filters are designed to handle autocorrelated-noise structure. For that reason, the present criterion is only partially fair to them:
- they are being judged mostly under white-noise-style studies rather than dedicated autocorrelated-noise studies
- the current bundle still lacks a purpose-built colored-noise benchmark that matches their design intent

So `EacrSPKF` and `EnacrSPKF` should not be rejected from the project based only on the current weighted table. A dedicated fair comparison should use:
- explicitly autocorrelated current and voltage noise
- disturbance models with temporal correlation
- complete coverage across autotuning, injection, and init-SOC studies

* `EaEKF` may still need a completeness check as a project candidate, but that does not affect the weighted ranking above.

## Recommended use

For the current repo state and the updated weighting, the practical recommendation is:

1. Use `EsSPKF` as the current selected estimator for the ATL desktop-evaluation bundle.
2. Keep `EbSPKF` as the main robustness challenger and fallback candidate.
3. Keep `ESC-EKF` as the best tuned-performance reference, especially when the decision is allowed to prioritize Bayes-fitted operation over covariance-robustness.
4. Keep `ROM-EKF` as a fairness baseline.
5. Run dedicated colored-noise studies before making a final decision on `EacrSPKF` and `EnacrSPKF`.
