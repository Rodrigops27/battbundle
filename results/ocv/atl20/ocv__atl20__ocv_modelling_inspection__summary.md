# OCV Modelling Inspection Summary

- layer: `ocv`
- suite: `atl20`
- scenario: `ocv_modelling_inspection`
- generated: `2026-04-04T15:54:37+02:00`
- promoted JSON: `results/ocv/atl20/ocv__atl20__ocv_modelling_inspection__summary.json`
- promoted Markdown: `results/ocv/atl20/ocv__atl20__ocv_modelling_inspection__summary.md`
- figure root: `results/figures/ocv/atl20/ocv_modelling_inspection`

## Decision Record

- selected/default method: `Middle curve`
- engine: `middleCurve`
- diag type: `n/a`
- selection source: `default`
- rationale: No explicit OCV method preference or visual-inspection choice was provided; defaulted to middleCurve.

## Reference Metrics Note

Reference metrics are method-relative metrics computed against a reconstructed OCV reference (middleCurve by default). They are not absolute physical-ground-truth OCV error metrics.
- metrics reference method: `middlecurve`

## Inputs

- cell id: `ATL20`
- data prefix: `ATL`
- OCV data input: `data/modelling/processed/ocv/atl20`
- temperatures (degC): `[-25 -15 -5 5 15 25 35 45]`

### Dataset Files

| temp_degC | source_file |
| --- | --- |
| -25 | data/modelling/processed/ocv/atl20/ATL_OCV_N25.mat |
| -15 | data/modelling/processed/ocv/atl20/ATL_OCV_N15.mat |
| -5 | data/modelling/processed/ocv/atl20/ATL_OCV_N05.mat |
| 5 | data/modelling/processed/ocv/atl20/ATL_OCV_P05.mat |
| 15 | data/modelling/processed/ocv/atl20/ATL_OCV_P15.mat |
| 25 | data/modelling/processed/ocv/atl20/ATL_OCV_P25.mat |
| 35 | data/modelling/processed/ocv/atl20/ATL_OCV_P35.mat |
| 45 | data/modelling/processed/ocv/atl20/ATL_OCV_P45.mat |

## Evaluated Methods

| rank | selected | display_name | engine | diag_type | plot_enabled | mean_rmse_mv | max_rmse_mv | mean_error_mv | mean_mae_mv | max_abs_error_mv | case_count |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | true | Middle curve | middleCurve |  | true | 61.2282 | 290.487 | -5.70688 | 40.6336 | 684.504 | 8 |
| 2 | false | Vavg | voltageAverage |  | true | 62.9517 | 283.863 | -6.6718 | 40.3473 | 678.38 | 8 |
| 3 | false | SOCavg | socAverage |  | true | 67.9592 | 272.967 | -7.29439 | 46.3994 | 683.243 | 8 |
| 4 | false | Resistance blend | resistanceBlend |  | true | 116.718 | 356.148 | -5.52112 | 72.6791 | 825.026 | 8 |
| 5 | false | Diag useDis | diagAverage | useDis | false | 36762.1 | 77516.6 | -1694.69 | 3401.11 | 1.06002e+06 | 8 |
| 6 | false | Diag useAvg | diagAverage | useAvg | false | 713191 | 1.55084e+06 | -96816.2 | 107638 | 1.55145e+07 | 8 |
| 7 | false | Diag useChg | diagAverage | useChg | false | 1.42424e+06 | 3.10058e+06 | -191938 | 211900 | 3.1028e+07 | 8 |

## Saved Figures

| temp_degC | saved_figure |
| --- | --- |
| -25 | results/figures/ocv/atl20/ocv_modelling_inspection/atl20_ocv_methods_N25.png |
| -15 | results/figures/ocv/atl20/ocv_modelling_inspection/atl20_ocv_methods_N15.png |
| -5 | results/figures/ocv/atl20/ocv_modelling_inspection/atl20_ocv_methods_N05.png |
| 5 | results/figures/ocv/atl20/ocv_modelling_inspection/atl20_ocv_methods_P05.png |
| 15 | results/figures/ocv/atl20/ocv_modelling_inspection/atl20_ocv_methods_P15.png |
| 25 | results/figures/ocv/atl20/ocv_modelling_inspection/atl20_ocv_methods_P25.png |
| 35 | results/figures/ocv/atl20/ocv_modelling_inspection/atl20_ocv_methods_P35.png |
| 45 | results/figures/ocv/atl20/ocv_modelling_inspection/atl20_ocv_methods_P45.png |

## Reproducibility

Run the default inspection workflow with:

```matlab
addpath(genpath('.'));
run(fullfile('ocv_id', 'stdy', 'runOcvModellingInspection.m'));
```

The run recorded this effective configuration:

- `ocv_data_input`: `data/modelling/processed/ocv/atl20`
- `data_prefix`: `ATL`
- `cell_id`: `ATL20`
- `desired_temperatures`: `[]`
- `reference_ocv_method`: `middleCurve`
- `plot_diag_methods`: `false`
- `save_inspection_figures`: `true`
- `inspection_figure_format`: `png`
- `selected_method`: `[default middleCurve]`
