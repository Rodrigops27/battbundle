# ROM Model Validation

## Brief description of the scenario

This result summarizes the ROM validation run from `models/TunedModels/validate_rom_models.m`. The scenario compares each retuned ROM against its source ESC model over the selected validation profile, using voltage RMSE as the primary metric and SOC RMSE as a secondary check.

Validated ROMs:
- `ROM_OMT8_beta.mat` against `OMTLIFEmodel.mat`
- `ROM_ATL20_beta.mat` against `ATLmodel.mat`

Primary harness:
- `models/TunedModels/retuningROMVal.m`
- `models/TunedModels/validate_rom_models.m`

## Results (tables)

### Summary table

| ROM model | Source ESC model | Voltage RMSE (mV) | Voltage ME (mV) | Voltage Max Abs (mV) | SOC RMSE (%) | Correlation | Fit Slope |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `ROM_OMT8_beta.mat` | `OMTLIFEmodel.mat` | 81.57 | -74.75 | 144.99 | 40.46 | 0.9566 | 0.2953 |
| `ROM_ATL20_beta.mat` | `ATLmodel.mat` | 101.67 | -91.41 | 229.45 | 19.76 | 0.9586 | 0.6774 |

### Auxiliary run information

| ROM model | Capacity (Ah) | Samples | Current range |
| --- | ---: | ---: | --- |
| `ROM_OMT8_beta.mat` | 8.000 | 8250 | 0 to 12 A |
| `ROM_ATL20_beta.mat` | 19.183 | 8250 | 0 to 28.774 A |

## Observations

- Both retuned ROMs preserve voltage trend correlation reasonably well, but absolute voltage accuracy is materially worse than the ESC validation results.
- `ROM_OMT8_beta.mat` has lower voltage RMSE than `ROM_ATL20_beta.mat`, but much worse SOC RMSE.
- `ROM_ATL20_beta.mat` tracks SOC better than `ROM_OMT8_beta.mat`, although both still show large systematic voltage underestimation.
- The current retuning flow changes OCV behavior, not the underlying base-ROM dynamics; that likely explains why chemistry transfer is only partial.
- This file is a result summary only. Detailed ROM workflow usage belongs in `models/README.md`.

## How to regenerate them

Run the ROM validation harness from the repository root:

```matlab
addpath(genpath('.'));
cd models/TunedModels
validate_rom_models
```

Optional follow-up:

```matlab
cd models/TunedModels
load('ROM_validation_results.mat');
plotRomValidation(result_omt);
plotRomValidation(result_atl);
```
