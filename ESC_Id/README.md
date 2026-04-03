# ESC_Id

This layer builds ESC models from modelling datasets and validates those models before estimator benchmarking.

## Modelling Policy

Canonical modelling reads and writes must resolve under:

- `data/modelling/raw`
- `data/modelling/interim`
- `data/modelling/processed`
- `data/modelling/synthetic`
- `data/modelling/derived`


## Lifecycle Mapping

- raw:
  immutable source OCV or lab files
- interim:
  cleaned or partially processed preparation assets
- processed:
  canonical modelling-ready OCV and dynamic datasets
- synthetic:
  generated modelling datasets
- derived:
  reusable OCV models, identification results, validation results, and similar reusable artifacts

## Main Entry Points

- `runOcvIdentification.m`
- `runDynamicIdentification.m`
- `ESCvalidation.m`
- `compareEscModels.m`
- `compareOcvModels.m`
- `runESCvalidation.m`
- `validate_models.m`
- `ATL20/buildATL20modelOcv.m`
- `ATL20/buildATLmodel.m`
- `NMC30/OCVNMC30fromROM.m`
- `NMC30/NMC30DynParIdROMsim.m`
- `OMTLIFE8AHC-HP/OMTLIFEocv.m`
- `OMTLIFE8AHC-HP/OMTdynId.m`

## OCV Preprocessing

All OCV engines in `ESC_Id` now start from the same preprocessing step:

- extract the slow discharge and slow charge branches from `script1` and `script3`
- normalize them to SOC using the 25 degC reference capacity
- apply `smoothdiff.m` to both branches before any OCV estimator is run

This shared preprocessing is implemented in `prepareOcvBranches.m` and is
used by:

- `processOCV.m`
- `VavgProcessOCV.m`
- `SOCavgOCV.m`
- `DiagProcessOCV.m`

The same smoothed-branch convention is also used when building OCV-reference
curves inside `computeOcvModelMetrics.m`.

TODO:
The current ESC OCV temperature regression still uses the legacy linear form
`OCV(SOC,T) = OCV0(SOC) + T*OCVrel(SOC)`. This may require a better
expression, preferably using Kelvin to avoid sign handling and to make the
reference temperature explicit, for example:
`OCV(SOC,T) = OCV(SOC) + (T - 298.15)*dOCV/dT(SOC)`.

## Canonical Inputs And Outputs

Examples:

- ATL20 processed OCV data:
  `data/modelling/processed/ocv/atl20`
- ATL20 processed dynamic data:
  `data/modelling/processed/dynamic/atl20/ATL_DYN_40_P25.mat`
- NMC30 processed dynamic data:
  `data/modelling/processed/dynamic/nmc30/NMC30_DYN_P25.mat`
- OMTLIFE raw validation profile:
  `data/evaluation/raw/omtlife8ahc_hp/Bus_CoreBatteryData_Data.mat`
- reusable OCV models:
  `data/modelling/derived/ocv_models/...`
- reusable identification results:
  `data/modelling/derived/identification_results/...`
  OCV-identification detail artifacts saved here are method-relative, not absolute-truth-relative, so their metrics are not directly comparable across methods.
- reusable validation results:
  `data/modelling/derived/validation_results/...`

## Example OCV Identification

`runOcvIdentification.m` supports these OCV engines:

- `voltageAverage`
- `socAverage`
- `middleCurve`
- `diagAverage`
- `resistanceBlend`

Regardless of engine choice, `smoothdiff.m` preprocessing is applied first to
the input OCV branches.

By default, `runOcvIdentification.m` evaluates the fitted model against a
common OCV reference built with `middleCurve` on each dataset temperature.
That reference is reconstructed directly from each temperature dataset and
does not use the candidate model's `OCV0/OCVrel` regression. Override this
with `cfg.reference_ocv_method` only when you explicitly want a different
reference builder.

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.run_name = 'ATL20 OCV identification';
cfg.ocv_data_input = fullfile('data', 'modelling', 'processed', 'ocv', 'atl20');
cfg.data_prefix = 'ATL';
cfg.cell_id = 'ATL20';
cfg.engine = 'voltageAverage';
cfg.temperature_scope = 'single';
cfg.desired_temperature = 25;
cfg.reference_ocv_method = 'middleCurve';
cfg.output.model_output_file = fullfile('data', 'modelling', 'derived', 'ocv_models', 'atl20', 'ATL20model-ocv-vavgFT.mat');
results = runOcvIdentification(cfg);
```

For the standard study flow, run `ESC_Id/stdy/runOcvModellingInspection.m`.
By default it evaluates the processed ATL20 OCV folder
`data/modelling/processed/ocv/atl20`, uses `middleCurve` as the common
metrics reference, computes all methods including the three
`DiagProcessOCV` variants, and opens one figure per temperature through
`ESC_Id/stdy/inspectOcvModelling.m`.

Those figures overlay the raw discharge/charge branches, the shared metrics
reference OCV, and the enabled model curves. By default the three diagonal
methods are still computed so their metrics remain available, but their
curves are hidden from the plots unless `cfg.plot_diag_methods = true`.

## Modelling Workflow

Use this workflow when building ESC models in `ESC_Id`:

1. Prepare or select the processed OCV laboratory dataset under `data/modelling/processed/ocv/...`.
2. Run `ESC_Id/stdy/runOcvModellingInspection.m` to batch-identify the OCV methods and launch `ESC_Id/stdy/inspectOcvModelling.m` for visual comparison across the available temperatures.
3. Choose the OCV estimator you want to carry forward: `resistanceBlend`, `voltageAverage`, `socAverage`, `middleCurve`, or `diagAverage` with one of `useDis`, `useChg`, or `useAvg`.
4. Build the OCV model with `runOcvIdentification.m` using the selected engine and temperature scope.
5. Review the identified OCV model visually and check the OCV-fit metrics before freezing that model for dynamic identification.
   By default those metrics are measured against the per-temperature `middleCurve` reconstruction, used as a common reference across OCV engines.
6. Prepare or select the processed dynamic-identification datasets under `data/modelling/processed/dynamic/...`.
7. Run `runDynamicIdentification.m` with the selected OCV model, the desired dynamic datasets, the pole count, and hysteresis setting to execute the `processDynamic` stage.
8. Review the resulting ESC model and the dynamic-fit metrics produced by `runDynamicIdentification.m`.
9. Validate the ESC model with `ESCvalidation.m`, `runESCvalidation.m`, or `compareEscModels.m` on the intended validation scenarios.
10. If multiple ESC candidates remain, compare them on common dynamic datasets and retain the model that best matches the intended operating conditions.

## Example Dynamic Identification

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.run_name = 'ATL20 P25 ESC identification';
cfg.ocv_model_input = fullfile('data', 'modelling', 'derived', 'ocv_models', 'atl20', 'ATL20model-ocv-vavgFT.mat');
cfg.dynamic_input = fullfile('data', 'modelling', 'processed', 'dynamic', 'atl20');
cfg.desired_temperature = 25;
cfg.numpoles = 2;
cfg.do_hysteresis = true;
cfg.output.model_output_file = fullfile('models', 'ATL20model_P25.mat');
cfg.output.results_file = fullfile('data', 'modelling', 'derived', 'identification_results', 'atl20', 'ATL20model_P25_identification_results.mat');
results = runDynamicIdentification(cfg);
```

## Example Validation

`ESCvalidation.m` accepts either:

- a canonical normalized dataset or measured-profile struct with fields such as `current_a`, `voltage_v`, and `time_s`
- a legacy `DYNData` file, in which case validation still uses `script1`

```matlab
addpath(genpath('.'));

results = ESCvalidation( ...
    fullfile('models', 'ATL20model_P25.mat'), ...
    fullfile('data', 'modelling', 'processed', 'dynamic', 'atl20', 'ATL_DYN_40_P25.mat'), ...
    true);
```

`legacy_window_rmse_mv` is a secondary ESC validation metric computed only on
the legacy 95%-to-5%-SOC voltage window used by older dynamic-validation
scripts. It is not the full-trace RMSE, and it appears in the validation
summary as `Legacy window RMSE`.

## Example Two-Model Comparison

`compareEscModels.m` compares two ESC models on the same dataset, returns both
validation result structs plus aggregate comparison tables, and can generate a
comparison figure.

To test `models/ATL20model_P25.mat` against `models/ATLmodel.mat` on
`data/modelling/processed/dynamic/atl20/ATL_DYN_50_P45.mat`:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.enabled_plot = true;

comparison = compareEscModels( ...
    fullfile('models', 'ATL20model_P25.mat'), ...
    fullfile('models', 'ATLmodel.mat'), ...
    fullfile('data', 'modelling', 'processed', 'dynamic', 'atl20', 'ATL_DYN_50_P45.mat'), ...
    cfg);

disp(comparison.case_summary_table);
disp(comparison.model_summary_table);
```

## Example OCV Comparison

`compareOcvModels.m` is the direct visual OCV comparator for two model files
against raw OCV test data at one temperature. It plots the raw discharge and
charge traces and both model OCV curves. It does not construct or rely on a
"true" OCV reference, so this comparison is visual rather than a fit-metric
validation.

To compare `models/ATL20model_P25.mat` against `models/ATLmodel.mat` at
25 degC using `data/modelling/processed/ocv/atl20/ATL_OCV_P25.mat`:

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.enabled_plot = true;
cfg.data_prefix = 'ATL';

comparison = compareOcvModels( ...
    fullfile('models', 'ATL20model_P25.mat'), ...
    fullfile('models', 'ATLmodel.mat'), ...
    fullfile('data', 'modelling', 'processed', 'ocv', 'atl20', 'ATL_OCV_P25.mat'), ...
    25, ...
    cfg);
```

## `ESC_Id/results` Classification

`ESC_Id/results/*` is no longer treated as a blanket data location.

- reusable modelling artifacts were copied into `data/modelling/derived/...`
- reporting summaries, figures, and helper scripts remain outside `data/`
- each decision is documented in `docs/data-layout-migration-report.md`

## Notes

- Released models belong in `models/`.
- Generated OCV-fit artifacts used during ESC modelling belong under `data/modelling/derived/ocv_models/...`.
- Those generated OCV-fit artifacts are not intended to be committed directly to Git; they should be distributed through the repository's data-artifact mechanism.
- `ESC_Id/FullESCmodels/` remains a legacy model fallback location for some scripts, but it is not part of the canonical `data/` registry.
- For the detailed migration record, see `docs/data-layout-migration-report.md`.
