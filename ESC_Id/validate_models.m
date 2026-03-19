% Validate three ESC models with temperature debugging
addpath(genpath('.'));

fprintf('Starting ESC Model Validation...\n\n');

% Validation 1: ATL model
fprintf('Validating ATLmodel.mat with ATL_DYN_40_P25.mat...\n');
try
    result_atl = ESCvalidation(...
        fullfile('models', 'ATLmodel.mat'), ...
        fullfile('ESC_Id', 'DYN_Files', 'ATL_DYN', 'ATL_DYN_40_P25.mat'), ...
        false);
    fprintf('✓ ATL validation completed\n');
    fprintf('  First case RMSE: %.2f mV\n\n', result_atl.cases(1).metrics.voltage_rmse_mv);
catch ME
    fprintf('✗ ATL validation failed: %s\n\n', ME.message);
    result_atl = [];
end

% Validation 2: NMC30 model
fprintf('Validating NMC30model.mat with rom_script1_dataset.mat...\n');
try
    result_nmc = ESCvalidation(...
        fullfile('models', 'NMC30model.mat'), ...
        fullfile('ESC_Id', 'NMC30', 'ROMSimData', 'rom_script1_dataset.mat'), ...
        false);
    fprintf('✓ NMC30 validation completed\n');
    fprintf('  First case RMSE: %.2f mV\n\n', result_nmc.cases(1).metrics.voltage_rmse_mv);
catch ME
    fprintf('✗ NMC30 validation failed: %s\n\n', ME.message);
    result_nmc = [];
end

% Validation 3: OMTLIFE model - try with ESC_Id version first
fprintf('Validating OMTLIFEmodel.mat (ESC_Id version) with Bus_CoreBatteryData_Data.mat...\n');
try
    result_omt = ESCvalidation(...
        fullfile('ESC_Id', 'OMTLIFE8AHC-HP', 'OMTLIFEmodel.mat'), ...
        fullfile('Evaluation', 'OMTLIFE8AHC-HP', 'Bus_CoreBatteryData_Data.mat'), ...
        false);
    fprintf('✓ OMTLIFE (ESC_Id) validation completed\n');
    fprintf('  First case RMSE: %.2f mV\n\n', result_omt.cases(1).metrics.voltage_rmse_mv);
catch ME
    fprintf('✗ OMTLIFE (ESC_Id) validation failed: %s\n', ME.message);
    fprintf('  Trying models folder version...\n');
    try
        result_omt = ESCvalidation(...
            fullfile('models', 'OMTLIFEmodel.mat'), ...
            fullfile('Evaluation', 'OMTLIFE8AHC-HP', 'Bus_CoreBatteryData_Data.mat'), ...
            false);
        fprintf('✓ OMTLIFE (models) validation completed\n');
        fprintf('  First case RMSE: %.2f mV\n\n', result_omt.cases(1).metrics.voltage_rmse_mv);
    catch ME2
        fprintf('✗ OMTLIFE (models) validation also failed: %s\n\n', ME2.message);
        result_omt = [];
    end
end

% Save results
save('ESC_validation_results.mat', 'result_atl', 'result_nmc', 'result_omt');
fprintf('\nValidation complete. Results saved to ESC_validation_results.mat\n');
