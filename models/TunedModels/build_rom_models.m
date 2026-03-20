% Build ROM models from ESC models using retuning
% This script creates ROM_OMT8_beta.mat and ROM_ATL20_beta.mat

addpath(genpath('.'));

fprintf('Starting ROM Model Creation...\n\n');

script_dir = fileparts(mfilename('fullpath'));
models_dir = fileparts(script_dir);  % models_dir is now the models folder
repo_root = fileparts(models_dir);   % repo_root is the main project root

% ROM 1: OMT8 model from OMTLIFE ESC
fprintf('Creating ROM_OMT8_beta.mat from OMTLIFEmodel.mat...\n');
try
    cfg_omt = struct();
    cfg_omt.base_rom_file = fullfile(models_dir, 'ROM_NMC30_HRA.mat');
    cfg_omt.esc_model_file = fullfile(models_dir, 'OMTLIFEmodel.mat');
    cfg_omt.tc = 25;
    
    rom_omt = retuningROM(...
        fullfile(models_dir, 'ROM_OMT8_beta.mat'), ...
        cfg_omt);
    fprintf('✓ ROM_OMT8_beta.mat created successfully\n\n');
catch ME
    fprintf('✗ ROM_OMT8_beta creation failed: %s\n\n', ME.message);
    rom_omt = [];
end

% ROM 2: ATL20 model from ATL ESC
fprintf('Creating ROM_ATL20_beta.mat from ATLmodel.mat...\n');
try
    cfg_atl = struct();
    cfg_atl.base_rom_file = fullfile(models_dir, 'ROM_NMC30_HRA.mat');
    cfg_atl.esc_model_file = fullfile(models_dir, 'ATLmodel.mat');
    cfg_atl.tc = 25;
    
    rom_atl = retuningROM(...
        fullfile(models_dir, 'ROM_ATL20_beta.mat'), ...
        cfg_atl);
    fprintf('✓ ROM_ATL20_beta.mat created successfully\n\n');
catch ME
    fprintf('✗ ROM_ATL20_beta creation failed: %s\n\n', ME.message);
    rom_atl = [];
end

fprintf('ROM model creation complete\n');
