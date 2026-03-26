# ECM Parametrization and SOC Estimation Benchmark Toolchain
This repository is distributed under the Creative Commons Attribution-ShareAlike 4.0 International License (CC BY-SA 4.0).

## Repository Purpose

This repository delivers a reference architecture for battery validation and benchmark orchestration across versioned model-estimator bundles.

The primary deployable unit is a validated estimator-model bundle tied to a benchmark suite version.
A bundle consists of an estimator, its dependent model, pinned datasets, evaluation entry points, a benchmark-suite version, and results.

The toolchain is designed to scale to additional models, datasets, and estimators without changing the top-level workflow shape. New bundles can reuse the same model-validation, benchmark, robustness-study, and results-reporting layers.

For the current repo state, the intended output is a validated estimator-model bundle tied to a benchmark suite version, consistent with [`results/EstimatorSelection.md`](results/EstimatorSelection.md).
This repository can also be used to evaluate the claim that SOC estimator performance drifts over time in chemistries with flat open-circuit-voltage (OCV) plateaus.

## Architecture

This repository is organized as layered workflows:

1. Build an Enhanced Self-Correcting (ESC) model in `ESC_Id/`.
2. Validate that model with [`ESC_Id/ESCvalidation.m`](ESC_Id/ESCvalidation.m).
3. Store released ESC or Reduced Order Model (ROM) artifacts as `.mat` model files in `models/`.
4. Add or maintain estimator implementations and initializers in `estimators/`.
5. Tune estimator covariance parameters with Bayes optimization in `autotuning/` when needed.
6. Benchmark estimators with [`Evaluation/runBenchmark.m`](Evaluation/runBenchmark.m); use [`Evaluation/mainEval.m`](Evaluation/mainEval.m) as a fixed example scenario.
7. Run robustness studies such as:
   - `Evaluation/initSOCs/`
   - `Evaluation/NoiseTuningSweep/`
   - `Evaluation/Injection/`
8. Store concise result summaries in `results/`.
9. Select the validated estimator-model bundle according to an explicit ranking criterion, for example [`results/EstimatorSelection.md`](results/EstimatorSelection.md).

The `utility/` layer contains shared simulation, plotting, profile, and example helpers.

### To add models or datasets

For ESC modeling data, use `ESC_Id/DYN_Files` and/or `ESC_Id/OCV_Files`.
These may also be mirrored into an external registry such as `data/Modelling`.

Store released model artifacts in `models/`, add estimator implementations in `estimators/`, and place benchmark-ready evaluation datasets under the active evaluation-data registry, for example `data/Evaluation`.

Explicit path overrides may be needed when using a relocated or external data registry with:
- [`Evaluation/runBenchmark.m`](Evaluation/runBenchmark.m)
- [`Evaluation/Injection/runInjectionStudy.m`](Evaluation/Injection/runInjectionStudy.m)
- [`Evaluation/initSOCs/runInitSocStudy.m`](Evaluation/initSOCs/runInitSocStudy.m)

Additional refactoring may still be needed for:
- [`Evaluation/mainEval.m`](Evaluation/mainEval.m)
- parts of [`autotuning/runAutotuning.m`](autotuning/runAutotuning.m)

The layer documentation below includes examples for these explicit-path cases.

## Benchmarks

- The ATL20 benchmark using [`models/ATLmodel.mat`](models/ATLmodel.mat) with the ESC-driven BSS dataset in [`Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`](Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat) is the desktop evaluation scenario.
- The NMC30 benchmark using [`models/NMC30model.mat`](models/NMC30model.mat) with the ROM-driven BSS dataset in [`Evaluation/ROMSimData/datasets/rom_bus_coreBattery_dataset.mat`](Evaluation/ROMSimData/datasets/rom_bus_coreBattery_dataset.mat) is the behavioral-test scenario and is useful for tuning.
- Study wrappers in `Evaluation/` default to the ATL20 desktop-evaluation scenario unless overridden explicitly.

### Desktop Evaluation

The full pipeline has been completed for the desktop evaluation scenario:

- model: `ATL20` via [`models/ATLmodel.mat`](models/ATLmodel.mat)
- manufacturer: ATL
- chemistry: LiFePO4
- nominal voltage: 3.2 V
- rated capacity: 20 Ah

- dataset: BSS application based on [1] (ESC-driven) 25 degC evaluation dataset at [`Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`](Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat).

- workflow coverage: model validation, benchmark execution, robustness studies, and estimator selection

Under this completed desktop-evaluation bundle, the current repo-level selection result is the validated estimator-model bundle documented in [`results/EstimatorSelection.md`](results/EstimatorSelection.md).

The desktop evaluation scenario reveals SOC estimation drift in LFP cells; see [`results/DriftStudy.md`](results/DriftStudy.md) for details.
![ATL BSS Estimation](assets/ATL%20BSS%20Estimation.png)

## Layer Guides

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
- [`models/TunedModels/README.md`](models/TunedModels/README.md)
  - direct guide for ROM retuning and ROM validation
- [`docs/Estimators Design.md`](docs/Estimators%20Design.md)
  - code-traceable estimator architecture and implementation reference


## Repository Notes

- Current sign convention is `+I = discharge`.
- Final ESC and ROM model artifacts belong in `models/`.
- Benchmark-ready datasets belong under `Evaluation/.../datasets/` or an equivalent external registry such as `data/Evaluation/`.

## License

See [`LICENSE`](LICENSE).

## Data source

This repository uses data from:

[1] Jöst, Dominik; Palaniswamy, Lakshimi Narayanan; Quade, Katharina Lilith; Sauer, Dirk Uwe (2024).
*Dataset for Towards Robust State Estimation for LFP Batteries: Model-in-the-Loop Analysis with Hysteresis Modeling and Perspectives for Other Chemistries*.
RWTH Aachen University.
DOI: 10.18154/RWTH-2024-03667
Source: https://publications.rwth-aachen.de/record/983741

License: CC BY 4.0
https://creativecommons.org/licenses/by/4.0/
