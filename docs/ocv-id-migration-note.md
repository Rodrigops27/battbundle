# OCV Layer Migration Note

## Summary

Generic OCV modelling was promoted out of `ESC_Id/` into a new top-level
layer: `ocv_id/`.

The intent is to make OCV handling reusable across multiple battery-model
families instead of coupling it to ESC-specific dynamic identification.

## What Moved

Moved from `ESC_Id/` to `ocv_id/`:

- `runOcvIdentification.m`
- OCV preprocessing helpers such as `prepareOcvBranches.m`, `smoothdiff.m`, and `linearinterp.m`
- OCV engines such as `processOCV.m`, `VavgProcessOCV.m`, `SOCavgOCV.m`, `middleOCV.m`, and `DiagProcessOCV.m`
- OCV-fit metrics and comparison utilities such as `computeOcvModelMetrics.m`, `compareOcvModels.m`, and `plotOcvModelFit.m`
- OCV study scripts under `stdy/`
- chemistry-specific OCV wrappers under `ATL20/`, `NMC30/`, and `OMTLIFE8AHC-HP/`

## What Stays In `ESC_Id`

`ESC_Id/` now keeps only ESC-specific responsibilities:

- `runDynamicIdentification.m`
- `processDynamic.m`
- `computeDynamicModelMetrics.m`
- `ESCvalidation.m`
- `compareEscModels.m`
- ESC-specific chemistry wrappers for dynamic identification

## Data And Artifact Policy

This refactor does not change the canonical data registry:

- processed OCV inputs remain in `data/modelling/processed/ocv/...`
- processed dynamic inputs remain in `data/modelling/processed/dynamic/...`
- reusable OCV models remain in `data/modelling/derived/ocv_models/...`
- reusable identification and validation results remain in `data/modelling/derived/...`

Only the code-layer ownership changed; the canonical data and artifact paths
did not.

## Practical Migration

- old OCV entry point: `ESC_Id/runOcvIdentification.m`
- new OCV entry point: `ocv_id/runOcvIdentification.m`

- old OCV study scripts: `ESC_Id/stdy/...`
- new OCV study scripts: `ocv_id/stdy/...`

- ESC dynamic identification still reads OCV model artifacts from
  `data/modelling/derived/ocv_models/...`, but it now depends on the
  `ocv_id` layer for optional OCV validation utilities.
