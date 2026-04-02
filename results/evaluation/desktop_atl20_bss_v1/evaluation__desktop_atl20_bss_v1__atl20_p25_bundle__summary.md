# Promoted Evaluation Summary

- layer: `evaluation`
- suite: `desktop_atl20_bss_v1`
- scenario: `atl20_p25_bundle`
- generated: `2026-03-30 21:50:25`
- promoted JSON: `results/evaluation/desktop_atl20_bss_v1/evaluation__desktop_atl20_bss_v1__atl20_p25_bundle__summary.json`
- heavy MAT: `Evaluation/results/atl20_p25_bundle_benchmark_results.mat`
- dataset: `data/evaluation/processed/desktop_atl20_bss_v1/nominal/esc_bus_coreBattery_dataset.mat`
- ESC model: `models/ATL20model_P25.mat`
- ROM model: `models/ROM_ATL20_beta.mat`
- figures root: `results/figures/evaluation/desktop_atl20_bss_v1/atl20_p25_bundle`

## Per-Estimator Metrics

| Estimator | SocRmsePct | SocMePct | SocMssdPct2 | VoltageRmseMv | VoltageMeMv | VoltageMssdMv2 |
| --- | --- | --- | --- | --- | --- | --- |
| ROM-EKF | 9.60056 | 0.0581096 | 9.70765e-06 | 48.637 | -4.56458 | 0.0127578 |
| ESC-SPKF | 7.66115 | 7.00769 | 1.90546e-06 | 20.4044 | -1.70884 | 0.110862 |
| ESC-EKF | 8.61489 | 7.67734 | 1.54961e-06 | 12.885 | -1.51866 | 0.0944456 |
| EaEKF | 9.83255 | 8.8946 | 0.00629327 | 0.048231 | -0.00011461 | 0.242079 |
| EacrSPKF | 0.496552 | -0.119247 | 0.000227583 | 1.1706 | 0.23495 | 0.220024 |
| EnacrSPKF | 13.4251 | 9.2333 | 4.84575 | 23.0354 | 17.5394 | 1.79292 |
| EDUKF | 5.64595 | 2.15522 | 0.000386096 | 7.78647 | -0.242871 | 74.4857 |
| EsSPKF | 8.26084 | 7.87508 | 1.66014e-06 | 12.5464 | -0.816255 | 0.248165 |
| EbSPKF | 8.44072 | 7.64159 | 1.96719e-06 | 20.3615 | -0.867619 | 0.110431 |
| EBiSPKF | 7.82221 | 7.38039 | 1.66787e-06 | 12.7241 | -1.4476 | 0.110828 |
| Em7SPKF | 7.59313 | 7.12477 | 1.62622e-06 | 16.1372 | -1.48818 | 0.302911 |

### Practical ranking for this study

This is the tuned nominal benchmark ranking by observed SOC RMSE on the final bundle run:

1. `EacrSPKF`
2. `EDUKF`
3. `Em7SPKF`
4. `ESC-SPKF`
5. `EBiSPKF`
6. `EsSPKF`
7. `EbSPKF`
8. `ESC-EKF`
9. `ROM-EKF`
10. `EaEKF`
11. `EnacrSPKF`

## Observations

- This artifact is the direct nominal benchmark result for the tuned bundle, so it is the cleanest statement of best-case estimator performance on the desktop ATL20 scenario.
- `EacrSPKF` is decisively best on SOC RMSE in this nominal run, and it is the only estimator below `1%`.
- `EDUKF` is second on SOC RMSE, but still well behind `EacrSPKF`.
- The practical mid-tier cluster is again the SPKF family: `Em7SPKF`, `ESC-SPKF`, `EBiSPKF`, `EsSPKF`, and `EbSPKF`.
- `ESC-EKF` is not a top nominal performer in this run despite its strong covariance-sweep best point, so its best-case tuning and its final tuned operating point should not be treated as the same thing.
- `EaEKF` achieves nearly zero voltage RMSE but remains poor on SOC RMSE here, which makes it unattractive if SOC accuracy is the primary objective.
- `EnacrSPKF` remains the weakest estimator in the final tuned benchmark.
