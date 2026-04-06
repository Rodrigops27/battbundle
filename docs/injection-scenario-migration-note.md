# Injection Scenario Naming Migration

## Breaking Change

`Evaluation/Injection` now accepts only the canonical scenario identifiers:

- `additive_measurement_noise`
- `sensor_gain_bias_fault`

Legacy names are no longer accepted in runtime configuration, parsing, or manifest-driven execution:

- `noise` -> `additive_measurement_noise`
- `disturbance` / repo-legacy `perturbance` -> `sensor_gain_bias_fault`

## Scope

The canonical names were propagated through:

- injection runtime configuration and dispatch
- validation of `name`, `mode`, `dataset_family`, and `augmentation_type`
- tracked manifests and promoted injection summaries
- examples, record docs, and asset filenames

## Upgrade Note

Update any saved configs, manifest-derived case definitions, or scripted reruns to use the canonical identifiers exactly. No backward-compatibility aliasing remains in executable code paths.
