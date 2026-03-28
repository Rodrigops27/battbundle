# ESC_Id

## 1. Purpose

- This layer builds ESC models from OCV and dynamic data and validates fitted ESC models against measured current-voltage traces.
- It exists so model identification and model validation happen before estimator benchmarking.

## 2. Scope

- In scope: OCV processing, chemistry-specific ESC fitting scripts, reusable dynamic-identification helpers, OCV-fit metrics and plotting, dynamic-fit metrics and plotting, ESC validation, and ESC validation plotting.
- Out of scope: estimator benchmarking, injected-noise studies, ROM benchmarking, and benchmark dataset comparison tables. Those belong in [`../Evaluation/README.md`](../Evaluation/README.md).

## 3. Directory structure

- [`DiagProcessOCV.m`](DiagProcessOCV.m)
  - Generic OCV-processing entry point.
- [`VavgProcessOCV.m`](VavgProcessOCV.m)
  - OCV-processing entry point using voltage averaging.
- [`processOCV.m`](processOCV.m)
  - Legacy OCV-processing entry point using resistance blending.
- [`processDynamic.m`](processDynamic.m)
  - Generic dynamic ESC parameter-identification routine for lab-style `DYNData`.
- [`computeOcvModelMetrics.m`](computeOcvModelMetrics.m)
  - Generic OCV-fit metrics function for `DiagProcessOCV` and legacy `processOCV` outputs.
- [`plotOcvModelFit.m`](plotOcvModelFit.m)
  - Generic OCV-fit plotting function against raw OCV references.
- [`computeDynamicModelMetrics.m`](computeDynamicModelMetrics.m)
  - Layer entry point for dynamic-fit metrics. Wraps [`ESCvalidation.m`](ESCvalidation.m).
- [`plotDynamicModelFit.m`](plotDynamicModelFit.m)
  - Layer entry point for dynamic-fit plotting. Wraps [`plotEscValidation.m`](plotEscValidation.m).
- [`ESCvalidation.m`](ESCvalidation.m)
  - Main ESC validation harness.
- [`runESCvalidation.m`](runESCvalidation.m)
  - Batch wrapper around [`ESCvalidation.m`](ESCvalidation.m).
- [`validate_models.m`](validate_models.m)
  - Convenience validation script for the repo's main ESC models.
- [`plotEscValidation.m`](plotEscValidation.m)
  - Plot saved dynamic-fit or ESC validation results.
- [`extract_results.m`](extract_results.m)
  - Prints selected values from saved ESC validation results.
- `ATL20/`
  - ATL-specific OCV and full-ESC model builders.
- `OCV_models/`
  - Intermediate OCV model `.mat` files used by dynamic identification.
- `results/`
  - Saved OCV-fit, dynamic-fit, and ESC-validation results. Includes chemistry-specific result wrappers such as `results/OCV/`.
- `NMC30/`
  - NMC30-specific OCV and dynamic-identification scripts.
- `OMTLIFE8AHC-HP/`
  - OMT8-specific OCV and special dynamic-identification scripts.
- `FullESCmodels/`
  - Legacy bundled ESC models used as fallbacks by some scripts.

## 4. Entry points

- [`ESCvalidation.m`](ESCvalidation.m)
  - Single validation run.

```matlab
addpath(genpath('.'));
results = ESCvalidation( ...
    fullfile('models', 'NMC30model.mat'), ...
    fullfile('ESC_Id', 'DYN_Files', 'NMC30_DYN', 'NMC30_DYN_P25.mat'), ...
    true);
```

- [`runESCvalidation.m`](runESCvalidation.m)
  - Batch validation across models and datasets.

```matlab
addpath(genpath('.'));
batch = runESCvalidation( ...
    {fullfile('models', 'ATLmodel.mat'), fullfile('models', 'NMC30model.mat')}, ...
    {fullfile('ESC_Id', 'DYN_Files', 'ATL_DYN', 'ATL_DYN_40_P25.mat')}, ...
    false);
```

- [`validate_models.m`](validate_models.m)
  - Repo convenience smoke test for the main ESC models.

```matlab
addpath(genpath('.'));
cd ESC_Id
validate_models
```

- [`NMC30/OCVNMC30fromROM.m`](NMC30/OCVNMC30fromROM.m)
  - Builds the NMC30 OCV model.
- [`NMC30/NMC30DynParIdROMsim.m`](NMC30/NMC30DynParIdROMsim.m)
  - Builds the NMC30 full ESC model from its special dynamic-identification path.
- [`ATL20/buildATLmodelOcv.m`](ATL20/buildATLmodelOcv.m)
  - Builds the legacy ATL OCV model with [`processOCV.m`](processOCV.m).
- [`ATL20/buildATL20modelOcv.m`](ATL20/buildATL20modelOcv.m)
  - Builds the ATL20 diagonal-average OCV model with [`DiagProcessOCV.m`](DiagProcessOCV.m).
- [`ATL20/buildATLmodel.m`](ATL20/buildATLmodel.m)
  - Builds the full ATL ESC model from `ATL_DYN` data and the legacy ATL OCV model.
- [`OMTLIFE8AHC-HP/OMTLIFEocv.m`](OMTLIFE8AHC-HP/OMTLIFEocv.m)
  - Builds the OMT8 OCV model.
- [`OMTLIFE8AHC-HP/OMTdynId.m`](OMTLIFE8AHC-HP/OMTdynId.m)
  - Builds the OMT8 full ESC model from its special single-profile dynamic-identification path.

## 5. Default behavior

- [`ESCvalidation.m`](ESCvalidation.m) defaults to a built-in model search order when `modelFile` is empty:
  - [`models/ATLmodel.mat`](../models/ATLmodel.mat)
  - [`ESC_Id/FullESCmodels/LFP/ATLmodel.mat`](FullESCmodels/LFP/ATLmodel.mat)
  - [`models/OMTLIFEmodel.mat`](../models/OMTLIFEmodel.mat)
  - `ESC_Id/OMTLIFE8AHC-HP/OMTLIFEmodel.mat`
- [`ESCvalidation.m`](ESCvalidation.m) defaults to [`Evaluation/OMTLIFE8AHC-HP/Bus_CoreBatteryData_Data.mat`](../Evaluation/OMTLIFE8AHC-HP/Bus_CoreBatteryData_Data.mat) when `data` is empty.
- [`ESCvalidation.m`](ESCvalidation.m) defaults `enabledPlot` to `true`.
- [`ESCvalidation.m`](ESCvalidation.m) assumes `+I = discharge` and will auto-flip current sign only when a SOC trace is available and indicates the sign is reversed.
- [`ESCvalidation.m`](ESCvalidation.m) uses a single scalar temperature in `simCell`; if the dataset contains a temperature trace, the median value is used.
- Legacy `DYNData.script1` validation uses `z0 = 1` by design for continuity with [`utility/DYN_eg/runProcessDynamic.m`](../utility/DYN_eg/runProcessDynamic.m).
- [`runESCvalidation.m`](runESCvalidation.m) disables plotting automatically when more than one job is run.

## 6. Inputs

- Required inputs for [`ESCvalidation.m`](ESCvalidation.m):
  - an ESC model file, a loaded model struct, or `[]` for default resolution
  - a dataset input, unless the default Bus Core Battery profile is intended
- Supported validation input formats in [`ESCvalidation.m`](ESCvalidation.m):
  - MAT-file path containing a measured profile
  - MAT-file path containing `dataset`
  - MAT-file path containing `DYNData`
  - struct with current/voltage fields
  - legacy struct array with `script1`
- Required model content:
  - ESC model struct with `QParam`, `RCParam`, `RParam`, `R0Param`, `MParam`, `M0Param`, `GParam`, and `etaParam`
- Optional inputs:
  - explicit temperature fields in the dataset
  - SOC trace for initial-SOC inference and current-sign correction
  - custom plot enable/disable flag

## 7. Datasets

- Keep source modeling data separate from code under `data/Modelling/`.
- Add OCV source data under `data/Modelling/OCV_Files/<CHEMISTRY>/`.
- Add reusable dynamic identification datasets under `data/Modelling/DYN_Files/<CHEMISTRY>_DYN/`.
- Save intermediate OCV model artifacts under `ESC_Id/OCV_models/`.
- Keep measured validation profiles in the owning application folder when that is the source of truth.
  - Current repo example: [`Evaluation/OMTLIFE8AHC-HP/Bus_CoreBatteryData_Data.mat`](../Evaluation/OMTLIFE8AHC-HP/Bus_CoreBatteryData_Data.mat)
- DYN naming convention used in this repo:
  - `<CHEMISTRY>_DYN_P25.mat`
  - `<CHEMISTRY>_DYN_N10.mat`
- Current examples:
  - [`data/Modelling/DYN_Files/ATL_DYN/ATL_DYN_40_P25.mat`](../data/Modelling/DYN_Files/ATL_DYN/ATL_DYN_40_P25.mat)
  - [`data/Modelling/OCV_Files/ATL20/ATL_OCV/ATL_OCV_P25.mat`](../data/Modelling/OCV_Files/ATL20/ATL_OCV/ATL_OCV_P25.mat)
  - [`ESC_Id/OCV_models/ATLmodel-ocv.mat`](OCV_models/ATLmodel-ocv.mat)
  - [`ESC_Id/OCV_models/ATL20model-ocv.mat`](OCV_models/ATL20model-ocv.mat)
- OCV patching for OMT8:
  - [`OMTLIFE8AHC-HP/OMTLIFEocv.m`](OMTLIFE8AHC-HP/OMTLIFEocv.m) is the current chemistry-specific OCV builder for OMT8.

## 8. How to run

- Standard run, NMC30:

```matlab
addpath(genpath('.'));
cd ESC_Id
NMC30.OCVNMC30fromROM
NMC30.NMC30DynParIdROMsim
```

- Standard run, OMT8:

```matlab
addpath(genpath('.'));
cd ESC_Id
OMTLIFE8AHC-HP.OMTLIFEocv
OMTLIFE8AHC-HP.OMTdynId
```

- Standard run, ATL legacy OCV plus full ESC:

```matlab
addpath(genpath('.'));
cd ESC_Id/ATL20
buildATLmodelOcv
buildATLmodel
```

- Standard run, ATL diagonal-average OCV:

```matlab
addpath(genpath('.'));
cd ESC_Id/ATL20
buildATL20modelOcv
```

- Validation run:

```matlab
addpath(genpath('.'));
results = ESCvalidation( ...
    fullfile('models', 'OMTLIFEmodel.mat'), ...
    fullfile('Evaluation', 'OMTLIFE8AHC-HP', 'Bus_CoreBatteryData_Data.mat'), ...
    true);
```

- Extended run:

```matlab
addpath(genpath('.'));
cd ESC_Id
validate_models
```

- Extended batch validation:

```matlab
addpath(genpath('.'));
jobs = struct( ...
    'modelFile', {fullfile('models', 'ATLmodel.mat'), fullfile('models', 'NMC30model.mat')}, ...
    'data', {fullfile('ESC_Id', 'DYN_Files', 'ATL_DYN', 'ATL_DYN_40_P25.mat'), ...
             fullfile('ESC_Id', 'DYN_Files', 'NMC30_DYN', 'NMC30_DYN_P25.mat')}, ...
    'enabledPlot', {false, false});
batch = runESCvalidation(jobs);
```

## 9. Validation tools

- OCV identification in this layer is a two-step workflow:
  - Step 1: a selected OCV estimator reconstructs a per-temperature `rawocv` curve, shown in plots as `Approximate OCV from data`.
  - Step 2: those per-temperature `rawocv` curves are used to fit the shared ESC temperature model `OCV(z,T) = OCV0(z) + T*OCVrel(z)`.
- Current OCV estimator entry points:
  - [`processOCV.m`](processOCV.m) for the legacy resistance-blend method
  - [`VavgProcessOCV.m`](VavgProcessOCV.m) for the voltage-average method
  - [`DiagProcessOCV.m`](DiagProcessOCV.m) for the diagonal-average method
- OCV-fit tools:
  - [`computeOcvModelMetrics.m`](computeOcvModelMetrics.m)
    - Computes OCV RMSE, mean error, MAE, and max-absolute error against raw OCV references.
  - [`plotOcvModelFit.m`](plotOcvModelFit.m)
    - Plots raw OCV references, charge/discharge traces, and fitted OCV curves.
- Dynamic-fit tools:
  - [`computeDynamicModelMetrics.m`](computeDynamicModelMetrics.m)
    - Computes dynamic-fit metrics by calling [`ESCvalidation.m`](ESCvalidation.m) on a full ESC model and dynamic dataset.
  - [`plotDynamicModelFit.m`](plotDynamicModelFit.m)
    - Plots dynamic-fit results by calling [`plotEscValidation.m`](plotEscValidation.m).
- [`ESCvalidation.m`](ESCvalidation.m)
  - Validates one model against one or more normalized cases and returns voltage RMSE, mean error, MAE, max-absolute error, and legacy 95% to 5% window RMSE.
- [`runESCvalidation.m`](runESCvalidation.m)
  - Runs multiple validation jobs and summarizes mean and max RMSE per job.
- [`validate_models.m`](validate_models.m)
  - Validates the repo's ATL, NMC30, and OMT8 ESC models.
- [`extract_results.m`](extract_results.m)
  - Reads saved validation results and prints a text summary.

Expected outputs:
- in-memory OCV validation struct from [`computeOcvModelMetrics.m`](computeOcvModelMetrics.m)
- in-memory dynamic-fit struct from [`computeDynamicModelMetrics.m`](computeDynamicModelMetrics.m)
- in-memory results struct from [`ESCvalidation.m`](ESCvalidation.m)
- in-memory batch struct from [`runESCvalidation.m`](runESCvalidation.m)
- [`ESC_Id/results/ESC_validation_results.mat`](results/ESC_validation_results.mat) when [`validate_models.m`](validate_models.m) is used
- chemistry-specific saved result files under `ESC_Id/results/` and `ESC_Id/results/OCV/`

## 10. Study / experiment tools

- [`runESCvalidation.m`](runESCvalidation.m)
  - Acts as the main multi-case comparison tool in this layer.
- [`extract_results.m`](extract_results.m)
  - Helps summarize saved validation runs for reporting.
- TODO: there is no dedicated ESC-only sweep runner in this layer beyond batch validation. Add one here if ESC model-comparison studies become a first-class workflow.

## 11. Plotting

- Plot dynamic-fit or ESC-validation results during validation by setting `enabledPlot = true` in [`ESCvalidation.m`](ESCvalidation.m).
- Re-plot saved dynamic-fit or ESC-validation results with [`plotEscValidation.m`](plotEscValidation.m).
- Plot OCV-fit results with [`plotOcvModelFit.m`](plotOcvModelFit.m).
- [`plotEscValidation.m`](plotEscValidation.m) is the dynamic-fit plotting function in this layer.

```matlab
addpath(genpath('.'));
cd ESC_Id
load(fullfile('results','ESC_validation_results.mat'));
plotEscValidation(result_nmc);
```

```matlab
validation = computeOcvModelMetrics( ...
    fullfile('ESC_Id','OCV_models','ATLmodel-ocv.mat'), ...
    fullfile('data','Modelling','OCV_Files','ATL20','ATL_OCV'), ...
    struct('data_prefix','ATL','cell_id','ATL','min_v',2.0,'max_v',3.75,'ocv_method','resistanceBlend'));
plotOcvModelFit(validation);
```

- Current plot content:
  - measured vs simulated voltage
  - current trace
  - voltage error trace
- Plot titles use normalized labels such as `NMC30 Dyn | RMSE xx.xx mV` and `OMT8 BSS | RMSE xx.xx mV`.

## 12. Results

- Intermediate OCV models are saved in `ESC_Id/OCV_models/`.
  - Example: [`ESC_Id/OCV_models/ATLmodel-ocv.mat`](OCV_models/ATLmodel-ocv.mat)
  - Example: [`ESC_Id/OCV_models/ATL20model-ocv.mat`](OCV_models/ATL20model-ocv.mat)
- Final ESC models are saved in `models/`, not in `ESC_Id/`, and these final `.mat` files should remain light parameter-only model files.
  - Example: [`models/NMC30model.mat`](../models/NMC30model.mat)
  - Example: [`models/ATLmodel.mat`](../models/ATLmodel.mat)
  - Example: [`models/OMTLIFEmodel.mat`](../models/OMTLIFEmodel.mat)
- OCV-fit and dynamic-fit validation artifacts belong in `ESC_Id/results/`, not in the final model files.
- Validation results saved by [`validate_models.m`](validate_models.m) go to:
  - [`ESC_Id/results/ESC_validation_results.mat`](results/ESC_validation_results.mat)
- ATL build example:
  - [`ESC_Id/ATL20/buildATLmodelOcv.m`](ATL20/buildATLmodelOcv.m) saves `ATLmodel-ocv.mat` plus `ocv_validation`
  - [`ESC_Id/ATL20/buildATLmodel.m`](ATL20/buildATLmodel.m) saves light [`models/ATLmodel.mat`](../models/ATLmodel.mat) plus [`ESC_Id/results/ATLmodel_identification_results.mat`](results/ATLmodel_identification_results.mat)
- Validation output format:
  - a top-level results struct with `cases`, `summary_table`, and `metrics`
- Result meaning:
  - OCV-fit metrics use method-specific `rawocv` reference minus fitted OCV prediction
  - `rawocv` is the per-temperature approximate OCV reconstructed by the chosen OCV method before fitting `OCV0` and `OCVrel`
  - OCV-fit metrics are method-relative, not absolute-truth-relative
  - RMSE values from different OCV estimators are therefore not directly comparable unless the models are re-evaluated against the same common reference
  - `voltage_rmse_mv` is the main whole-trace voltage-fit metric
  - `legacy_window_rmse_mv` preserves the older 95% to 5% OCV-window comparison
  - `voltage_mean_error_mv` is the bias term
  - `voltage_max_abs_error_mv` highlights worst-case excursion

## 13. Troubleshooting

- Warning: `Current may have wrong sign as SOC > 110%`
  - Usually means a legacy `script1` validation path is being used on a profile that does not start near full discharge-ready SOC.
- Error: missing required model fields
  - The loaded model is not a full ESC model usable by `simCell`.
- Unexpected temperature behavior
  - [`ESCvalidation.m`](ESCvalidation.m) uses one scalar temperature even if the source profile varies over time.
- Small temperature mismatch between validation data and a single-temperature model
  - [`utility/ESCmgmt/getParamESC.m`](../utility/ESCmgmt/getParamESC.m) includes a repo patch that allows a `1 degC` tolerance when the model contains only one temperature point. This is meant to avoid rejecting nearby cases such as `26 degC` data against a `25 degC` model.
- OMT8 mismatch between dynamic fit and validation route
  - [`OMTdynId.m`](OMTLIFE8AHC-HP/OMTdynId.m) is a special single-profile fitting path and should not be treated as a generic [`processDynamic.m`](processDynamic.m) case.
- TODO: MATLAB version and toolbox requirements are not explicit in code for every chemistry-specific script.

## 14. Related documentation

- Parent layer:
  - [`../README.md`](../README.md)
- Related layers:
  - [`../Evaluation/README.md`](../Evaluation/README.md)
  - [`../models/TunedModels/README.md`](../models/TunedModels/README.md)
- Related scripts:
  - [`DiagProcessOCV.m`](DiagProcessOCV.m)
  - [`processOCV.m`](processOCV.m)
  - [`computeOcvModelMetrics.m`](computeOcvModelMetrics.m)
  - [`plotOcvModelFit.m`](plotOcvModelFit.m)
  - [`processDynamic.m`](processDynamic.m)
  - [`computeDynamicModelMetrics.m`](computeDynamicModelMetrics.m)
  - [`plotDynamicModelFit.m`](plotDynamicModelFit.m)
  - [`ESCvalidation.m`](ESCvalidation.m)
  - [`plotEscValidation.m`](plotEscValidation.m)
