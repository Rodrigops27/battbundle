# ESC Model Validation

This document describes the model-validation harness implemented in the ESC identification layer and the voltage metrics it reports.

## Validation Entry Points

- `ESC_Id/ESCvalidation.m`
  Single-run ESC model validation against measured current-voltage data.
- `ESC_Id/runESCvalidation.m`
  Batch wrapper for one model across many datasets, many models across one dataset, or explicit model/data job pairs.

The harness validates an ESC model by replaying measured current through `utility/ESCmgmt/simCell.m` and comparing the simulated terminal voltage against measured voltage.

## Recommended Documentation Structure

- Keep `docs/models.md` as the common reference for:
  - validation entry points
  - accepted dataset shapes
  - metric definitions
  - output/result contract
- Add one per-model note when needed, preferably under `docs/models/`:
  - example: `docs/models/ATLmodel.md`
  - example: `docs/models/OMTLIFEmodel.md`
- Per-model notes should focus on provenance and evidence:
  - source datasets used for identification
  - identification temperature range
  - latest validation datasets
  - latest validation summary table or plots
  - known limitations or mismatch patterns

## Defaults

- Default model:
  - `models/ATLmodel.mat`
  - fallback: `ESC_Id/FullESCmodels/LFP/ATLmodel.mat`
  - additional fallback in the harness: `ESC_Id/OMTLIFE8AHC-HP/OMTLIFEmodel.mat`
- Default measured dataset:
  - `Evaluation/OMTLIFE8AHC-HP/Bus_CoreBatteryData_Data.mat`

The default location of the harness is intentional: model validation now lives in `ESC_Id/`, not only in `Evaluation/`.

## Accepted Measured-Data Inputs

`ESCvalidation` accepts these forms:

1. MAT-file path to a measured profile
   - Intended for real measured datasets such as `Evaluation/OMTLIFE8AHC-HP/Bus_CoreBatteryData_Data.mat`.
2. Normalized struct
   - Expected measured fields are current plus voltage, with optional time, temperature, and SOC reference.
3. Legacy dynamic struct array
   - `processDynamic`-style entries with `temp` and `script1.current` / `script1.voltage`.
4. Struct loaded from a MAT file
   - The harness recursively searches nested structs for supported signal aliases.

This parser is alias-based, not schema-free. If a new measured dataset uses different signal names, extend the alias lists in `ESC_Id/ESCvalidation.m`.

Signal aliases currently supported by `ESC_Id/ESCvalidation.m` include:

- Current:
  - `current_a`, `current`, `i`, `i_a`, `measured_current_a`, `pack_current_a`, `Total_Current_A`, `Current_Vector_A`, `source_current_a`
- Voltage:
  - `metric_voltage_v`, `metric_voltage`, `source_voltage_v`, `measured_voltage_v`, `terminal_voltage_v`, `voltage_v`, `voltage`, `v`, `Voltage_Vector_V`, `Total_Voltage_V`
- SOC:
  - `metric_soc`, `reference_soc`, `soc_true`, `soc_ref`, `soc`, `soc_percent`, `SOC_Vector_Percent`
- Temperature:
  - `temperature_c`, `temperature`, `temp_c`, `temp`, `temperature_degc`, `Temperature_Vector_degC`
- Time:
  - `time_s`, `time`, `t`, `time_sec`, `timestamp_s`, `timestamp`, `seconds`

## Normalization Rules

These rules come from `ESC_Id/ESCvalidation.m` and `utility/ESCmgmt/simCell.m`.

- Current sign:
  - Repo convention is `+I = discharge`.
  - If SOC reference is present, the harness can flip current sign automatically from the SOC trend.
  - If no SOC reference is present, the harness leaves current sign as provided.
- Sample time:
  - If timestamps are irregular, the harness resamples to the median sample time.
  - Current uses zero-order hold (`previous`); voltage, SOC, and temperature use linear interpolation.
- Temperature:
  - `simCell` uses one scalar temperature, not a time-varying temperature trace.
  - The harness uses the median measured temperature when available.
  - If temperature is missing, it defaults to the model temperature nearest `25 degC`, or `25 degC` if the model does not expose `temps`.
- Initial SOC:
  - If a valid SOC reference exists, the first valid SOC sample is used.
  - Otherwise the harness estimates initial SOC from voltage using `SOCfromOCVtemp`.
  - For legacy `script1` validation, `z0 = 1` is used to match `utility/DYN_eg/runProcessDynamic.m`.

## Metrics

### Primary voltage metric

- `voltage_rmse_v`
  - Root-mean-square of measured-minus-simulated terminal-voltage error over all valid samples.
- `voltage_rmse_mv`
  - Same metric in millivolts.

Formula:

```matlab
verr = voltage_meas_v - voltage_est_v;
voltage_rmse_v = sqrt(mean(verr(valid_idx).^2));
```

This is the main score to compare ESC models on the same measured dataset.

### Supporting voltage metrics

- `voltage_mean_error_v` / `voltage_mean_error_mv`
  - Signed mean voltage bias.
- `voltage_mae_v` / `voltage_mae_mv`
  - Mean absolute voltage error.
- `voltage_max_abs_error_v` / `voltage_max_abs_error_mv`
  - Worst instantaneous voltage mismatch.

These metrics help separate bias problems from transient mismatch.

### Legacy window RMSE

- `legacy_window_rmse_v` / `legacy_window_rmse_mv`
  - Reproduces the older Plett-style 95%-to-5% OCV-window RMSE used in `utility/DYN_eg/runProcessDynamic.m`.

Definition:

```matlab
v95 = OCVfromSOCtemp(0.95, tc, model);
v05 = OCVfromSOCtemp(0.05, tc, model);
N1 = find(voltage_meas_v < v95, 1, 'first');
N2 = find(voltage_meas_v < v05, 1, 'first');
legacy_window_rmse_v = sqrt(mean(verr(N1:N2).^2));
```

Use this metric only as a compatibility score with the legacy dynamic-identification flow. For arbitrary measured duty cycles, `voltage_rmse_v` is the safer primary metric.

## Output Contract

`ESCvalidation` returns a struct with:

- `model_file`, `model_name`
- `cases`
  - each case stores measured traces, simulated traces, SOC trace, voltage error, notes, and metrics
- `summary_table`
  - one row per case
- `metrics`
  - aggregate RMSE summary across all cases

`runESCvalidation` returns a batch struct with:

- `entries`
  - each entry contains one full `ESCvalidation` result
- `summary_table`
  - one row per job

## Usage Examples

Default ATL validation on the default measured dataset:

```matlab
addpath(genpath('.'));
results = ESCvalidation([], [], true);
```

Validate the OMT8 ESC model on the saved DYN dataset:

```matlab
addpath(genpath('.'));

results = ESCvalidation( ...
    fullfile('ESC_Id', 'OMTLIFE8AHC-HP', 'OMTLIFEmodel.mat'), ...
    fullfile('ESC_Id', 'DYN_Files', 'OMT8_DYN', 'OMT8_DYN_P25.mat'), ...
    true);
```

Batch validation across several models:

```matlab
addpath(genpath('.'));

batch = runESCvalidation( ...
    {fullfile('models', 'ATLmodel.mat'), fullfile('ESC_Id', 'OMTLIFE8AHC-HP', 'OMTLIFEmodel.mat')}, ...
    {fullfile('ESC_Id', 'DYN_Files', 'OMT8_DYN', 'OMT8_DYN_P25.mat')}, ...
    false);
```

## Plot Results (Anytime)

The plotting function is decoupled from the validation harness, allowing you to visualize results at any time without re-running validation.

### Plot During Validation
```matlab
addpath(genpath('.'));
results = ESCvalidation([], [], true);  % Shows plots immediately after validation
```

### Plot Saved Results
After running validation and saving results, load and visualize validation plots anytime:

```matlab
% Load previous validation results
cd ESC_Id
load('ESC_validation_results.mat');

% Plot individual ESC validation results
plotEscValidation(result_atl);
plotEscValidation(result_nmc);
plotEscValidation(result_omt);
```

### Custom Validation and Plotting
```matlab
% Run validation without auto-plotting
addpath(genpath('.'));
results = ESCvalidation('models/ATLmodel.mat', 'ESC_Id/DYN_Files/ATL_DYN/ATL_DYN_40_P25.mat', false);

% Inspect metrics first
fprintf('Voltage RMSE: %.2f mV\n', results.cases(1).metrics.voltage_rmse_mv);

% Create plots only if satisfied
plotEscValidation(results);

% Save for later
save('my_esc_validation.mat', 'results');
```

### Batch Plotting All Results
```matlab
clear
cd ESC_Id
load('ESC_validation_results.mat');

models_to_plot = {'ATL', 'NMC30', 'OMT8'};
results = {result_atl, result_nmc, result_omt};

for idx = 1:numel(results)
    fprintf('Plotting %s...\n', models_to_plot{idx});
    plotEscValidation(results{idx});
end
```

### Plotting Function Reference

The `plotEscValidation` function creates one figure per validation case showing:
- **Top panel:** Measured voltage vs. simulated voltage with RMSE metric
- **Middle panel:** Current profile trace
- **Bottom panel:** Voltage error (measured - simulated)

Shows 3 subplots for direct error analysis across the entire validation profile.

## Validation Results (Latest Run)

Comprehensive ESC model validation was performed on March 19, 2026 against multiple datasets using the three primary models in the repository. All validations completed successfully.

### Summary Table

| Model | Dataset | Temperature | RMSE (mV) | Mean Error (mV) | MAE (mV) | Max Error (mV) | Samples |
|-------|---------|-------------|-----------|-----------------|----------|----------------|---------|
| ATL | ESC_Id/DYN_Files/ATL_DYN/ATL_DYN_40_P25.mat | 25.0°C | 24.97 | -11.18 | 19.90 | 175.26 | 35,560 |
| NMC30 | NMC30_DYN_P25.mat | 25.0°C | 12.39 | -9.95 | 9.95 | 49.88 | 8,250 |
| OMT8 | OMT8_DYN_P25.mat | 25.0°C | 6.94 | 1.08 | 5.39 | 27.09 | 576,001 |

### Detailed Results

#### ATL Model
- **Model File:** `models/ATLmodel.mat`
- **Test Data:** `ESC_Id/DYN_Files/ATL_DYN/ATL_DYN_40_P25.mat` (legacy script1 format)
- **Validation Temperature:** 25.0°C
- **Voltage RMSE:** 24.97 mV
- **Voltage Mean Error:** -11.18 mV (bias toward overestimation)
- **Voltage Mean Absolute Error:** 19.90 mV
- **Maximum Error:** 175.26 mV
- **Data Points Analyzed:** 35,560 samples
- **Notes:** Steady-state dynamic profile with moderate to good agreement. Negative bias suggests the model tends to overestimate voltage under certain conditions.

#### NMC30 Model
- **Model File:** `models/NMC30model.mat`
- **Test Data:** `ESC_Id/DYN_Files/NMC30_DYN/NMC30_DYN_P25.mat`
- **Validation Temperature:** 25.0°C
- **Voltage RMSE:** 12.39 mV
- **Voltage Mean Error:** -9.95 mV (bias toward overestimation)
- **Voltage Mean Absolute Error:** 9.95 mV
- **Maximum Error:** 49.88 mV
- **Data Points Analyzed:** 8,250 samples
- **Notes:** Synthetic dataset from ROM simulations. Better fit compared to ATL model with tighter error distribution.

#### OMT8 Model
- **Model File:** `ESC_Id/OMTLIFE8AHC-HP/OMTLIFEmodel.mat`
- **Test Data:** `ESC_Id/DYN_Files/OMT8_DYN/OMT8_DYN_P25.mat`
- **Validation Temperature:** 25.0°C
- **Voltage RMSE:** 6.94 mV
- **Voltage Mean Error:** 1.08 mV (minimal bias)
- **Voltage Mean Absolute Error:** 5.39 mV
- **Maximum Error:** 27.09 mV
- **Data Points Analyzed:** 576,001 samples
- **Notes:** Best overall performance with large dataset from actual bus system operation. Model is well-matched to this chemistry and operating profile with excellent agreement.

### Observations

1. **Model Performance Ranking (by RMSE):**
   - OMTLIFE: **6.94 mV** (best) — Real measured data, largest dataset
   - NMC30: **12.39 mV** — Synthetic ROM data
   - ATL: **24.97 mV** — Legacy script1 profile

2. **Bias Analysis:**
   - ATL and NMC30 show consistent negative bias (-11.18 mV and -9.95 mV), indicating tendency to overestimate terminal voltage
   - OMTLIFE shows minimal bias (1.08 mV), indicating well-calibrated model

3. **Data Volume:**
   - OMTLIFE validation used significantly more data points (576K vs ~36K vs ~8K)
   - Larger datasets provide more robust validation evidence

4. **Temperature Compatibility:**
   - All validations executed at 25.0°C
   - Note: A tolerance of ±1°C is now allowed for single-temperature models to accommodate realistic measurement variations

## Practical Guidance

- Use `voltage_rmse_v` as the default model-selection metric.
- Use `legacy_window_rmse_v` only when you want direct continuity with `runProcessDynamic`.
- If the measured dataset spans a wide temperature range, expect mismatch because `simCell` is evaluated at a single temperature.
- If current sign is wrong and no SOC reference is available, the harness cannot reliably correct it automatically.
- If the dataset does not include SOC reference, the initial-SOC estimate depends on OCV consistency and the presence of near-rest samples at the beginning.
