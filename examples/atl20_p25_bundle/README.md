# ATL20 P25 Bundle Example

## Purpose

This example is the guided end-to-end workflow for the 25 degC ATL20 ESC model bundle. It starts from OCV and dynamic-identification inputs, builds the ATL20 P25 ESC model, tunes the estimator layer, and runs the downstream benchmark and robustness studies used by this repository.

Main entrypoint:

- `examples/atl20_p25_bundle/run_atl20_p25_bundle.m`

## Assumptions

- ESC model target: `models/ATL20model_P25.mat`
- suite version: `desktop_atl20_bss_v1`
- nominal downstream dataset:
  `data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat`
- estimator bundle:
  - `ROM-EKF`
  - `ESC-SPKF`
  - `ESC-EKF`
  - `EaEKF`
  - `EacrSPKF`
  - `EnacrSPKF`
  - `EDUKF`
  - `EsSPKF`
  - `EbSPKF`
  - `EBiSPKF`
  - `Em7SPKF`
- studies enabled in the example:
  - OCV identification
  - dynamic ESC identification
  - application-dataset ESC validation
  - Bayesian autotuning
  - tuned benchmark validation
  - full-grid noise-covariance sweep
  - initial-SOC sweep
  - injection study on canonical additive, fault, and hall-bias cases

## What The Script Runs

`run_atl20_p25_bundle.m` executes these sections in order:

1. OCV identification at 25 degC only.
2. Dynamic ESC identification at 25 degC.
3. Application-side ESC validation on the processed desktop ESC dataset.
4. Bayesian autotuning for all bundle estimators.
5. Final tuned benchmark validation.
6. Full-grid noise-covariance sweep, split into group 1 and group 2 for hardware reasons.
7. Initial-SOC sweep with the tuned covariances.
8. Injection study using inline canonical case definitions for:
   - `additive_measurement_noise`
   - `sensor_gain_bias_fault`
   - `hall_bias` with `mode = 'composite_measurement_error'`

Step 8 still passes `models/ROM_ATL20_beta.mat` into `runBenchmark` because the benchmark estimator bundle includes `ROM-EKF`. The ROM file is only used by that estimator path; the injected datasets themselves are still generated from the ESC dataset plus the Injection-layer case config.

## Where Outputs Go

### Promoted summaries

These are the Git-trackable outputs. They are written under `results/...`.

- autotuning summaries:
  - `results/autotuning/desktop_atl20_bss_v1/autotuning__desktop_atl20_bss_v1__atl20_p25_bundle__summary.json`
  - `results/autotuning/desktop_atl20_bss_v1/autotuning__desktop_atl20_bss_v1__atl20_p25_bundle__summary.md`
  - `results/autotuning/desktop_atl20_bss_v1/autotuning__desktop_atl20_bss_v1__atl20_p25_bundle__tuned_params.json`
- benchmark summary:
  - `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle__summary.json`
  - `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle__summary.md`
- noise sweep summaries:
  - `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_noise_cov_study_group1__summary.json`
  - `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_noise_cov_study_group1__summary.md`
  - `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_noise_cov_study_group2__summary.json`
  - `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_noise_cov_study_group2__summary.md`
  - optional combined artifact if you generate it:
    - `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_noise_cov_study__summary.json`
    - `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_noise_cov_study__summary.md`
- init-SOC sweep summary:
  - `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_init_soc_sweep__summary.json`
  - `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_init_soc_sweep__summary.md`
- injection summary:
  - `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_injection_study__summary.json`
  - `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_injection_study__summary.md`
- model validation report block:
  - `results/models.md`

### Figures

Optional exported figures go under:

- `results/figures/autotuning/desktop_atl20_bss_v1/atl20_p25_bundle/`
- `results/figures/evaluation/desktop_atl20_bss_v1/atl20_p25_bundle/`

By default the example keeps exported figure saving disabled:

- `save_optional_figures = false`

Some studies still open MATLAB figures interactively unless their plotting flags are turned off.

### Heavy local-only artifacts

These are the large MAT files and per-run outputs that are intentionally local-only.

- OCV / dynamic identification:
  - `data/modelling/derived/ocv_models/atl20/ATL20model-ocv-vavgFT.mat`
  - `data/modelling/derived/identification_results/atl20/ATL20_ocv_identification_results.mat`
  - `models/ATL20model_P25.mat`
  - `data/modelling/derived/identification_results/atl20/ATL20model_P25_identification_results.mat`
  - `data/modelling/derived/validation_results/esc/ATL20model_P25_desktop_atl20_bss_v1_validation.mat`
- autotuning:
  - `autotuning/results/atl20_p25_bundle_autotuning_results.mat`
  - per-estimator best reruns under `autotuning/results/...`
- benchmark:
  - `Evaluation/results/atl20_p25_bundle_benchmark_results.mat`
- noise sweep:
  - `Evaluation/NoiseTuningSweep/results/atl20_p25_bundle_noise_cov_study_group1.mat`
  - `Evaluation/NoiseTuningSweep/results/atl20_p25_bundle_noise_cov_study_group2.mat`
- init-SOC:
  - `Evaluation/initSOCs/results/atl20_p25_bundle_init_soc_sweep.mat`
  - `Evaluation/initSOCs/results/atl20_p25_bundle_init_soc_sweep_summary.mat`
- injection:
  - `Evaluation/Injection/results/atl20_p25_bundle_injection_study.mat`
  - per-case benchmark MATs under `Evaluation/Injection/results/atl20_p25_bundle_injection_study/`
  - canonical derived injected datasets and manifests under `data/evaluation/derived/desktop_atl20_bss_v1/...`

## Low-Storage Mode

The example is not currently a cache-aware or storage-minimizing pipeline. By default it saves the heavy MAT outputs needed by later steps and by the promoted-summary writers.

For low storage:

- keep `save_optional_figures = false`
- if you only want the build steps, skip sections 4 to 7
- if you only want promoted summaries from already-saved heavy MATs, use the recovery helpers instead of rerunning the studies

Per-step heavy save controls exist, but disabling them has consequences:

- step 1: `cfg_ocv.output.save_model`, `cfg_ocv.output.save_results`
- step 2: `cfg_dyn.output.save_model`, `cfg_dyn.output.save_results`
- step 3: `cfg_auto.output.save_results`
  also disable `bestResultFlags.SaveResults` if you do not want per-estimator best reruns
- step 4: `flags.SaveResults`
- step 5A/5B: `step5*_noise_cfg.SaveResults`
- step 6: `step6_cfg.SaveResults`
- step 7: `step7_cfg.output.save_results`
  and `step7_cfg.scenarios.benchmarkFlags.SaveResults`

Important:

- steps 4 to 7 currently write promoted summaries from heavy MAT results
- if you disable heavy MAT saving for those steps, also disable the promoted-summary write for that step or adapt the script to summarize from in-memory results
- steps 1 and 2 should normally keep saving enabled because later sections read the saved model files

## How To Inspect Results

### Benchmark metrics table

```matlab
S = load(fullfile('Evaluation', 'results', 'atl20_p25_bundle_benchmark_results.mat'));
results = S.results;
results.metadata.metrics_table
```

### Autotuning summary

```matlab
S = load(fullfile('autotuning', 'results', 'atl20_p25_bundle_autotuning_results.mat'));
printAutotuningSummary(S.autotuning_results)
```

### ESC model validation on modelling data

```matlab
S = load(fullfile('data', 'modelling', 'derived', 'identification_results', ...
    'atl20', 'ATL20model_P25_identification_results.mat'));
plotEscValidation(S.identification_results.dynamic_validation)
S.identification_results.dynamic_validation.summary_table
S.identification_results.metrics
```

### Application-side ESC validation

```matlab
S = load(fullfile('data', 'modelling', 'derived', 'validation_results', ...
    'esc', 'ATL20model_P25_desktop_atl20_bss_v1_validation.mat'));
plotEscValidation(S.atl20_p25_application_validation)
S.atl20_p25_application_validation.summary_table
```

### Estimator selection summary

This example does not emit one single `estimator_selection` artifact. In practice, selection evidence comes from:

- benchmark summary:
  - `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle__summary.*`
- noise-covariance sweep summaries:
  - `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_noise_cov_study*`
- initial-SOC sweep summary:
  - `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_init_soc_sweep__summary.*`
- injection study summary:
  - `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle_injection_study__summary.*`

### Initial-SOC sweep

```matlab
S = load(fullfile('Evaluation', 'initSOCs', 'results', ...
    'atl20_p25_bundle_init_soc_sweep_summary.mat'));
printInitSocSweepSummary(S.summary)
```

### Injection outputs

```matlab
S = load(fullfile('Evaluation', 'Injection', 'results', ...
    'atl20_p25_bundle_injection_study.mat'));
printInjectionSummary(S.injection_results)
S.injection_results.summary_table
```

### Noise-covariance sweep

```matlab
S = load(fullfile('Evaluation', 'NoiseTuningSweep', 'results', ...
    'atl20_p25_bundle_noise_cov_study_group1.mat'));
printNoiseSweepSummary(S.sweepResults)
```

## Rerun Behavior

This example is a rerunnable workflow, not an incremental cached pipeline.

- rerunning the full script recomputes the sections and overwrites the same named output files
- the script includes recovery comments for several steps so you can regenerate promoted summaries from saved heavy MAT files without rerunning the study
- step 7 is the only section that intentionally reuses existing injected datasets by setting `overwrite = false` for the canonical derived cases
