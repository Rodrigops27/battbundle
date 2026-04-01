% Extract validation results for documentation
addpath(genpath('.'));

results_file = fullfile('data', 'modelling', 'derived', 'validation_results', 'esc', 'ESC_validation_results.mat');
loaded = load(results_file);

if isfield(loaded, 'esc_validation_results')
    result_atl = findValidationResult(loaded.esc_validation_results, 'atl');
    result_nmc = findValidationResult(loaded.esc_validation_results, 'nmc30');
    result_omt = findValidationResult(loaded.esc_validation_results, 'omtlife8ahc_hp');
else
    result_atl = fieldOr(loaded, 'result_atl', []);
    result_nmc = fieldOr(loaded, 'result_nmc', []);
    result_omt = fieldOr(loaded, 'result_omt', []);
end

fprintf('=== ESC Model Validation Results ===\n\n');

% ATL Results
if ~isempty(result_atl)
    fprintf('ATL Model (models/ATLmodel.mat with data/modelling/processed/dynamic/atl20/ATL_DYN_40_P25.mat):\n');
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
    fprintf('NMC30 Model (data/modelling/processed/dynamic/nmc30/NMC30_DYN_P25.mat):\n');
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
    fprintf('OMT8 Model (data/evaluation/raw/omtlife8ahc_hp/Bus_CoreBatteryData_Data.mat):\n');
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

function result = findValidationResult(bundle, entry_name)
result = [];
if ~isstruct(bundle) || ~isfield(bundle, 'entries') || isempty(bundle.entries)
    return;
end

for idx = 1:numel(bundle.entries)
    if isfield(bundle.entries(idx), 'name') && strcmpi(char(bundle.entries(idx).name), entry_name)
        result = bundle.entries(idx).result;
        return;
    end
end
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end
