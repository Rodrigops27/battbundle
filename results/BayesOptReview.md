# Bayes Optimization Review Against the Full Noise-Covariance Grid

## Purpose

This note evaluates how good the Bayes optimization in `results/estimatorsBayesTuning.md` was by comparing it against the full covariance grid sweep reported in `results/estimatorsInitNoiseSweep.md`.

This is a review of optimizer quality, not just estimator quality.

The question is:
- did Bayes optimization recover the same good region found by the full grid sweep?
- did it miss a clearly better region that the grid already exposed?
- or did it improve on the coarse grid by refining between grid points?

## Short answer

Overall, the Bayes optimization was good for most estimators.

Main conclusions:
- For the main competitive filters, Bayes optimization usually matched the grid-best SOC RMSE very closely.
- In several cases, Bayes slightly beat the grid best, which is reasonable because Bayes searched continuously while the sweep used a coarse discrete grid.
- The clearest Bayes miss is `EacrSPKF`, where the optimizer did not recover the best region indicated by the grid sweep.
- The Bayes result for `ESC-EKF` is credible as a true optimum, but the sweep still shows that this optimum lives in a fragile tuning region.

So the review is:
- good optimizer quality overall
- very good on the main practical estimators
- one important miss on `EacrSPKF`
- robustness and optimizer quality are not the same thing

## How the comparison should be read

The grid sweep is exhaustive only over the tested grid points:
- `sigma_w = 0.001, 0.005, 0.025, 0.125, 0.625, 3.12, 15.6, 78.1, 100`
- `sigma_v = 1e-06, 5e-06, 2.5e-05, 0.000125, 0.000625, 0.00313, 0.0156, 0.0781, 0.2`

Bayes optimization is continuous, so it can legitimately do better than the best grid point when:
- the true optimum lies between grid nodes
- the response surface is smooth enough for local refinement to help

Because of that:
- Bayes equal to the grid best is a strong result
- Bayes slightly better than the grid best is also a strong result
- Bayes materially worse than the grid best is evidence that the optimizer missed a better region

## Bayes quality table

| Estimator | Bayes SOC RMSE [%] | Sweep best SOC RMSE [%] | Gap `(Bayes - sweep best)` | Reading |
| --- | ---: | ---: | ---: | --- |
| `ROM-EKF` | 9.1362 | 9.2297 | -0.0935 | Bayes slightly beats the coarse grid best; optimizer quality is acceptable, but the estimator remains poor overall. |
| `ESC-SPKF` | 0.6263 | 0.6253 | +0.0010 | Excellent recovery of the grid-best region. |
| `ESC-EKF` | 0.5955 | 0.5958 | -0.0003 | Excellent recovery of the grid-best region. |
| `EaEKF` | 0.7271 | 1.0694 | -0.3423 | Bayes clearly improved on the coarse grid; likely the grid was too coarse to resolve the best initialization scale for this adaptive filter. |
| `EacrSPKF` | 0.6567 | 0.5965 | +0.0602 | Clear optimizer miss relative to the grid sweep. |
| `EnacrSPKF` | 10.4370 | 15.4640 | -5.0270 | Bayes improved strongly over the coarse grid, but the estimator still remains noncompetitive. |
| `EDUKF` | 0.6287 | 0.6237 | +0.0050 | Good result, slightly off the grid best but still close. |
| `EsSPKF` | 0.6246 | 0.6236 | +0.0010 | Excellent recovery of the grid-best region. |
| `EbSPKF` | 0.6261 | 0.6214 | +0.0047 | Good result, very close to the grid best. |
| `EBiSPKF` | 0.6268 | 0.6253 | +0.0015 | Excellent recovery of the grid-best region. |
| `Em7SPKF` | 0.6275 | 0.6236 | +0.0039 | Good result, very close to the grid best. |

## Estimator-by-estimator reading of Bayes quality

### Excellent Bayes recovery

The Bayes run looks genuinely strong for:
- `ESC-SPKF`
- `ESC-EKF`
- `EsSPKF`
- `EBiSPKF`

These all land essentially on top of the best grid performance. That means the optimizer is not inventing a false winner. It is recovering the same useful region already visible in the exhaustive grid sweep.

This is especially important for `ESC-EKF`:
- Bayes best SOC RMSE is `0.5955%`
- grid best SOC RMSE is `0.5958%`

That agreement is too close to dismiss. The Bayes winner is real.

### Good Bayes recovery

The Bayes run is also good for:
- `EDUKF`
- `EbSPKF`
- `Em7SPKF`

These do not hit the exact best grid value, but the miss is small enough that the optimizer still found the right practical region.

For these filters, the Bayes result should be read as:
- credible
- near-optimal
- good enough for practical tuning conclusions

### Bayes improved beyond the coarse grid

The Bayes result is better than the grid best for:
- `ROM-EKF`
- `EaEKF`
- `EnacrSPKF`

This does not mean the sweep was wrong. It means the sweep grid was too coarse to fully resolve the optimum for those cases.

The important distinction is:
- for `ROM-EKF` and `EnacrSPKF`, Bayes improvement does not rescue them as practical estimators, because their absolute error remains poor
- for `EaEKF`, the improvement is meaningful and suggests the coarse grid understates what the estimator can do after tuning

So for `EaEKF`, the Bayes run is informative:
- the optimizer found a much better initialization scale than the discrete sweep points exposed
- but that does not change the sweep conclusion that `EaEKF` is tuning-sensitive

### Clear Bayes miss: `EacrSPKF`

`EacrSPKF` is the one estimator where the Bayes optimization does not look good when judged against the full grid:
- Bayes best SOC RMSE: `0.6567%`
- grid best SOC RMSE: `0.5965%`
- absolute miss: `0.0602%`

That is not a tiny numerical difference in this cluster. It is a real miss.

The covariance locations also disagree strongly:
- Bayes optimum: `sigma_w = 1.0251e-06`, `sigma_v = 0.199504`
- grid best point: `sigma_w = 100`, `sigma_v = 5e-06`

That is not local refinement around the same basin. It is a completely different region.

The most plausible interpretations are:
- the Bayes budget of `30` objective evaluations was not enough for this estimator
- the response surface is difficult or multimodal for `EacrSPKF`
- the optimizer got trapped in a region that looks locally good but is not globally best over the explored search box

So `EacrSPKF` is the main case where the full grid sweep should be trusted more than the current Bayes run.

## Bayes quality versus robustness

This review should also be separated from transfer robustness under explicit sensor corruption. A Bayes result can be genuinely good against the full covariance grid and still transfer poorly to the injected `additive_measurement_noise` case, because the optimizer was tuned on the nominal ATL `SocRmsePct` objective rather than on a corrupted-measurement benchmark. That distinction appears clearly in this repo: several SPKF-family estimators show excellent or good Bayes recovery against the grid in this review, yet the tuned-profile injection study shows that `ESC-SPKF`, `EDUKF`, `EsSPKF`, `EBiSPKF`, and `Em7SPKF` can degrade badly under random measurement corruption. A plausible reason is over-specialization of the tuned covariance point to the nominal desktop benchmark, especially where Bayes selected extremely small sensor-noise values, making the filter too confident in measurements that are later corrupted in the injection testbench. So a strong Bayes/grid match should be read as evidence of optimizer quality at the nominal objective, not as automatic evidence of robustness to injected measurement noise.
This review also separates two questions that are easy to mix together:

1. Did Bayes optimization find a near-best tuned point?
2. Is that tuned point robust to covariance mismatch?

For `ESC-EKF`, the answers are different:
- Bayes quality: yes, very good
- robustness: no, relatively weak

Evidence:
- Bayes best and grid best are almost identical
- but the full sweep mean SOC RMSE is `5.899%`
- and the full sweep worst SOC RMSE is `19.740%`

So the optimizer did its job well for `ESC-EKF`. The issue is not optimizer failure. The issue is that the estimator's good region is narrow.

That distinction matters:
- Bayes optimization validates `ESC-EKF` as a best-case estimator
- the full grid sweep limits confidence in `ESC-EKF` as a deployment-robust estimator

The same contrast appears, in the opposite direction, for `EsSPKF`:
- Bayes quality is also very good
- and the sweep mean and worst-case metrics are much better than `ESC-EKF`

So `EsSPKF` is not just well-optimized. It is also more forgiving.

## What this says about the Bayes study as a whole

Taken as a whole, the Bayes study is trustworthy for the main benchmark conclusions.

Why:
- it reproduces the grid-best region very well for the main top-tier estimators
- it does not produce a fake winner that the sweep cannot support
- it improves on the coarse grid in some cases where continuous refinement should help

But it also has one visible weakness:
- it does not appear to have solved `EacrSPKF` well

So the correct project-level reading is:
- trust the Bayes study for `ESC-EKF`, `ESC-SPKF`, `EsSPKF`, `EbSPKF`, `EBiSPKF`, `Em7SPKF`, and broadly `EDUKF`
- treat the `EaEKF` Bayes improvement as real, but still interpret it through the sweep's robustness warning
- do not treat the `EacrSPKF` Bayes result as final

## Practical verdict

The Bayes optimization was good overall when checked against the full grid sweep.

The strongest verdicts are:
1. `ESC-EKF` Bayes tuning is credible. It truly finds the best tuned point seen in this ATL setup.
2. `EsSPKF` Bayes tuning is also credible and nearly optimal, while the full sweep shows much better robustness.
3. `EbSPKF` and `Em7SPKF` were tuned well enough to support practical comparisons.
4. `EacrSPKF` needs a dedicated retuning pass or a larger optimizer budget before its Bayes result should be trusted.

So the Bayes study passed the main quality check against the exhaustive grid, but not uniformly across every estimator.