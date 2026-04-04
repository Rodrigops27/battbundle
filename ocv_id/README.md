# ocv_id

This layer owns reusable open-circuit-voltage modelling across battery-model
families. It is intentionally model-family-agnostic: ESC workflows consume
its OCV artifacts, but the same OCV models and utilities are intended to be
reused by future physics-based and data-driven model families as well.

## Scope

`ocv_id` owns:

- processed OCV data loading and normalization
- shared OCV preprocessing
- OCV identification engines
- OCV-fit metrics and OCV comparison utilities
- study/inspection scripts for OCV method comparison
- chemistry-specific OCV wrappers that only build OCV artifacts

`ocv_id` does not own dynamic identification, ESC validation, or full ESC
model comparison. Those stay in `ESC_Id/`.

## Canonical Inputs And Outputs

Canonical modelling reads and writes still resolve under `data/modelling/...`.
Moving OCV code into `ocv_id` does not change the data registry.

- processed OCV inputs:
  `data/modelling/processed/ocv/...`
- interim OCV preparation assets:
  `data/modelling/interim/ocv/...`
- reusable OCV models:
  `data/modelling/derived/ocv_models/...`
- reusable OCV identification results:
  `data/modelling/derived/identification_results/...`
- promoted OCV inspection decision records:
  `results/ocv/...`
- local-only saved OCV inspection figures:
  `results/figures/ocv/...`

Generated OCV artifacts remain reusable modelling artifacts. They do not
belong in `results/` and they are not ESC-specific.

## Main Entry Points

- `runOcvIdentification.m`
- `compareOcvModels.m`
- `plotOcvModelFit.m`
- `stdy/runOcvModellingInspection.m`
- `stdy/inspectOcvModelling.m`
- `ATL20/buildATL20modelOcv.m`
- `ATL20/buildATLmodelOcv.m`
- `NMC30/OCVNMC30fromROM.m`
- `OMTLIFE8AHC-HP/OMTLIFEocv.m`

## Shared Preprocessing

All OCV engines in `ocv_id` start from the same preprocessing step:

- extract the slow discharge and slow charge branches from `script1` and `script3`
- normalize them to SOC using the 25 degC reference capacity
- apply `smoothdiff.m` to both branches before any OCV estimator is run

This shared preprocessing is implemented in `prepareOcvBranches.m`.

## Supported OCV Engines

`runOcvIdentification.m` supports:

- `voltageAverage`
- `socAverage`
- `middleCurve`
- `diagAverage`
- `resistanceBlend`

By default, OCV-fit metrics are measured against a common OCV reference built
with `middleCurve` independently at each dataset temperature. That reference
is reconstructed directly from each temperature dataset and does not use the
candidate model's `OCV0/OCVrel` regression.

These are reference metrics, not physical-ground-truth OCV metrics. The
project cannot measure a strict absolute OCV truth curve directly, so method
comparison is performed against a reconstructed charge/discharge-envelope
reference.

TODO:
The current OCV temperature regression still uses the legacy linear form
`OCV(SOC,T) = OCV0(SOC) + T*OCVrel(SOC)`. This may require a better
expression, preferably using Kelvin and an explicit reference temperature,
for example:
`OCV(SOC,T) = OCV(SOC) + (T - 298.15)*dOCV/dT(SOC)`.

## Example OCV Identification

```matlab
addpath(genpath('.'));

cfg = struct();
cfg.run_name = 'ATL20 OCV identification';
cfg.ocv_data_input = fullfile('data', 'modelling', 'processed', 'ocv', 'atl20');
cfg.data_prefix = 'ATL';
cfg.cell_id = 'ATL20';
cfg.engine = 'middleCurve';
cfg.temperature_scope = 'single';
cfg.desired_temperature = 25;
cfg.reference_ocv_method = 'middleCurve';
cfg.output.model_output_file = fullfile('data', 'modelling', 'derived', 'ocv_models', 'atl20', 'ATL20model-ocv-middleCurve.mat');
results = runOcvIdentification(cfg);
```

## Inspection Workflow

Use this workflow when selecting an OCV method:

1. Prepare or select processed OCV data under `data/modelling/processed/ocv/...`.
2. Run `stdy/runOcvModellingInspection.m` to batch-identify the supported OCV methods and launch the visual inspector.
3. Review one figure per temperature in `stdy/inspectOcvModelling.m`.
4. Compare the raw branches, the common metrics-reference OCV, and the enabled model curves.
5. Read the promoted decision record written under `results/ocv/...`, including per-method reference metrics, selected/default method, rerun instructions, and any saved figure paths.
6. Choose the OCV engine you want to promote into a reusable model artifact.
7. Update the inspection selection if needed, for example set `cfg.selected_method = 'socAverage'`, rerun the inspection flow, and record that decision in the promoted summary.
8. Run `runOcvIdentification.m` for the final selected engine and save the model into `data/modelling/derived/ocv_models/...`.
9. Pass that OCV artifact into `ESC_Id/runDynamicIdentification.m` or any future model-family-specific dynamic-identification layer.

By default the study flow computes all supported methods, including the three
diagonal variants, but hides the diagonal curves from the plots unless
`cfg.plot_diag_methods = true`.

If no explicit method preference or visual-inspection choice is recorded, the
inspection flow falls back to `middleCurve` only as the initial default.
After visual inspection, that default should be replaced by the method the
user actually selected for the dataset under study.

Use `cfg.selected_method` in `stdy/runOcvModellingInspection.m` to record the
chosen method in the inspection summary. Example:

```matlab
cfg.selected_method = 'socAverage';
```

Then use the same engine in the final identification run:

```matlab
cfg.engine = 'socAverage';
```

`stdy/runOcvModellingInspection.m` enables local figure saving by default.
Saved visual-inspection figures are written under `results/figures/ocv/...`
and are referenced from the promoted JSON and Markdown summaries under
`results/ocv/...`.

## Notes

- `ocv_id` owns generic OCV modelling, not full-cell dynamic identification.
- Released family-specific full models still belong in `models/`.
- Reusable OCV models remain in `data/modelling/derived/ocv_models/...`.
- The study scripts in `stdy/` are for inspection and method selection, not for storing canonical artifacts.
