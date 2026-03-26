#  ECM parametrization and SOC Estimation Benchmark Toolchain

MATLAB toolchain for:
- building ESC battery models from OCV and dynamic data
- validating fitted models against measured voltage traces
- benchmarking ESC and ROM-based estimators on common datasets

## Repository Purpose

This repository delivers a clean reference architecture for battery validation and benchmark orchestration across versioned model-estimator bundles.

The primary deployable unit is a validated estimator-model bundle tied to a benchmark suite version.
Bundle = estimator + dependent model + pinned datasets + evaluation entry points + benchmark suite version + results.

The toolchain is designed to scale to additional models, datasets, and estimators without changing the top-level workflow shape. New bundles can reuse the same model-validation, benchmark, robustness-study, and results-reporting layers.

For the current repo state, the intended output is a validated estimator-model bundle tied to a benchmark suite version, consistent with `results/EstimatorSelection.md`.

This repository is organized as layered workflows:
- `ESC_Id/` builds and validates ESC models
- `Evaluation/` benchmarks estimators and runs robustness studies
- `estimators/` contains estimator implementations and initializers
- `models/` stores released ESC and ROM model artifacts and ROM retuning tools
- `results/` stores concise result summaries and regeneration notes
- `utility/` contains shared simulation, plotting, profile, and example helpers

The root README is intentionally short. Use the layer READMEs below for actual usage.

## Documentation Tree

- `README.md`
  - project orientation and entry points
- `ESC_Id/README.md`
  - ESC modelling and ESC validation
- `Evaluation/README.md`
  - estimator benchmarking, injected tests, and study runners
- `models/TunedModels/README.md`
  - direct guide for ROM retuning and ROM validation
- `docs/Estimators Design.md`
  - code-traceable estimator architecture and implementation reference

## First Run

From the repository root in MATLAB:

```matlab
addpath(genpath('.'));
```

Typical workflow:

1. Build or refresh an ESC model in `ESC_Id/`.
2. Validate that model with `ESC_Id/ESCvalidation.m`.
3. Place the final `.mat` model in `models/`.
4. Benchmark estimators with `Evaluation/runBenchmark.m` or `Evaluation/mainEval.m`.

## Benchmark Roles

- The ATL20 benchmark using `models/ATLmodel.mat` with the ESC-driven BSS dataset in `Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat` is the core desktop evaluation.
- The NMC30 benchmark using `models/NMC30model.mat` with the ROM-driven BSS dataset in `Evaluation/ROMSimData/datasets/rom_bus_coreBattery_dataset.mat` is the behavioral test and is useful for tuning.
- Study wrappers in `Evaluation/` default to the ATL20 desktop-evaluation scenario unless overridden explicitly.

## Desktop Evaluation

The full pipeline has been completed for the desktop evaluation scenario:
- model: `ATL20` via `models/ATLmodel.mat`
- dataset: ESC-driven BSS evaluation dataset at `Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`
- workflow coverage: model validation, benchmark execution, robustness studies, and estimator selection

Under this completed desktop-evaluation bundle, the current repo-level selection result is the validated estimator-model bundle documented in `results/EstimatorSelection.md`.

## Layer Guides

- `ESC_Id/README.md`
- `Evaluation/README.md`
- `Evaluation/Injection/README.md`
- `Evaluation/NoiseTuningSweep/README.md`
- `models/TunedModels/README.md`

## Repository Notes

- Current sign convention is `+I = discharge`.
- Final ESC and ROM model artifacts belong in `models/`.
- Benchmark-ready datasets belong under `Evaluation/.../datasets/`.
- Support folders such as `assets/`, `bin/`, `stdies/`, and `Test/` are not primary user-facing workflow layers.

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
