# Estimator Benchmark Results

## Description of the scenario
This summary collects the latest saved benchmark runs from the Evaluation layer.

Included runs:
- `ATL20`
  - ESC-driven Bus Core Battery synthetic dataset
  - dataset: `Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat`
  - ESC model: `models/ATLmodel.mat`
  - ROM model: `models/ROM_ATL20_beta.mat`
- `NMC30`
  - ROM-driven benchmark dataset
  - dataset: `Evaluation/ROMSimData/datasets/rom_bus_coreBattery_dataset.mat`
  - ESC model: `models/NMC30model.mat`
  - ROM model: `models/ROM_NMC30_HRA12.mat`

Both runs use `Evaluation/runBenchmark.m` and can be re-plotted with `Evaluation/plotEvalResults.m`.

## Results

### Scenario summary

| Scenario | Dataset type | ESC model | ROM model | Estimator count |
| --- | --- | --- | --- | ---: |
| `ATL BSS` | ESC-driven BSS synthetic data | `ATLmodel.mat` | `ROM_ATL20_beta.mat` | 11 |
| `NMC30` | ROM-driven benchmark data | `NMC30model.mat` | `ROM_NMC30_HRA12.mat` | 11 |

### ATL BSS benchmark

| Estimator | SOC RMSE (%) | SOC ME (%) | Voltage RMSE (mV) | Voltage ME (mV) |
| --- | ---: | ---: | ---: | ---: |
| `EaEKF` | 1.5622 | 0.6576 | 0.0195 | 0.0007 |
| `EsSPKF` | 0.6422 | 0.5476 | 0.0312 | 0.0030 |
| `Em7SPKF` | 0.6422 | 0.5476 | 0.0312 | 0.0030 |
| `EDUKF` | 0.6422 | 0.5476 | 0.0313 | 0.0029 |
| `ESC-SPKF` | 0.6413 | 0.5462 | 0.0375 | 0.0019 |
| `EBiSPKF` | 0.6413 | 0.5462 | 0.0375 | 0.0019 |
| `EbSPKF` | 0.6392 | 0.5419 | 0.0487 | 0.0028 |
| `EacrSPKF` | 0.6652 | 0.5790 | 0.6170 | 0.1446 |
| `ESC-EKF` | 2.9235 | 1.7203 | 6.4262 | 0.5877 |
| `EnacrSPKF` | 22.3728 | 19.9459 | 17.3213 | -10.6063 |
| `ROM-EKF` | 26.2343 | 14.5965 | 40.1757 | 10.1249 |

### ATL20 ranking

| Rank | Best by SOC RMSE | Value | Best by Voltage RMSE | Value |
| --- | --- | ---: | --- | ---: |
| 1 | `EbSPKF` | 0.6392% | `EaEKF` | 0.0195 mV |
| 2 | `ESC-SPKF` / `EBiSPKF` | 0.6413% | `EsSPKF` / `Em7SPKF` | 0.0312 mV |
| 3 | `EDUKF` | 0.6422% | `EDUKF` | 0.0313 mV |

### NMC30 benchmark

| Estimator | SOC RMSE (%) | SOC ME (%) | Voltage RMSE (mV) | Voltage ME (mV) |
| --- | ---: | ---: | ---: | ---: |
| `EbSPKF` | 0.1539 | -0.0390 | 2.3093 | -0.0072 |
| `EaEKF` | 0.2943 | -0.0427 | 0.0765 | 0.0012 |
| `EnacrSPKF` | 0.7089 | 0.2735 | 4.1035 | 2.4304 |
| `EDUKF` | 0.8000 | -0.6762 | 6.8006 | -5.7545 |
| `EsSPKF` | 0.8001 | -0.6758 | 6.8006 | -5.7526 |
| `ESC-EKF` | 0.8151 | -0.6800 | 7.3088 | -5.8205 |
| `ESC-SPKF` | 0.8152 | -0.6799 | 7.3091 | -5.8199 |
| `EBiSPKF` | 0.8152 | -0.6799 | 7.3091 | -5.8199 |
| `EacrSPKF` | 1.7161 | -1.4638 | 0.8851 | 0.4816 |
| `ROM-EKF` | 6.1780 | -1.8840 | 32.8663 | 0.7255 |
| `Em7SPKF` | 0.8001 | -0.6758 | 6.8006 | -5.7526 |

### NMC30 ranking

| Rank | Best by SOC RMSE | Value | Best by Voltage RMSE | Value |
| --- | --- | ---: | --- | ---: |
| 1 | `EbSPKF` | 0.1539% | `EaEKF` | 0.0765 mV |
| 2 | `EaEKF` | 0.2943% | `EacrSPKF` | 0.8851 mV |
| 3 | `EnacrSPKF` | 0.7089% | `EbSPKF` | 2.3093 mV |

## Observations

- `ATL20`
  - `EbSPKF` is best on SOC RMSE, while `EaEKF` is best on voltage RMSE.
  - Most ESC sigma-point variants have extremely small voltage RMSE but still keep a positive SOC mean error around `0.54%` to `0.58%`, so the voltage fit is much better than the SOC bias.
  - `EBiSPKF` matches `ESC-SPKF` numerically, and `Em7SPKF` matches `EsSPKF`. In this repo, that is consistent with the default bias-model branch being effectively inactive.
  - `EnacrSPKF` is unstable on this scenario relative to the other ESC methods.

- `NMC30`
  - `EaEKF` gives the best voltage RMSE, while `EbSPKF` gives the best SOC RMSE.
  - `ROM-EKF` is again clearly worse than the top ESC estimators on this saved run.
  - `EacrSPKF` has strong voltage RMSE but weak SOC RMSE. It is a voltage-fit specialist here, not the best overall SOC estimator.
  - `EBiSPKF` again matches `ESC-SPKF`, and `Em7SPKF` again matches `EsSPKF`, which reinforces the same repo-specific bias-branch limitation.

- Across both runs
  - `EaEKF` is consistently strong on voltage RMSE.
  - `EbSPKF` is consistently strong on SOC RMSE.

## How to regenerate them

Regenerate the default ATL BSS benchmark:

```matlab
addpath(genpath('.'));
results = runBenchmark();
results.metadata.metrics_table
plotEvalResults(results.metadata.saved_results_file);
```

Regenerate the NMC30 ROM-driven benchmark:

```matlab
addpath(genpath('.'));

datasetSpec = struct( ...
    'dataset_file', fullfile('Evaluation', 'ROMSimData', 'datasets', 'rom_bus_coreBattery_dataset.mat'), ...
    'dataset_variable', 'dataset');

modelSpec = struct( ...
    'esc_model_file', fullfile('models', 'NMC30model.mat'), ...
    'rom_model_file', fullfile('models', 'ROM_NMC30_HRA12.mat'), ...
    'tc', 25, ...
    'chemistry_label', 'NMC30');

estimatorSetSpec = struct('registry_name', 'all');
flags = struct('Summaryfigs', true, 'Verbose', true, 'SaveResults', true, ...
    'results_file', fullfile('Evaluation', 'NMC30ValidationResults.mat'));

results = runBenchmark(datasetSpec, modelSpec, estimatorSetSpec, flags);
plotEvalResults(results.metadata.saved_results_file);
```
