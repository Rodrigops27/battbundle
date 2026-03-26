# Evaluation Layer

This layer contains the estimator benchmarking harnesses, synthetic evaluation dataset builders, and robustness studies.

Use this layer when you want to:
- benchmark several estimators on the same ESC or ROM-backed dataset
- compare SOC and voltage metrics across estimators
- run initialization, noise, or fault sensitivity studies

The default study scenario in this layer is the ATL20 desktop evaluation:
- ESC model: [`models/ATLmodel.mat`](../models/ATLmodel.mat)
- benchmark dataset: [`Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`](ESCSimData/datasets/esc_bus_coreBattery_dataset.mat)

## Main Entry Points

- [`runBenchmark.m`](runBenchmark.m)
  - Reusable benchmark API for dataset, model, and estimator-set specs.
  - No-input default now runs the ATL ESC-driven BSS benchmark and saves results unless disabled.
- [`resolveEstimatorTuningBundle.m`](resolveEstimatorTuningBundle.m)
  - Resolves direct tuning structs or autotuning profile MAT files into per-estimator tuning.
- [`xKFeval.m`](xKFeval.m)
  - Core evaluation runner.
- [`mainEval.m`](mainEval.m)
  - Example structured benchmark entry point.
- [`initSOCs/sweepInitSocStudy.m`](initSOCs/sweepInitSocStudy.m)
  - SOC-initialization sensitivity study.
- [`NoiseTuningSweep/README.md`](NoiseTuningSweep/README.md)
  - covariance-tuning study guide and entry points.
- [`Injection/README.md`](Injection/README.md)
  - Noise-injection and perturbance-injection study guide and entry points.
- [`plotInnovationAcfPacf.m`](plotInnovationAcfPacf.m)
  - Innovation plotting helper.
- [`printEstimatorBiasMetrics.m`](printEstimatorBiasMetrics.m)
  - Bias and innovation summary helper.

## Folder Conventions

### Benchmark datasets

Save benchmark-ready `.mat` files containing a `dataset` struct under one of:
- `Evaluation/ROMSimData/datasets/`
- `Evaluation/ESCSimData/datasets/`
- `Evaluation/Injection/datasets/`

Use:
- `ROMSimData/datasets/` for ROM-driven reference datasets
- `ESCSimData/datasets/` for ESC-driven reference datasets
- `Injection/datasets/` for the renamed user-facing injection-study datasets

### Raw measured application profiles

Keep raw measured profiles near their application-specific subfolder if they are used as source material before conversion into a benchmark dataset.

Current repo example:
- [`Evaluation/OMTLIFE8AHC-HP/Bus_CoreBatteryData_Data.mat`](OMTLIFE8AHC-HP/Bus_CoreBatteryData_Data.mat)

### Models

Benchmarking expects models in the repository-level `models/` folder:
- ESC models such as [`models/ATLmodel.mat`](../models/ATLmodel.mat)
- ESC models such as [`models/NMC30model.mat`](../models/NMC30model.mat)
- ROM models such as [`models/ROM_ATL20_beta.mat`](../models/ROM_ATL20_beta.mat)
- ROM models such as [`models/ROM_NMC30_HRA12.mat`](../models/ROM_NMC30_HRA12.mat)

## Benchmark Dataset Contract

[`runBenchmark.m`](runBenchmark.m) expects a saved `dataset` struct with at least:
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

See the top-level [`README.md`](../README.md) for the full benchmark dataset contract.

## Recommended Process

1. Place or build a benchmark dataset under `Evaluation/.../datasets/`.
2. Ensure the ESC model exists in `models/`.
3. Add a ROM model in `models/` if `ROM-EKF` should run.
4. Optionally point `estimatorSetSpec.tuning` or wrapper `cfg.tuning` at an autotuning param file.
5. Run [`runBenchmark.m`](runBenchmark.m) or a study wrapper.
5. Inspect the metric table and plots.

## Tuned Estimator Profiles

[`runBenchmark.m`](runBenchmark.m) now accepts two tuning styles:
- a plain shared tuning struct, as before
- a resolved tuning profile spec pointing at an autotuning MAT file

The tuning-profile entry point is:

```matlab
estimatorSetSpec.tuning = struct( ...
    'kind', 'autotuning_profile', ...
    'param_file', fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'), ...
    'scenario_name', 'atl_bss_esc', ...
    'selection_policy', 'best_objective', ...
    'fallback_to_default', true);
```

Supported profile fields:
- `param_file`
  - MAT file produced by the autotuning layer.
- `scenario_name`
  - Optional scenario filter inside the autotuning MAT file.
- `selection_policy`
  - One of `best_objective`, `last`, or `first`.
- `fallback_to_default`
  - If `true`, missing files or missing estimator entries fall back to default/shared tuning.
- `warn_on_missing_param_file`
  - Default `true`.
- `warn_on_missing_estimator`
  - Default `true`.
- any regular tuning fields such as `SigmaX0_soc`
  - Applied as shared overrides on top of the resolved tuned values.

Behavior:
- If the param file is found and a matching estimator entry exists, [`runBenchmark.m`](runBenchmark.m) uses the tuned covariance values from that file.
- If the param file is missing, [`runBenchmark.m`](runBenchmark.m) warns and falls back to default/shared tuning when `fallback_to_default = true`.
- If a requested estimator is missing from the param file, [`runBenchmark.m`](runBenchmark.m) also warns and falls back for that estimator when `fallback_to_default = true`.
- The resolved outcome is saved in `results.metadata.tuning_bundle`.

## Default Benchmark Example

With no inputs, [`runBenchmark.m`](runBenchmark.m) now defaults to the ATL ESC-driven BSS case:

```matlab
addpath(genpath('.'));
results = runBenchmark();
results.metadata.metrics_table
```

Default configuration:
- dataset: [`Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`](ESCSimData/datasets/esc_bus_coreBattery_dataset.mat)
- ESC model: [`models/ATLmodel.mat`](../models/ATLmodel.mat)
- ROM model: [`models/ROM_ATL20_beta.mat`](../models/ROM_ATL20_beta.mat)
- estimator set: `all`
- dataset builder fallback: [`Evaluation/ESCSimData/BSSsimESCdata.m`](ESCSimData/BSSsimESCdata.m)
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
    'allow_rom_skip', true, ...
    'tuning', struct( ...
        'kind', 'autotuning_profile', ...
        'param_file', fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'), ...
        'scenario_name', 'atl_bss_esc', ...
        'selection_policy', 'best_objective', ...
        'fallback_to_default', true));

flags = struct( ...
    'Summaryfigs', true, ...
    'Verbose', true);

results = runBenchmark(datasetSpec, modelSpec, estimatorSetSpec, flags);
results.metadata.metrics_table
```

The dataset builder for this case is:
- [`Evaluation/ESCSimData/BSSsimESCdata.m`](ESCSimData/BSSsimESCdata.m)

The saved dataset path used by the benchmark is:
- [`Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`](ESCSimData/datasets/esc_bus_coreBattery_dataset.mat)

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

With a tuning profile and parallel computing:

```matlab
cfg = struct();
cfg.parallel.use_parallel = true;
cfg.parallel.auto_start_pool = true;
cfg.estimatorSetSpec.tuning = struct( ...
    'kind', 'autotuning_profile', ...
    'param_file', fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'), ...
    'scenario_name', 'atl_bss_esc', ...
    'selection_policy', 'best_objective', ...
    'fallback_to_default', true);
runInitSocStudy([0 100], 10, cfg);
```

Run the full 11-estimator desktop set with parallel computing:

```matlab
cfg = struct();
cfg.parallel.use_parallel = true;
cfg.parallel.auto_start_pool = true;
cfg.estimatorSetSpec.estimator_names = { ...
    'ROM-EKF', ...
    'ESC-SPKF', 'ESC-EKF', 'EaEKF', ...
    'EacrSPKF', 'EnacrSPKF', 'EDUKF', ...
    'EsSPKF', 'EbSPKF', 'EBiSPKF', 'Em7SPKF'};
cfg.estimatorSetSpec.tuning = struct( ...
    'kind', 'autotuning_profile', ...
    'param_file', fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'), ...
    'scenario_name', 'atl_bss_esc', ...
    'selection_policy', 'best_objective', ...
    'fallback_to_default', true);
runInitSocStudy([0 100], 10, cfg);
```

[`runInitSocStudy.m`](initSOCs/runInitSocStudy.m) now accepts the estimator-selection entry points:
- `cfg.estimatorSetSpec.estimator_names`
- `cfg.estimatorSetSpec.tuning`
- compatibility shim: `cfg.scenarios(1).estimatorSetSpec.*`

If `cfg.estimatorSetSpec.registry_name = 'all'`, the wrapper expands to the full desktop estimator set:
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

### Noise and perturbance injection

```matlab
cd Evaluation/Injection
runInjectionStudy
```

With a tuning profile:

```matlab
cfg = defaultInjectionConfig();
cfg.scenarios(1).estimatorSetSpec.tuning = struct( ...
    'kind', 'autotuning_profile', ...
    'param_file', fullfile('autotuning', 'results', 'autotuning_20260324_000225.mat'), ...
    'scenario_name', 'atl_bss_esc', ...
    'selection_policy', 'best_objective', ...
    'fallback_to_default', true);
runInjectionStudy(cfg);
```

## Plotting And Outputs

Plot generation is controlled mostly through the `flags` passed into [`xKFeval.m`](xKFeval.m) or [`runBenchmark.m`](runBenchmark.m).

Common flags:
- `SOCfigs`
- `Vfigs`
- `Biasfigs`
- `R0figs`
- `InnovationACFPACFfigs`
- `Summaryfigs`

Additional plotting helpers:
- [`plotEvalResults.m`](plotEvalResults.m)
- [`plotInnovationAcfPacf.m`](plotInnovationAcfPacf.m)
- the figure output embedded in [`xKFeval.m`](xKFeval.m)

Metrics are exposed in:
- `results.metadata.metrics_table`
- per-estimator fields in `results.estimators`

[`runBenchmark.m`](runBenchmark.m) now saves results automatically by default. The default output path is:
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
- `ROM-EKF` is skipped by [`runBenchmark.m`](runBenchmark.m) when no compatible ROM is available unless that skip is disallowed explicitly.
- Tuning-profile warnings come from [`runBenchmark.m`](runBenchmark.m) when a param file or estimator entry is missing and fallback tuning is used.
- [`mainEval.m`](mainEval.m) is an example scenario, not the only supported benchmark path.
- Benchmark datasets should be normalized before use; raw measured profiles belong in source/application folders until converted.
- Estimator-specific assumptions and failure modes are documented in [`docs/Estimators Design.md`](../docs/Estimators%20Design.md).
