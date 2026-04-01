# Estimator Designs

This document is the estimator algorithm-design guide for battbundle: it explains each estimator’s core logic, tracked quantities, assumptions, tuning parameters, best-use cases, and likely failure modes, so benchmark results and final estimator selection can be interpreted in the context of estimator design.

## Inventory

| Estimator | Family | Active in benchmark path | Relative cost | Main risk |
| --- | --- | --- | --- | --- |
| `ROM-EKF` | ROM | Yes | High | Missing or incompatible ROM |
| `ROM-SPKF` | ROM | No | High | Not wired into active benchmark flow |
| `ESC-SPKF` | ESC | Yes | Medium | No explicit bias or `R0` tracking |
| `ESC-EKF` | ESC | Yes | Low | Linearization error |
| `EaEKF` | ESC adaptive | Yes | Medium | Adaptive covariance may stay initialization-dominated |
| `EacrSPKF` | ESC correlated-noise | Yes | Medium | Can fit the wrong error source |
| `EnacrSPKF` | ESC correlated-process | Yes | High | Larger state and tuning sensitivity |
| `EDUKF` | ESC plus `R0` | Yes | High | State and `R0` tradeoff |
| `EsSPKF` | ESC plus `R0` | Yes | Medium | Same state and `R0` tradeoff |
| `EbSPKF` | ESC plus current bias | Yes | Medium | Bias state can absorb generic model mismatch |
| `EBiSPKF` | ESC plus "shaped" input bias branch | Yes | Medium | Default repo bias model appears inert |
| `Em7SPKF` | ESC plus current bias plus `R0` | Yes | High | Default repo bias model appears inert |

## Shared Conventions

- At the evaluation layer, all estimators consume measured voltage, measured current, temperature in `degC`, and sample interval `dt` ([`Evaluation/xKFeval.m`](../Evaluation/xKFeval.m), [`README.md`](../README.md)).
- Repo sign convention is `+I = discharge` ([`README.md`](../README.md)).
- All ESC-family estimators multiply charging current (`ik < 0`) by `etaParam` before the update ([`estimators/iterESCSPKF.m`](../estimators/iterESCSPKF.m), [`estimators/iterESCEKF.m`](../estimators/iterESCEKF.m), [`estimators/iterEaEKF.m`](../estimators/iterEaEKF.m), [`estimators/iterEDUKF.m`](../estimators/iterEDUKF.m), [`estimators/iterEsSPKF.m`](../estimators/iterEsSPKF.m), [`estimators/iterEbSPKF.m`](../estimators/iterEbSPKF.m), [`estimators/iterEBiSPKF.m`](../estimators/iterEBiSPKF.m), [`estimators/iterEacrSPKF.m`](../estimators/iterEacrSPKF.m), [`estimators/iterEnacrSPKF.m`](../estimators/iterEnacrSPKF.m), [`estimators/Em7SPKF.m`](../estimators/Em7SPKF.m)).
- User-facing benchmark outputs are normalized into the same result shape by [`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m) and [`Evaluation/xKFeval.m`](../Evaluation/xKFeval.m): SOC, predicted voltage, bounds, innovation, plus optional `R0` and bias traces.

## Summary Table

All entries in the `Best scenario` column are `inferred` from implementation details and benchmark coverage rather than from explicit design notes in the code.

| Estimator | Main assumptions | Required signals | Cost | Common failure modes | Best scenario |
| --- | --- | --- | --- | --- | --- |
| `ROM-EKF` | Compatible ROM exists; ROM chemistry matches ESC chemistry when `runBenchmark` enforces it; ROM matrices satisfy `initKF` checks; no explicit bias or `R0` state | `V`, `I`, `T`, `dt`, compatible `ROM` struct | High | Missing/incompatible ROM, chemistry mismatch, large nonlinear mismatch, repeated warnings can print `EKF is probably broken/lost` | Highest-fidelity baseline when a matching ROM is available |
| `ROM-SPKF` | Same ROM assumptions as `ROM-EKF`; not part of active benchmark path | `V`, `I`, `T`, `dt`, compatible `ROM` struct | High | Not benchmark-wired, repeated warnings can print `SPKF is probably broken/lost`, file contains `GLP NEEDS OB/MB variants` comment | Experimental ROM sigma-point work outside the supported benchmark path |
| `ESC-SPKF` | Full ESC model with RC states; fixed `R0`; white/noise-like sensor and process errors; no explicit bias state | `V`, `I`, `T`, `dt`, ESC model | Medium | Voltage outliers zero the gain; repeated residuals bump SOC covariance; unmodeled current bias or `R0` drift | General nonlinear ESC baseline |
| `ESC-EKF` | Same ESC assumptions as `ESC-SPKF`, but with linearization around the current state | `V`, `I`, `T`, `dt`, ESC model | Low | Linearization error, outlier-driven covariance inflation, no bias or `R0` tracking | Fastest ESC baseline when model mismatch is modest |
| `EaEKF` | Same ESC assumptions as `ESC-EKF`; process and sensor noise drift slowly enough for adaptive averaging to help | `V`, `I`, `T`, `dt`, ESC model | Medium | Adaptive buffers may not fill on short runs; covariance adaptation can stay initialization-dominated | When fixed `Q/R` tuning is unreliable and runs are long enough to adapt |
| `EacrSPKF` | Main problem is correlated voltage-measurement error; scalar voltage measurement only | `V`, `I`, `T`, `dt`, ESC model | Medium | Wrong correlation model can absorb the wrong error source; no bias or `R0` tracking | Voltage sensor drift / correlation is the dominant nuisance |
| `EnacrSPKF` | Main problem is autocorrelated process/model mismatch; scalar voltage measurement only | `V`, `I`, `T`, `dt`, ESC model | High | State dimension doubles; more tuning-sensitive; no explicit bias or `R0` tracking | Slowly varying process mismatch dominates voltage error |
| `EDUKF` | `R0` is the parameter that needs adaptation; current sensor is effectively unbiased | `V`, `I`, `T`, `dt`, ESC model | High | `R0` and state error can trade off; no explicit current-bias handling | Need SOC plus online `R0` tracking with the full dual-filter structure |
| `EsSPKF` | Same as `EDUKF`, but a simpler post-state-update `R0` branch is sufficient | `V`, `I`, `T`, `dt`, ESC model | Medium | Same state/`R0` tradeoff; no explicit current-bias handling | Lightweight `R0` tracking on top of the ESC-SPKF state estimate |
| `EbSPKF` | Dominant nuisance is current-sensor bias; voltage sensor bias and `R0` drift are not modeled | `V`, `I`, `T`, `dt`, ESC model | Medium | Bias state can absorb generic model mismatch; only current bias is tracked | Current-sensor bias is the main error source |
| `EBiSPKF` | External bias-filter model is supplied or meaningful | `V`, `I`, `T`, `dt`, ESC model | Medium | `inferred`: repo default init leaves bias-model matrices at zero, so `bhat` does not update | Only if you supply a nontrivial bias model and want a separate bias branch |
| `Em7SPKF` | Need both `R0` tracking and an external bias model | `V`, `I`, `T`, `dt`, ESC model | High | `inferred`: repo default init leaves bias-model matrices at zero, so bias tracking is effectively inactive; state and `R0` can still trade off | Only if you supply a nontrivial bias model and want `R0` + bias tracking together |

## Estimator Entries

For every estimator entry below, the sections `Best-case scenario / when this estimator is a good choice` and `Worst-case scenario / when not to use it` are `inferred` from the code and the way the repo exercises the estimator.

### `ROM-EKF`

#### Name
`ROM-EKF`

#### Short purpose
SOC and voltage estimation against a compatible reduced-order electrochemical model.

#### Core idea / mechanism
Uses `initKF` + `iterEKF` to run an EKF over a ROM grid indexed by temperature and SOC, with either output blending or model blending available in the implementation. The repo's public entry points always initialize it with `blend = 'OutB'` ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m), [`Evaluation/mainEval.m`](../Evaluation/mainEval.m), [`Evaluation/Injection/runInjectionStudy.m`](../Evaluation/Injection/runInjectionStudy.m), [`Evaluation/NoiseTuningSweep/sweepNoiseStudy.m`](../Evaluation/NoiseTuningSweep/sweepNoiseStudy.m)).

#### Assumptions it makes
- A compatible `ROM` struct is available and contains `ROM.ROMmdls`, `tfData`, `xraData`, and `cellData` ([`estimators/initKF.m`](../estimators/initKF.m)).
- Each ROM `A` matrix is diagonal and its last state is an integrator; `B` must be all ones ([`estimators/initKF.m`](../estimators/initKF.m)).
- [`runBenchmark.m`](../Evaluation/runBenchmark.m) assumes ROM chemistry should match the ESC chemistry unless `modelSpec.require_rom_match` is disabled.
- No explicit current-bias or `R0` adaptation is implemented in the public benchmark wrapper.

#### Required inputs / signals
- Measured voltage, current, temperature, and sample interval via the benchmark step wrapper ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m), [`Evaluation/xKFeval.m`](../Evaluation/xKFeval.m)).
- Initial SOC and covariance.
- A compatible ROM file / struct ([`README.md`](../README.md), [`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m)).

#### Optional inputs / tunable parameters
- `blend` mode in `initKF`: `OutB`, `MdlB`, or the nonblend aliases handled as degenerate model-blend ([`estimators/initKF.m`](../estimators/initKF.m)).
- Benchmark tuning: `sigma_x0_rom_tail`, `sigma_w_ekf`, `sigma_v_ekf` ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m)).
- Initial SOC override through `estimatorSetSpec.soc0_percent` ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m)).

#### Expected outputs
- User-facing benchmark outputs are SOC, predicted voltage, 3-sigma SOC bound, 3-sigma voltage bound, innovation, and innovation covariance proxy `sk` ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m), [`Evaluation/xKFeval.m`](../Evaluation/xKFeval.m)).
- Internally `iterEKF` returns a larger state/output vector; the repo wrapper maps `zk(end)` to SOC and `zk(end-1)` to voltage ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m)).

#### Estimated computation cost
- qualitative: `high`
- brief explanation of what drives the cost: Reconstructs nonlinear ROM variables and blends up to four neighboring ROM setpoints each step ([`estimators/iterEKF.m`](../estimators/iterEKF.m)).

#### Common failure modes
- Skipped entirely when no compatible ROM is available ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m), [`README.md`](../README.md)).
- ROM chemistry mismatch causes skip or error depending on `allow_rom_skip` ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m)).
- Repeated warning conditions can print `EKF is probably broken/lost` ([`estimators/iterEKF.m`](../estimators/iterEKF.m)).
- Large voltage residuals double `SigmaX` ([`estimators/iterEKF.m`](../estimators/iterEKF.m)).

#### Best-case scenario / when this estimator is a good choice
When you have a validated ROM for the same chemistry and want the repo's highest-fidelity baseline estimator.

#### Worst-case scenario / when not to use it
When no compatible ROM is available, chemistry metadata does not match, or compute budget is much tighter than the ESC estimators allow.

#### Implementation notes / gotchas from this repo
- The active benchmark stack exposes `ROM-EKF`, not `ROM-SPKF` ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m)).
- The README's stable smoke test is explicitly `ROM-EKF` on the NMC30 ROM dataset ([`README.md`](../README.md)).
- `initKF` accepts multiple blend modes, but the repo's shipped benchmark scripts always use `'OutB'`.

### `ROM-SPKF`

#### Name
`ROM-SPKF`

#### Short purpose
Sigma-point counterpart to the ROM EKF.

#### Core idea / mechanism
Uses the same `initKF` ROM data structure as `ROM-EKF`, but updates it through `iterSPKF` instead of `iterEKF` ([`estimators/initKF.m`](../estimators/initKF.m), [`estimators/iterSPKF.m`](../estimators/iterSPKF.m)).

#### Assumptions it makes
- Same ROM structural assumptions as `ROM-EKF`.
- Same temperature/SOC grid blending assumptions as `initKF`.
- `inferred`: This path is not part of the repo's supported benchmark surface, because no active benchmark or test wrapper calls `iterSPKF`.

#### Required inputs / signals
- Measured voltage, current, temperature, and sample interval.
- A compatible ROM struct initialized through `initKF`.

#### Optional inputs / tunable parameters
- Same `initKF` options as `ROM-EKF`, including blend mode and covariance choices.

#### Expected outputs
- `iterSPKF` returns an internal output vector `zk` and bounds `boundzk` ([`estimators/iterSPKF.m`](../estimators/iterSPKF.m)).
- Not explicit in code: no public `xKFeval` wrapper is provided for this estimator in the current repo.

#### Estimated computation cost
- qualitative: `high`
- brief explanation of what drives the cost: Sigma-point generation is layered on top of the same ROM nonlinear-variable reconstruction used by the ROM EKF.

#### Common failure modes
- Repeated warning conditions can print `SPKF is probably broken/lost` ([`estimators/iterSPKF.m`](../estimators/iterSPKF.m)).
- Large residuals double `SigmaX` ([`estimators/iterSPKF.m`](../estimators/iterSPKF.m)).
- The file contains the comment `GLP NEEDS OB/MB variants` near `getVariables`, which is a direct sign that this path is not fully cleaned up for current repo usage ([`estimators/iterSPKF.m`](../estimators/iterSPKF.m)).

#### Best-case scenario / when this estimator is a good choice
Only for local experimentation if you specifically want a ROM sigma-point filter and are comfortable wiring it yourself.

#### Worst-case scenario / when not to use it
When you want a repo-supported estimator path, benchmark integration, or existing test coverage.

#### Implementation notes / gotchas from this repo
- [`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m), [`Evaluation/mainEval.m`](../Evaluation/mainEval.m), [`Evaluation/Injection/runInjectionStudy.m`](../Evaluation/Injection/runInjectionStudy.m), and the sweep scripts do not expose it.
- [`estimators/iterSPKF.m`](../estimators/iterSPKF.m) does not populate `lastInnovationPre` / `lastSk`, so it is not aligned with the current innovation-diagnostics plumbing used by `xKFeval`.
- This estimator appears unused in the active repository workflows.

### `ESC-SPKF`

#### Name
`ESC-SPKF`

#### Short purpose
Baseline sigma-point ESC estimator for SOC and terminal voltage.

#### Core idea / mechanism
Runs an SPKF over the ESC state vector `[ir(1:nRC); h; soc]`, using sigma points built from `SigmaX`, process noise, and sensor noise ([`estimators/initESCSPKF.m`](../estimators/initESCSPKF.m), [`estimators/iterESCSPKF.m`](../estimators/iterESCSPKF.m)).

#### Assumptions it makes
- A full ESC model is available with RC branches ([`estimators/initESCSPKF.m`](../estimators/initESCSPKF.m)).
- `R0` is fixed at the model value for the current temperature ([`estimators/iterESCSPKF.m`](../estimators/iterESCSPKF.m)).
- Current/voltage errors are treated as white-noise-like through `SigmaW` and `SigmaV`.
- No explicit current-bias or `R0` drift state is modeled.

#### Required inputs / signals
- Measured voltage `vk`, current `ik`, temperature `Tk`, sample interval `deltat`, and an ESC model ([`estimators/iterESCSPKF.m`](../estimators/iterESCSPKF.m)).

#### Optional inputs / tunable parameters
- State covariance `SigmaX0`.
- Sensor/process noise variances `SigmaV`, `SigmaW`.
- Benchmark defaults come from `sigma_v_esc`, `sigma_w_esc`, and `SigmaX0_*` in [`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m).

#### Expected outputs
- SOC, predicted voltage, SOC bound, voltage bound, innovation, and `sk` in the benchmark wrappers ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m), [`Evaluation/xKFeval.m`](../Evaluation/xKFeval.m)).

#### Estimated computation cost
- qualitative: `medium`
- brief explanation of what drives the cost: Small-state sigma-point propagation is more expensive than `ESC-EKF`, but still much lighter than the ROM estimators.

#### Common failure modes
- Residuals beyond `100 * SigmaY` zero the gain for that step ([`estimators/iterESCSPKF.m`](../estimators/iterESCSPKF.m)).
- Residuals beyond `4 * SigmaY` multiply SOC covariance by `Qbump = 5` ([`estimators/initESCSPKF.m`](../estimators/initESCSPKF.m), [`estimators/iterESCSPKF.m`](../estimators/iterESCSPKF.m)).
- Current bias, correlated noise, or `R0` drift are unmodeled and can show up as persistent innovation error.

#### Best-case scenario / when this estimator is a good choice
As the general nonlinear ESC baseline when you want better nonlinear handling than `ESC-EKF` without adding bias or `R0` subfilters.

#### Worst-case scenario / when not to use it
When the dominant error source is current-sensor bias, correlated noise, or changing `R0`.

#### Implementation notes / gotchas from this repo
- `initESCSPKF` silently converts SOC from percent to `[0,1]` if `soc0 > 1`.
- Charge current is corrected by `etaParam` when `ik < 0` ([`estimators/iterESCSPKF.m`](../estimators/iterESCSPKF.m)).
- Hysteresis sign only updates when `|ik| > Q/100`, so very small currents reuse the previous sign state.

### `ESC-EKF`

#### Name
`ESC-EKF`

#### Short purpose
Lower-cost EKF version of the baseline ESC estimator.

#### Core idea / mechanism
Uses the same ESC state layout as `ESC-SPKF`, but performs EKF prediction/correction with an analytically built state matrix and a numerically differentiated OCV slope in the output Jacobian ([`estimators/initESCSPKF.m`](../estimators/initESCSPKF.m), [`estimators/iterESCEKF.m`](../estimators/iterESCEKF.m)).

#### Assumptions it makes
- Same full-ESC-model and fixed-`R0` assumptions as `ESC-SPKF`.
- Linearization around the current estimate is good enough for the operating region.

#### Required inputs / signals
- Measured voltage, current, temperature, sample interval, ESC model.

#### Optional inputs / tunable parameters
- Same benchmark-facing tuning as `ESC-SPKF`: `SigmaX0_*`, `sigma_v_esc`, `sigma_w_esc`.

#### Expected outputs
- SOC, predicted voltage, SOC/voltage bounds, innovation, `sk` ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m), [`Evaluation/xKFeval.m`](../Evaluation/xKFeval.m)).

#### Estimated computation cost
- qualitative: `low`
- brief explanation of what drives the cost: Uses a single EKF linearization instead of sigma-point propagation.

#### Common failure modes
- Linearization error can degrade accuracy around strong ESC nonlinearities.
- Outliers can zero the gain or trigger covariance bumping ([`estimators/iterESCEKF.m`](../estimators/iterESCEKF.m)).
- No explicit handling for current bias, correlated sensor noise, or `R0` drift.

#### Best-case scenario / when this estimator is a good choice
When you need the fastest ESC estimator path and the fixed-parameter ESC model is already a good fit.

#### Worst-case scenario / when not to use it
When nonlinear behavior, sensor bias, or parameter drift dominate the error budget.

#### Implementation notes / gotchas from this repo
- This estimator reuses the [`estimators/initESCSPKF.m`](../estimators/initESCSPKF.m) data structure; there is no separate `initESCEKF.m`.
- OCV slope is approximated numerically with `ds = 1e-6` in [`estimators/iterESCEKF.m`](../estimators/iterESCEKF.m).
- The benchmark and study stack exercises this estimator in `mainEval`, `runBenchmark`, `runInjectionStudy`, and `sweepNoiseStudy`.

### `EaEKF`

#### Name
`EaEKF`

#### Short purpose
Adaptive EKF that retunes process and sensor noise online.

#### Core idea / mechanism
Starts from the ESC-EKF state/update structure, then updates `SigmaW` and `SigmaV` using smoothed averages of innovation-driven covariance estimates stored in rolling buffers ([`estimators/initEaEKF.m`](../estimators/initEaEKF.m), [`estimators/iterEaEKF.m`](../estimators/iterEaEKF.m)).

#### Assumptions it makes
- Same full ESC model and fixed-`R0` assumptions as `ESC-EKF`.
- Noise statistics move slowly enough that exponential smoothing and long buffers are meaningful.
- No explicit current-bias or `R0` drift state is modeled.

#### Required inputs / signals
- Measured voltage, current, temperature, sample interval, ESC model.

#### Optional inputs / tunable parameters
- `alpha` smoothing factor, default `0.99` ([`estimators/initEaEKF.m`](../estimators/initEaEKF.m)).
- `NW` and `NV` rolling-buffer lengths, default `500` each ([`estimators/initEaEKF.m`](../estimators/initEaEKF.m)).
- Benchmark-facing initial covariances: `SigmaX0_*`, `sigma_v_esc`, `sigma_w_esc` ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m)).

#### Expected outputs
- Same benchmark outputs as `ESC-EKF`.
- Final adapted `SigmaW` and `SigmaV` remain in `results.estimators(i).kfDataFinal`, and the repo has a dedicated plotting helper for them: [`Evaluation/NoiseTuningSweep/plotEaEkfCovarianceSweeps.m`](../Evaluation/NoiseTuningSweep/plotEaEkfCovarianceSweeps.m).

#### Estimated computation cost
- qualitative: `medium`
- brief explanation of what drives the cost: EKF math is cheap, but each step also updates and averages covariance-estimation buffers.

#### Common failure modes
- If the run does not exceed the buffer lengths, the adaptive `SigmaW` / `SigmaV` updates do not execute ([`estimators/iterEaEKF.m`](../estimators/iterEaEKF.m)).
- `inferred`: On shorter or weakly exciting runs, the final adaptive covariances can remain dominated by their initialization; the repo added [`plotEaEkfCovarianceSweeps.m`](../Evaluation/NoiseTuningSweep/plotEaEkfCovarianceSweeps.m) specifically to diagnose this.
- Still does not model explicit current bias or `R0` drift.

#### Best-case scenario / when this estimator is a good choice
When fixed ESC `Q/R` tuning is hard to set once and the evaluation runs are long enough for online adaptation to settle.

#### Worst-case scenario / when not to use it
When the run is short, the disturbance is really a structured bias/parameter problem, or you need tightly controlled fixed-noise behavior.

#### Implementation notes / gotchas from this repo
- No benchmark script in the repo overrides `alpha`, `NW`, or `NV`; all shipped runs appear to use the defaults.
- [`plotEaEkfCovarianceSweeps.m`](../Evaluation/NoiseTuningSweep/plotEaEkfCovarianceSweeps.m) diagnoses the final adapted covariances as either `convergent adaptive covariance estimation` or `initialization-dominated covariance scaling`.

### `EacrSPKF`

#### Name
`EacrSPKF`

#### Short purpose
ESC-SPKF variant that adds a correlated sensor-noise state.

#### Core idea / mechanism
On the first call, `iterEacrSPKF` augments the base ESC state with one extra state `x_corr` and adds it directly to the output equation. Its dynamics are `x_corr(k) = Af * x_corr(k-1) + w_corr(k-1)` ([`estimators/iterEacrSPKF.m`](../estimators/iterEacrSPKF.m)).

#### Assumptions it makes
- Full ESC model with RC states.
- Scalar voltage measurement only (`iterEacrSPKF` checks `Nv == 1`).
- Correlated measurement error is a better explanation than explicit current bias or `R0` drift.

#### Required inputs / signals
- Measured voltage, current, temperature, sample interval, ESC model.

#### Optional inputs / tunable parameters
- Same base ESC-SPKF tuning as `ESC-SPKF`.
- Optional `esckfData.eacrAf` scalar before first use; default is `1`, i.e. random-walk correlation state ([`estimators/iterEacrSPKF.m`](../estimators/iterEacrSPKF.m)).

#### Expected outputs
- Same user-facing outputs as `ESC-SPKF`.

#### Estimated computation cost
- qualitative: `medium`
- brief explanation of what drives the cost: Adds only one extra state on top of the base ESC-SPKF sigma-point update.

#### Common failure modes
- If the dominant problem is process mismatch or current bias instead of correlated measurement noise, the extra sensor-correlation state can fit the wrong phenomenon.
- Same outlier/gain-zero/Q-bump behavior as the base ESC-SPKF path.

#### Best-case scenario / when this estimator is a good choice
When measured-voltage error has a slow correlated component that a white-noise `SigmaV` model does not capture well.

#### Worst-case scenario / when not to use it
When the real error source is current bias, `R0` drift, or broad process mismatch.

#### Implementation notes / gotchas from this repo
- There is no dedicated initializer; the first step mutates a plain `initESCSPKF` state into the augmented form.
- The repo does not set `eacrAf` anywhere in its benchmark scripts, so the shipped path uses the default random-walk value `Af = 1`.
- This estimator is in the main benchmark and noise sweep, but not in the initial-SOC sweep or injected-noise/fault wrapper.

### `EnacrSPKF`

#### Name
`EnacrSPKF`

#### Short purpose
ESC-SPKF variant that models autocorrelated process mismatch.

#### Core idea / mechanism
On the first call, doubles the state dimension from `Nx0` to `2*Nx0` by appending a process-correlation state `x_proc`. The main state update becomes `x_main_new = x_main_nominal + x_proc_old`, while `x_proc_new = Af * x_proc_old + w` ([`estimators/iterEnacrSPKF.m`](../estimators/iterEnacrSPKF.m)).

#### Assumptions it makes
- Full ESC model with RC states.
- Scalar voltage measurement only.
- Slowly varying process/model mismatch is better modeled as an autocorrelated state than as pure white process noise.

#### Required inputs / signals
- Measured voltage, current, temperature, sample interval, ESC model.

#### Optional inputs / tunable parameters
- Same base ESC-SPKF tuning as `ESC-SPKF`.
- Optional `enacrAf` before first use; scalar expands to `Af * I`, matrix form is also accepted. Default is `0.98 * I` ([`estimators/iterEnacrSPKF.m`](../estimators/iterEnacrSPKF.m)).

#### Expected outputs
- Same user-facing outputs as `ESC-SPKF`.

#### Estimated computation cost
- qualitative: `high`
- brief explanation of what drives the cost: The augmented process-correlation state doubles the ESC state dimension before sigma-point generation.

#### Common failure modes
- More state dimension and more sigma points make tuning more sensitive.
- If the dominant issue is measurement bias rather than process mismatch, the extra process state can chase the wrong error source.
- Same outlier/gain-zero/Q-bump handling as the base ESC-SPKF.

#### Best-case scenario / when this estimator is a good choice
When model/process mismatch evolves slowly over time and a plain white-noise ESC-SPKF is too optimistic.

#### Worst-case scenario / when not to use it
When compute budget is tight or the dominant issue is sensor bias instead of process drift.

#### Implementation notes / gotchas from this repo
- Like `EacrSPKF`, it performs one-time internal augmentation rather than using a dedicated init function.
- Default `Af` is `0.98 * I`; the repo does not override it in its benchmark scripts.
- This estimator is exercised more broadly than `EacrSPKF`: it appears in `mainEval`, `runBenchmark`, `sweepInitSocStudy`, `runInjectionStudy`, and `sweepNoiseStudy`.

### `EDUKF`

#### Name
`EDUKF`

#### Short purpose
Dual ESC sigma-point filter that estimates SOC/state and `R0` together.

#### Core idea / mechanism
Uses two coupled sigma-point filters in `iterEDUKF`: a state SPKF for the ESC states and a parallel 1-state parameter filter for `R0`, both driven by the same voltage measurement ([`estimators/initEDUKF.m`](../estimators/initEDUKF.m), [`estimators/iterEDUKF.m`](../estimators/iterEDUKF.m)).

#### Assumptions it makes
- Full ESC model with RC states.
- `R0` is the parameter that needs online adaptation.
- Current-sensor bias is not explicitly modeled.

#### Required inputs / signals
- Measured voltage, current, temperature, sample interval, ESC model.
- Initial `R0` estimate and `R0` covariance (`SigmaR0`, `SigmaWR0`).

#### Optional inputs / tunable parameters
- Base ESC state covariance / noise tuning.
- `SigmaR0` and `SigmaWR0` for the `R0` branch ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m), [`estimators/initEDUKF.m`](../estimators/initEDUKF.m)).

#### Expected outputs
- SOC, predicted voltage, SOC/voltage bounds, innovation, `sk`.
- `R0` estimate and `R0` bound through the benchmark wrappers ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m), [`Evaluation/xKFeval.m`](../Evaluation/xKFeval.m)).

#### Estimated computation cost
- qualitative: `high`
- brief explanation of what drives the cost: Runs a full state SPKF plus a separate parameter sigma-point update for `R0`.

#### Common failure modes
- State error and `R0` error can trade off against each other through the same voltage residual.
- No explicit current-bias branch, so current bias can be misread as state/`R0` mismatch.
- Same sigma-point outlier gating and covariance bumping as the ESC-SPKF family.

#### Best-case scenario / when this estimator is a good choice
When `R0` drift matters and you want the repo's fuller dual-filter treatment rather than a lighter post-update branch.

#### Worst-case scenario / when not to use it
When the dominant error is current-sensor bias or a parameter other than `R0`.

#### Implementation notes / gotchas from this repo
- `initEDUKF` is also reused to initialize `EsSPKF`; the step function decides which `R0` update logic is used.
- The repo has a dedicated comparison script, [`Evaluation/ABestComp.m`](../Evaluation/ABestComp.m), for `EDUKF` vs `EsSPKF`.

### `EsSPKF`

#### Name
`EsSPKF`

#### Short purpose
ESC-SPKF with a simplified separate `R0` tracking branch.

#### Core idea / mechanism
Runs the normal ESC-SPKF state update first, then calls a local 1-state `R0SPKF` using the updated ESC state and the current voltage measurement ([`estimators/iterEsSPKF.m`](../estimators/iterEsSPKF.m)).

#### Assumptions it makes
- Same full ESC model assumptions as `ESC-SPKF`.
- `R0` is the only parameter that needs explicit adaptation.
- Current-sensor bias is not explicitly modeled.

#### Required inputs / signals
- Measured voltage, current, temperature, sample interval, ESC model.
- Initial `R0`, `SigmaR0`, and `SigmaWR0`.

#### Optional inputs / tunable parameters
- Same base ESC state tuning as `ESC-SPKF`.
- `SigmaR0`, `SigmaWR0` for the `R0` branch.

#### Expected outputs
- Same outputs as `EDUKF`: SOC, voltage, bounds, innovation, `R0`, and `R0` bounds.

#### Estimated computation cost
- qualitative: `medium`
- brief explanation of what drives the cost: Adds only a lightweight 1-state `R0` SPKF on top of the base ESC-SPKF update.

#### Common failure modes
- State and `R0` can still compensate for each other.
- No explicit current-bias or voltage-bias branch.
- Same sigma-point outlier/Q-bump behavior as the base ESC-SPKF.

#### Best-case scenario / when this estimator is a good choice
When you want `R0` tracking but do not need the heavier dual-filter structure of `EDUKF`.

#### Worst-case scenario / when not to use it
When the dominant problem is sensor bias, correlated noise, or a parameter drift other than `R0`.

#### Implementation notes / gotchas from this repo
- This estimator is used more broadly than `EDUKF`: it appears in `runBenchmark`, `ABestComp`, `sweepInitSocStudy`, `runInjectionStudy`, and `sweepNoiseStudy`.
- Its initializer is still `initEDUKF`, which is easy to miss if you search only for `EsSPKF` names.

### `EbSPKF`

#### Name
`EbSPKF`

#### Short purpose
ESC-SPKF with an explicit current-bias state inside the main filter state vector.

#### Core idea / mechanism
Augments the ESC state with one extra state `ib` and uses separate process-noise entries for current noise and bias random walk. Prediction and output use `currentEff = current - ib` ([`estimators/iterEbSPKF.m`](../estimators/iterEbSPKF.m); local init helper `initEbSpkf` in [`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m)).

#### Assumptions it makes
- Full ESC model with RC states.
- A current-sensor bias is a meaningful latent state.
- `R0` remains fixed.

#### Required inputs / signals
- Measured voltage, current, temperature, sample interval, ESC model.

#### Optional inputs / tunable parameters
- Base ESC tuning: `SigmaX0`, `SigmaV`.
- Separate current-noise and bias-noise variances through the local helper signature `initEbSpkf(..., sigma_w_current, sigma_w_bias, sigma_ib0, ...)`.
- Benchmark defaults: `single_bias_process_var`, `current_bias_var0`, plus base ESC tuning ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m)).

#### Expected outputs
- SOC, predicted voltage, bounds, innovation.
- Current-bias estimate and bound ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m), [`Evaluation/xKFeval.m`](../Evaluation/xKFeval.m)).

#### Estimated computation cost
- qualitative: `medium`
- brief explanation of what drives the cost: Adds one more state and one more process-noise channel to the base ESC-SPKF.

#### Common failure modes
- The bias state can absorb generic model mismatch, not just true sensor bias.
- Voltage-sensor bias and `R0` drift remain unmodeled.
- Same sigma-point outlier/Q-bump behavior as the base ESC-SPKF.

#### Best-case scenario / when this estimator is a good choice
When current-sensor bias is the main nuisance and `R0` is not the main uncertainty.

#### Worst-case scenario / when not to use it
When the dominant issue is voltage bias, correlated voltage noise, or changing `R0`.

#### Implementation notes / gotchas from this repo
- There is no standalone `estimators/initEbSPKF.m`; the benchmark scripts each define a local `initEbSpkf` helper.
- The helper fixes `currentNoiseInd = 1` and `biasNoiseInd = 2`.
- This estimator is included in `runBenchmark`, `mainEval`, `sweepInitSocStudy`, `runInjectionStudy`, and `sweepNoiseStudy`.

### `EBiSPKF`

#### Name
`EBiSPKF`

#### Short purpose
Two-stage ESC-SPKF with a separate external bias (shaping) filter branch.

#### Core idea / mechanism
Runs a normal ESC-SPKF state update, then updates a separate bias estimate `bhat` using matrices `Bb`, `Cb`, `V`, and either dynamic or static `Ad`/`Cd` bias models ([`estimators/initESCSPKF.m`](../estimators/initESCSPKF.m), [`estimators/iterEBiSPKF.m`](../estimators/iterEBiSPKF.m)).

#### Assumptions it makes
- Full ESC model with RC states.
- A meaningful external bias model is available through the bias-filter matrices.
- Repo benchmark wiring uses a single bias state (`nb = 1`) and treats it as current bias (`currentBiasInd = 1`).

#### Required inputs / signals
- Measured voltage, current, temperature, sample interval, ESC model.
- Bias-filter fields created by `initESCSPKF(..., biasCfg)`.

#### Optional inputs / tunable parameters
- `biasCfg.nb`, `bhat0`, `SigmaB0`, `Bb`, `Cb`, `V0`, `currentBiasInd`, `biasModelStatic`, `Ad`, `Cd` ([`estimators/initESCSPKF.m`](../estimators/initESCSPKF.m)).
- The repo helper `initEbiSpkf` only sets `nb = 1`, `bhat0 = 0`, `SigmaB0 = sigma_ib0`, and `currentBiasInd = 1` ([`Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m) and similar script-local helpers).

#### Expected outputs
- SOC, predicted voltage, bounds, innovation.
- Bias estimate and bias bound.

#### Estimated computation cost
- qualitative: `medium`
- brief explanation of what drives the cost: Uses the base ESC-SPKF plus an extra matrix-based bias update each step.

#### Common failure modes
- `inferred`: With the repo's default helper, `Bb`, `Cb`, and `V0` all stay at the zero defaults from `initESCSPKF`. In `iterEBiSPKF`, that keeps `U`, `S`, `V`, and `Lb` at zero, so `bhat` stays fixed at its initial value.
- Because of that, the bias branch can look active in plots while effectively doing nothing unless the caller supplies a nontrivial bias model.
- This estimator does not handle `R0` drift.

#### Best-case scenario / when this estimator is a good choice
Only when you are prepared to provide nonzero bias-model matrices and want a bias branch separated from the core ESC state.

#### Worst-case scenario / when not to use it
When you expect the repo's default benchmark wiring to estimate current bias automatically.

#### Implementation notes / gotchas from this repo
- This is the clearest "appears incomplete / experimental" estimator in the active registry.
- It is present in `runBenchmark`, `mainEval`, and `sweepNoiseStudy`, but not in `runInjectionStudy` or `sweepInitSocStudy`.
- The bias-model hooks are real, but the shipped helpers do not populate them.

### `Em7SPKF`

#### Name
`Em7SPKF`

#### Short purpose
Method-7 ESC-SPKF that combines the external bias branch with a simplified `R0` SPKF.

#### Core idea / mechanism
Runs the same two-stage external bias machinery as `EBiSPKF`, then performs a simplified 1-state `R0` SPKF using the bias-corrected current ([`estimators/Em7init.m`](../estimators/Em7init.m), [`estimators/Em7SPKF.m`](../estimators/Em7SPKF.m)).

#### Assumptions it makes
- Full ESC model with RC states.
- A useful external bias model exists.
- `R0` is the only parameter drift modeled explicitly.

#### Required inputs / signals
- Measured voltage, current, temperature, sample interval, ESC model.
- Initial `R0`, `SigmaR0`, `SigmaWR0`, and the bias-filter fields produced by `Em7init(..., biasCfg)`.

#### Optional inputs / tunable parameters
- Base ESC state tuning.
- `SigmaR0` and `SigmaWR0` for the `R0` branch.
- Same `biasCfg` options as `EBiSPKF`; the repo helper again only supplies `nb = 1`, `bhat0 = 0`, `SigmaB0`, and `currentBiasInd = 1`.

#### Expected outputs
- SOC, predicted voltage, bounds, innovation.
- Bias estimate and bound.
- `R0` estimate and bound.

#### Estimated computation cost
- qualitative: `high`
- brief explanation of what drives the cost: Uses the base ESC-SPKF, the external bias-filter branch, and an additional 1-state `R0` SPKF.

#### Common failure modes
- `inferred`: Under the repo's default helper, the bias branch has the same zero-matrix problem as `EBiSPKF`, so `bhat` stays at its initial value unless custom bias-model matrices are supplied.
- If bias is inactive, the estimator effectively reduces to an `R0`-tracking ESC-SPKF rather than a true joint bias+`R0` estimator.
- State error and `R0` error can still trade off through the voltage residual.

#### Best-case scenario / when this estimator is a good choice
When you are willing to provide a real bias model and want both explicit bias tracking and `R0` tracking in one estimator.

#### Worst-case scenario / when not to use it
When you expect the shipped benchmark initialization to estimate current bias automatically.

#### Implementation notes / gotchas from this repo
- This estimator is in the public registry and the initial-SOC sweep, and it is the only ESC estimator supported by the dedicated single-estimator noise sweep besides `ROM-EKF` ([`Evaluation/NoiseTuningSweep/oneEstSweeNoise.m`](../Evaluation/NoiseTuningSweep/oneEstSweeNoise.m)).
- That extra study support does not fix the default zero-matrix bias-model issue described above.
