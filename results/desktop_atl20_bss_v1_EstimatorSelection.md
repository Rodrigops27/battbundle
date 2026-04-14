# Estimator Selection For The ATL20 P25 Bundle

## Purpose

This note documents the practical estimator selection for the ATL20 P25 bundle produced by `examples/atl20_p25_bundle/run_atl20_p25_bundle.m`.

- ESC model: `models/ATL20model_P25.mat`
- OCV path: `voltageAverage` at `25 degC`
- ROM model: `models/ROM_ATL20_beta.mat`
- nominal dataset: `data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat`
- suite: `desktop_atl20_bss_v1`

The bundle now includes:

- tuned nominal benchmark
- full covariance robustness sweep
- shared-covariance initial-SOC sweep
- tuned initial-SOC sweep
- shared-covariance injection robustness
- tuned injection robustness

Both injection families include the three canonical cases:

- `additive_measurement_noise`
- `sensor_gain_bias_fault`
- `hall_bias`

## Weighting used

The parent criterion in `results/EstimatorSelection.md` already weights:

- noise covariance robustness
- Bayes-tuned nominal performance
- shared-covariance injection robustness
- tuned-covariance injection robustness
- shared-covariance init-SOC robustness
- tuned-covariance init-SOC robustness

For this ATL20 P25 bundle, the same structure is used and `hall_bias` is added at `5%` per covariance family:

- `40%` from the noise covariance sweep
- `30%` from the Bayes-tuned nominal benchmark
- `4.2%` from the shared-covariance `additive_measurement_noise` injection case
- `9.8%` from the shared-covariance `sensor_gain_bias_fault` injection case
- `5%` from the shared-covariance `hall_bias` injection case
- `1.8%` from the tuned `additive_measurement_noise` injection case
- `4.2%` from the tuned `sensor_gain_bias_fault` injection case
- `5%` from the tuned `hall_bias` injection case
- `7%` from the shared-covariance init-SOC sweep
- `3%` from the tuned init-SOC sweep

These raw weights sum to `110%`, so the final score renormalizes them to sum to `100%` while preserving the requested `hall_bias` emphasis.

Renormalized bundle weights:

- `36.36%` noise covariance sweep robustness
- `27.27%` Bayes-tuned nominal benchmark
- `3.82%` shared `additive_measurement_noise`
- `8.91%` shared `sensor_gain_bias_fault`
- `4.55%` shared `hall_bias`
- `1.64%` tuned `additive_measurement_noise`
- `3.82%` tuned `sensor_gain_bias_fault`
- `4.55%` tuned `hall_bias`
- `6.36%` shared init-SOC sweep
- `2.73%` tuned init-SOC sweep

## Source provenance and status

| Weighted source | Backing results file | Status |
| --- | --- | --- |
| Noise covariance sweep robustness | `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_noise_cov_study__summary.md` | Present and used |
| Bayes-tuned nominal benchmark | `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle__summary.md` | Present and used |
| Shared `additive_measurement_noise` injection | `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_injection_study_shared_cov__summary.md` | Present and used |
| Shared `sensor_gain_bias_fault` injection | `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_injection_study_shared_cov__summary.md` | Present and used |
| Shared `hall_bias` injection | `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_injection_study_shared_cov__summary.md` | Present and used |
| Tuned `additive_measurement_noise` injection | `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_injection_study__summary.md` | Present and used |
| Tuned `sensor_gain_bias_fault` injection | `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_injection_study__summary.md` | Present and used |
| Tuned `hall_bias` injection | `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_injection_study__summary.md` | Present and used |
| Shared init-SOC sweep | `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_init_soc_sweep_shared_cov__summary.md` | Present and used |
| Tuned init-SOC sweep | `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_init_soc_sweep__summary.md` | Present and used |

## Scoring rule

The overall bundle score is:

```text
score(estimator) =
0.3636 * rank_noise_sweep_mean_soc_rmse +
0.2727 * rank_nominal_soc_rmse +
0.0382 * rank_shared_additive_measurement_noise_soc_rmse +
0.0891 * rank_shared_sensor_gain_bias_fault_soc_rmse +
0.0455 * rank_shared_hall_bias_soc_rmse +
0.0164 * rank_tuned_additive_measurement_noise_soc_rmse +
0.0382 * rank_tuned_sensor_gain_bias_fault_soc_rmse +
0.0455 * rank_tuned_hall_bias_soc_rmse +
0.0636 * rank_shared_init_soc_mean_soc_rmse +
0.0273 * rank_tuned_init_soc_mean_soc_rmse
```

Rules used in the computation:

- lower SOC RMSE is always better
- lower rank is always better
- lower final weighted score is the better overall bundle estimator
- exact numeric ties use average rank

### Metric used inside each source

- Noise covariance sweep: mean SOC RMSE rank across the full covariance grid
- Nominal benchmark: SOC RMSE rank from the final tuned bundle benchmark
- Shared `additive_measurement_noise`: SOC RMSE rank in the shared-covariance case
- Shared `sensor_gain_bias_fault`: SOC RMSE rank in the shared-covariance case
- Shared `hall_bias`: SOC RMSE rank in the shared-covariance case
- Tuned `additive_measurement_noise`: SOC RMSE rank in the tuned case
- Tuned `sensor_gain_bias_fault`: SOC RMSE rank in the tuned case
- Tuned `hall_bias`: SOC RMSE rank in the tuned case
- Shared init-SOC sweep: mean SOC RMSE rank across the full sweep
- Tuned init-SOC sweep: mean SOC RMSE rank across the full sweep

Voltage RMSE remains supporting context, not the primary selection metric.

## Comparable estimator set

The comparable set is the estimator intersection that appears in all ten weighted sources:

`ROM-EKF`, `ESC-SPKF`, `ESC-EKF`, `EaEKF`, `EacrSPKF`, `EnacrSPKF`, `EDUKF`, `EsSPKF`, `EbSPKF`, `EBiSPKF`, `Em7SPKF`

## Source ranks used in the calculation

| Estimator | Noise sweep rank | Nominal rank | Shared-additive rank | Shared-fault rank | Shared-hall rank | Tuned-additive rank | Tuned-fault rank | Tuned-hall rank | Shared init-SOC rank | Tuned init-SOC rank |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `ROM-EKF` | 11.0 | 9.0 | 11.0 | 11.0 | 9.0 | 7.0 | 11.0 | 9.0 | 11.0 | 8.0 |
| `ESC-SPKF` | 6.5 | 4.0 | 6.5 | 6.5 | 4.5 | 2.0 | 3.0 | 4.0 | 3.5 | 4.0 |
| `ESC-EKF` | 2.0 | 8.0 | 2.0 | 5.0 | 3.0 | 6.0 | 7.0 | 8.0 | 2.0 | 7.0 |
| `EaEKF` | 1.0 | 10.0 | 9.0 | 8.0 | 8.0 | 11.0 | 6.0 | 2.0 | 1.0 | 1.0 |
| `EacrSPKF` | 3.0 | 1.0 | 1.0 | 9.0 | 11.0 | 9.0 | 8.0 | 11.0 | 10.0 | 9.0 |
| `EnacrSPKF` | 10.0 | 11.0 | 10.0 | 10.0 | 10.0 | 8.0 | 10.0 | 7.0 | 9.0 | 10.0 |
| `EDUKF` | 9.0 | 2.0 | 3.0 | 2.0 | 2.0 | 10.0 | 9.0 | 10.0 | 8.0 | 11.0 |
| `EsSPKF` | 4.5 | 6.0 | 4.5 | 3.5 | 6.5 | 4.0 | 2.0 | 3.0 | 6.5 | 2.0 |
| `EbSPKF` | 8.0 | 7.0 | 8.0 | 1.0 | 1.0 | 5.0 | 1.0 | 1.0 | 5.0 | 6.0 |
| `EBiSPKF` | 6.5 | 5.0 | 6.5 | 6.5 | 4.5 | 3.0 | 5.0 | 6.0 | 3.5 | 3.0 |
| `Em7SPKF` | 4.5 | 3.0 | 4.5 | 3.5 | 6.5 | 1.0 | 4.0 | 5.0 | 6.5 | 5.0 |

## Weighted selection result

| Rank | Estimator | Noise contribution | Nominal contribution | Shared injection contribution | Tuned injection contribution | Init-SOC contribution | Final score |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | `Em7SPKF` | 1.636 | 0.818 | 0.779 | 0.396 | 0.550 | 4.180 |
| 2 | `EacrSPKF` | 1.091 | 0.273 | 1.340 | 0.953 | 0.882 | 4.538 |
| 3 | `ESC-EKF` | 0.727 | 2.182 | 0.658 | 0.729 | 0.318 | 4.615 |
| 4 | `EsSPKF` | 1.636 | 1.636 | 0.779 | 0.278 | 0.468 | 4.798 |
| 5 | `EaEKF` | 0.364 | 2.727 | 1.420 | 0.500 | 0.091 | 5.102 |
| 6 | `ESC-SPKF` | 2.364 | 1.091 | 1.032 | 0.329 | 0.332 | 5.147 |
| 7 | `EBiSPKF` | 2.364 | 1.364 | 1.032 | 0.513 | 0.305 | 5.576 |
| 8 | `EbSPKF` | 2.909 | 1.909 | 0.440 | 0.165 | 0.482 | 5.905 |
| 9 | `EDUKF` | 3.273 | 0.545 | 0.384 | 0.962 | 0.809 | 5.973 |
| 10 | `EnacrSPKF` | 3.636 | 3.000 | 1.727 | 0.831 | 0.845 | 10.040 |
| 11 | `ROM-EKF` | 4.000 | 2.455 | 1.809 | 0.944 | 0.918 | 10.125 |

## Decision

Under the updated ATL20 bundle weighting, the best overall estimator for the ATL20 P25 bundle is:

`Em7SPKF`

## Interpretation of the top candidates

- `Em7SPKF` wins because it stays strong in the two largest terms, noise sweep and nominal tuned benchmark, while avoiding collapse in either shared or tuned injection.
- `EacrSPKF` remains the nominal benchmark winner, but the added `hall_bias` and shared-covariance evidence penalize its weak transfer under biased current-sensor corruption.
- `ESC-EKF` benefits from excellent covariance robustness and strong shared-covariance robustness, but it still gives up too much ground in the nominal tuned run to take first place.
- `EsSPKF` remains the most balanced low-risk alternative. It is not the absolute winner in the dominant studies, but it stays near the front in most of them.
- `EbSPKF` is still the strongest bias-transfer specialist. It wins both `hall_bias` cases and both `sensor_gain_bias_fault` cases, but its weaker nominal and covariance-sweep ranks prevent it from winning the aggregate score.

## Side notes on correlation and fairness

### Injection-case similarity

The injection cases are not all telling the same story.

- `sensor_gain_bias_fault` and `hall_bias` are strongly correlated in the observed rank order:
  shared-covariance rank correlation is about `0.826`
  tuned-covariance rank correlation is about `0.800`
- `additive_measurement_noise` is much less aligned with the bias-like cases:
  shared `additive` vs shared `hall_bias` is about `0.211`
  tuned `additive` vs tuned `hall_bias` is about `0.364`
  shared `additive` vs tuned `additive` is about `0.055`

So the new `hall_bias` case is not redundant with `additive_measurement_noise`, but it is close in spirit to `sensor_gain_bias_fault`. That makes sense physically: both are persistent sensor-distortion cases rather than pure zero-mean noise.

### Shared-covariance fairness

The shared/default covariance studies are useful, but they are not a fully even hyperparameter-neutral comparison.

- The shared vs tuned ranking alignment is moderate for `sensor_gain_bias_fault` and weak for `hall_bias` and `additive_measurement_noise`.
- That means a meaningful part of the observed difference is coming from estimator default tuning quality, not only from intrinsic robustness to the injected corruption.

Practical implication:

- shared/default studies are fair as deployment-stress references
- they are not fully fair as the only robustness evidence for cross-estimator model quality

A more even comparison would add one of these:

- equal-budget retuning per estimator family under each robustness family
- a shared hyperparameter search budget applied uniformly to all estimators on the corrupted-data objectives
- scenario-family tuning, for example one tuned profile for nominal use and one tuned profile for biased-sensor deployment

## Recommended use

For the current ATL20 P25 example bundle, the practical recommendation is:

1. Use `Em7SPKF` as the bundle-wide selected estimator under the updated weighting that now includes shared/tuned `hall_bias`.
2. Keep `EsSPKF` as the most balanced low-risk fallback.
3. Keep `EbSPKF` as the bias-robust challenger when current-sensor distortion matters more than nominal optimality.
4. Keep `EacrSPKF` as the nominal-performance reference rather than the bundle-wide default.
5. Treat the shared-covariance studies as robustness references, not as a substitute for equal-budget robustness tuning.
