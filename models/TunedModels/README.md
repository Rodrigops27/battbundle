# TunedModels

Direct usage guide for the ROM retuning and ROM validation workflow in `models/TunedModels/`.

## What this folder does

This folder contains the scripts used to:
- build retuned ROM models from existing ESC models
- validate those ROMs against the source ESC models
- re-plot saved ROM validation results

Current entry points:
- `retuningROM.m`
- `build_rom_models.m`
- `retuningROMVal.m`
- `validate_rom_models.m`
- `plotRomValidation.m`
- `extract_rom_results.m`

## Quick start

From the repository root in MATLAB:

```matlab
addpath(genpath('.'));
cd models/TunedModels
```

## Build retuned ROM models

Batch build the repo's current ROM variants:

```matlab
build_rom_models
```

What it creates:
- `models/ROM_OMT8_beta.mat`
- `models/ROM_ATL20_beta.mat`

What it uses:
- base ROM: `models/ROM_NMC30_HRA.mat`
- ESC source models:
  - `models/OMTLIFEmodel.mat`
  - `models/ATLmodel.mat`

## Build one ROM manually

Default single-ROM build:

```matlab
ROM = retuningROM;
```

Custom build:

```matlab
cfg = struct();
cfg.base_rom_file = fullfile('models', 'ROM_NMC30_HRA.mat');
cfg.esc_model_file = fullfile('models', 'OMTLIFEmodel.mat');
cfg.tc = 25;

ROM = retuningROM(fullfile('models', 'ROM_OMT8_beta.mat'), cfg);
```

Defaults in `retuningROM.m`:
- output file: `models/ROM_ATL20_beta.mat`
- base ROM: `models/ROM_NMC30_HRA.mat`
- ESC source model: `models/ATLmodel.mat`
- temperature: `25 degC`

## Validate ROM models

Batch validation for the repo's current ROM set:

```matlab
validate_rom_models
```

What it validates:
- `models/ROM_OMT8_beta.mat` against `models/OMTLIFEmodel.mat`
- `models/ROM_ATL20_beta.mat` against `models/ATLmodel.mat`

Saved output:
- `models/TunedModels/ROM_validation_results.mat`

## Validate one ROM manually

```matlab
cfg = struct();
cfg.rom_file = fullfile('models', 'ROM_ATL20_beta.mat');
cfg.esc_model_file = fullfile('models', 'ATLmodel.mat');
cfg.tc = 25;
cfg.ts = [];
cfg.soc_init = 100;
cfg.show_plots = true;

validation = retuningROMVal(cfg);
```

Useful `retuningROMVal.m` options:
- `rom_file`
- `esc_model_file`
- `tc`
- `ts`
- `soc_init`
- `show_plots`
- `dyn_file`

Important default behavior:
- if `ts` is empty, the ROM native sample time is used
- if `dyn_file` is not provided, the script tries to use a chemistry-matched DYN `script1` profile from `ESC_Id/DYN_Files/...`
- if no matching DYN file is found, it falls back to the synthetic script-1 profile from `utility/profiles/buildScript1NormalizedProfile.m`

## Plot results anytime

Plot after a fresh validation:

```matlab
plotRomValidation(validation)
```

Plot saved batch results later:

```matlab
load('ROM_validation_results.mat');
plotRomValidation(result_omt);
plotRomValidation(result_atl);
```

The plotting function creates:
- a current and SOC figure
- a voltage and voltage-error figure

Plot titles are normalized to the form:
- `NMC30 Dyn | RMSE xx.xx mV`
- `OMT8 BSS | RMSE xx.xx mV`

## Extract text summaries

```matlab
extract_rom_results
```

This reads `ROM_validation_results.mat` and prints a compact text summary of the saved metrics.

## Files and outputs

Inputs expected by this folder:
- ESC models in `models/`
- base ROMs in `models/`
- optional DYN validation profiles in `ESC_Id/DYN_Files/...`

Outputs produced by this folder:
- retuned ROM `.mat` files in `models/`
- `ROM_validation_results.mat` in `models/TunedModels/`

## Related docs

- `results/ROMvalidation.md`
- `ESC_Id/README.md`
- `Evaluation/README.md`
