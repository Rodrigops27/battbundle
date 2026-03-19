% ROM validation harness - validates retuned ROM models against their source ESC models
% Follows the same pattern as ESC_Id/validate_models.m

script_dir = fileparts(mfilename('fullpath'));
models_dir = fileparts(script_dir);
repo_root = fileparts(models_dir);
results_file = fullfile(script_dir, 'ROM_validation_results.mat');

addpath(genpath(repo_root));

fprintf('Starting ROM Model Validation...\n\n');

% Validation 1: ROM_OMT8_beta
fprintf('Validating ROM_OMT8_beta.mat against OMTLIFEmodel.mat...\n');
try
    cfg_omt = struct();
    cfg_omt.rom_file = fullfile(models_dir, 'ROM_OMT8_beta.mat');
    cfg_omt.esc_model_file = fullfile(models_dir, 'OMTLIFEmodel.mat');
    cfg_omt.tc = 25;
    cfg_omt.ts = [];  % Use ROM native sample time
    cfg_omt.soc_init = 100;
    cfg_omt.show_plots = false;
    
    result_omt = retuningROMVal(cfg_omt);
    fprintf('✓ OMT8 validation completed\n');
    fprintf('  Voltage RMSE: %.2f mV\n', 1000 * result_omt.voltage_rmse_v);
    fprintf('  SOC RMSE: %.4f%%\n\n', 100 * result_omt.soc_rmse);
catch ME
    fprintf('✗ OMT8 validation failed: %s\n\n', ME.message);
    result_omt = [];
end

% Validation 2: ROM_ATL20_beta
fprintf('Validating ROM_ATL20_beta.mat against ATLmodel.mat...\n');
try
    cfg_atl = struct();
    cfg_atl.rom_file = fullfile(models_dir, 'ROM_ATL20_beta.mat');
    cfg_atl.esc_model_file = fullfile(models_dir, 'ATLmodel.mat');
    cfg_atl.tc = 25;
    cfg_atl.ts = [];  % Use ROM native sample time
    cfg_atl.soc_init = 100;
    cfg_atl.show_plots = false;
    
    result_atl = retuningROMVal(cfg_atl);
    fprintf('✓ ATL20 validation completed\n');
    fprintf('  Voltage RMSE: %.2f mV\n', 1000 * result_atl.voltage_rmse_v);
    fprintf('  SOC RMSE: %.4f%%\n\n', 100 * result_atl.soc_rmse);
catch ME
    fprintf('✗ ATL20 validation failed: %s\n\n', ME.message);
    result_atl = [];
end

% Save results
save(results_file, 'result_omt', 'result_atl');
fprintf('\nValidation complete. Results saved to %s\n', results_file);
