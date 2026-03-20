% Extract ROM validation results for documentation
addpath(genpath('.'));

load('ROM_validation_results.mat');

fprintf('=== ROM Model Validation Results ===\n\n');

% OMT8 Results
if ~isempty(result_omt)
    fprintf('ROM_OMT8_beta (from OMTLIFEmodel.mat, base: ROM_NMC30_HRA):\n');
    fprintf('  Temperature: %.1f degC\n', result_omt.tc);
    fprintf('  Capacity: %.3f Ah\n', result_omt.capacity_ah);
    fprintf('  Voltage RMSE: %.2f mV\n', 1000 * result_omt.voltage_rmse_v);
    fprintf('  Voltage Mean Error: %.2f mV\n', 1000 * result_omt.voltage_me_v);
    fprintf('  Voltage Max Error: %.2f mV\n', 1000 * result_omt.voltage_max_abs_error_v);
    fprintf('  Voltage Correlation: %.4f\n', result_omt.voltage_corr);
    fprintf('  SOC RMSE: %.4f%%\n', 100 * result_omt.soc_rmse);
    fprintf('  SOC Mean Error: %.4f%%\n', 100 * result_omt.soc_me);
    fprintf('  Sample Count: %d samples\n', numel(result_omt.time_s));
    fprintf('\n');
end

% ATL20 Results
if ~isempty(result_atl)
    fprintf('ROM_ATL20_beta (from ATLmodel.mat, base: ROM_NMC30_HRA):\n');
    fprintf('  Temperature: %.1f degC\n', result_atl.tc);
    fprintf('  Capacity: %.3f Ah\n', result_atl.capacity_ah);
    fprintf('  Voltage RMSE: %.2f mV\n', 1000 * result_atl.voltage_rmse_v);
    fprintf('  Voltage Mean Error: %.2f mV\n', 1000 * result_atl.voltage_me_v);
    fprintf('  Voltage Max Error: %.2f mV\n', 1000 * result_atl.voltage_max_abs_error_v);
    fprintf('  Voltage Correlation: %.4f\n', result_atl.voltage_corr);
    fprintf('  SOC RMSE: %.4f%%\n', 100 * result_atl.soc_rmse);
    fprintf('  SOC Mean Error: %.4f%%\n', 100 * result_atl.soc_me);
    fprintf('  Sample Count: %d samples\n', numel(result_atl.time_s));
    fprintf('\n');
end

fprintf('=== Summary Table ===\n');
fprintf('Model             | Capacity | V RMSE (mV) | V ME (mV) | V Corr | SOC RMSE (%%)\n');
fprintf('%-17s | %8.3f | %11.2f | %9.2f | %6.4f | %12.4f\n', 'ROM_OMT8_beta', ...
    result_omt.capacity_ah, 1000 * result_omt.voltage_rmse_v, 1000 * result_omt.voltage_me_v, ...
    result_omt.voltage_corr, 100 * result_omt.soc_rmse);
fprintf('%-17s | %8.3f | %11.2f | %9.2f | %6.4f | %12.4f\n', 'ROM_ATL20_beta', ...
    result_atl.capacity_ah, 1000 * result_atl.voltage_rmse_v, 1000 * result_atl.voltage_me_v, ...
    result_atl.voltage_corr, 100 * result_atl.soc_rmse);
