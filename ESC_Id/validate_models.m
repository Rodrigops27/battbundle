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
        fullfile('data', 'modelling', 'processed', 'dynamic', 'atl20', 'ATL_DYN_40_P25.mat'), ...
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
        fullfile('data', 'modelling', 'processed', 'dynamic', 'nmc30', 'NMC30_DYN_P25.mat'), ...
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
        fullfile('data', 'evaluation', 'raw', 'omtlife8ahc_hp', 'Bus_CoreBatteryData_Data.mat'), ...
        false);
    fprintf('OMT8 validation completed\n');
    fprintf('  First case RMSE: %.2f mV\n\n', result_omt.cases(1).metrics.voltage_rmse_mv);
catch ME
    fprintf('OMT8 validation failed: %s\n\n', ME.message);
    result_omt = [];
end

results_file = fullfile(repo_root, 'data', 'modelling', 'derived', 'validation_results', 'esc', 'ESC_validation_results.mat');
results_dir = fileparts(results_file);
if exist(results_dir, 'dir') ~= 7
    mkdir(results_dir);
end
esc_validation_results = struct();
esc_validation_results.kind = 'esc_validation_results';
esc_validation_results.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
esc_validation_results.entries = struct( ...
    'name', {'atl', 'nmc30', 'omtlife8ahc_hp'}, ...
    'result', {result_atl, result_nmc, result_omt}, ...
    'source_dataset', { ...
        fullfile('data', 'modelling', 'processed', 'dynamic', 'atl20', 'ATL_DYN_40_P25.mat'), ...
        fullfile('data', 'modelling', 'processed', 'dynamic', 'nmc30', 'NMC30_DYN_P25.mat'), ...
        fullfile('data', 'evaluation', 'raw', 'omtlife8ahc_hp', 'Bus_CoreBatteryData_Data.mat')} ...
    );
save(results_file, 'esc_validation_results', 'result_atl', 'result_nmc', 'result_omt');
fprintf('\nValidation complete. Results saved to %s\n', results_file);
