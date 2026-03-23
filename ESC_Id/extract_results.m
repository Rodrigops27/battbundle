% Extract validation results for documentation
addpath(genpath('.'));

load('ESC_validation_results.mat');

fprintf('=== ESC Model Validation Results ===\n\n');

% ATL Results
if ~isempty(result_atl)
    fprintf('ATL Model (models/ATLmodel.mat with ESC_Id/DYN_Files/ATL_DYN/ATL_DYN_40_P25.mat):\n');
    fprintf('  Temperature: %.1f degC\n', result_atl.cases(1).tc);
    fprintf('  Voltage RMSE: %.2f mV\n', result_atl.cases(1).metrics.voltage_rmse_mv);
    fprintf('  Voltage Mean Error: %.2f mV\n', result_atl.cases(1).metrics.voltage_mean_error_mv);
    fprintf('  Voltage MAE: %.2f mV\n', result_atl.cases(1).metrics.voltage_mae_mv);
    fprintf('  Voltage Max Error: %.2f mV\n', result_atl.cases(1).metrics.voltage_max_abs_error_mv);
    fprintf('  Sample Count: %d samples\n', result_atl.cases(1).sample_count);
    fprintf('\n');
end

% NMC30 Results
if ~isempty(result_nmc)
    fprintf('NMC30 Model (NMC30_DYN_P25.mat):\n');
    fprintf('  Temperature: %.1f degC\n', result_nmc.cases(1).tc);
    fprintf('  Voltage RMSE: %.2f mV\n', result_nmc.cases(1).metrics.voltage_rmse_mv);
    fprintf('  Voltage Mean Error: %.2f mV\n', result_nmc.cases(1).metrics.voltage_mean_error_mv);
    fprintf('  Voltage MAE: %.2f mV\n', result_nmc.cases(1).metrics.voltage_mae_mv);
    fprintf('  Voltage Max Error: %.2f mV\n', result_nmc.cases(1).metrics.voltage_max_abs_error_mv);
    fprintf('  Sample Count: %d samples\n', result_nmc.cases(1).sample_count);
    fprintf('\n');
end

% OMTLIFE Results
if ~isempty(result_omt)
    fprintf('OMT8 Model (OMT8_DYN_P25.mat):\n');
    fprintf('  Temperature: %.1f degC\n', result_omt.cases(1).tc);
    fprintf('  Voltage RMSE: %.2f mV\n', result_omt.cases(1).metrics.voltage_rmse_mv);
    fprintf('  Voltage Mean Error: %.2f mV\n', result_omt.cases(1).metrics.voltage_mean_error_mv);
    fprintf('  Voltage MAE: %.2f mV\n', result_omt.cases(1).metrics.voltage_mae_mv);
    fprintf('  Voltage Max Error: %.2f mV\n', result_omt.cases(1).metrics.voltage_max_abs_error_mv);
    fprintf('  Sample Count: %d samples\n', result_omt.cases(1).sample_count);
    fprintf('\n');
end

fprintf('=== Summary Table ===\n');
fprintf('Model          | RMSE (mV) | Mean Error (mV) | MAE (mV) | Samples\n');
fprintf('%-14s | %9.2f | %15.2f | %8.2f | %d\n', 'ATL', ...
    result_atl.cases(1).metrics.voltage_rmse_mv, ...
    result_atl.cases(1).metrics.voltage_mean_error_mv, ...
    result_atl.cases(1).metrics.voltage_mae_mv, ...
    result_atl.cases(1).sample_count);
fprintf('%-14s | %9.2f | %15.2f | %8.2f | %d\n', 'NMC30', ...
    result_nmc.cases(1).metrics.voltage_rmse_mv, ...
    result_nmc.cases(1).metrics.voltage_mean_error_mv, ...
    result_nmc.cases(1).metrics.voltage_mae_mv, ...
    result_nmc.cases(1).sample_count);
fprintf('%-14s | %9.2f | %15.2f | %8.2f | %d\n', 'OMTLIFE', ...
    result_omt.cases(1).metrics.voltage_rmse_mv, ...
    result_omt.cases(1).metrics.voltage_mean_error_mv, ...
    result_omt.cases(1).metrics.voltage_mae_mv, ...
    result_omt.cases(1).sample_count);
