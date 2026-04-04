## Purpose

This document defines the repository-wide storage layout and the top-level workflow boundaries.

Use it together with the layer READMEs when adding new models, datasets, studies, or promoted result summaries.

Store released model artifacts in `models/`, estimator implementations in `estimators/`, canonical evaluation data in `data/evaluation/...`, and canonical modelling data in `data/modelling/...`.

## Top-Level Workflow

The repository is organized as a layered workflow:

1. Build reusable OCV modelling artifacts in `ocv_id/` and `data/modelling/...`.
2. Build ESC-specific dynamic-identification artifacts in `ESC_Id/`.
3. Produce released ESC or ROM model artifacts in `models/`.
4. Build or curate canonical evaluation datasets in `data/evaluation/...`.
5. Tune estimator covariances in `autotuning/` against a versioned evaluation suite.
6. Run benchmark and robustness studies in `Evaluation/`.
7. Promote lightweight summaries and selected figures into `results/...`.

Stable configurable entry points are:

- [`../ocv_id/runOcvIdentification.m`](../ocv_id/runOcvIdentification.m)
- [`../ocv_id/stdy/runOcvModellingInspection.m`](../ocv_id/stdy/runOcvModellingInspection.m)
- [`../ESC_Id/runDynamicIdentification.m`](../ESC_Id/runDynamicIdentification.m)
- [`../Evaluation/runBenchmark.m`](../Evaluation/runBenchmark.m)
- [`../Evaluation/Injection/runInjectionStudy.m`](../Evaluation/Injection/runInjectionStudy.m)
- [`../Evaluation/initSOCs/runInitSocStudy.m`](../Evaluation/initSOCs/runInitSocStudy.m)
- [`../Evaluation/NoiseTuningSweep/sweepNoiseStudy.m`](../Evaluation/NoiseTuningSweep/sweepNoiseStudy.m)
- [`../autotuning/runAutotuning.m`](../autotuning/runAutotuning.m)

[`../Evaluation/mainEval.m`](../Evaluation/mainEval.m) is a fixed example scenario script built on top of `runBenchmark.m`.

## Data Layout

```text
data/
  modelling/
    raw/
    interim/
    processed/
    synthetic/
    derived/
  evaluation/
    raw/
    interim/
    synthetic/
    processed/
    derived/
  shared/
```

Lifecycle meanings:

- `raw`: immutable source data
- `interim`: transformed but not yet canonical
- `processed`: canonical model-ready or benchmark-ready datasets
- `synthetic`: generated modelling datasets or evaluation-side synthetic builder assets
- `derived`: generated reusable artifacts derived from another dataset
- `shared`: cross-domain metadata reused by modelling and evaluation

## Evaluation Registry

Canonical evaluation locations are:

- raw source profiles:
  `data/evaluation/raw/...`
- synthetic builder-side assets:
  `data/evaluation/synthetic/...`
- processed nominal benchmark datasets:
  `data/evaluation/processed/<suite_version>/nominal/*.mat`
- derived evaluation cases:
  `data/evaluation/derived/<suite_version>/<dataset_family>/<case_id>/dataset.mat`

Generated derived evaluation datasets also save:

- `manifest.json`
- optional `manifest.mat`

Example derived case:

`data/evaluation/derived/desktop_atl20_bss_v1/stochastic_sensor/case_001/`

Helpers added for this registry:

- `utility/dataRegistry/ensureDataRegistryLayout.m`
- `utility/dataRegistry/resolveEvaluationDatasetPath.m`
- `utility/dataRegistry/resolveEvaluationOutputRoot.m`
- `utility/dataRegistry/writeDerivedDatasetManifest.m`
- `utility/dataRegistry/readDerivedDatasetManifest.m`
- `utility/dataRegistry/summarizeEvaluationSuiteManifests.m`
- `utility/dataRegistry/resolveModellingDatasetPath.m`
- `utility/dataRegistry/resolveModellingOutputRoot.m`
- `utility/dataRegistry/classifyModellingArtifactPath.m`


## Modelling Registry

Canonical modelling locations are:

- raw source modelling data:
  `data/modelling/raw/...`
- interim OCV preparation assets:
  `data/modelling/interim/...`
- processed identification inputs:
  `data/modelling/processed/ocv/...`
  `data/modelling/processed/dynamic/...`
- synthetic modelling datasets:
  `data/modelling/synthetic/...`
- derived reusable modelling artifacts:
  `data/modelling/derived/ocv_models/...`
  `data/modelling/derived/identification_results/...`
  `data/modelling/derived/validation_results/...`

## Output Artifact Policy

Evaluation and autotuning outputs are split into two classes:

- summary artifacts:
  lightweight, Git-trackable outputs such as metrics tables, manifests, metadata, and selected published plots
- heavy artifacts:
  local-only outputs such as full estimator time-series performance, merged MAT result bundles, study-detail MAT files, and autotuning checkpoints

Trackable summary outputs belong under:

- `results/evaluation/...`
- `results/autotuning/...`
- `results/ocv/...`
- `results/figures/...`

Promoted summary filenames should use stable stems:

- `autotuning__<suite_version>__<scenario_or_model_id>__summary.md`
- `autotuning__<suite_version>__<scenario_or_model_id>__summary.json`
- `evaluation__<suite_version>__<scenario_or_model_id>__summary.md`
- `evaluation__<suite_version>__<scenario_or_model_id>__summary.json`
- `ocv__<suite_version>__<scenario_or_model_id>__summary.md`
- `ocv__<suite_version>__<scenario_or_model_id>__summary.json`

Heavy local-only outputs stay in workflow-local artifact locations such as:

- `data/evaluation/derived/...`
- `Evaluation/.../results/...`
- `autotuning/results/...`

Use one lightweight summary artifact per study or scenario, keep any full time-series MAT output optional and local-only, and route routine generated figures to `results/figures/...`. Keep `assets/` for stable hand-curated repository visuals only.

For autotuning studies, it is also valid to promote a compact tuned-parameter artifact such as `results/autotuning/<suite_version>/autotuning__<suite_version>__<scenario_or_model_id>__tuned_params.json`.
