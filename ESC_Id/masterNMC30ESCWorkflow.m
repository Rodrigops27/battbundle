% masterNMC30ESCWorkflow.m
% Master script to execute the complete NMC30 ESC modeling and SOC comparison
% 
% This script runs in sequence:
%   1. OCV comparison and NMC30 model creation
%   2. Parameter identification (demonstration)
%   3. SOC estimation comparison
%   4. Results summary

clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
ecm_root = fileparts(script_dir);
results_file = fullfile(ecm_root, 'results_NMC30_SOC_comparison.mat');

fprintf('\n');
fprintf('================================================================\n');
fprintf('   NMC30 ESC Model Creation and SOC Estimation Comparison\n');
fprintf('================================================================\n\n');

%% STEP 1: Create OCV Model from ROM
fprintf('STEP 1/3: Create NMC30 OCV Model from ROM\n');
fprintf('  Running: createNMC30Model.m\n');
fprintf('  This creates NMC30model-ocv.mat with OCV curve\n');
fprintf('  (about 10 seconds)...\n\n');

try
    createNMC30Model;
    fprintf('\n✓ OCV model creation complete\n');
    fprintf('  - Output: %s\n\n', fullfile(script_dir, 'NMC30model-ocv.mat'));
    pause(2);
catch ME
    fprintf('\n✗ Error with createNMC30Model %s\n', ME.message);
    return;
end

%% STEP 2: Full Parameter Identification
fprintf('STEP 2/3: Full Parameter Identification (processDynamic)\n');
fprintf('  Running: fullParameterIdentificationNMC30.m\n');
fprintf('  This identifies R0, R, RC, G, M0, M parameters\n');
fprintf('  (about 1-3 minutes)...\n\n');

try
    fullParameterIdentificationNMC30;
    fprintf('\n✓ Parameter identification complete\n');
    fprintf('  - Output: %s (FULL model)\n\n', fullfile(script_dir, 'NMC30model.mat'));
    pause(2);
catch ME
    fprintf('\n✗ Error with fullParameterIdentificationNMC30 : %s\n', ME.message);
    return;
end

%% STEP 3: SOC Estimation Comparison
fprintf('STEP 3/3: SOC Estimation Comparison\n');
fprintf('  Running: runNMC30SOCComparison.m\n');
fprintf('  This will simulate fast-charge and compare 3 SOC methods\n');
fprintf('  Estimated runtime: 5-10 minutes\n\n');

try
    runNMC30SOCComparison;
    fprintf('\n✓ SOC estimation complete\n');
    fprintf('  - Output: %s\n\n', results_file);
    pause(2);
catch ME
    fprintf('\n✗ Error in SOC estimation: %s\n', ME.message);
    fprintf('  Check that all required files are present\n\n');
end

%% SUMMARY
fprintf('================================================================\n');
fprintf('   WORKFLOW SUMMARY (3 Steps)\n');
fprintf('================================================================\n\n');

fprintf('Steps executed:\n');
fprintf('  Step 1: Create NMC30 OCV model from ROM → NMC30model-ocv.mat\n');
fprintf('  Step 2: Parameter identification via processDynamic → NMC30model.mat\n');
fprintf('  Step 3: SOC estimation comparison → results_NMC30_SOC_comparison.mat\n\n');

fprintf('Files generated:\n');
fprintf('  1. %s\n', fullfile(script_dir, 'NMC30model-ocv.mat'));
fprintf('     - OCV curve from ROM\n');
fprintf('     - RC template parameters\n');
fprintf('     - Capacity = 30 Ah\n\n');

fprintf('  2. %s (FULL model)\n', fullfile(script_dir, 'NMC30model.mat'));
fprintf('     - OCV curve from ROM\n');
fprintf('     - Identified R0, R, RC parameters via processDynamic\n');
fprintf('     - Hysteresis parameters (G, M0, M)\n');
fprintf('     - Capacity = 30 Ah\n\n');

fprintf('  3. %s\n', results_file);
fprintf('     - SOC estimates from 3 methods\n');
fprintf('     - Performance metrics (RMSE, max error)\n');
fprintf('     - Time-domain results\n\n');

fprintf('Next steps:\n');
fprintf('  1. Check %s exists (full model)\n', fullfile(script_dir, 'NMC30model.mat'));
fprintf('  2. Review SOC comparison results in %s\n', results_file);
fprintf('  3. For multi-temperature model:\n');
fprintf('     >> Repeat fullParameterIdentificationNMC30 at T = 5, 15, 35, 45°C\n');
fprintf('     >> Merge results into single NMC30model with temps=[5,15,25,35,45]\n');
fprintf('  4. Integrate ESC-SPKF into fast-charge controller\n\n');

fprintf('For detailed information, see:\n');
fprintf('   - README_NMC30_ESC.md\n\n');

fprintf('================================================================\n');
fprintf('   Workflow Complete\n');
fprintf('================================================================\n\n');

% Check for full model
if exist(fullfile(script_dir, 'NMC30model.mat'), 'file')
    fprintf('✓ FULL identified model created successfully\n');
    fprintf('  Use this for best SOC estimation accuracy\n');
elseif exist(fullfile(script_dir, 'NMC30model-ocv.mat'), 'file')
    fprintf('⚠ Only OCV-only model available\n');
    fprintf('  Run: fullParameterIdentificationNMC30\n');
    fprintf('  to get full identified model for better accuracy\n');
end

fprintf('\nModel files available:\n');
if exist(fullfile(script_dir, 'NMC30model.mat'), 'file')
    fprintf('   - NMC30model.mat (FULL, RECOMMENDED)\n');
end
if exist(fullfile(script_dir, 'NMC30model-ocv.mat'), 'file')
    fprintf('   - NMC30model-ocv.mat (OCV + template RC)\n');
end

if exist(results_file, 'file')
    fprintf('\nResults available:\n');
    fprintf('   - %s\n', results_file);
    fprintf('   Load with: load(''%s'')\n', results_file);
end

fprintf('\n================================================================\n\n');
