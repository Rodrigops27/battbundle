% NMC30DynParIdROMsim.m
% Complete parameter identification for NMC30 using processDynamic
% 
% This script:
%   1. Uses OB_step to generate synthetic dynamic test data (discharge profile)
%   2. Formats data in processDynamic input structure
%   3. Calls processDynamic to identify dynamic parameters
%   4. Creates NMC30model.mat with ALL identified parameters
%   5. Validates results with simCell comparison

clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
nmc30_parent = fileparts(script_dir);  % ESC_Id/NMC30 -> ESC_Id/
repo_root = fileparts(nmc30_parent);    % ESC_Id/ -> bnchmrk/
models_output_dir = fullfile(repo_root, 'models');

addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'utility')));
addpath(genpath(fullfile(repo_root, 'ESC_Id')));

fprintf('\n');
fprintf('================================================================\n');
fprintf('  NMC30 Full Parameter Identification via processDynamic\n');
fprintf('================================================================\n\n');

%% ROM File Resolution (defensive pattern)
rom_candidates = {
    fullfile(repo_root, 'models', 'ROM_NMC30_HRA12.mat')
    fullfile(repo_root, 'models', 'ROM_NMC30_HRA.mat')
    fullfile(script_dir, 'ROM_NMC30_HRA12.mat')
    fullfile(script_dir, 'ROM_NMC30_HRA.mat')
};
ROMfile = '';
for idx = 1:numel(rom_candidates)
    if exist(rom_candidates{idx}, 'file')
        ROMfile = rom_candidates{idx};
        break;
    end
end
if isempty(ROMfile)
    error('NMC30DynParIdROMsim:MissingROM', ...
        'ROM file not found. Expected one of:\n  %s\n', ...
        strjoin(rom_candidates, '\n  '));
end

%% SETTINGS
tc_test = 25;                     % Test temperature [°C]
ts = 1;                           % Sample time [s]
nmc30_capacity = 30;              % Capacity [Ah]
numpoles = 2;                     % Number of RC poles (fits better than 1)
do_hysteresis = 1;                % Include hysteresis model

% Load OCV model (from previous step)
fprintf('Step 1: Load NMC30 OCV model\n');
ocv_file = fullfile(repo_root, 'data', 'modelling', 'derived', 'ocv_models', 'nmc30', 'NMC30model-ocv.mat');
if ~exist(ocv_file, 'file')
    error('NMC30DynParIdROMsim:MissingOCV', ...
        'NMC30 OCV model not found: %s\nRun ocv_id/NMC30/OCVNMC30fromROM.m first.', ocv_file);
end
ocv_data = load(ocv_file);
model_ocv = ocv_data.nmc30_model;
fprintf('  ✓ Loaded NMC30 OCV model with capacity = %.1f Ah\n', model_ocv.QParam);

% Load ROM (for ground truth test data generation)
fprintf('\nStep 2: Load ROM for synthetic test data generation\n');
rom_data = load(ROMfile);
ROM = rom_data.ROM;
fprintf('  ✓ ROM loaded from: %s\n', ROMfile);

%% STEP 1: Generate synthetic test data at 25°C using OB_step
fprintf('\nStep 3: Generate synthetic test data via OB_step\n');
fprintf('  This simulates discharge-rest-charge protocol...\n\n');

% Test protocols (following processDynamic conventions):
% Script 1: Rest @ 100% SOC, Discharge @ 1C to 90% SOC, Rest
% Script 2: Rest @ 10% SOC, Deep discharge to min voltage, Rest, CV at Vmin
% Script 3: Rest @ 0% SOC, Charge @ 1C to max voltage, Rest, CV at Vmax

data_point = struct();
data_point.temp = tc_test;

% ----- SCRIPT 1: Discharge from 100% to ~10% at 1C -----
fprintf('  Generating Script 1 (Discharge 100% → 10% @ 1C)...');
soc_init_script1 = 100;
i_1c = 1 * nmc30_capacity;  % 1C current [A] (30A for 30Ah)
[script1_current, script1_step] = buildScript1Profile(i_1c, nmc30_capacity, ts);
[script1_time, script1_voltage, script1_chgAh, script1_disAh] = ...
    simulateDynScript(script1_current, soc_init_script1, tc_test, ROM, ts);

fprintf(' complete\n');

% ----- SCRIPT 2: Rest, Discharge CV @ Vmin, Rest, Dither -----
fprintf('  Generating Script 2 (CV at Vmin, rest at 10%)...');
soc_init_script2 = 10;
[script2_current, script2_step] = buildScript2Profile(i_1c, ts);
[script2_time, script2_voltage, script2_chgAh, script2_disAh] = ...
    simulateDynScript(script2_current, soc_init_script2, tc_test, ROM, ts);

fprintf(' complete\n');

% ----- SCRIPT 3: Rest, Charge @ 1C to Vmax, Rest, CV Dither -----
fprintf('  Generating Script 3 (Charge 0% → 100% @ 1C)...');
soc_init_script3 = 0;
[script3_current, script3_step] = buildScript3Profile(i_1c, nmc30_capacity, ts);
[script3_time, script3_voltage, script3_chgAh, script3_disAh] = ...
    simulateDynScript(script3_current, soc_init_script3, tc_test, ROM, ts);

fprintf(' complete\n');

% Assemble data structure for processDynamic using the same script layout
% as the *_DYN_*.mat files loaded by runProcessDynamic.m.
data_point.script1 = makeDynScript(script1_time, script1_current, ...
                                   script1_voltage, script1_chgAh, ...
                                   script1_disAh, script1_step);

data_point.script2 = makeDynScript(script2_time, script2_current, ...
                                   script2_voltage, script2_chgAh, ...
                                   script2_disAh, script2_step);

data_point.script3 = makeDynScript(script3_time, script3_current, ...
                                   script3_voltage, script3_chgAh, ...
                                   script3_disAh, script3_step);

data = data_point;  % processDynamic expects array of data structures
validateDynCurrentConvention(data);

fprintf('\nTest data generated:\n');
fprintf('  Script 1: %d samples, current range [%.1f, %.1f] A\n', ...
    length(script1_time), min(script1_current), max(script1_current));
fprintf('  Script 2: %d samples, voltage range [%.2f, %.2f] V\n', ...
    length(script2_time), min(script2_voltage), max(script2_voltage));
fprintf('  Script 3: %d samples, current range [%.1f, %.1f] A\n', ...
    length(script3_time), min(script3_current), max(script3_current));
fprintf('  Sign convention: +I = discharge, -I = charge\n');

%% STEP 2: Call processDynamic
fprintf('\nStep 4: Run processDynamic to identify parameters\n');
fprintf('  This optimizes: R0, R, RC, G, M0, M\n');
fprintf('  (May take 1-5 minutes)...\n\n');

% try
    % Pass OCV model to processDynamic
    model_dyn = processDynamic(data, model_ocv, numpoles, do_hysteresis);
    fprintf('\n✓ processDynamic completed successfully\n');
% catch ME
%     fprintf('\n⚠ processDynamic warning/error (often expected with synthetic data):\n');
%     fprintf('  %s\n', ME.message);
%     fprintf('  Continuing with results...\n\n');
%     model_dyn = model_ocv;  % Fall back to OCV model if processDynamic fails
% end

%% STEP 3: Extract and save identified parameters
fprintf('\nStep 5: Extract identified parameters\n');

nmc30_model = struct();
nmc30_model.temps = tc_test;
nmc30_model.name = 'NMC30';
nmc30_model.capacity = nmc30_capacity;

% OCV parameters (from model_dyn)
if isfield(model_dyn, 'OCV0')
    nmc30_model.OCV0 = model_dyn.OCV0;
    nmc30_model.OCVrel = model_dyn.OCVrel;
    nmc30_model.SOC = model_dyn.SOC;
else
    nmc30_model.OCV0 = model_ocv.OCV0;
    nmc30_model.OCVrel = model_ocv.OCVrel;
    nmc30_model.SOC = model_ocv.SOC;
end

% Dynamic parameters
if isfield(model_dyn, 'R0Param')
    nmc30_model.R0Param = model_dyn.R0Param(1);
    fprintf('  R0 = %.6f Ω\n', nmc30_model.R0Param);
else
    nmc30_model.R0Param = 0.01;
    fprintf('  R0 = %.6f Ω (default)\n', nmc30_model.R0Param);
end

if isfield(model_dyn, 'RParam')
    nmc30_model.RParam = model_dyn.RParam(1, :);
    fprintf('  R (RC pair) = [%s] Ω\n', sprintf('%.6f ', nmc30_model.RParam));
else
    nmc30_model.RParam = 0.005 * ones(1, numpoles);
    fprintf('  R (RC pair) = [%s] Ω (default)\n', sprintf('%.6f ', nmc30_model.RParam));
end

if isfield(model_dyn, 'RCParam')
    nmc30_model.RCParam = model_dyn.RCParam(1, :);
    fprintf('  RC (time constants) = [%s] s\n', sprintf('%.2f ', nmc30_model.RCParam));
else
    nmc30_model.RCParam = [10 100];
    fprintf('  RC (time constants) = [%s] s (default)\n', sprintf('%.2f ', nmc30_model.RCParam));
end

% Hysteresis parameters
if isfield(model_dyn, 'GParam')
    nmc30_model.GParam = model_dyn.GParam(1);
else
    nmc30_model.GParam = 0;
end

if isfield(model_dyn, 'M0Param')
    nmc30_model.M0Param = model_dyn.M0Param(1);
else
    nmc30_model.M0Param = 0;
end

if isfield(model_dyn, 'MParam')
    nmc30_model.MParam = model_dyn.MParam(1);
else
    nmc30_model.MParam = 0;
end

% Capacity and efficiency
nmc30_model.QParam = nmc30_capacity;
if isfield(model_dyn, 'etaParam')
    nmc30_model.etaParam = model_dyn.etaParam(1);
else
    nmc30_model.etaParam = 1.0;
end

% Voltage-SOC reverse lookup (for some algorithms)
if isfield(model_dyn, 'OCV')
    nmc30_model.OCV = model_dyn.OCV;
    nmc30_model.SOC0 = model_dyn.SOC0;
    nmc30_model.SOCrel = model_dyn.SOCrel;
else
    % Create from OCV0, OCVrel
    v_grid = linspace(min(nmc30_model.OCV0)-0.5, max(nmc30_model.OCV0)+0.5, 100)';
    nmc30_model.OCV = v_grid;
    nmc30_model.SOC0 = interp1(nmc30_model.OCV0, nmc30_model.SOC, v_grid, 'linear', 'extrap');
    nmc30_model.SOCrel = zeros(size(v_grid));
end

fprintf('\n✓ Extracted %d RC time constant(s)\n', length(nmc30_model.RCParam));

%% STEP 4: Validate and save
fprintf('\nStep 6: Validate model and save\n');

% Validation: Check voltage range
ocv_test = OCVfromSOCtemp((0:0.1:1)', tc_test, nmc30_model);
fprintf('  OCV range: [%.3f, %.3f] V\n', min(ocv_test), max(ocv_test));

% Validation: Compare simCell model voltage against the synthetic script-1
% ROM voltage and report RMS error over the central SOC window.
[vk, rck, hk, zk, sik, OCV] = simCell(data.script1.current, tc_test, 1, ...
                                      nmc30_model, 1, zeros(numpoles, 1), 0); %#ok<ASGLU>
tk = (0:length(data.script1.current)-1)';
vk = vk(:);
vtrue = data.script1.voltage(:);

figure('Name', sprintf('Validation at %d degC', tc_test), 'NumberTitle', 'off');
plot(tk, vtrue, tk, vk, 'LineWidth', 1.2);
grid on;
xlabel('Time (s)');
ylabel('Voltage (V)');
title(sprintf('Voltage and estimates at T = %d', tc_test));
legend('Synthetic ROM voltage', 'simCell estimate', 'Location', 'best');

verr = vtrue - vk;
v1 = OCVfromSOCtemp(0.95, tc_test, nmc30_model);
v2 = OCVfromSOCtemp(0.05, tc_test, nmc30_model);
N1 = find(vtrue < v1, 1, 'first');
N2 = find(vtrue < v2, 1, 'first');
if isempty(N1), N1 = 1; end
if isempty(N2), N2 = length(verr); end
rmserr = sqrt(mean(verr(N1:N2).^2));
fprintf('  RMS error of simCell @ %d degC = %0.2f mV\n', tc_test, rmserr * 1000);

% Save
if exist(models_output_dir, 'dir') ~= 7
    mkdir(models_output_dir);
end
output_file = fullfile(models_output_dir, 'NMC30model.mat');
save(output_file, 'nmc30_model');
fprintf('  Saved to: %s\n', output_file);

fprintf('\n');
fprintf('================================================================\n');
fprintf('  Parameter Identification Complete\n');
fprintf('================================================================\n\n');

fprintf('Summary:\n');
fprintf('  Temperature: %d °C\n', tc_test);
fprintf('  Capacity: %.1f Ah\n', nmc30_model.QParam);
fprintf('  R0: %.6f Ω\n', nmc30_model.R0Param);
fprintf('  RC poles: %d\n', length(nmc30_model.RCParam));
fprintf('\nFiles created:\n');
fprintf('  - %s\n\n', output_file);

fprintf('Next:\n');
fprintf('  1. Validate %s with ESCvalidation.m\n', output_file);
fprintf('  2. For extended temperature range, repeat at T = 5, 15, 35, 45°C\n');
fprintf('  3. Merge multi-temperature models into single struct\n\n');
function [time_s, voltage_v, chg_ah, dis_ah] = simulateDynScript(current_a, soc0, tc_test, ROM, ts)
current_a = reshape(current_a, 1, []);
time_s = (0:length(current_a)-1) * ts;
voltage_v = NaN(size(current_a));

rom_state = [];
init_cfg = struct('SOC0', soc0, 'warnOff', true);
for k = 1:length(current_a)
    if k == 1
        [voltage_v(k), ~, rom_state] = OB_step(current_a(k), tc_test, [], ROM, init_cfg);
    else
        [voltage_v(k), ~, rom_state] = OB_step(current_a(k), tc_test, rom_state, ROM, []);
    end
end

chg_ah = cumsum([0, max(-current_a(1:end-1), 0)]) * ts / 3600;
dis_ah = cumsum([0, max(current_a(1:end-1), 0)]) * ts / 3600;
end

function [current_a, step_id] = buildScript1Profile(i_1c, capacity_ah, ts)
current_a = [];
step_id = [];
target_discharge_ah = 0.90 * capacity_ah;

[current_a, step_id] = appendSegment(current_a, step_id, 0, 10 * 60, 1, ts);
[current_a, step_id] = appendSegment(current_a, step_id, i_1c, 0.10 * capacity_ah * 3600 / i_1c, 2, ts);

while sum(max(current_a, 0)) * ts / 3600 < target_discharge_ah
    [current_a, step_id] = appendSegment(current_a, step_id, 0.50 * i_1c, 45, 3, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 0, 15, 4, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 1.00 * i_1c, 45, 5, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 0, 45, 6, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 1.50 * i_1c, 30, 3, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 0, 30, 4, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 0.25 * i_1c, 90, 5, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 0, 30, 6, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 0.75 * i_1c, 60, 3, ts);
    [current_a, step_id] = appendSegment(current_a, step_id, 0, 30, 8, ts);
end

dis_ah = cumsum(max(current_a, 0)) * ts / 3600;
last_idx = find(dis_ah >= target_discharge_ah, 1, 'first');
current_a = current_a(1:last_idx);
step_id = step_id(1:last_idx);
[current_a, step_id] = appendSegment(current_a, step_id, 0, 10 * 60, 8, ts);
end

function [current_a, step_id] = buildScript2Profile(i_1c, ts)
current_a = [];
step_id = [];

[current_a, step_id] = appendSegment(current_a, step_id, 0, 10 * 60, 1, ts);
[current_a, step_id] = appendSegment(current_a, step_id, 0.33 * i_1c, 5 * 60, 2, ts);
[current_a, step_id] = appendSegment(current_a, step_id, 0, 5 * 60, 3, ts);
[current_a, step_id] = appendSegment(current_a, step_id, 0.10 * i_1c, 10 * 60, 4, ts);
[current_a, step_id] = appendSegment(current_a, step_id, -0.05 * i_1c, 2 * 60, 5, ts);
[current_a, step_id] = appendSegment(current_a, step_id, 0.05 * i_1c, 2 * 60, 6, ts);
[current_a, step_id] = appendSegment(current_a, step_id, -0.05 * i_1c, 2 * 60, 7, ts);
[current_a, step_id] = appendSegment(current_a, step_id, 0.05 * i_1c, 2 * 60, 8, ts);
[current_a, step_id] = appendSegment(current_a, step_id, 0, 5 * 60, 9, ts);
[current_a, step_id] = appendSegment(current_a, step_id, 0, 5 * 60, 10, ts);
end

function [current_a, step_id] = buildScript3Profile(i_1c, capacity_ah, ts)
current_a = [];
step_id = [];

[current_a, step_id] = appendSegment(current_a, step_id, 0, 10 * 60, 11, ts);
[current_a, step_id] = appendSegment(current_a, step_id, -i_1c, 0.90 * capacity_ah * 3600 / i_1c, 12, ts);
[current_a, step_id] = appendSegment(current_a, step_id, 0, 5 * 60, 14, ts);
[current_a, step_id] = appendSegment(current_a, step_id, -0.20 * i_1c, 10 * 60, 15, ts);
[current_a, step_id] = appendSegment(current_a, step_id, 0.05 * i_1c, 2 * 60, 16, ts);
[current_a, step_id] = appendSegment(current_a, step_id, -0.05 * i_1c, 2 * 60, 17, ts);
[current_a, step_id] = appendSegment(current_a, step_id, 0.05 * i_1c, 2 * 60, 18, ts);
[current_a, step_id] = appendSegment(current_a, step_id, -0.05 * i_1c, 2 * 60, 19, ts);
[current_a, step_id] = appendSegment(current_a, step_id, 0, 5 * 60, 20, ts);
[current_a, step_id] = appendSegment(current_a, step_id, 0, 5 * 60, 21, ts);
end

function [current_a, step_id] = appendSegment(current_a, step_id, current_level, duration_s, step_value, ts)
num_samples = max(1, round(duration_s / ts));
current_a = [current_a, current_level * ones(1, num_samples)];
step_id = [step_id, step_value * ones(1, num_samples)];
end

function validateDynCurrentConvention(data)
script_names = {'script1', 'script2', 'script3'};
for idx = 1:numel(script_names)
    script = data.(script_names{idx});
    pos_idx = script.current > 0;
    neg_idx = script.current < 0;

    if any(diff(script.disAh(pos_idx)) < -1e-12)
        error('%s disAh must be nondecreasing during positive-current discharge segments.', script_names{idx});
    end
    if any(diff(script.chgAh(neg_idx)) < -1e-12)
        error('%s chgAh must be nondecreasing during negative-current charge segments.', script_names{idx});
    end
end
end

function script = makeDynScript(time_s, current_a, voltage_v, chg_ah, dis_ah, step_id)
time_s = reshape(time_s, 1, []);
current_a = reshape(current_a, 1, []);
voltage_v = reshape(voltage_v, 1, []);
chg_ah = reshape(chg_ah, 1, []);
dis_ah = reshape(dis_ah, 1, []);
step_id = reshape(step_id, 1, []);

script = struct('time', time_s, ...
                'step', step_id, ...
                'current', current_a, ...
                'voltage', voltage_v, ...
                'chgAh', chg_ah, ...
                'disAh', dis_ah);
end
