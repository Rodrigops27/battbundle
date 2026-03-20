# results

## Brief description of the scenario

This layer holds concise written summaries of completed modelling and validation scenarios. Each file is intended to answer four questions quickly:
- what was run
- what the key numbers were
- what those numbers mean
- how to regenerate the result

Current result documents:

| File | Scenario |
| --- | --- |
| `results/estimators.md` | Estimator inventory and implementation-based comparison summary |
| `results/models.md` | ESC model validation summary |
| `results/ROMvalidation.md` | ROM-vs-ESC validation summary |

## Results (tables)

| Scenario file | Main result content | Primary source scripts |
| --- | --- | --- |
| `results/estimators.md` | Estimator comparison table, assumptions, failure modes, best-use cases | `Evaluation/runBenchmark.m`, `Evaluation/xKFeval.m`, `estimators/*.m` |
| `results/models.md` | ESC validation RMSE tables and per-model observations | `ESC_Id/ESCvalidation.m`, `ESC_Id/validate_models.m`, `ESC_Id/plotEscValidation.m` |
| `results/ROMvalidation.md` | ROM validation RMSE/SOC tables and ROM-specific observations | `models/TunedModels/retuningROMVal.m`, `models/TunedModels/validate_rom_models.m`, `models/TunedModels/plotRomValidation.m` |

## Observations

- `results/` is a reporting layer, not a computation layer.
- The source of truth for regeneration remains in `ESC_Id/`, `Evaluation/`, and `models/TunedModels/`.
- Result files should stay short and scenario-oriented. Detailed usage belongs in the layer READMEs, not here.
- If a result file contains historical numeric values, update it only after rerunning the owning harness.

## How to regenerate them

- Regenerate ESC model validation summaries:

```matlab
addpath(genpath('.'));
cd ESC_Id
validate_models
```

- Regenerate ROM validation summaries:

```matlab
addpath(genpath('.'));
cd models/TunedModels
validate_rom_models
```

- Regenerate estimator benchmark results:
  - run the owning benchmark or study in `Evaluation/`
  - then update `results/estimators.md` from the generated benchmark outputs

Common entry points:

```matlab
addpath(genpath('.'));
cd Evaluation
mainEval
```

```matlab
addpath(genpath('.'));
results = runBenchmark(datasetSpec, modelSpec, estimatorSetSpec, flags);
```
