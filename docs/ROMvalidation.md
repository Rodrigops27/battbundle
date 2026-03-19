# ROM Model Validation

This document describes the validation framework for retuned Reduced Order Model (ROM) variants and their performance against the ESC models from which they were derived.

## Overview

ROM validation tests the accuracy of simplified electrochemical models that approximate the full ESC model dynamics. The retuned ROMs use Open-Circuit Voltage (OCV) data extracted from the corresponding ESC models but retain the base ROM's internal RC network and dynamics.

## Validation Methodology

### Approach
1. **Synthetic Data Generation:** Create a reference current profile (legacy script-1) from ESC model capacity
2. **Dual Simulation:** Run both the source ESC model and retuned ROM with identical:
   - Current input
   - Temperature (25°C)
   - Initial SOC (100%)
   - Sample time (native to ROM)
3. **Metric Computation:** Compare voltage and SOC outputs using RMSE, correlation, and other metrics

### Key Metrics
- **Voltage RMSE:** Root-mean-square error between ESC and ROM terminal voltages (primary metric)
- **Voltage Mean Error (ME):** Bias indicator showing systematic over/underestimation
- **Voltage Correlation:** Linear relationship between ESC and ROM voltages
- **SOC RMSE:** State-of-charge tracking error as percentage
- **MSSD:** Mean-squared spectral density for signal fidelity comparison

## Validation Results (March 19, 2026)

### ROM_OMT8_beta
**Source Model:** OMTLIFE battery ESC model  
**OCV Temperature:** 25.0°C  
**Base ROM:** ROM_NMC30_HRA (NMC 18650 dynamics)  

| Metric | Value |
|--------|-------|
| **Capacity** | 8.000 Ah |
| **Voltage RMSE** | 81.57 mV |
| **Voltage Mean Error** | -74.75 mV |
| **Voltage Max Abs Error** | 144.99 mV |
| **Voltage Correlation** | 0.9566 |
| **SOC RMSE** | 40.46% |
| **SOC Mean Error** | -34.69% |
| **Data Points** | 8,250 samples |
| **Current Range** | 0 to 12 A (max 1.5C) |

**Linear Fit:** $V_{ROM} = 0.2953 \times V_{ESC} + 2.3760$

**Analysis:**
- Voltage correlation is strong (0.9566), indicating the ROM captures ESC voltage trends
- Negative mean error (-74.75 mV) indicates ROM tends to underestimate voltage, consistent with the fit slope < 0.3
- Large SOC error (40.46%) reflects significant differences in charge separation dynamics between ESC and ROM models
- The poor voltage fit (slope 0.2953) suggests the ROM's capacity or reference voltage differs significantly from the ESC model
- Trade-off: ROM provides computational speed but sacrifices voltage and SOC accuracy for this chemistry

### ROM_ATL20_beta
**Source Model:** ATL battery ESC model  
**OCV Temperature:** 25.0°C  
**Base ROM:** ROM_NMC30_HRA (NMC 18650 dynamics)  

| Metric | Value |
|--------|-------|
| **Capacity** | 19.183 Ah |
| **Voltage RMSE** | 101.67 mV |
| **Voltage Mean Error** | -91.41 mV |
| **Voltage Max Abs Error** | 229.45 mV |
| **Voltage Correlation** | 0.9586 |
| **SOC RMSE** | 19.76% |
| **SOC Mean Error** | -16.95% |
| **Data Points** | 8,250 samples |
| **Current Range** | 0 to 28.774 A (max 1.5C) |

**Linear Fit:** $V_{ROM} = 0.6774 \times V_{ESC} + 1.1337$

**Analysis:**
- Similar voltage correlation (0.9586) but slightly higher RMSE due to larger battery size and dynamic range
- Negative mean error (-91.41 mV) indicates systematic ROM underestimation, though slope is better than OMT8 (0.6774 vs 0.2953)
- Lower SOC error (19.76% vs 40.46%) suggests ATL cell dynamics are better represented by the NMC-based ROM model
- ATL model shows more consistent scaling between ESC and ROM outputs
- Higher dynamic voltage range (229.45 mV max error) due to larger capacity handling higher currents

## Comparative Summary

| Model | Voltage RMSE | Voltage ME | SOC RMSE | Correlation | Fit Slope |
|-------|-------------|-----------|---------|------------|----------|
| ROM_OMT8_beta | 81.57 mV | -74.75 mV | 40.46% | 0.9566 | 0.2953 |
| ROM_ATL20_beta | 101.67 mV | -91.41 mV | 19.76% | 0.9586 | 0.6774 |

## Observations

### Voltage Accuracy
1. **OMT8 advantages:** Smaller battery size results in lower absolute voltage error (81.57 vs 101.67 mV)
2. **ATL20 advantages:** Better linear correspondence with ESC model (fit slope closer to unity)
3. **Common issue:** Both ROM variants underestimate voltage relative to their source ESC models
4. **Cause hypothesis:** ROM's simplified electrode/electrolyte physics may not fully capture OCV hysteresis or temperature dependencies present in the detailed ESC model

### SOC Tracking
1. **OMT8 struggles:** Large SOC divergence (40.46%) indicates poor coulomb-counting fidelity
2. **ATL20 performs better:** More reasonable SOC error (19.76%) suggests better chemistry-to-NMC correspondence
3. **Root cause:** ROM state dynamics derive from NMC 18650 base model; both ATL and OMTLIFE are pouch cells with different internal structures

### Model Fitness
- **OMT8 verdict:** ROM dynamics poorly matched to OMTLIFE chemistry; recommend obtaining OMTLIFE-specific ROM or using full ESC model
- **ATL20 verdict:** Reasonable approximation for power-level applications; acceptable for computational speed trade-off when voltage errors < 100 mV are tolerable

## Recommendations

### For Users Requiring High Accuracy
- Use full ESC models (ATLmodel.mat, OMTLIFEmodel.mat) for applications requiring:
  - Device-specific voltage prediction (< 50 mV error)
  - Accurate SOC estimation from coulomb counting
  - Fast transient response simulation

### For Users Prioritizing Computational Speed
- **ROM_ATL20_beta:** Suitable for:
  - Battery pack-level simulations where individual cell variations dominate
  - Long-horizon planning with many simulations
  - Trade-off: ±100 mV voltage error, ±20% SOC error acceptable
  
- **ROM_OMT8_beta:** Not recommended for production use without further refinement
  - Consider obtaining OMTLIFE-specific ROM training data
  - Or use full ESC model despite computational cost

### Future Improvements
1. Train ROM base model on actual ATL/OMTLIFE impedance data
2. Include temperature-dependent OCV retuning (currently fixed at 25°C)
3. Validate ROM models on real measured data (currently synthetic ESC-derived reference)
4. Investigate ROM state initialization and coulomb-counting drift mechanisms

## Technical Details

### Validation Dataset
- **Source:** Legacy script-1 dynamic profile (90% to 10% SOC discharge)
- **Duration:** 8,250 samples at 1-second intervals
- **Current:** C-rate normalized discharge from zero to peak, then return to partial rest
- **Rationale:** Same profile as ESC_Id validation for consistency; simulated rather than measured

### Model Files Used
- **ROM_OMT8_beta.mat:** Created from ROM_NMC30_HRA.mat + OMTLIFEmodel.mat OCV
- **ROM_ATL20_beta.mat:** Created from ROM_NMC30_HRA.mat + ATLmodel.mat OCV
- **Location:** models/ folder (same as ESC models)
- **Date Created:** March 19, 2026

## Usage

### Run Validation Harness
```matlab
cd models/TunedModels
validate_rom_models
extract_rom_results  % For formatted output
```

### Plot Results (Anytime)

The plotting function is decoupled from the validation harness, allowing you to visualize results at any time without re-running validation.

#### Plot During Validation
```matlab
cfg = struct();
cfg.rom_file = 'models/ROM_ATL20_beta.mat';
cfg.esc_model_file = 'models/ATLmodel.mat';
cfg.tc = 25;
cfg.soc_init = 100;
cfg.show_plots = true;  % Shows plots immediately after validation

result = retuningROMVal(cfg);
```

#### Plot Saved Results
After running validation and saving results to `ROM_validation_results.mat`, load and visualize anytime:

```matlab
% Load previous validation results
cd models/TunedModels
load('ROM_validation_results.mat');

% Plot ROM_OMT8_beta results
plotRomValidation(result_omt);

% Plot ROM_ATL20_beta results
plotRomValidation(result_atl);
```

#### Custom ROM Validation and Plotting
```matlab
% Run validation for a custom ROM
cfg = struct();
cfg.rom_file = 'models/ROM_ATL20_beta.mat';
cfg.esc_model_file = 'models/ATLmodel.mat';
cfg.tc = 25;
cfg.soc_init = 100;
cfg.show_plots = false;  % Don't auto-plot

result = retuningROMVal(cfg);

% Inspect metrics first
fprintf('Voltage RMSE: %.2f mV\n', 1000 * result.voltage_rmse_v);
fprintf('SOC RMSE: %.4f%%\n', 100 * result.soc_rmse);

% Create plots manually if satisfied
plotRomValidation(result);

% Save for later
save('my_rom_validation.mat', 'result');
```

### Plotting Function Reference

The `plotRomValidation` function creates two comprehensive figures:

**Figure 1: Current and SOC Analysis**
- Current profile (normalized from 100% to ~10% SOC)
- SOC overlay: ESC model vs. ROM vs. error trace
- Useful for identifying coulomb-counting drift and state tracking mismatch

**Figure 2: Voltage Analysis**
- Voltage overlay: ESC model vs. ROM
- Voltage error time trace
- Voltage correlation scatter plot with linear fit
- Color-coded by time for transient analysis

### Batch Plotting All Results
```matlab
clear
cd models/TunedModels
load('ROM_validation_results.mat');

models_to_plot = {'ROM_OMT8_beta', 'ROM_ATL20_beta'};
results = {result_omt, result_atl};

for idx = 1:numel(results)
    fprintf('Plotting %s...\n', models_to_plot{idx});
    plotRomValidation(results{idx});
end
```

## References

- Validation harness: `models/TunedModels/validate_rom_models.m`
- ROM creation: `models/TunedModels/build_rom_models.m`
- ROM retuning function: `models/TunedModels/retuningROM.m`
- Validation function: `models/TunedModels/retuningROMVal.m`
- ESC validation reference: `docs/models.md`
