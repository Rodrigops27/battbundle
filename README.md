# ECM Parametrization and SOC Estimation Benchmark Toolchain
This repository is distributed under the Creative Commons Attribution-ShareAlike 4.0 International License (CC BY-SA 4.0).

## Repository Purpose

This repository delivers a clean reference architecture for battery validation and benchmark orchestration across versioned model-estimator bundles.

The primary deployable unit is a validated estimator-model bundle tied to a benchmark suite version.
Bundle = estimator + dependent model + pinned datasets + evaluation entry points + benchmark suite version + results.

The toolchain is designed to scale to additional models, datasets, and estimators without changing the top-level workflow shape. New bundles can reuse the same model-validation, benchmark, robustness-study, and results-reporting layers.

For the current repo state, the intended output is a validated estimator-model bundle tied to a benchmark suite version, consistent with `results/EstimatorSelection.md`.

## Architecture

This repository is organized as layered workflows:

1. Build an Enhanced Self-Correcting (ESC) model in `ESC_Id/`.
2. Validate that model with `ESC_Id/ESCvalidation.m`.
3. Store released ESC or Reduced Order Model (ROM) artifacts as `.mat` model files in `models/`.
4. Add or maintain estimator implementations and initializers in `estimators/`.
5. Tune estimator covariance parameters with Bayes optimization in `autotuning/` when needed.
6. Benchmark estimators with `Evaluation/runBenchmark.m`; use `Evaluation/mainEval.m` as a fixed example scenario.
7. Run robustness studies such as:
   - `Evaluation/initSOCs/`
   - `Evaluation/NoiseTuningSweep/`
   - `Evaluation/Injection/`
8. Store concise result summaries in `results/`.
9. Select the validated estimator-model bundle according to an explicit ranking criterion, for example `results/EstimatorSelection.md`.

- The `utility/` layer contains shared simulation, plotting, profile, and example helpers

### To add models or datasets

For ESC modelling data, use `ESC_Id/DYN_Files` and/or `ESC_Id/OCV_Files`.
These may also be mirrored into an external registry such as `data/Modelling`.

Store released model artifacts in `models/`, add estimator implementations in `estimators/`, and place benchmark-ready evaluation datasets under the active evaluation-data registry, for example `data/Evaluation`.

Explicit path overrides may be needed when using a relocated or external data registry with:
- `Evaluation/runBenchmark.m`
- `Evaluation/Injection/runInjectionStudy.m`
- `Evaluation/initSOCs/runInitSocStudy.m`

Additional refactoring may still be needed for:
- `Evaluation/mainEval.m`
- parts of `autotuning/runAutotuning.m`

The layer documentation below includes examples for these explicit-path cases.

## Benchmarks

- The ATL20 benchmark using `models/ATLmodel.mat` with the ESC-driven BSS dataset in `Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat` is the desktop evaluation.
- The NMC30 benchmark using `models/NMC30model.mat` with the ROM-driven BSS dataset in `Evaluation/ROMSimData/datasets/rom_bus_coreBattery_dataset.mat` is the behavioral test and is useful for tuning.
- Study wrappers in `Evaluation/` default to the ATL20 desktop-evaluation scenario unless overridden explicitly.

### Desktop Evaluation

The full pipeline has been completed for the desktop evaluation scenario:
- model: `ATL20` via `models/ATLmodel.mat`
- dataset: ESC-driven BSS evaluation dataset at `Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`
- workflow coverage: model validation, benchmark execution, robustness studies, and estimator selection

Under this completed desktop-evaluation bundle, the current repo-level selection result is the validated estimator-model bundle documented in `results/EstimatorSelection.md`.

## Layer Guides

- `README.md`
  - project orientation and entry points
- `ESC_Id/README.md`
  - ESC modelling and ESC validation
- `Evaluation/README.md`
  - estimator benchmarking, injected tests, and study runners
- `Evaluation/NoiseTuningSweep/README.md`
  - covariance-tuning study guide and entry points
- `Evaluation/Injection/README.md`
  - injection-study configuration and custom path examples
- `models/TunedModels/README.md`
  - direct guide for ROM retuning and ROM validation
- `docs/Estimators Design.md`
  - code-traceable estimator architecture and implementation reference


## Repository Notes

- Current sign convention is `+I = discharge`.
- Final ESC and ROM model artifacts belong in `models/`.
- Benchmark-ready datasets belong under `Evaluation/.../datasets/`.

## License

See `LICENSE`.

## Data source

This repository uses data from:

Jöst, Dominik; Palaniswamy, Lakshimi Narayanan; Quade, Katharina Lilith; Sauer, Dirk Uwe (2024).
*Dataset for Towards Robust State Estimation for LFP Batteries: Model-in-the-Loop Analysis with Hysteresis Modeling and Perspectives for Other Chemistries*.
RWTH Aachen University.
DOI: 10.18154/RWTH-2024-03667
Source: https://publications.rwth-aachen.de/record/983741

License: CC BY 4.0
https://creativecommons.org/licenses/by/4.0/
