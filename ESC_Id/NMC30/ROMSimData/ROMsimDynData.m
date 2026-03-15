function dataset = ROMsimDynData(savePath, cfg)
% ROMsimDynData Build and optionally save the legacy 90-10 ROM dataset.
% Signals saved for reusable KF evaluation:
%   time_s, current_a, voltage_v, temperature_c, soc_true, soc_cc
%
% Usage:
%   dataset = ROMsimDynData();
%   dataset = ROMsimDynData('datasets/rom_script1.mat');
%   dataset = ROMsimDynData([], struct('soc_init', 100, 'tc', 25, 'ts', 1));

script_fullpath = mfilename('fullpath');
script_dir = fileparts(script_fullpath);
synthm_dir = fullfile(script_dir, 'Synthm');
if exist(synthm_dir, 'dir') == 7
    addpath(synthm_dir);
end

if nargin < 1 || isempty(savePath)
    savePath = fullfile(script_dir, 'datasets', 'rom_script1_dataset.mat');
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end

if ~isfield(cfg, 'soc_init'), cfg.soc_init = 100; end
if ~isfield(cfg, 'tc'), cfg.tc = 25; end
if ~isfield(cfg, 'ts'), cfg.ts = 1; end

capacity_ah = loadNMC30Capacity(script_dir);
i_1c = capacity_ah;
[current_a, step_id] = buildScript1Profile(i_1c, capacity_ah, cfg.ts);
current_a = current_a(:);
time_s = (0:numel(current_a)-1).' * cfg.ts;

sim_cfg = struct( ...
    'dataset_name', 'ROM script-1 synthetic dataset', ...
    'soc_init', cfg.soc_init, ...
    'tc', cfg.tc, ...
    'ts', cfg.ts, ...
    'time_s', time_s, ...
    'step_id', step_id(:), ...
    'savePath', savePath);

dataset = simulateROMProfile(current_a, sim_cfg);
end

function capacity_ah = loadNMC30Capacity(script_dir)
esc_id_root = fullfile(script_dir, 'ESC_Id');
esc_model_file = firstExistingFile({ ...
    fullfile(script_dir, 'models', 'NMC30model.mat'), ...
    fullfile(script_dir, 'NMC30model.mat'), ...
    fullfile(esc_id_root, 'NMC30model.mat')}, ...
    'createROMSyntheticDataset:MissingESCModel', ...
    'No NMC30 full ESC model found.');

esc_data = load(esc_model_file);
model = esc_data.nmc30_model;
capacity_ah = model.QParam;
end

function file_path = firstExistingFile(candidates, error_id, error_msg)
file_path = '';
for idx = 1:numel(candidates)
    if exist(candidates{idx}, 'file')
        file_path = candidates{idx};
        break;
    end
end
if isempty(file_path)
    searched = sprintf('\n  - %s', candidates{:});
    error(error_id, '%s Searched:%s', error_msg, searched);
end
end

function [current_a, step_id] = buildScript1Profile(i_1c, capacity_ah, ts)
current_a = [];
step_id = [];
target_discharge_ah = 0.90 * capacity_ah;

[current_a, step_id] = appendSegment(current_a, step_id, 0, 10 * 60, 1, ts);
[current_a, step_id] = appendSegment(current_a, step_id, i_1c, ...
    0.10 * capacity_ah * 3600 / i_1c, 2, ts);

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

function [current_a, step_id] = appendSegment(current_a, step_id, current_level, duration_s, step_value, ts)
num_samples = max(1, round(duration_s / ts));
current_a = [current_a, current_level * ones(1, num_samples)]; %#ok<AGROW>
step_id = [step_id, step_value * ones(1, num_samples)]; %#ok<AGROW>
end
