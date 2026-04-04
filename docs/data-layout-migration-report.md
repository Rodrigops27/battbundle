# Data Layout Migration Report

## Scope

This report records the flag-day migration from legacy in-repo dataset locations to the canonical lowercase `data/` registry.

Canonical roots:

- `data/evaluation/...`
- `data/modelling/...`
- `data/shared/...`

Released model artifacts remain in `models/`.

## Evaluation Migration

Automatically migrated nominal evaluation assets:

- `data/Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`
  -> `data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat`
- `data/Evaluation/ROMSimData/datasets/rom_bus_coreBattery_dataset.mat`
  -> `data/evaluation/processed/behavioral_nmc30_bss_v1/nominal/rom_bus_coreBattery_dataset.mat`
- `data/Evaluation/OMTLIFE8AHC-HP/Bus_CoreBatteryData_Data.mat`
  -> `data/evaluation/raw/omtlife8ahc_hp/Bus_CoreBatteryData_Data.mat`

Updated evaluation entry points:

- `Evaluation/runBenchmark.m`
- `Evaluation/mainEval.m`
- `Evaluation/ESCSimData/BSSsimESCdata.m`
- `Evaluation/ROMSimData/createBusCoreBatterySyntheticDataset.m`
- `Evaluation/Injection/runInjectionStudy.m`
- `Evaluation/Injection/defaultInjectionConfig.m`
- `Evaluation/initSOCs/sweepInitSocStudy.m`
- `Evaluation/NoiseTuningSweep/sweepNoiseStudy.m`
- `Evaluation/NoiseTuningSweep/oneEstSweeNoise.m`
- `autotuning/defaultAutotuningConfig.m`
- `autotuning/runAutotuning.m`

Eliminated evaluation path assumptions:

- `Evaluation/ESCSimData/datasets/...`
- `Evaluation/ROMSimData/datasets/...`
- `Evaluation/Injection/datasets/...`
- `data/Evaluation/...`

## Modelling Migration

Automatically migrated clearly classifiable modelling assets:

- `data/Modelling/DYN_Files/ATL_DYN/ATL_DYN_40_P25.mat`
  -> `data/modelling/processed/dynamic/atl20/ATL_DYN_40_P25.mat`
- `data/Modelling/DYN_Files/NMC30_DYN/NMC30_DYN_P25.mat`
  -> `data/modelling/processed/dynamic/nmc30/NMC30_DYN_P25.mat`
- `data/Modelling/OCV_Files/ATL20/ATL_OCV/*.mat`
  -> `data/modelling/processed/ocv/atl20/*.mat`
- `data/Modelling/OCV_Files/OMTLIFE8AHC-HP/LFP_OCV_interp*.mat`
  -> `data/modelling/interim/ocv/omtlife8ahc_hp/*.mat`
- `data/Modelling/OCV_Files/OMTLIFE8AHC-HP/OMTLIFEmodel-ocv-diag.mat`
  -> `data/modelling/derived/ocv_models/omtlife8ahc_hp/OMTLIFEmodel-ocv-diag.mat`
- `ESC_Id/OCV_models/*.mat`
  -> `data/modelling/derived/ocv_models/...`
- `ESC_Id/NMC30/ROMSimData/datasets/rom_script1_dataset.mat`
  -> `data/modelling/synthetic/nmc30/romsim/rom_script1_dataset.mat`

Updated modelling entry points:

- `ocv_id/runOcvIdentification.m`
- `ESC_Id/runDynamicIdentification.m`
- `ESC_Id/ESCvalidation.m`
- `ESC_Id/validate_models.m`
- `ocv_id/ATL20/buildATL20modelOcv.m`
- `ESC_Id/ATL20/buildATLmodel.m`
- `ocv_id/ATL20/buildATLmodelOcv.m`
- `ocv_id/NMC30/OCVNMC30fromROM.m`
- `ESC_Id/NMC30/NMC30DynParIdROMsim.m`
- `ESC_Id/NMC30/ROMsimDynData.m`
- `ocv_id/OMTLIFE8AHC-HP/OMTLIFEocv.m`
- `ESC_Id/OMTLIFE8AHC-HP/OMTdynId.m`
- `models/TunedModels/retuningROMVal.m`

Eliminated modelling path assumptions:

- `ESC_Id/DYN_Files/...`
- `ESC_Id/OCV_Files/...`
- `data/Modelling/...`

## `ESC_Id/results/*` Classification Decisions

Each current entry was classified before migration.

| Source path | Classification | Decision | Target / rationale |
| --- | --- | --- | --- |
| `ESC_Id/results/ATL20_ocv_identification_results.mat` | reusable modelling artifact | migrated copy | `data/modelling/derived/identification_results/atl20/ATL20_ocv_identification_results.mat` because it is a structured OCV identification output |
| `ESC_Id/results/ATL20model_P25_identification_results.mat` | reusable modelling artifact | migrated copy | `data/modelling/derived/identification_results/atl20/ATL20model_P25_identification_results.mat` because it is a structured dynamic identification output |
| `ESC_Id/results/ESC_validation_results.mat` | reusable modelling artifact | migrated copy | `data/modelling/derived/validation_results/esc/ESC_validation_results.mat` because it is a structured validation output that can be consumed programmatically |
| `ESC_Id/results/.gitignore` | repository control file | left outside `data/` | not a data artifact |

## Nominal Manifest Scaffolding

Added nominal manifest scaffolds for the current processed suites:

- `data/evaluation/derived/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset/manifest.json`
- `data/evaluation/derived/behavioral_nmc30_bss_v1/nominal/rom_bus_coreBattery_dataset/manifest.json`

## Temporary Staging And Follow-Up Items

The rename staging directories created during the migration are not canonical data roots and are not supported by the new resolvers:

- `data/__Evaluation_legacy_tmp/`
- `data/__Modelling_legacy_tmp/`

These directories remain only as migration staging/inventory until the remaining non-canonical contents are either removed or reclassified.

Ambiguous follow-up items intentionally not auto-migrated:

- residual user-facing markdown in `results/` that documents past experiments rather than canonical runtime configuration
- legacy fallback model locations under `ESC_Id/FullESCmodels/`
- any non-runtime helper still operating on user-managed local copies outside `data/`

## Clear Failure Policy

Canonical resolvers now fail explicitly when callers point at known legacy dataset roots.

- benchmark/runtime evaluation reads reject legacy benchmark dataset roots
- builder/conversion evaluation reads allow `data/evaluation/raw/...` only
- modelling reads/writes reject legacy `ESC_Id/DYN_Files/...`, `ESC_Id/OCV_Files/...`, and `ESC_Id/OCV_models/...`

## Output And Ignore Changes

The repository now distinguishes trackable summary artifacts from heavy local-only evaluation and autotuning outputs.

- summary artifacts are documented to live under `results/evaluation/...`, `results/autotuning/...`, and `results/figures/...`
- heavy evaluation MAT outputs remain local in workflow-specific output folders
- heavy autotuning MAT outputs remain local in `autotuning/results/...`
- `.gitignore` now ignores heavy benchmark-result MAT files, study-detail MAT files, checkpoint MAT files, and best-benchmark MAT files by default
