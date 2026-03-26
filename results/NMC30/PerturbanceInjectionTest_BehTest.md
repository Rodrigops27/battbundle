# Perturbance And Noise Injection Results (Behavior Test)

## Description of the scenario

This summary reports the rerun of the NMC30 behavior-test injection study using the ROM-driven NMC30 benchmark dataset and the same "top estimator" set used for the latest follow-up comparison.

| Item | Value |
| --- | --- |
| Study layer | `Evaluation/Injection/` |
| Core script | `Evaluation/Injection/runInjectionStudy.m` |
| Source dataset | `Evaluation/ROMSimData/datasets/rom_bus_coreBattery_dataset.mat` |
| ESC model | `models/NMC30model.mat` |
| ROM model | `models/ROM_NMC30_HRA12.mat` |
| Scenario label | `nmc30_behavior_test` |
| Injection cases reported here | `noise`, `perturbance` |
| Estimators reported here | `ROM-EKF`, `EsSPKF`, `ESC-SPKF`, `EaEKF`, `EbSPKF`, `EBiSPKF`, `EDUKF`, `Em7SPKF`, `ESC-EKF` |

This file is the behavior-test companion to the ATL desktop injection results in `results/PerturbanceInjectionTest.md`.

## Results

### Injected-dataset validation summary

| Injection case | Current RMSE [A] | Voltage RMSE [mV] | Interpretation |
| --- | ---: | ---: | --- |
| `noise` | 0.1289 | 14.991 | Moderate random sensor corruption with visible voltage noise and modest current distortion |
| `perturbance` | 0.4572 | 4.3112 | Stronger current-channel distortion with smaller direct voltage mismatch |

### Noise case

| Estimator | SOC RMSE [%] | SOC ME [%] | Voltage RMSE [mV] | Voltage ME [mV] |
| --- | ---: | ---: | ---: | ---: |
| `EbSPKF` | 0.1449 | -0.0370 | 2.3114 | 0.0190 |
| `EDUKF` | 0.7886 | -0.6782 | 6.7148 | -5.7407 |
| `EsSPKF` | 0.7886 | -0.6786 | 6.7151 | -5.7432 |
| `Em7SPKF` | 0.7886 | -0.6786 | 6.7151 | -5.7432 |
| `ESC-EKF` | 0.8036 | -0.6744 | 7.2214 | -5.7631 |
| `ESC-SPKF` | 0.8037 | -0.6743 | 7.2213 | -5.7619 |
| `EBiSPKF` | 0.8037 | -0.6743 | 7.2213 | -5.7619 |
| `EaEKF` | 0.8776 | -0.0320 | 7.1470 | 0.0465 |
| `ROM-EKF` | 65.8900 | 57.4310 | 9382.5000 | 107.9600 |

### Perturbance case

| Estimator | SOC RMSE [%] | SOC ME [%] | Voltage RMSE [mV] | Voltage ME [mV] |
| --- | ---: | ---: | ---: | ---: |
| `ROM-EKF` | 0.5995 | -0.5209 | 4.5333 | -4.0041 |
| `EaEKF` | 0.6037 | -0.5531 | 4.3105 | -4.3099 |
| `EbSPKF` | 0.6292 | -0.4782 | 5.2411 | -3.8955 |
| `ESC-SPKF` | 2.3401 | 1.6059 | 20.4030 | 14.4420 |
| `EBiSPKF` | 2.3401 | 1.6059 | 20.4030 | 14.4420 |
| `ESC-EKF` | 2.3402 | 1.6060 | 20.4040 | 14.4430 |
| `EsSPKF` | 2.3685 | 1.6660 | 20.6340 | 14.9530 |
| `Em7SPKF` | 2.3685 | 1.6660 | 20.6340 | 14.9530 |
| `EDUKF` | 2.3706 | 1.6679 | 20.6390 | 14.9840 |

### Practical ranking for this study

| Case | Rank | Best on SOC RMSE | Value | Best on Voltage RMSE | Value |
| --- | ---: | --- | ---: | --- | ---: |
| `noise` | 1 | `EbSPKF` | 0.1449 | `EbSPKF` | 2.3114 |
| `noise` | 2 | `EDUKF` / `EsSPKF` / `Em7SPKF` | 0.7886 | `EDUKF` / `EsSPKF` / `Em7SPKF` | 6.7148 to 6.7151 |
| `noise` | 3 | `ESC-EKF` | 0.8036 | `EaEKF` | 7.1470 |
| `perturbance` | 1 | `ROM-EKF` | 0.5995 | `EaEKF` | 4.3105 |
| `perturbance` | 2 | `EaEKF` | 0.6037 | `ROM-EKF` | 4.5333 |
| `perturbance` | 3 | `EbSPKF` | 0.6292 | `EbSPKF` | 5.2411 |

## Observations

- In the `noise` behavior test, `EbSPKF` is still the clear best overall estimator. It is best on both SOC RMSE and voltage RMSE by a wide margin.
- `ROM-EKF` remains completely unsuitable for the NMC30 noise-injected case in this saved run. Its voltage RMSE explodes into the multi-volt range.
- `EDUKF`, `EsSPKF`, and `Em7SPKF` are effectively tied on the noise case. That same near-identity also appears in several other result files in this repo.
- `ESC-SPKF`, `EBiSPKF`, and `ESC-EKF` also cluster tightly in the noise case. `EBiSPKF` and `ESC-SPKF` are numerically identical here.
- The rerun changes the perturbance-case story substantially relative to the older behavior-test notes: `ROM-EKF`, `EaEKF`, and `EbSPKF` now dominate, while the SPKF family that was strongest in the ATL desktop case sits well behind them.
- In the perturbance case, `EaEKF` gives the best voltage RMSE, while `ROM-EKF` gives the best SOC RMSE. `EbSPKF` is the strongest compromise estimator because it stays close to the best on both metrics.
- The perturbance case appears to align unusually well with `ROM-EKF` and `EaEKF` on this NMC30 setup. That is scenario-specific behavior and should not be generalized to the ATL desktop study.

## How to regenerate them

To regenerate the NMC30 behavior-test comparison with the same nine reported estimators:

```matlab
addpath(genpath('.'));

cfg = defaultInjectionConfig();
cfg.scenarios(1).name = 'nmc30_behavior_test';
cfg.scenarios(1).source_dataset.dataset_file = fullfile('Evaluation', 'ROMSimData', 'datasets', 'rom_bus_coreBattery_dataset.mat');
cfg.scenarios(1).source_dataset.builder_fcn = [];
cfg.scenarios(1).modelSpec = struct( ...
    'esc_model_file', fullfile('models', 'NMC30model.mat'), ...
    'rom_model_file', fullfile('models', 'ROM_NMC30_HRA12.mat'), ...
    'tc', 25, ...
    'chemistry_label', 'NMC30', ...
    'require_rom_match', true);
cfg.scenarios(1).benchmark_dataset_template = struct( ...
    'dataset_variable', 'dataset', ...
    'dataset_soc_field', 'soc_true', ...
    'metric_soc_field', 'soc_true', ...
    'metric_voltage_field', 'voltage_v_true', ...
    'reference_name', 'ROM reference', ...
    'voltage_name', 'Injected voltage', ...
    'title_prefix', 'NMC30 Injection');
cfg.scenarios(1).estimatorSetSpec = struct( ...
    'registry_name', 'all', ...
    'estimator_names', {{ ...
        'ROM-EKF', ...
        'EsSPKF', 'ESC-SPKF', 'EaEKF', 'EbSPKF', ...
        'EBiSPKF', 'EDUKF', 'Em7SPKF', 'ESC-EKF'}}, ...
    'allow_rom_skip', true);

results = runInjectionStudy(cfg);
printInjectionSummary(results);
plotInjectionResults(results);
```

For a noise-only rerun:

```matlab
cfg.scenarios(1).injection_cases = struct( ...
    'name', 'noise', ...
    'mode', 'noise', ...
    'voltage_std_mv', 15, ...
    'current_error_percent', 5, ...
    'random_seed', 7, ...
    'overwrite', true);
```

For a perturbance-only rerun:

```matlab
cfg.scenarios(1).injection_cases = struct( ...
    'name', 'perturbance', ...
    'mode', 'perturbance', ...
    'current_gain', 1.1, ...
    'current_offset_a', 0.1, ...
    'voltage_gain_fault', 6e-4, ...
    'voltage_offset_mv', 2, ...
    'random_seed', 11, ...
    'overwrite', true);
```
