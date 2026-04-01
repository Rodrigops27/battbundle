# ESC Model Validation

## Brief description of the scenario

This result summarizes the latest ESC-model validation run from `ESC_Id/validate_models.m`. The scenario compares the repo's main ESC models against their current validation datasets using voltage RMSE as the primary score.

Scope of this summary:
- `ATLmodel.mat`
- `NMC30model.mat`
- `OMTLIFEmodel.mat`
- `ATL20model_P25.mat`

Primary harness:
- `ESC_Id/ESCvalidation.m`
- `ESC_Id/validate_models.m`

## Results

### Summary table

| Model | Dataset | Temperature | RMSE (mV) | Mean Error (mV) | MAE (mV) | Max Error (mV) | Samples |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| ATL | `data/modelling/processed/dynamic/atl20/ATL_DYN_40_P25.mat` | 25.0 C | 24.97 | -11.18 | 19.90 | 175.26 | 35560 |
| ATL20model_P25 | `data/modelling/processed/ocv/atl20` | multi-temp OCV fit | 22.07 | -7.08 | - | - | - |
| NMC30 | `data/modelling/processed/dynamic/nmc30/NMC30_DYN_P25.mat` | 25.0 C | 12.39 | -9.95 | 9.95 | 49.88 | 8250 |
| OMT8 | `data/evaluation/raw/omtlife8ahc_hp/Bus_CoreBatteryData_Data.mat` or the canonical OMT8 validation route | 25.0 C | 6.94 | 1.08 | 5.39 | 27.09 | 576001 |

### Ranking by RMSE

| Rank | Model | RMSE (mV) |
| --- | --- | ---: |
| 1 | OMT8 | 6.94 |
| 2 | NMC30 | 12.39 |
| 3 | ATL20model_P25 | 22.07 |
| 4 | ATL | 24.97 |

## Observations

- NMC30 is materially better than ATL on its current validation profile.
- ATL and NMC30 both show negative mean voltage error, which indicates systematic overestimation of terminal voltage on these runs.
- OMT8 was fitted with a BSS profile 55% to 90% SOC profile. It has the smallest bias and the lowest max error in the current summary.
- This file is a result summary only. Detailed harness behavior, accepted dataset shapes, and metric definitions belong in `ESC_Id/README.md`.

## How to regenerate them

Run the ESC validation harness from the repository root:

```matlab
addpath(genpath('.'));
cd ESC_Id
validate_models
```

Optional follow-up:

```matlab
cd ESC_Id
load(fullfile('..', 'data', 'modelling', 'derived', 'validation_results', 'esc', 'ESC_validation_results.mat'));
plotEscValidation(result_atl);
plotEscValidation(result_nmc);
plotEscValidation(result_omt);
```

<!-- BEGIN GENERATED ATL20 P25 APP VALIDATION -->
## ATL20 P25 Application Dataset

This generated section summarizes the latest ATL20 P25 ESC-model validation on the canonical desktop ATL20 ESC evaluation dataset.

- ESC model: `models/ATL20model_P25.mat`
- dataset: `data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat`
- saved validation MAT: `data/modelling/derived/validation_results/esc/ATL20model_P25_desktop_atl20_bss_v1_validation.mat`
- generated: `2026-03-31 16:39:35`
- cases: `1`

### Aggregate Metrics

- mean RMSE: `0 mV`
- mean error: `0 mV`
- mean MAE: `0 mV`
- mean max abs error: `0 mV`
- worst-case RMSE: `0 mV`

### Case Summary

| case_name | source_type | source_file | tc_degC | samples | voltage_rmse_mv | legacy_window_rmse_mv | voltage_mean_error_mv | voltage_max_abs_error_mv |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| esc_bus_coreBattery_dataset.mat | normalized_dataset | Bus_CoreBatteryData_Data.mat | 25 | 576001 | 0 | 0 | 0 | 0 |

### Per-Case Detailed Metrics

| case_name | source_file | temperature_degC | samples | voltage_rmse_mv | voltage_mean_error_mv | voltage_mae_mv | voltage_max_abs_error_mv | voltage_corr | fit_slope | fit_intercept |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| esc_bus_coreBattery_dataset.mat | Bus_CoreBatteryData_Data.mat | 25 | 576001 | 0 | 0 | 0 | 0 | 1 | 1 | 4.08367e-16 |
