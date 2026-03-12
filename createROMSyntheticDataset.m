function dataset = createROMSyntheticDataset(savePath, cfg)
% createROMSyntheticDataset Build and optionally save ROM synthetic signals.
% Signals saved for reusable KF evaluation:
%   time_s, current_a, voltage_v, temperature_c, soc_true, soc_cc
%
% Usage:
%   dataset = createROMSyntheticDataset();
%   dataset = createROMSyntheticDataset('datasets/rom_script1.mat');
%   dataset = createROMSyntheticDataset([], struct('soc_init', 100, 'tc', 25, 'ts', 1));

script_fullpath = mfilename('fullpath');
script_dir = fileparts(script_fullpath);
project_root = fileparts(fileparts(fileparts(script_dir)));
esc_id_root = fullfile(script_dir, 'ESC_Id');

if nargin < 1 || isempty(savePath)
    savePath = fullfile(script_dir, 'datasets', 'rom_script1_dataset.mat');
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end

if ~isfield(cfg, 'soc_init'), cfg.soc_init = 100; end
if ~isfield(cfg, 'tc'), cfg.tc = 25; end
if ~isfield(cfg, 'ts'), cfg.ts = 1; end

rom_file = firstExistingFile({ ...
    fullfile(script_dir, 'models', 'ROM_NMC30_HRA12.mat'), ...
    fullfile(script_dir, 'ROM_NMC30_HRA12.mat'), ...
    fullfile(project_root, 'models', 'ROM_NMC30_HRA12.mat'), ...
    fullfile(project_root, 'src', 'MPC-EKF4FastCharge', 'ROM_NMC30_HRA12.mat')}, ...
    'createROMSyntheticDataset:MissingROMFile', ...
    'No ROM model file found.');

esc_model_file = firstExistingFile({ ...
    fullfile(script_dir, 'models', 'NMC30model.mat'), ...
    fullfile(script_dir, 'NMC30model.mat'), ...
    fullfile(esc_id_root, 'NMC30model.mat'), ...
    fullfile(project_root, 'models', 'NMC30model.mat')}, ...
    'createROMSyntheticDataset:MissingESCModel', ...
    'No NMC30 full ESC model found.');

rom_data = load(rom_file);
ROM = rom_data.ROM;

esc_data = load(esc_model_file);
model = esc_data.nmc30_model;
if ~isfield(model, 'RCParam')
    error('createROMSyntheticDataset:MissingRCParam', ...
        'Loaded ESC model is not full: RCParam is missing.');
end

capacity_ah = model.QParam;
i_1c = capacity_ah;
[current_a, step_id] = buildScript1Profile(i_1c, capacity_ah, cfg.ts);
current_a = current_a(:);
time_s = (0:numel(current_a)-1).' * cfg.ts;
temperature_c = cfg.tc * ones(numel(current_a), 1);

voltage_v = NaN(numel(time_s), 1);
soc_true = NaN(numel(time_s), 1);
soc_true(1) = cfg.soc_init / 100;
rom_state = [];
init_cfg = struct('SOC0', cfg.soc_init, 'warnOff', true);

for k = 1:numel(time_s)
    if k == 1
        [voltage_v(k), ~, rom_state] = OB_step(current_a(k), cfg.tc, [], ROM, init_cfg);
        soc_true(k) = cfg.soc_init / 100;
    else
        [voltage_v(k), ~, rom_state] = OB_step(current_a(k), cfg.tc, rom_state, ROM, []);
        soc_true(k) = soc_true(k-1) - (current_a(k) * cfg.ts) / (3600 * capacity_ah);
        soc_true(k) = max(0, min(1, soc_true(k)));
    end
end

soc_cc = NaN(size(soc_true));
soc_cc(1) = cfg.soc_init / 100;
for k = 2:numel(soc_cc)
    soc_cc(k) = soc_cc(k-1) - (current_a(k) * cfg.ts) / (3600 * capacity_ah);
    soc_cc(k) = max(0, min(1, soc_cc(k)));
end

dataset = struct();
dataset.name = 'ROM script-1 synthetic dataset';
dataset.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
dataset.soc_init_percent = cfg.soc_init;
dataset.ts = cfg.ts;
dataset.time_s = time_s;
dataset.current_a = current_a;
dataset.voltage_v = voltage_v;
dataset.temperature_c = temperature_c;
dataset.soc_true = soc_true;
dataset.soc_cc = soc_cc;
dataset.capacity_ah = capacity_ah;
dataset.step_id = step_id(:);
dataset.rom_file = rom_file;
dataset.esc_model_file = esc_model_file;

if ~isempty(savePath)
    out_dir = fileparts(savePath);
    if ~isempty(out_dir) && ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end
    save(savePath, 'dataset');
end
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
