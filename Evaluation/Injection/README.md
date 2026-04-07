# Injection Study Layer

This layer generates derived evaluation datasets from a nominal benchmark dataset, validates each injected case, and runs [`runBenchmark.m`](../runBenchmark.m) on the derived output.

## Purpose

Use this layer when you want to:

- generate injected datasets from a clean benchmark dataset
- validate the injected dataset against the clean source trace
- benchmark one or more estimators on the injected dataset
- summarize saved injection-study results later

## Injection Modes

Each injection case selects one mode. Modes are mutually exclusive within a case, but multiple cases can be combined in a study.

### additive_measurement_noise

Applies zero-mean additive voltage noise plus bounded multiplicative current error.
Use this mode for generic measurement-noise sensitivity studies.

### sensor_gain_bias_fault

Applies deterministic current gain/offset and voltage gain/offset faults.
Use this mode for simple calibration or offset fault studies.

### composite_measurement_error

Applies a stochastic current-sensor model and leaves voltage unchanged unless future configuration adds explicit voltage handling.

For this mode:

- `i_true = dataset.current_a_true`
- `i_pre_q = (1 + g) * i_true + b(k) + v(k)`
- `i_meas = quantize(i_pre_q, current_quant_lsb_a)`
- `n_q = i_meas - i_pre_q`
- `dataset.current_a = i_meas`
- `dataset.voltage_v = dataset.voltage_v_true`

Supported current-bias modes:

- `constant`
- `random_walk`

The current implementation uses `random_walk` for drifting bias:

- `b(1) = b0`
- `b(k) = b(k-1) + sigma_b * randn`

The default desktop scenario uses:

- source dataset: [`data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat`](../../data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat)
- ESC model: [`models/ATLmodel.mat`](../../models/ATLmodel.mat)
- ROM model: [`models/ROM_ATL20_beta.mat`](../../models/ROM_ATL20_beta.mat)
- default estimator set:
  `EsSPKF`, `ESC-SPKF`, `EaEKF`, `EbSPKF`, `EBiSPKF`, `EDUKF`, `Em7SPKF`, `ESC-EKF`
- default cases:
  `additive_measurement_noise`, `sensor_gain_bias_fault`, `hall_bias`

The default `hall_bias` case uses a capacity-scaled constant bias:

- `current_bias_spec = 'c_rate_scaled'`
- `current_bias_c_rate = -0.1`
- if `capacity_ah` is not set in the case config, the Injection layer uses `dataset.capacity_ah` from the source dataset

## Canonical Output Layout

Generated evaluation cases save under:

`data/evaluation/derived/<suite_version>/<canonical_mode>/<case_id>/`

Each case directory contains:

- `dataset.mat`
- `manifest.json`
- optional `manifest.mat`

Example:

`data/evaluation/derived/desktop_atl20_bss_v1/composite_measurement_error/case_003/`

## Main Files

- [`runInjectionStudy.m`](runInjectionStudy.m)
  Main API/configuration entry point.
- [`defaultInjectionConfig.m`](defaultInjectionConfig.m)
  Default ATL desktop scenario and default injection cases.
- [`generateInjectedDataset.m`](generateInjectedDataset.m)
  Dataset-generation helper for canonical injection cases.
- [`validateInjectedDataset.m`](validateInjectedDataset.m)
  Validation helper for clean-vs-injected traces.
- [`normalizeInjectionCaseConfig.m`](normalizeInjectionCaseConfig.m)
  Canonical case-identifier validation for executable config fields.

## Quick Start

```matlab
addpath(genpath('.'));

cfg = defaultInjectionConfig();
cfg.validation.show_plots = false;
results = runInjectionStudy(cfg);
```

## Parallel Execution

Independent injection cases can run in parallel:

```matlab
cfg = defaultInjectionConfig();
cfg.parallel.use_parallel = true;
cfg.parallel.auto_start_pool = true;
cfg.parallel.pool_size = [];

results = runInjectionStudy(cfg);
```

When parallel execution is unavailable, the layer falls back to serial mode and prints the reason.

## Custom Settings

For a custom `additive_measurement_noise` case, the main configurable inputs are:

- `name`
- `mode = 'additive_measurement_noise'`
- `dataset_family = 'additive_measurement_noise'`
- `augmentation_type = 'additive_measurement_noise'`
- `voltage_std_mv`
- `current_error_percent`
- `random_seed`
- `overwrite`

For a custom `sensor_gain_bias_fault` case, the main configurable inputs are:

- `name`
- `mode = 'sensor_gain_bias_fault'`
- `dataset_family = 'sensor_gain_bias_fault'`
- `augmentation_type = 'sensor_gain_bias_fault'`
- `current_gain`
- `current_offset_a`
- `voltage_gain_fault`
- `voltage_offset_mv`
- `random_seed`
- `overwrite`

For a custom `composite_measurement_error` case, the main configurable inputs are:

- `name`
- `mode = 'composite_measurement_error'`
- `dataset_family = 'composite_measurement_error'`
- `augmentation_type = 'composite_measurement_error'`
- `current_gain_error`
- `current_bias_mode`
- `current_bias_spec`
- `current_bias_a`
- `current_bias_c_rate`
- `capacity_ah`
- `current_bias_rw_std_a`
- `current_noise_std_a`
- `current_quant_lsb_a`
- `random_seed`
- `overwrite`

### composite_measurement_error Parameter Definitions

- `current_gain_error`
  Scalar fractional gain error `g` applied once per run.
- `current_bias_mode`
  Bias time-series model. Supported values: `constant`, `random_walk`.
- `current_bias_spec`
  Bias configuration style. Supported values: `absolute_a`, `c_rate_scaled`.
- `current_bias_a`
  Absolute current bias in amperes. Required when `current_bias_spec = 'absolute_a'`.
- `current_bias_c_rate`
  Bias expressed as a C-rate fraction. Required when `current_bias_spec = 'c_rate_scaled'`.
- `capacity_ah`
  Nominal cell or pack capacity in ampere-hours. Required for `c_rate_scaled` unless the source dataset already provides `dataset.capacity_ah`.
- `current_bias_rw_std_a`
  Random-walk step standard deviation in amperes per sample.
- `current_noise_std_a`
  Zero-mean Gaussian analog noise standard deviation in amperes.
- `current_quant_lsb_a`
  Current quantizer LSB in amperes. If `<= 0`, quantization is skipped.
- `random_seed`
  Optional RNG seed for deterministic replay.

### Bias-Spec Resolution

The implementation resolves one scalar bias value in amperes before building the bias trace.

If `current_bias_spec = 'absolute_a'`:

- require `current_bias_a`
- resolve `b0 = current_bias_a`

If `current_bias_spec = 'c_rate_scaled'`:

- require `current_bias_c_rate`
- resolve `capacity_ah` from `cfg.capacity_ah` when provided, otherwise from `dataset.capacity_ah`
- resolve `b0 = current_bias_c_rate * capacity_ah`

The resolved scalar is then used consistently for:

- the full constant-bias trace
- the initial condition of the random-walk bias trace

The resolved value is stored in:

- `dataset.injection_config_resolved.current_bias_a`
- `metadata.injection_config_resolved.current_bias_a`
- the written case manifest under `injection_config_resolved.current_bias_a`

### Traceability Fields Added by composite_measurement_error

Generated datasets store the current-sensor components explicitly:

- `injected_current_gain_error`
- `injected_current_bias_a`
- `injected_current_analog_noise_a`
- `injected_current_quantization_a`
- `injected_current_prequant_a`
- `injected_current_measured_a`
- `injection_config_resolved`

### Example composite_measurement_error Config

```matlab
cfg = defaultInjectionConfig();
cfg.scenarios(1).injection_cases = struct( ...
    'name', 'hall_bias', ...
    'mode', 'composite_measurement_error', ...
    'dataset_family', 'composite_measurement_error', ...
    'augmentation_type', 'composite_measurement_error', ...
    'current_gain_error', 0.01, ...
    'current_bias_mode', 'random_walk', ...
    'current_bias_spec', 'c_rate_scaled', ...
    'current_bias_c_rate', -0.02, ...
    'capacity_ah', 20, ...
    'current_bias_rw_std_a', 0.002, ...
    'current_noise_std_a', 0.01, ...
    'current_quant_lsb_a', 0.05, ...
    'random_seed', 23, ...
    'overwrite', true);

results = runInjectionStudy(cfg);
```

## How It Differs From the Existing Modes

`composite_measurement_error` differs from the two simpler runtime modes as follows:

- Compared with `additive_measurement_noise`, it explicitly models current gain error, resolved bias, analog noise, and quantization instead of only bounded noise-style perturbations.
- Compared with `sensor_gain_bias_fault`, it supports stochastic bias evolution and explicit quantization while keeping the gain term scalar per run.
- In legacy discussion, this is the richer current-sensor model relative to the older "noise" and "perturbance" style studies, but executable config now uses only the canonical mode names above.

## Manifest Semantics

`runInjectionStudy.m` writes case metadata with stable identifiers:

- `dataset_id`
- `parent_dataset_id`
- `suite_version`
- `dataset_family`
- `augmentation_type`
- `case_id`
- `source_dataset_path`
- `resolved_output_path`
- `random_seed`
- `benchmark_contract_version`
- `injection_config`
- `injection_config_resolved`

Example dataset id:

`desktop_atl20_bss_v1__composite_measurement_error__case_003`

## Notes

- The benchmark engine is still `runBenchmark` / `xKFeval`.
- Dataset validation runs before the benchmark by default.
- Validation now reports current RMSE, MAE, mean error, standard deviation, max-abs error, and optional pre-quantization / quantization summaries when those fields exist.
- The default metric-voltage comparison uses the clean voltage trace stored as `voltage_v_true`.
- Derived `dataset.mat` files are reproducible workflow artifacts and are Git-ignored by default; lightweight manifests remain trackable.
- `mode`, `dataset_family`, and `augmentation_type` must be canonical runtime identifiers: `additive_measurement_noise`, `sensor_gain_bias_fault`, or `composite_measurement_error`.
- `name` is a free-form case label and does not need to match `mode`.
- See [`../../docs/injection-scenario-migration-note.md`](../../docs/injection-scenario-migration-note.md) for the explicit rename and upgrade note.
