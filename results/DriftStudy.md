# SOC Estimation Drift In The ATL Desktop Evaluation Scenario

## Purpose

This note records how the ATL desktop evaluation scenario exposes SOC estimation drift over time.

Here, drift means that the estimator does not simply start with an offset and then converge cleanly. Instead, the SOC estimate keeps a persistent bias, separates progressively from the reference trajectory, or becomes strongly initialization-dependent along the desktop-evaluation timeline.

The scenario considered here is:

| Item | Value |
| --- | --- |
| Bundle | ATL desktop evaluation |
| Dataset | `data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat` |
| Dataset type | ESC-driven BSS synthetic dataset |
| ESC model | `models/ATLmodel.mat` |
| Main benchmark reference | `results/estimatorsBayesTuning.md` |
| Init-SOC robustness references | `results/estimatorsSOCInitSweepSameESCsCovs.md`, `results/estimatorsSOCInitSweepBayesFitted.md` |

## Visual Evidence

### Desktop Evaluation Scenario

The desktop scenario itself is the BSS mission used throughout the ATL bundle:

![ATL20 desktop evaluation scenario](../assets/ATL20%20%28ESC-driven%29%20BSS.png)

### Baseline SOC Comparison

The benchmark comparison already shows that not all estimators stay equally well aligned with the reference SOC over the full drive:

![ATL BSS SOC estimation comparison](../assets/ATL%20BSS%20SOC%20Estimation%20Comparison.png)

The error view makes that separation clearer. A good estimator remains centered and bounded; a drifting one builds a persistent signed error over time:

![ATL BSS SOC estimation errors](../assets/ATL%20BSS%20SOC%20Estimation%20Errors.png)

### Stable Versus Drifting Convergence

These convergence plots show the stronger point: on the same desktop scenario, some estimators recover from wrong initialization while others keep a long-lived SOC bias.

`EBiSPKF` is representative of the stable group under the tuned initialization sweep:

![SOC estimation convergence EBiSPKF](../assets/SOC%20Estimation%20Convergence%20-%20EBiSPKF.png)

`ESC-EKF` can also converge well when it is tuned consistently with the scenario:

![SOC estimation convergence ESC-EKF](../assets/SOC%20Estimation%20Convergence%20-%20ESC-EKF.png)

But the same estimator family can drift badly when the tuning is mismatched, which is why the desktop scenario is useful as a drift-exposure test and not only as a best-case benchmark:

![SOC estimation convergence ESC-EKF mistuned](../assets/SOC%20Estimation%20Convergence%20-%20ESC-EKF%20%28mistuned%29.png)

`EaEKF` shows another useful contrast: adaptation can reduce the effect of wrong initialization, but the result is still estimator-dependent and should not be assumed from a single best tuned benchmark:

![SOC estimation convergence EaEKF](../assets/SOC%20Estimation%20Convergence%20-%20EaEKF.png)

## Reading Of The Evidence

- The tuned desktop benchmark in `results/estimatorsBayesTuning.md` shows that several estimators can achieve about `0.6%` SOC RMSE on this scenario, with `ESC-EKF` best at the tuned operating point.
- That best-point result is not enough to rule out drift. The initialization sweeps show that some filters remain flat across wrong initial SOC values, while others degrade sharply and keep a sustained SOC bias over the trajectory.
- Under the tuned init-SOC sweep, the strongest anti-drift behavior comes from `EBiSPKF`, `ESC-SPKF`, and `EbSPKF`. Their SOC RMSE stays comparatively flat from `0%` to `100%` initial SOC.
- `ESC-EKF`, `EsSPKF`, and `Em7SPKF` can look excellent near the correct initialization but still drift strongly when the initial condition or covariance fit is wrong.
- The mistuned `ESC-EKF` figure is the clearest visual warning: the desktop scenario is sensitive enough to reveal estimator drift even when the same estimator is excellent at its tuned optimum.

## Conclusion

The ATL desktop evaluation scenario should be read as both:

- a best-case benchmark for tuned estimator accuracy, and
- a stress test for SOC drift over time.

That is why the bundle selection in `results/EstimatorSelection.md` does not rely on the tuned desktop benchmark alone. The final recommendation uses the desktop benchmark together with covariance-robustness, injection, and init-SOC studies, because drift sensitivity is estimator-specific and becomes visible only when the scenario is viewed over the full trajectory rather than at a single tuned operating point.
