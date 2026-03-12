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
- `KFEval.m`: evaluates selected estimators on a saved dataset.
- `plotInnovationAcfPacf.m`: helper to plot innovation ACF/PACF.
- `SOCnVeval.m`: shared SOC/voltage evaluation helper.

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
