# ESC Model Validation

## Brief description of the scenario

This result summarizes the latest ESC-model validation run from `ESC_Id/validate_models.m`. The scenario compares the repo's main ESC models against their current validation datasets using voltage RMSE as the primary score.

Scope of this summary:
- `ATLmodel.mat`
- `NMC30model.mat`
- `OMTLIFEmodel.mat`

Primary harness:
- `ESC_Id/ESCvalidation.m`
- `ESC_Id/validate_models.m`

## Results

### Summary table

| Model | Dataset | Temperature | RMSE (mV) | Mean Error (mV) | MAE (mV) | Max Error (mV) | Samples |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| ATL | `ESC_Id/DYN_Files/ATL_DYN/ATL_DYN_40_P25.mat` | 25.0 C | 24.97 | -11.18 | 19.90 | 175.26 | 35560 |
| ATL20 OCV Vavg | `data/Modelling/OCV_Files/ATL20/ATL_OCV` | multi-temp OCV fit | 22.07 | -7.08 | - | - | - |
| NMC30 | `ESC_Id/DYN_Files/NMC30_DYN/NMC30_DYN_P25.mat` | 25.0 C | 12.39 | -9.95 | 9.95 | 49.88 | 8250 |
| OMT8 | `Evaluation/OMTLIFE8AHC-HP/Bus_CoreBatteryData_Data.mat` or 90-10 dynamic profile OMT8 validation dataset route | 25.0 C | 6.94 | 1.08 | 5.39 | 27.09 | 576001 |

### Ranking by RMSE

| Rank | Model | RMSE (mV) |
| --- | --- | ---: |
| 1 | OMT8 | 6.94 |
| 2 | NMC30 | 12.39 |
| 3 | ATL20 OCV Vavg | 22.07 |
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
load('ESC_validation_results.mat');
plotEscValidation(result_atl);
plotEscValidation(result_nmc);
plotEscValidation(result_omt);
```
