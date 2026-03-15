# SOC ESC Identification and Benchmark Toolchain

This repository is a MATLAB toolchain for ESC battery-model identification, validation, and estimator benchmarking.

The workflow is:

1. Identify ESC model parameters from OCV data and dynamic current-voltage data.
2. Validate the model with voltage-focused metrics such as RMSE and mean error.
3. Pair the model with several estimators and benchmark them on representative datasets.
4. Use the benchmark results to promote the best model and estimator combination for the target application.

The evaluation layer also supports robustness studies such as different SOC initialization, sensor-noise injection, and sensor-fault injection.

## Project Aim

The toolchain is intended to support:

1. ESC parameter identification
   - Prefer OCV data plus dynamic datasets spanning diverse C-rates.
   - Prefer charge and discharge coverage, ideally across roughly 10% to 90% SOC.
2. Model validation
   - Validate the identified model before estimator benchmarking.
   - Focus on voltage RMSE and mean voltage bias error.
3. Model-estimator pairing and benchmarking
   - Evaluate which estimator works best for a given ESC model and dataset.
   - Support both diverse-C-rate datasets and application-specific duty cycles.
   - Study sensitivity to SOC initialization error.
   - Run additional injected-noise and injected-fault tests in the evaluation layer.
4. Selection for deployment
   - Promote the best model (chemestry) and estimator for the required application.

## Repository Structure

- `ESC_Id/`: ESC identification and regeneration scripts.
  - OCV processing and dynamic parameter identification live here.
  - Includes NMC30 and OMTLIFE-oriented identification flows.
- `estimators/`: estimator implementations and initializers.
  - EKF, SPKF, adaptive, bias-aware, and R0-tracking variants.
- `Evaluation/`: model validation, estimator benchmarking, and robustness studies.
  - Structured benchmark runner, initial-SOC sweeps, injected-noise/fault studies, and plotting helpers.
- `models/`: released ESC and ROM model artifacts (`.mat`).
- `utility/`: shared helper functions used by the identification and estimator layers.
- `ESC Modelling Data/`: source data and supporting modelling assets.
- `assets/`: saved figures and report artifacts.

## Toolchain Stages

### 1. ESC Identification

The identification layer builds ESC models from OCV and dynamic data.

Relevant parametrization tools:
- `ESC_Id/DiagProcessOCV.m`
- `ESC_Id/processDynamic.m`

#### 1.1 Model Validation

Model validation should happen before estimator benchmarking. In this repo, validation is primarily voltage-oriented and uses metrics such as:
- Voltage RMSE
- Mean voltage error / bias

### 2. Estimator Pairing and Benchmarking

The ESC model is paired with multiple estimators and evaluated on a common dataset so the best estimator for that model/configuration can be identified.

Current benchmark entry points:

- `Evaluation/mainEval.m`
  - Main structured benchmark entry point.
  - Uses `Evaluation/xKFeval.m` as the generic evaluation engine.
- `Evaluation/xKFeval.m`
  - Core reusable evaluation runner for datasets plus initialized estimators.
- `Evaluation/initSOCs/sweepInitSocStudy.m`
  - Initial-SOC sensitivity study for the ESC estimator family.
  - `Evaluation/initSOCs/runInitSocStudy.m`: convenience wrapper around `sweepInitSocStudy.m` with fixed defaults.
- `Evaluation/tests/runInjTest.m`
  - Noise-injection and fault-injection benchmark wrapper.

### 3. Promotion of the Best Configuration

The intended output of the toolchain is not just a fitted model or a single estimator result. The goal is to identify the best model-estimator pair for the required application profile and cell chemistry, then carry that pair forward.

## Main Evaluation Entry Points

- `Evaluation/mainEval.m`: primary estimator benchmark tested on the NMC30 ROM-based bus_coreBattery dataset.
- `Evaluation/initSOCs/sweepInitSocStudy.m`: configurable SOC-initialization sweep.
- `Evaluation/tests/runInjTest.m`: configurable injected-noise or injected-fault benchmark.
- `Evaluation/plotInnovationAcfPacf.m`: innovation ACF/PACF plotting helper.
- `Evaluation/printEstimatorBiasMetrics.m`: bias and innovation summary helper.

## Dependencies

1. MATLAB, recommended `R2023a` or newer.

## Conventions

- Current sign: `+I = discharge`, `-I = charge`.
- Positive current reduces SOC.
- Script-level SOC inputs are often in percent, while internal ESC states typically use normalized SOC in `[0, 1]`.
- Temperatures at the evaluation-layer interface are in `degC`.
- Voltage is terminal cell voltage in volts.

## NMC30 Dynamic-Data Note

For the NMC30 ESC parameter identification flow, the dynamic dataset was generated from a ROM-based simulation path. That is a practical source of dynamic data, but it is not the only possible one.

In principle, the same identification procedure could be driven by an external model or higher-fidelity source, for example:

- PyBaMM
- COMSOL
- another FOM or experimentally derived dynamic dataset

## License

See [`LICENSE`](./LICENSE) for license scope and attribution requirements.
