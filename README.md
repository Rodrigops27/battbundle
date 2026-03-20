# SOC ESC Identification and Benchmark Toolchain

MATLAB toolchain for:
- building ESC battery models from OCV and dynamic data
- validating fitted models against measured voltage traces
- benchmarking ESC and ROM-based estimators on common datasets

## Repository Purpose

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
- `estimators/README.md`
  - estimator inventory and integration entry points
- `models/README.md`
  - TODO: parent models-layer guide not added yet
- `models/TunedModels/README.md`
  - direct guide for ROM retuning and ROM validation
- `results/README.md`
  - concise scenario-level summaries and regeneration pointers
- `utility/README.md`
  - shared helpers, examples, and reusable plotting tools

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

## Layer Guides

- `ESC_Id/README.md`
- `Evaluation/README.md`
- `estimators/README.md`
- `models/TunedModels/README.md`
- `results/README.md`
- `utility/README.md`

## Repository Notes

- Current sign convention is `+I = discharge`.
- Final ESC and ROM model artifacts belong in `models/`.
- Benchmark-ready datasets belong under `Evaluation/.../datasets/`.
- Support folders such as `assets/`, `bin/`, `stdies/`, and `Test/` are not primary user-facing workflow layers.

## License

See `LICENSE`.
