function dataset = ROMsimDynData(savePath, cfg)
% ROMsimDynData Build and optionally save the NMC30 ROM synthetic dataset.
% Signals saved for reusable KF evaluation:
%   time_s, current_a, voltage_v, temperature_c, soc_true, soc_cc
%
% Usage:
%   dataset = ROMsimDynData();
%   dataset = ROMsimDynData(fullfile('data', 'modelling', 'synthetic', 'nmc30', 'romsim', 'rom_script1_dataset.mat'));
%   dataset = ROMsimDynData([], struct('soc_init', 100, 'tc', 25, 'ts', 1));

script_fullpath = mfilename('fullpath');
script_dir = fileparts(script_fullpath);
esc_id_root = fileparts(script_dir);  % NMC30/ -> ESC_Id/
repo_root = fileparts(esc_id_root);  % ESC_Id/ -> bnchmrk/

addpath(genpath(fullfile(repo_root, 'utility')));

if nargin < 1 || isempty(savePath)
    savePath = fullfile(repo_root, 'data', 'modelling', 'synthetic', 'nmc30', 'romsim', 'rom_script1_dataset.mat');
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end

if ~isfield(cfg, 'soc_init'), cfg.soc_init = 100; end
if ~isfield(cfg, 'tc'), cfg.tc = 25; end
if ~isfield(cfg, 'ts'), cfg.ts = 1; end

capacity_ah = loadNMC30Capacity(esc_id_root, repo_root);
[current_c_rate, step_id] = buildScript1NormalizedProfile(cfg.ts);
current_a = capacity_ah * current_c_rate;
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

function capacity_ah = loadNMC30Capacity(esc_id_root, repo_root)
% Defensive path resolution for NMC30 model
esc_model_candidates = {
    fullfile(repo_root, 'models', 'NMC30model.mat')
    fullfile(esc_id_root, 'NMC30', 'NMC30model.mat')
    fullfile(esc_id_root, 'NMC30model.mat')
};
esc_model_file = '';
for idx = 1:numel(esc_model_candidates)
    if exist(esc_model_candidates{idx}, 'file')
        esc_model_file = esc_model_candidates{idx};
        break;
    end
end

if isempty(esc_model_file)
    searched = sprintf('\n  %s', esc_model_candidates{:});
    error('ROMsimDynData:MissingESCModel', ...
        'No NMC30 full ESC model found. Searched:%s\nRun ocv_id/NMC30/OCVNMC30fromROM.m and ESC_Id/NMC30/NMC30DynParIdROMsim.m first.', ...
        searched);
end

esc_data = load(esc_model_file);
model = esc_data.nmc30_model;
capacity_ah = model.QParam;
end
