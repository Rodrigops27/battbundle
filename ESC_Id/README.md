# ESC_Id

This layer owns ESC-specific dynamic identification, ESC validation, and
ESC-model comparison. Generic OCV modelling no longer lives here; it was
promoted into the top-level [`ocv_id`](../ocv_id/README.md) layer so it can
be reused by multiple battery-model families.

## Scope

`ESC_Id` owns:

- ESC dynamic identification from an input OCV model
- ESC validation against dynamic datasets or processed evaluation datasets
- ESC-model comparison on common validation scenarios
- chemistry-specific ESC dynamic wrappers

`ESC_Id` does not own:

- OCV preprocessing
- OCV identification engines
- OCV-fit metrics
- OCV method inspection studies
- OCV-only comparison utilities

Those now live in `ocv_id/`.

## Main Entry Points

- `runDynamicIdentification.m`
- `ESCvalidation.m`
- `compareEscModels.m`
- `runESCvalidation.m`
- `validate_models.m`
- `ATL20/buildATLmodel.m`
- `NMC30/NMC30DynParIdROMsim.m`
- `OMTLIFE8AHC-HP/OMTdynId.m`

## Canonical Inputs And Outputs

Canonical modelling reads and writes still resolve under:

- `data/modelling/raw`
- `data/modelling/interim`
- `data/modelling/processed`
- `data/modelling/synthetic`
- `data/modelling/derived`

Examples:

- reusable OCV model inputs from `ocv_id`:
  `data/modelling/derived/ocv_models/...`
- processed dynamic-identification inputs:
  `data/modelling/processed/dynamic/...`
- reusable dynamic-identification results:
  `data/modelling/derived/identification_results/...`
- reusable ESC validation results:
  `data/modelling/derived/validation_results/...`

## ESC Workflow

Use this workflow when building and validating ESC models:

1. Build or select an OCV model artifact in `ocv_id`.
2. Prepare or select the processed dynamic-identification datasets under `data/modelling/processed/dynamic/...`.
3. Run `runDynamicIdentification.m` with the OCV model, the desired dynamic datasets, the pole count, and the hysteresis setting.
4. Review the resulting ESC model and the dynamic-fit metrics.
5. Validate the ESC model with `ESCvalidation.m`, `runESCvalidation.m`, or `compareEscModels.m`.
6. If multiple ESC candidates remain, compare them on common datasets and retain the model that best matches the intended operating conditions.

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

## Notes

- Generic OCV modelling moved to `ocv_id/`.
- `ESC_Id/results/*` is no longer treated as a blanket data location.
- Released full ESC models belong in `models/`.
- `ESC_Id/FullESCmodels/` remains a legacy model fallback location for some scripts, but it is not part of the canonical `data/` registry.
