# Evaluation Layer

This layer contains the estimator benchmarking harnesses, synthetic evaluation dataset builders, and robustness studies.

Use this layer when you want to:
- benchmark several estimators on the same ESC or ROM-backed dataset
- compare SOC and voltage metrics across estimators
- run initialization, noise, or fault sensitivity studies

## Main Entry Points

- `runBenchmark.m`
  - Reusable benchmark API for dataset, model, and estimator-set specs.
  - No-input default now runs the ATL ESC-driven BSS benchmark and saves results unless disabled.
- `xKFeval.m`
  - Core evaluation runner.
- `mainEval.m`
  - Example structured benchmark entry point.
- `initSOCs/sweepInitSocStudy.m`
  - SOC-initialization sensitivity study.
- `tests/runInjTest.m`
  - Noise-injection and fault-injection wrapper.
- `plotInnovationAcfPacf.m`
  - Innovation plotting helper.
- `printEstimatorBiasMetrics.m`
  - Bias and innovation summary helper.

## Folder Conventions

### Benchmark datasets

Save benchmark-ready `.mat` files containing a `dataset` struct under one of:
- `Evaluation/ROMSimData/datasets/`
- `Evaluation/ESCSimData/datasets/`
- `Evaluation/tests/datasets/`

Use:
- `ROMSimData/datasets/` for ROM-driven reference datasets
- `ESCSimData/datasets/` for ESC-driven reference datasets
- `tests/datasets/` for perturbed, injected-noise, or injected-fault cases

### Raw measured application profiles

Keep raw measured profiles near their application-specific subfolder if they are used as source material before conversion into a benchmark dataset.

Current repo example:
- `Evaluation/OMTLIFE8AHC-HP/Bus_CoreBatteryData_Data.mat`

### Models

Benchmarking expects models in the repository-level `models/` folder:
- ESC models such as `models/ATLmodel.mat`
- ESC models such as `models/NMC30model.mat`
- ROM models such as `models/ROM_ATL20_beta.mat`
- ROM models such as `models/ROM_NMC30_HRA12.mat`

## Benchmark Dataset Contract

`runBenchmark.m` expects a saved `dataset` struct with at least:
- `current_a`
- `voltage_v`

Common optional fields:
- `time_s`
- `temperature_c`
- `reference_soc`
- `soc_init_reference`
- `capacity_ah`
- `dataset_soc`
- `metric_soc`
- `metric_voltage`
- `reference_name`
- `voltage_name`
- `title_prefix`

See the top-level `README.md` for the full benchmark dataset contract.

## Recommended Process

1. Place or build a benchmark dataset under `Evaluation/.../datasets/`.
2. Ensure the ESC model exists in `models/`.
3. Add a ROM model in `models/` if `ROM-EKF` should run.
4. Run `runBenchmark.m` or a study wrapper.
5. Inspect the metric table and plots.

## Default Benchmark Example

With no inputs, `runBenchmark.m` now defaults to the ATL ESC-driven BSS case:

```matlab
addpath(genpath('.'));
results = runBenchmark();
results.metadata.metrics_table
```

Default configuration:
- dataset: `Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`
- ESC model: `models/ATLmodel.mat`
- ROM model: `models/ROM_ATL20_beta.mat`
- estimator set: `all`
- dataset builder fallback: `Evaluation/ESCSimData/BSSsimESCdata.m`
- automatic save: enabled

## NMC30 Benchmark Example

```matlab
addpath(genpath('.'));

datasetSpec = struct( ...
    'dataset_file', fullfile('Evaluation', 'ROMSimData', 'datasets', 'rom_bus_coreBattery_dataset.mat'), ...
    'dataset_variable', 'dataset');

modelSpec = struct( ...
    'esc_model_file', fullfile('models', 'NMC30model.mat'), ...
    'rom_model_file', fullfile('models', 'ROM_NMC30_HRA12.mat'), ...
    'tc', 25, ...
    'chemistry_label', 'NMC30');

estimatorSetSpec = struct('registry_name', 'mainEval10');
flags = struct('Summaryfigs', true, 'Verbose', true);

results = runBenchmark(datasetSpec, modelSpec, estimatorSetSpec, flags);
results.metadata.metrics_table
```

## ATL ESC-Driven BSS Example

Use this when you want to benchmark the ATL ESC model against the ESC-driven Bus Core Battery synthetic dataset:

```matlab
addpath(genpath('.'));

datasetSpec = struct( ...
    'dataset_file', fullfile('Evaluation', 'ESCSimData', 'datasets', 'esc_bus_coreBattery_dataset.mat'), ...
    'dataset_variable', 'dataset', ...
    'builder_fcn', 'BSSsimESCdata', ...
    'builder_cfg', struct('model_file', fullfile('models', 'ATLmodel.mat'), 'tc', 25), ...
    'dataset_soc_field', 'soc_true', ...
    'metric_soc_field', 'soc_true', ...
    'metric_voltage_field', 'voltage_v', ...
    'reference_name', 'ESC reference', ...
    'voltage_name', 'ESC voltage', ...
    'title_prefix', 'ATL BSS');

modelSpec = struct( ...
    'esc_model_file', fullfile('models', 'ATLmodel.mat'), ...
    'rom_model_file', fullfile('models', 'ROM_ATL20_beta.mat'), ...
    'tc', 25, ...
    'chemistry_label', 'ATL', ...
    'require_rom_match', true);

estimatorSetSpec = struct( ...
    'registry_name', 'all', ...
    'allow_rom_skip', true);

flags = struct( ...
    'Summaryfigs', true, ...
    'Verbose', true);

results = runBenchmark(datasetSpec, modelSpec, estimatorSetSpec, flags);
results.metadata.metrics_table
```

The dataset builder for this case is:
- `Evaluation/ESCSimData/BSSsimESCdata.m`

The saved dataset path used by the benchmark is:
- `Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`

## Study Wrappers

### Main benchmark

```matlab
cd Evaluation
mainEval
```

### Initial SOC sensitivity

```matlab
cd Evaluation/initSOCs
runInitSocStudy
```

### Noise and fault injection

```matlab
cd Evaluation/tests
runInjTest
```

## Plotting And Outputs

Plot generation is controlled mostly through the `flags` passed into `xKFeval.m` or `runBenchmark.m`.

Common flags:
- `SOCfigs`
- `Vfigs`
- `Biasfigs`
- `R0figs`
- `InnovationACFPACFfigs`
- `Summaryfigs`

Additional plotting helpers:
- `plotEvalResults.m`
- `plotInnovationAcfPacf.m`
- the figure output embedded in `xKFeval.m`

Metrics are exposed in:
- `results.metadata.metrics_table`
- per-estimator fields in `results.estimators`

`runBenchmark.m` now saves results automatically by default. The default output path is:
- `Evaluation/results/<title_prefix>_benchmark_results.mat`

```matlab
results = runBenchmark(datasetSpec, modelSpec, estimatorSetSpec, flags);
results.metadata.saved_results_file
```

Re-plot at any time with:

```matlab
plotEvalResults(results.metadata.saved_results_file);
```

Disable autosave with:

```matlab
flags = struct('SaveResults', false, 'Summaryfigs', true, 'Verbose', true);
results = runBenchmark(datasetSpec, modelSpec, estimatorSetSpec, flags);
```

## Notes And Gotchas

- Repo convention is `+I = discharge`.
- `ROM-EKF` is skipped by `runBenchmark.m` when no compatible ROM is available unless that skip is disallowed explicitly.
- `mainEval.m` is an example scenario, not the only supported benchmark path.
- Benchmark datasets should be normalized before use; raw measured profiles belong in source/application folders until converted.
- Estimator-specific assumptions and failure modes are documented in `docs/estimators.md`.
