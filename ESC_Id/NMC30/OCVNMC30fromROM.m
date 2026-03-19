% OCVNMC30fromROM.m
% Creates NMC30 ESC model directly from ROM OCV data
% No comparison - directly formats ROM OCV in ESC structure
%
% Outputs:
%   - NMC30model-ocv.mat: NMC30 with OCV from ROM, 30Ah capacity, eta=0.99

clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
nmc30_parent = fileparts(script_dir);  % NMC30/ -> ESC_Id/
repo_root = fileparts(nmc30_parent);    % ESC_Id/ -> bnchmrk/
ocv_output_dir = fullfile(nmc30_parent, 'OCV_Files', 'NMC30');

% Use bnchmrk path setup (root + selected folders and subfolders).
addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'utility')));
addpath(genpath(fullfile(repo_root, 'ESC_Id')));

fprintf('\n');
fprintf('================================================================\n');
fprintf('  Create NMC30 ESC Model from ROM OCV\n');
fprintf('================================================================\n\n');

%% SETTINGS
tc_ref = 25;                      % Temperature [°C]
nmc30_capacity = 30;              % Capacity [Ah]
rom_candidates = {
    fullfile(repo_root, 'models', 'ROM_NMC30_HRA12.mat')
    fullfile(repo_root, 'models', 'ROM_NMC30_HRA.mat')
    fullfile(script_dir, 'ROM_NMC30_HRA12.mat')
    fullfile(script_dir, 'ROM_NMC30_HRA.mat')
};
rom_file = '';
for i = 1:numel(rom_candidates)
    if exist(rom_candidates{i}, 'file')
        rom_file = rom_candidates{i};
        break;
    end
end
if isempty(rom_file)
    error(['ROM file not found. Expected one of:\n  %s\n', ...
           'Tip: in MATLAB use "Set Path > Add with Subfolders" on bnchmrk root.'], ...
          strjoin(rom_candidates, '\n  '));
end

%% STEP 1: Load ROM and extract NMC30 OCV at 25°C
fprintf('Step 1: Load ROM and extract NMC30 OCV\n');
rom_data = load(rom_file, 'ROM');
ROM = rom_data.ROM;
fprintf('  Loaded ROM from: %s\n', rom_file);
Tk = tc_ref + 273.15;

% Create SOC grid
soc_cell = linspace(0, 1, 201).';

% Extract half-cell OCPs
theta_n = ROM.cellData.function.neg.soc(soc_cell, Tk);
theta_p = ROM.cellData.function.pos.soc(soc_cell, Tk);
U_n = ROM.cellData.function.neg.Uocp(theta_n, Tk);
U_p = ROM.cellData.function.pos.Uocp(theta_p, Tk);

% Full cell OCV
nmc30_ocv_rom = U_p - U_n;

fprintf('  ✓ NMC30 OCV range: [%.3f V, %.3f V]\n', min(nmc30_ocv_rom), max(nmc30_ocv_rom));

%% STEP 2: Create NMC30 model in ESC format
fprintf('\nStep 2: Create NMC30 ESC model\n');

nmc30_model = struct();
nmc30_model.temps = tc_ref;
nmc30_model.name = 'NMC30';

% OCV curve at 25°C (using standard ESC temperature format)
% Format: OCV(z,T) = OCV0(z) + (T-0)*OCVrel(z)
% For 25°C only: OCV0 contains actual OCV, OCVrel = 0

soc_octave = (0:0.01:1).';  % 0 to 100% in 1% steps
nmc30_model.SOC = soc_octave;

% Interpolate ROM OCV to standard grid
nmc30_model.OCV0 = interp1(soc_cell, nmc30_ocv_rom, soc_octave, 'spline');
nmc30_model.OCVrel = zeros(size(soc_octave));  % No temperature variation (25°C only)

% Reverse mapping: voltage to SOC
v_grid = linspace(min(nmc30_model.OCV0)-0.5, max(nmc30_model.OCV0)+0.5, 100).';
nmc30_model.OCV = v_grid;
nmc30_model.SOC0 = interp1(nmc30_model.OCV0, nmc30_model.SOC, v_grid, 'linear', 'extrap');
nmc30_model.SOCrel = zeros(size(v_grid));

% Capacity and efficiency
nmc30_model.QParam = nmc30_capacity;
nmc30_model.etaParam = 0.99;  % Placeholder coulombic efficiency
% RCs, R0 and hysteresis will be identified via processDynamic

fprintf('  ✓ Capacity: %.1f Ah\n', nmc30_model.QParam);
fprintf('  ✓ Coulomb efficiency (eta): %.1f (100%%, ideal)\n', nmc30_model.etaParam);
fprintf('  ✓ Temperature: %d °C\n', tc_ref);
fprintf('  ✓ OCV points: %d\n', length(nmc30_model.SOC));

%% STEP 3: Save model
fprintf('\nStep 3: Save NMC30 model\n');

if exist(ocv_output_dir, 'dir') ~= 7
    mkdir(ocv_output_dir);
end
output_file = fullfile(ocv_output_dir, 'NMC30model-ocv.mat');
save(output_file, 'nmc30_model');
fprintf('  ✓ Saved to: %s\n', output_file);

%% STEP 4: Visualization
fprintf('\nStep 4: Plot OCV\n');

figure('Name', 'NMC30 OCV', 'NumberTitle', 'off');
plot(100*nmc30_model.SOC, nmc30_model.OCV0, 'o-', 'LineWidth', 2.5, 'MarkerSize', 3);
grid on;
xlabel('SOC [%]');
ylabel('OCV [V]');
title(sprintf('NMC30 ESC Model OCV at %d°C (Q = %.0f Ah, η = 1.0)', tc_ref, nmc30_capacity));

fprintf('\n');
fprintf('================================================================\n');
fprintf('  NMC30 Model Creation Complete\n');
fprintf('================================================================\n\n');

fprintf('Summary:\n');
fprintf('  Temperature: %d °C\n', tc_ref);
fprintf('  Capacity: %.1f Ah\n', nmc30_model.QParam);
fprintf('  Coulomb efficiency (η): %.1f (ideal, no losses)\n', nmc30_model.etaParam);
fprintf('  OCV source: NMC30 ROM (direct)\n');
fprintf('  RC parameters: Placeholder (will be identified via processDynamic)\n\n');

fprintf('Next steps:\n');
fprintf('  1. Run fullParameterIdentificationNMC30 to identify RC parameters\n');
fprintf('  2. This will create NMC30model.mat with optimized parameters\n');
fprintf('  3. Use NMC30model.mat in runNMC30SOCComparison\n\n');
