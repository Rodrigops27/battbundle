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
- `runESCvalidation.m`
- `validate_models.m`
- `ATL20/buildATL20modelOcv.m`
- `ATL20/buildATLmodel.m`
- `NMC30/OCVNMC30fromROM.m`
- `NMC30/NMC30DynParIdROMsim.m`
- `OMTLIFE8AHC-HP/OMTLIFEocv.m`
- `OMTLIFE8AHC-HP/OMTdynId.m`

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
cfg.output.model_output_file = fullfile('data', 'modelling', 'derived', 'ocv_models', 'atl20', 'ATL20model-ocv-vavgFT.mat');
results = runOcvIdentification(cfg);
```

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
