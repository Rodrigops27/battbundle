# Noise Tuning Sweep

This layer sweeps estimator covariance settings against an evaluation dataset.

## Canonical Dataset Policy

Noise-sweep studies must use canonical evaluation dataset paths:

- benchmark/runtime reads:
  `data/evaluation/processed/...`
  `data/evaluation/derived/...`
- builder source profiles:
  `data/evaluation/raw/...`

## Defaults

- ESC dataset:
  `data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat`
- ROM dataset:
  `data/evaluation/processed/behavioral_nmc30_bss_v1/nominal/rom_bus_coreBattery_dataset.mat`
- raw source profile used by builders:
  `data/evaluation/raw/omtlife8ahc_hp/Bus_CoreBatteryData_Data.mat`

## Entry Points

- `sweepNoiseStudy.m`
- `oneEstSweeNoise.m`

## Output Artifact Policy

Noise-sweep outputs follow the evaluation-layer split:

- promoted lightweight summaries:
  `results/evaluation/<suite_version>/...`
  `results/figures/...`
- heavy local-only study outputs:
  `Evaluation/NoiseTuningSweep/results/...`

Heavy MAT sweep outputs remain local-only and are Git-ignored by default.
