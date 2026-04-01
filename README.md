# ECM Parametrization and SOC Estimation Benchmark Toolchain
This repository is distributed under the Creative Commons Attribution-ShareAlike 4.0 International License (CC BY-SA 4.0).

## Repository Purpose

This repository builds battery models, validates them, tunes estimator covariances, and benchmarks estimator-model bundles against versioned evaluation suites.

The main output is a validated estimator-model bundle tied to a benchmark suite version. A bundle consists of:
- an estimator
- its dependent model
- pinned datasets
- evaluation entry points
- a benchmark suite version
- result summaries

The toolchain is designed to scale to additional models, datasets, and estimators without changing the top-level workflow shape. It also supports studying model-complexity tradeoffs and SOC-estimation drift in chemistries with flat open-circuit-voltage (OCV) plateaus.

For the current repo state, the intended output is consistent with [`results/EstimatorSelection.md`](results/EstimatorSelection.md).

## Workflow Overview

This repository is organized as layered workflows:

1. Build an Enhanced Self-Correcting (ESC) model, based on [1], in `ESC_Id/`.
2. Validate that model with [`ESC_Id/ESCvalidation.m`](ESC_Id/ESCvalidation.m).
3. Store released ESC or Reduced Order Model (ROM) artifacts as `.mat` model files in `models/`.
4. Evaluate the battery cell model accuracy with application specific datasets (stored or to be stored) at [`data/evaluation/processed`](data/evaluation/processed).
5. Add or maintain estimator implementations and initializers in `estimators/`.
6. Tune estimator covariance parameters with Bayes optimization in `autotuning/` when needed.
   - Run a grid search to sweep the Kalman Filter Covariances for an specifc dataset..
7. Benchmark estimators with [`Evaluation/runBenchmark.m`](Evaluation/runBenchmark.m); use [`Evaluation/mainEval.m`](Evaluation/mainEval.m) as a fixed example scenario.
8. Run robustness studies such as initialization, covariance, and injection studies in  [`Evaluation`](Evaluation) .
9. Store concise result summaries in `results/`.
10. Select the validated estimator-model bundle according to an explicit ranking criterion, for example [`results/EstimatorSelection.md`](results/EstimatorSelection.md).

Shared simulation, plotting, profile, data registries and utility helpers live in `utility/`.

See [`docs/architecture.md`](docs/architecture.md) for the repository purpose, top-level workflow, and canonical storage policy.

## Current Suites

The current canonical evaluation suites are:

- **Desktop ESC suite**  
  `data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat`

- **Behavioral ROM suite**  
  `data/evaluation/processed/behavioral_nmc30_bss_v1/nominal/rom_bus_coreBattery_dataset.mat`

- **Raw source profile used by dataset builders**  
  `data/evaluation/raw/omtlife8ahc_hp/Bus_CoreBatteryData_Data.mat`

Benchmark and runtime evaluation reads must use canonical processed or derived datasets. Builder and conversion scripts may read source profiles from `data/evaluation/raw/...`.


## Current Benchmark Scenarios

### Desktop evaluation
The desktop evaluation scenario uses:
- model: [`models/ATLmodel.mat`](models/ATLmodel.mat)
- chemistry: LiFePO4
- dataset: `desktop_atl20_bss_v1`,  based on [2].
- workflow coverage: model validation, benchmarking, robustness studies, and estimator selection

The current repo-level validated bundle is documented in [`results/EstimatorSelection.md`](results/EstimatorSelection.md).

Related notes:
- SOC-estimation drift for the ATL cell under the ESC hysteresis description is discussed in [`results/DriftStudy.md`](results/DriftStudy.md).
- Bayes-optimization tuning quality is reviewed in [`results/BayesOptReview.md`](results/BayesOptReview.md).

![ATL BSS Estimation](assets/ATL%20BSS%20Estimation.png)

### Behavioral evaluation
The behavioral-test scenario uses:
- model: [`models/NMC30model.mat`](models/NMC30model.mat)
- dataset: `behavioral_nmc30_bss_v1`

This scenario is useful for ROM-backed benchmarking and tuning studies.

## Data and Artifact Policy

Canonical data roots live under [`data/`](data):

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

  Use these as the canonical local workspace.

High-level policy:

- released model artifacts belong in [`models/`](models)
- benchmark-ready evaluation datasets belong in `data/evaluation/processed/...`
- generated evaluation cases belong in `data/evaluation/derived/...`
- promoted summaries belong in `results/...`
- heavy generated outputs such as full time-series results, checkpoints, and large MAT artifacts are local-only by default

See [`docs/architecture.md`](docs/architecture.md) for the full registry and artifact policy.

## Main Entry Points

- `ESC_Id/runOcvIdentification.m`
- `ESC_Id/runDynamicIdentification.m`
- `ESC_Id/ESCvalidation.m`
- `Evaluation/runBenchmark.m`
- `Evaluation/mainEval.m`
- `Evaluation/Injection/runInjectionStudy.m`
- `Evaluation/initSOCs/runInitSocStudy.m`
- `Evaluation/NoiseTuningSweep/sweepNoiseStudy.m`
- `autotuning/runAutotuning.m`

## Further Documetnation

- [`README.md`](README.md)
  - project orientation and entry points
- [`ESC_Id/README.md`](ESC_Id/README.md)
  - ESC modeling and ESC validation
- [`Evaluation/README.md`](Evaluation/README.md)
  - estimator benchmarking, injected tests, and study runners
- [`Evaluation/NoiseTuningSweep/README.md`](Evaluation/NoiseTuningSweep/README.md)
  - covariance-tuning study guide and entry points
- [`Evaluation/Injection/README.md`](Evaluation/Injection/README.md)
  - injection-study configuration and custom path examples
- [`Evaluation/initSOCs/README.md`](Evaluation/initSOCs/README.md)
  - initial-SOC sweep guide and entry points.
- [`models/TunedModels/README.md`](models/TunedModels/README.md)
  - direct guide for ROM retuning and ROM validation
- [`docs/Estimators Design.md`](docs/Estimators%20Design.md)
  - algorithm-design guide summarizing estimator's features, assumptions, tuning knobs, expected best-use cases, and likely failure modes to support estimator analysis and selection.
- [`docs/architecture.md`](docs/architecture.md)
  - repository purpose, workflow, data registry, and artifact policy
- [`docs/data-layout-migration-report.md`](docs/data-layout-migration-report.md) migration record

## Repository Notes

- Current sign convention is `+I = discharge`.
- Final ESC and ROM model artifacts belong in `models/`.
- Benchmark-ready datasets belong under canonical `data/evaluation/processed/...` or `data/evaluation/derived/...`.
- Builder and conversion scripts may read source profiles from `data/evaluation/raw/...`.

## References

[1] G. L. Plett, *Battery Management Systems, Volume II: Equivalent-Circuit Methods*. Artech House, 2015.

See `LICENSE`.

### Data Source

[2] Jost, Dominik; Palaniswamy, Lakshimi Narayanan; Quade, Katharina Lilith; Sauer, Dirk Uwe (2024).  
*Dataset for Towards Robust State Estimation for LFP Batteries: Model-in-the-Loop Analysis with Hysteresis Modeling and Perspectives for Other Chemistries*.  
RWTH Aachen University.  
DOI: 10.18154/RWTH-2024-03667  
Source: https://publications.rwth-aachen.de/record/983741  
License: CC BY 4.0  
