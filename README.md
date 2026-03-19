# SOC ESC Identification and Benchmark Toolchain

This repository is a MATLAB toolchain for ESC battery-model identification, validation, and estimator benchmarking.

The workflow is:

1. Identify ESC model parameters from OCV data and dynamic current-voltage data.
2. Validate the model with voltage-focused metrics such as RMSE and mean error.
3. Pair the model with several estimators and benchmark them on representative datasets.
4. Use the benchmark results to promote the best model and estimator combination for the target application.

The evaluation layer also supports robustness studies such as different SOC initialization, sensor-noise injection, and sensor-fault injection.

## Project Aim

The toolchain is intended to support:

1. ESC parameter identification
   - Prefer OCV data plus dynamic datasets spanning diverse C-rates.
   - Prefer charge and discharge coverage, ideally across roughly 10% to 90% SOC.
2. Model validation
   - Validate the identified model before estimator benchmarking.
   - Focus on voltage RMSE and mean voltage bias error.
3. Model-estimator pairing and benchmarking
   - Evaluate which estimator works best for a given ESC model and dataset.
   - Support both diverse-C-rate datasets and application-specific duty cycles.
   - Study sensitivity to SOC initialization error.
   - Run additional injected-noise and injected-fault tests in the evaluation layer.
4. Selection for deployment
   - Promote the best model (chemestry) and estimator for the required application.

## Repository Structure

- `ESC_Id/`: ESC identification and regeneration scripts.
  - OCV processing and dynamic parameter identification live here.
  - Includes NMC30 and OMTLIFE-oriented identification flows.
- `estimators/`: estimator implementations and initializers.
  - EKF, SPKF, adaptive, bias-aware, and R0-tracking variants.
- `Evaluation/`: model validation, estimator benchmarking, and robustness studies.
  - Structured benchmark runner, initial-SOC sweeps, injected-noise/fault studies, and plotting helpers.
  - `Evaluation/runBenchmark.m` is the reusable benchmark API above `xKFeval.m`.
- `models/`: released ESC and ROM model artifacts (`.mat`).
- `utility/`: shared helper functions used by the identification and estimator layers.
- `ESC Modelling Data/`: source data and supporting modelling assets.
- `assets/`: saved figures and report artifacts.

## Toolchain Stages

### 1. ESC Identification

The identification layer builds ESC models from OCV and dynamic data.

Relevant parametrization tools:
- `ESC_Id/DiagProcessOCV.m`
- `ESC_Id/processDynamic.m`

#### 1.1 Model Validation

Model validation should happen before estimator benchmarking. In this repo, validation is primarily voltage-oriented and uses metrics such as:
- Voltage RMSE
- Mean voltage error / bias

Primary entry points:
- `ESC_Id/ESCvalidation.m`
- `ESC_Id/runESCvalidation.m`
- `docs/models.md`

### 2. Estimator Pairing and Benchmarking

The ESC model is paired with multiple estimators and evaluated on a common dataset so the best estimator for that model/configuration can be identified.

Current benchmark entry points:

- `Evaluation/runBenchmark.m`
  - Generic benchmark API that binds a dataset spec, model spec, and estimator-set spec into `Evaluation/xKFeval.m`.
- `Evaluation/mainEval.m`
  - Main structured benchmark entry point.
  - Scenario script built on the same estimator/evaluation stack.
- `Evaluation/xKFeval.m`
  - Core reusable evaluation runner for datasets plus initialized estimators.
- `Evaluation/initSOCs/sweepInitSocStudy.m`
  - Initial-SOC sensitivity study for the ESC estimator family.
  - `Evaluation/initSOCs/runInitSocStudy.m`: convenience wrapper around `sweepInitSocStudy.m` with fixed defaults.
- `Evaluation/tests/runInjTest.m`
  - Noise-injection and fault-injection benchmark wrapper.

### 3. Promotion of the Best Configuration

The intended output of the toolchain is not just a fitted model or a single estimator result. The goal is to identify the best model-estimator pair for the required application profile and cell chemistry, then carry that pair forward.

## Main Evaluation Entry Points

- `Evaluation/runBenchmark.m`: reusable benchmark runner that accepts `datasetSpec`, `modelSpec`, and `estimatorSetSpec`.
- `Evaluation/mainEval.m`: primary estimator benchmark tested on the NMC30 ROM-based bus_coreBattery dataset.
- `Evaluation/initSOCs/sweepInitSocStudy.m`: configurable SOC-initialization sweep.
- `Evaluation/tests/runInjTest.m`: configurable injected-noise or injected-fault benchmark.
- `Evaluation/plotInnovationAcfPacf.m`: innovation ACF/PACF plotting helper.
- `Evaluation/printEstimatorBiasMetrics.m`: bias and innovation summary helper.
- `docs/estimators.md`: user-facing estimator reference, assumptions, failure modes, and selection guidance.
- `docs/models.md`: ESC model-validation harness, accepted measured-data shapes, and metric definitions.

## Dataset Contract For xKFeval

`Evaluation/xKFeval.m` accepts one dataset struct plus one or more initialized estimators.

Required dataset fields:
- `current_a`: current trace, with `+I = discharge`.
- `voltage_v`: terminal-voltage trace.

Optional dataset fields:
- `time_s`: sample timestamps. If omitted, `xKFeval` uses `0,1,2,...`.
- `temperature_c`: scalar or vector temperature in `degC`. If omitted, the runner default is used.
- `reference_soc`: SOC reference in `[0,1]`. If present, this is the benchmark SOC reference.
- `soc_init_reference`: initial SOC in percent. Required when `reference_soc` is not supplied.
- `capacity_ah`: required with `soc_init_reference` when `reference_soc` is not supplied so `xKFeval` can Coulomb-count a reference.
- `dataset_soc`: optional SOC trace used only for plotting overlays.
- `metric_soc`: optional SOC trace used for metrics. Defaults to `reference_soc`.
- `metric_voltage`: optional voltage trace used for metrics. Defaults to `voltage_v`.
- `reference_name`, `dataset_soc_name`, `metric_soc_name`, `voltage_name`, `metric_voltage_name`, `title_prefix`: optional plotting labels.

The saved benchmark datasets in this repo follow that contract by storing a `dataset` struct inside a `.mat` file. The recommended locations are:
- `Evaluation/ROMSimData/datasets/` for ROM-driven evaluation datasets.
- `Evaluation/ESCSimData/datasets/` for ESC-driven evaluation datasets.
- `Evaluation/tests/datasets/` for perturbed or injected-fault test datasets.

## Model .mat Contract

`runBenchmark.m` expects the model files to be MATLAB `.mat` files with consistent top-level variables.

ESC model contract:
- Put ESC models under `models/`.
- The file must contain either `nmc30_model` or `model`.
- The loaded struct must be a full ESC model with fields used by `getParamESC`, especially `RCParam`, `QParam`, and `R0Param`.

ROM model contract:
- Put ROM models under `models/`.
- The file must contain `ROM`.
- The runner infers the ROM state count from `ROM.ROMmdls(1).A`.
- `iterKF` requires a ROM. If `ROM-EKF` is requested and no ROM file is supplied, or the file is missing, or the chemistry tag mismatches the ESC chemistry, `runBenchmark` skips `ROM-EKF` by default and records the reason in `results.metadata.rom_status`.
- Chemistry matching is taken from `ROM.meta.ocv_source_model_name`, then `ROM.meta.chemistry`, then the ROM file/model name.

## How To Add A New Benchmark Config

The intended extension flow is:

1. Drop the evaluation dataset in `Evaluation/.../datasets/`.
2. Drop the ESC model in `models/`.
3. Drop the ROM model in `models/` if you want to run `ROM-EKF`.
4. Register the estimator names through `estimatorSetSpec.estimator_names` or use a registry such as `mainEval10` or `esc9`.
5. Run one config through `Evaluation/runBenchmark.m`.

Minimal benchmark configuration shape:

```matlab
datasetSpec = struct( ...
    'dataset_file', fullfile('Evaluation', 'ROMSimData', 'datasets', 'rom_bus_coreBattery_dataset.mat'), ...
    'dataset_variable', 'dataset');

modelSpec = struct( ...
    'esc_model_file', fullfile('models', 'NMC30model.mat'), ...
    'rom_model_file', fullfile('models', 'ROM_NMC30_HRA12.mat'), ...
    'tc', 25, ...
    'chemistry_label', 'NMC30');

estimatorSetSpec = struct( ...
    'registry_name', 'mainEval10');

flags = struct('Summaryfigs', true, 'Verbose', true);
results = runBenchmark(datasetSpec, modelSpec, estimatorSetSpec, flags);
```

If the dataset is not built yet, add a dataset builder:

```matlab
datasetSpec.builder_fcn = @createBusCoreBatterySyntheticDataset;
datasetSpec.builder_cfg = struct('tc', 25);
datasetSpec.rebuild_dataset = true;
```

To override tuning, pass a partial tuning struct in `estimatorSetSpec.tuning`. Any omitted fields fall back to the default benchmark tuning used by `runBenchmark.m`.

### Stable NMC30 Test For runBenchmark

The stable NMC30 benchmark path in this repository is:
- Dataset: `Evaluation/ROMSimData/datasets/rom_bus_coreBattery_dataset.mat`
- ESC model: `models/NMC30model.mat`
- ROM model: `models/ROM_NMC30_HRA12.mat`
- Estimator set: `mainEval10` = 9 ESC estimators + `ROM-EKF`

Use this from the repository root:

```matlab
addpath(genpath('.'));

datasetSpec = struct( ...
    'dataset_file', fullfile('Evaluation', 'ROMSimData', 'datasets', 'rom_bus_coreBattery_dataset.mat'), ...
    'dataset_variable', 'dataset', ...
    'dataset_soc_field', 'soc_true', ...
    'metric_soc_field', 'soc_true', ...
    'metric_voltage_field', 'voltage_v', ...
    'reference_name', 'ROM reference', ...
    'voltage_name', 'ROM voltage', ...
    'title_prefix', 'NMC30');

modelSpec = struct( ...
    'esc_model_file', fullfile('models', 'NMC30model.mat'), ...
    'rom_model_file', fullfile('models', 'ROM_NMC30_HRA12.mat'), ...
    'tc', 25, ...
    'chemistry_label', 'NMC30', ...
    'require_rom_match', true);

estimatorSetSpec = struct( ...
    'registry_name', 'mainEval10', ...
    'allow_rom_skip', false);

flags = struct( ...
    'SOCfigs', false, ...
    'Vfigs', false, ...
    'Biasfigs', true, ...
    'R0figs', true, ...
    'InnovationACFPACFfigs', true, ...
    'Summaryfigs', true, ...
    'Verbose', true);

results = runBenchmark(datasetSpec, modelSpec, estimatorSetSpec, flags);
results.metadata.metrics_table
```

That run is the intended smoke test for `runBenchmark.m`. If `ROM-EKF` fails there, the issue is in the ROM path, ROM chemistry metadata, or ROM compatibility handling rather than in the generic ESC estimator path.

## Dependencies

1. MATLAB, recommended `R2023a` or newer.

## Conventions

- Current sign: `+I = discharge`, `-I = charge`.
- Positive current reduces SOC.
- Script-level SOC inputs are often in percent, while internal ESC states typically use normalized SOC in `[0, 1]`.
- Temperatures at the evaluation-layer interface are in `degC`.
- Voltage is terminal cell voltage in volts.

## NMC30 Dynamic-Data Note

For the NMC30 ESC parameter identification flow, the dynamic dataset was generated from a ROM-based simulation path. That is a practical source of dynamic data, but it is not the only possible one.

In principle, the same identification procedure could be driven by an external model or higher-fidelity source, for example:

- PyBaMM
- COMSOL
- another FOM or experimentally derived dynamic dataset

## License

See [`LICENSE`](./LICENSE) for license scope and attribution requirements.
