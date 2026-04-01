# Tuned ROM Models

This folder contains released tuned ROM model artifacts and ROM-specific validation helpers.

Released model files remain in `models/` and are not moved into `data/`.

## Purpose

Use this folder when you want to:

- build retuned ROM models from existing ESC models
- validate ROM models against their source ESC models
- re-plot saved ROM validation results later

Current entry points:

- [`retuningROM.m`](retuningROM.m)
- [`build_rom_models.m`](build_rom_models.m)
- [`retuningROMVal.m`](retuningROMVal.m)
- [`validate_rom_models.m`](validate_rom_models.m)
- [`plotRomValidation.m`](plotRomValidation.m)
- [`extract_rom_results.m`](extract_rom_results.m)

## Quick Start

From the repository root in MATLAB:

```matlab
addpath(genpath('.'));
cd models/TunedModels
```

Batch build the repo's ROM variants:

```matlab
build_rom_models
```

Batch validate the repo's ROM set:

```matlab
validate_rom_models
```

## Build One ROM Manually

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

## Validate One ROM Manually

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

## Custom Settings

Useful [`retuningROMVal.m`](retuningROMVal.m) options:

- `rom_file`
- `esc_model_file`
- `tc`
- `ts`
- `soc_init`
- `show_plots`
- `dyn_file`

Where a ROM validation helper needs a DYN validation profile, it now resolves canonical modelling inputs under:

- `data/modelling/processed/dynamic/...`

Examples:

- `data/modelling/processed/dynamic/atl20/ATL_DYN_40_P25.mat`
- `data/modelling/processed/dynamic/nmc30/NMC30_DYN_P25.mat`

To force a specific validation profile:

```matlab
cfg = struct();
cfg.rom_file = fullfile('models', 'ROM_ATL20_beta.mat');
cfg.esc_model_file = fullfile('models', 'ATLmodel.mat');
cfg.dyn_file = fullfile('data', 'modelling', 'processed', 'dynamic', 'atl20', 'ATL_DYN_40_P25.mat');

validation = retuningROMVal(cfg);
```

If `dyn_file` is not provided, `retuningROMVal.m` tries to use a chemistry-matched canonical DYN `script1` profile. If no matching canonical DYN file is found, it falls back to the synthetic script-1 profile from [`utility/profiles/buildScript1NormalizedProfile.m`](../../utility/profiles/buildScript1NormalizedProfile.m).

## Plot Results Anytime

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

## Files and Outputs

Inputs expected by this folder:

- ESC models in `models/`
- base ROMs in `models/`
- optional DYN validation profiles in `data/modelling/processed/dynamic/...`

Outputs produced by this folder:

- retuned ROM `.mat` files in `models/`
- `ROM_validation_results.mat` in `models/TunedModels/`

## Notes

- Legacy assumptions about `ESC_Id/DYN_Files/...` are intentionally unsupported after the data-layout refactor.
- This folder does not define any parallel execution layer of its own.
