% Validate three ESC models against DYN-style datasets
script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(script_dir);

addpath(genpath(repo_root));

fprintf('Starting ESC Model Validation...\n\n');

% Validation 1: ATL model
fprintf('Validating ATLmodel.mat with ATL_DYN_40_P25.mat...\n');
try
    result_atl = ESCvalidation( ...
        fullfile('models', 'ATLmodel.mat'), ...
        fullfile('ESC_Id', 'DYN_Files', 'ATL_DYN', 'ATL_DYN_40_P25.mat'), ...
        false);
    fprintf('ATL validation completed\n');
    fprintf('  First case RMSE: %.2f mV\n\n', result_atl.cases(1).metrics.voltage_rmse_mv);
catch ME
    fprintf('ATL validation failed: %s\n\n', ME.message);
    result_atl = [];
end

% Validation 2: NMC30 model
fprintf('Validating NMC30model.mat with NMC30_DYN_P25.mat...\n');
try
    result_nmc = ESCvalidation( ...
        fullfile('models', 'NMC30model.mat'), ...
        fullfile('ESC_Id', 'DYN_Files', 'NMC30_DYN', 'NMC30_DYN_P25.mat'), ...
        false);
    fprintf('NMC30 validation completed\n');
    fprintf('  First case RMSE: %.2f mV\n\n', result_nmc.cases(1).metrics.voltage_rmse_mv);
catch ME
    fprintf('NMC30 validation failed: %s\n\n', ME.message);
    result_nmc = [];
end

% Validation 3: OMT8 model
fprintf('Validating OMTLIFEmodel.mat with Bus_CoreBatteryData_Data.mat...\n');
try
    result_omt = ESCvalidation( ...
        fullfile('models', 'OMTLIFEmodel.mat'), ...
        fullfile('Evaluation', 'OMTLIFE8AHC-HP', 'Bus_CoreBatteryData_Data.mat'), ...
        false);
    fprintf('OMT8 validation completed\n');
    fprintf('  First case RMSE: %.2f mV\n\n', result_omt.cases(1).metrics.voltage_rmse_mv);
catch ME
    fprintf('OMT8 validation failed: %s\n\n', ME.message);
    result_omt = [];
end

results_file = fullfile(script_dir, 'ESC_validation_results.mat');
save(results_file, 'result_atl', 'result_nmc', 'result_omt');
fprintf('\nValidation complete. Results saved to %s\n', results_file);
