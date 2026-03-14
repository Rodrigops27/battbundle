# SOC Estimator Validation Bundle (NMC30)

Validated estimator/model bundle tied to this benchmark suite version.

## Repository Layout
- `SOCestimatorsEval.m`: main validation run (ROM-EKF, ESC-SPKF, EDUKF, EsSPKF, EBiSPKF, Em7SPKF).
- `runNMC30SOCComparison.m`: alternate validation run (EaEKF variant instead of EDUKF).
- `utility/`: estimator/core MATLAB functions.
- `models/`: required ROM and ESC model bundles (`.mat`).
- `ESC_Id/`: model identification/regeneration workflow scripts.
- `assets/`: saved figures.

## Dependencies and Setup
1. MATLAB (recommended: R2023a or newer).
2. Required model files must exist:
   - `models/ROM_NMC30_HRA12.mat`
   - `models/NMC30model.mat`
3. Start MATLAB in repo root and set paths:

```matlab
repoRoot = pwd;  % run from bnchmrk root
addpath(repoRoot);
addpath(genpath(fullfile(repoRoot, "utility")));
addpath(genpath(fullfile(repoRoot, "ESC_Id")));
```

Notes:
- Scripts already search several fallback locations for model files.
- If `models/NMC30model.mat` is missing, regenerate via `ESC_Id/createNMC30Model.m` then `ESC_Id/fullParameterIdentificationNMC30.m`.
- `ESC_Id/createNMC30Model.m` loads ROM from `models/ROM_NMC30_HRA12.mat` (with local fallbacks).

## How to Run Validation
Run either script from MATLAB command window:

```matlab
SOCestimatorsEval
```

or

```matlab
runNMC30SOCComparison
```

Both print:
- SOC RMSE and max error per estimator.
- Bias/innovation diagnostics:
  - Mean Voltage Bias Error
  - Mean SOC Bias Error
  - NIS (Normalized Innovation Squared)
  - Innovation autocorrelation (lag-1) with 95% block-bootstrap CI

## Additional Tools
- `createROMSyntheticDataset.m`: builds/saves a reusable ROM synthetic dataset in `datasets/`.
- `Synthm/simulateROMProfile.m`: shared ROM playback engine for synthetic profile simulation.
- `Synthm/createBusCoreBatterySyntheticDataset.m`: builds the bus-coreBattery-driven ROM dataset.
- `KFEval.m`: evaluates selected estimators on a saved dataset.
- `plotInnovationAcfPacf.m`: helper to plot innovation ACF/PACF.
- `SOCnVeval.m`: shared SOC/voltage evaluation helper.

## OMTLIFE 8 Ah ESC Identification
The repo now includes a first-pass ESC identification path for the `OMTLIFE8AHC-HP` dataset under `ESC_Id/Datasets/OMTLIFE8AHC-HP`.

- `ESC_Id/patchLfpOcvInterpTail.m`: patches the high-SOC tail of `LFP_OCV_interp.mat` before OCV fitting.
- `ESC_Id/OCV_eg/DiagProcessOCV.m`: alternate OCV characterization method based on diagonal averaging of charge and discharge curves.
- `ESC_Id/OMTLIFEocv.m`: builds a 25 degC OCV-only ESC model from the patched `LFP_OCV_interp.mat` and saves `ESC_Id/OMTLIFEmodel-ocv-diag.mat`.
- `ESC_Id/OMTdynId.m`: performs dynamic ESC identification directly on `Bus_CoreBatteryData_Data.mat`, fitting `R0`, two RC pairs, and hysteresis at 25 degC, and saves `ESC_Id/OMTLIFEmodel.mat`.

Current assumptions for this path:

- single-temperature identification at `25 degC`
- nominal capacity `8 Ah` unless explicitly overridden
- direct use of measured current and voltage from the bus-core battery dataset
- current reoriented to the repo convention `+I = discharge`, `-I = charge`

This OMTLIFE workflow is separate from the NMC30 ROM-based identification path and does not require a ROM model.

## ROM / KF Conventions
The ROM simulator and Kalman-filter evaluation scripts currently use the same external convention:

- Current sign: `+I = discharge`, `-I = charge`.
- SOC behavior: positive current reduces SOC.
- SOC units: script inputs such as `soc_init` and `SOC0` are in percent, while most internal estimator/model SOC states are normalized to `[0, 1]`.
- Temperature at script/filter interfaces is in `degC`; lower-level ROM/physics code converts to Kelvin internally where needed.
- Voltage is terminal cell voltage in volts.

This convention is consistent across the main ROM/ESC paths used in this repo, including:

- `utility/OB_step.m`
- `utility/NB_step.m`
- `ESC_Id/ModelMgmt/simCell.m`
- `utility/ESCmgmt/simCell.m`
- `utility/iterEKF.m`
- `utility/iterSPKF.m`

For imported source datasets, `Synthm/createBusCoreBatterySyntheticDataset.m` explicitly reorients/scales the profile so the generated ROM dataset also follows the same convention.

## Reproduce a "Validated Bundle" Result
Use this checklist to reproduce and freeze a validated result set:

1. Freeze environment:
   - MATLAB release
   - OS version
   - benchmark suite commit/version tag
2. Freeze model artifacts by hashing:

```powershell
Get-FileHash .\models\ROM_NMC30_HRA12.mat -Algorithm SHA256
Get-FileHash .\models\NMC30model.mat -Algorithm SHA256
```

3. Run a clean MATLAB session and capture logs:

```matlab
restoredefaultpath;
repoRoot = "C:\Users\RodrigoPS\Documents\Prjcts\SOC\bnchmrk";
cd(repoRoot);
addpath(repoRoot);
addpath(genpath(fullfile(repoRoot, "utility")));
addpath(genpath(fullfile(repoRoot, "ESC_Id")));
rng(0, "twister");  % keeps bootstrap-CI output deterministic
diary(fullfile(repoRoot, "validation.log"));
SOCestimatorsEval
diary off;
save(fullfile(repoRoot, "validation_workspace.mat"));
```

4. Archive together:
   - `validation.log`
   - `validation_workspace.mat`
   - model hashes
   - script name + commit/version tag
5. Compare future runs against archived SOC metrics + bias/innovation diagnostics.


## License
See [`LICENSE`](./LICENSE) for ROM estimator license scope and attribution requirements.
