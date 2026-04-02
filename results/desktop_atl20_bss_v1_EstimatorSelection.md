# Estimator Selection For The ATL20 P25 Bundle

## Purpose

This note documents the practical estimator selection for the ATL20 P25 bundle produced by `examples/atl20_p25_bundle/run_atl20_p25_bundle.m`.

- ESC model: `models/ATL20model_P25.mat`
- ROM model: `models/ROM_ATL20_beta.mat`
- nominal dataset: `data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat`
- suite: `desktop_atl20_bss_v1`

The intent is to follow the same selection logic used in `results/EstimatorSelection.md`, but restricted to the studies that are actually part of this bundle run:

- tuned nominal benchmark
- full covariance robustness sweep
- tuned initial-SOC sweep
- tuned injection robustness (`noise` and `perturbance`)

## Weighting used

The parent criterion in `results/EstimatorSelection.md` mixes shared-covariance and tuned-covariance studies. The ATL20 bundle only produces the tuned bundle studies, so this selection keeps the same relative emphasis but renormalizes to the studies available here.

Original weights retained from the parent criterion:

- `40%` from the noise covariance sweep
- `30%` from the Bayes-tuned nominal benchmark
- `1.8%` from the tuned `noise` injection case
- `4.2%` from the tuned `perturbance` injection case
- `3%` from the tuned initial-SOC sweep

Available-weight total: `79%`

Renormalized bundle-only weights:

- `50.63%` noise covariance sweep robustness
- `37.97%` tuned nominal benchmark
- `2.28%` tuned `noise` injection
- `5.32%` tuned `perturbance` injection
- `3.80%` tuned initial-SOC sweep

## Source provenance and status

| Weighted source | Backing results file | Status |
| --- | --- | --- |
| Noise covariance sweep robustness | `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_noise_cov_study__summary.md` | Present, complete, and used |
| Bayes-tuned nominal benchmark | `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle__summary.md` | Present, complete, and used |
| Tuned injection `noise` case | `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_injection_study__summary.md` | Present, complete, and used |
| Tuned injection `perturbance` case | `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_injection_study__summary.md` | Present, complete, and used |
| Tuned initial-SOC sweep | `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_init_soc_sweep__summary.md` | Present, complete, and used |

## Scoring rule

The overall bundle score is:

```text
score(estimator) =
0.5063 * rank_noise_sweep_mean_soc_rmse +
0.3797 * rank_nominal_soc_rmse +
0.0228 * rank_tuned_noise_soc_rmse +
0.0532 * rank_tuned_perturbance_soc_rmse +
0.0380 * rank_tuned_init_soc_mean_soc_rmse
```

Rules used in the computation:

- lower SOC RMSE is always better
- lower rank is always better
- lower final weighted score is the better overall bundle estimator
- exact numeric ties use average rank

### Metric used inside each source

- Noise covariance sweep: mean SOC RMSE rank across the full covariance grid
- Nominal benchmark: SOC RMSE rank from the final tuned bundle benchmark
- Injection `noise`: SOC RMSE rank in the `noise` case
- Injection `perturbance`: SOC RMSE rank in the `perturbance` case
- Initial-SOC sweep: mean SOC RMSE rank across the full sweep

Voltage RMSE remains supporting context, not the primary selection metric.

## Comparable estimator set

The comparable set is the estimator intersection that appears in all bundle studies:

`ROM-EKF`, `ESC-SPKF`, `ESC-EKF`, `EaEKF`, `EacrSPKF`, `EnacrSPKF`, `EDUKF`, `EsSPKF`, `EbSPKF`, `EBiSPKF`, `Em7SPKF`

## Source ranks used in the calculation

| Estimator | Noise sweep rank | Nominal benchmark rank | Tuned-noise rank | Tuned-perturbance rank | Tuned init-SOC rank |
| --- | ---: | ---: | ---: | ---: | ---: |
| `ROM-EKF` | 11.0 | 9.0 | 7.0 | 11.0 | 8.0 |
| `ESC-SPKF` | 6.5 | 4.0 | 2.0 | 3.0 | 4.0 |
| `ESC-EKF` | 2.0 | 8.0 | 6.0 | 7.0 | 7.0 |
| `EaEKF` | 1.0 | 10.0 | 11.0 | 6.0 | 1.0 |
| `EacrSPKF` | 3.0 | 1.0 | 9.0 | 8.0 | 9.0 |
| `EnacrSPKF` | 10.0 | 11.0 | 8.0 | 10.0 | 10.0 |
| `EDUKF` | 9.0 | 2.0 | 10.0 | 9.0 | 11.0 |
| `EsSPKF` | 4.5 | 6.0 | 4.0 | 2.0 | 2.0 |
| `EbSPKF` | 8.0 | 7.0 | 5.0 | 1.0 | 6.0 |
| `EBiSPKF` | 6.5 | 5.0 | 3.0 | 5.0 | 3.0 |
| `Em7SPKF` | 4.5 | 3.0 | 1.0 | 4.0 | 5.0 |

## Weighted selection result

| Rank | Estimator | Noise sweep contribution | Nominal contribution | Injection contribution | Init-SOC contribution | Final score |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | `EacrSPKF` | 1.519 | 0.380 | 0.630 | 0.342 | 2.870 |
| 2 | `Em7SPKF` | 2.278 | 1.139 | 0.235 | 0.190 | 3.841 |
| 3 | `ESC-EKF` | 1.013 | 3.038 | 0.509 | 0.266 | 4.826 |
| 4 | `EsSPKF` | 2.278 | 2.278 | 0.198 | 0.076 | 4.830 |
| 5 | `EaEKF` | 0.506 | 3.797 | 0.570 | 0.038 | 4.911 |
| 6 | `ESC-SPKF` | 3.291 | 1.519 | 0.205 | 0.152 | 5.167 |
| 7 | `EBiSPKF` | 3.291 | 1.899 | 0.335 | 0.114 | 5.640 |
| 8 | `EDUKF` | 4.557 | 0.759 | 0.707 | 0.418 | 6.440 |
| 9 | `EbSPKF` | 4.051 | 2.658 | 0.166 | 0.228 | 7.102 |
| 10 | `ROM-EKF` | 5.570 | 3.418 | 0.745 | 0.304 | 10.037 |
| 11 | `EnacrSPKF` | 5.063 | 4.177 | 0.714 | 0.380 | 10.334 |

## Decision

Under the bundle-only version of the selection criterion, the best overall estimator for the ATL20 P25 bundle is:

`EacrSPKF`

## Interpretation of the top candidates

- `EacrSPKF` wins because the bundle-only weighting still emphasizes the two dominant studies: the covariance sweep and the tuned nominal benchmark. It is the nominal winner and also remains near the top of the covariance-robustness study.
- `Em7SPKF` finishes second because it is strong across all bundle studies without a major collapse. It is not the absolute best in any dominant source, but it is consistently competitive.
- `ESC-EKF` and `EsSPKF` are nearly tied. `ESC-EKF` is helped by its very strong covariance robustness, while `EsSPKF` is helped by a more balanced profile in the injection and init-SOC studies.
- `EaEKF` stays competitive because it dominates the init-SOC study and the covariance sweep, but it loses ground badly in the nominal and injection studies.
- `ESC-SPKF` and `EBiSPKF` remain credible all-round alternatives, but neither is dominant enough in the highest-weight bundle studies to win overall.

## Side notes on fairness

### Bundle scope

This bundle-only selection is not identical to the broader criterion in `results/EstimatorSelection.md` because the bundle run does not include the shared-covariance injection or shared-covariance init-SOC studies. So this note is a selection for the example bundle itself, not a replacement for the broader project-wide criterion.

### `EacrSPKF` and transfer robustness

The weighted score selects `EacrSPKF`, but the injection summary still shows a real caveat: nominal dominance does not transfer cleanly to corrupted-data cases. So `EacrSPKF` is the best answer only if the bundle criterion keeps nominal+tuning evidence as the main priority.

### `Em7SPKF`, `EsSPKF`, and `EbSPKF`

These SPKF variants remain the most practical robustness challengers:

- `Em7SPKF` is the strongest bundle-wide runner-up
- `EsSPKF` is the most balanced low-risk option
- `EbSPKF` transfers best in the injection study but loses too much ground in the heavily weighted covariance and nominal studies

## Recommended use

For the current ATL20 P25 example bundle, the practical recommendation is:

1. Use `EacrSPKF` as the selected estimator if nominal tuned performance and covariance-robustness remain the primary decision criteria.
2. Keep `Em7SPKF` as the main practical runner-up when a more balanced cross-study profile is preferred.
3. Keep `EsSPKF` as the conservative low-risk fallback.
4. Use `EbSPKF` as the injection-robust challenger when corrupted-data transfer matters more than nominal optimality.
5. Do not treat this bundle note as the final project-wide selection rule; use `results/EstimatorSelection.md` for that broader decision.
