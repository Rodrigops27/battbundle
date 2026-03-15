function faultedDataset = perturbFaultData(datasetInput, savePath, cfg)
% perturbFaultData Create and save a fault-injected dataset.
%
% Usage:
%   faultedDataset = perturbFaultData()
%   faultedDataset = perturbFaultData(datasetInput, savePath, cfg)
%
% Inputs:
%   datasetInput  Dataset struct or MAT file path containing variable
%                 "dataset". Default:
%                 Evaluation/ROMSimData/datasets/rom_bus_coreBattery_dataset.mat
%   savePath      Output MAT file path. Default:
%                 Evaluation/tests/datasets/<source>_fault_*.mat
%   cfg           Fault configuration struct:
%                   current_gain       default 1.1
%                   current_offset_a   default 0.1
%                   voltage_std_mv     default 300
%                   random_seed        optional scalar
%                   overwrite          default true
%
% Output:
%   faultedDataset Saved/returned dataset struct with faulted current/voltage.

if nargin < 1
    datasetInput = [];
end
if nargin < 2
    savePath = [];
end
if nargin < 3 || isempty(cfg)
    cfg = struct();
end

if ~isdeployed
    here = fileparts(which(mfilename));
    if isempty(here)
        here = fileparts(mfilename('fullpath'));
    end
    if isempty(here)
        here = pwd;
    end
    cd(here);
end

repo_root = fileparts(fileparts(here));
cfg = normalizeFaultConfig(cfg);
[baseDataset, sourceInfo] = loadDatasetInput(datasetInput, repo_root);

if isempty(savePath)
    savePath = defaultFaultSavePath(sourceInfo, cfg, repo_root);
end

if exist(savePath, 'file') == 2 && ~cfg.overwrite
    loaded = load(savePath);
    faultedDataset = extractSavedDataset(loaded, savePath, 'perturbFaultData');
    return;
end

validateSourceDataset(baseDataset, sourceInfo.label, 'perturbFaultData');

if ~isempty(cfg.random_seed)
    rng(cfg.random_seed);
end

faultedDataset = baseDataset;
faultedDataset.current_a_true = baseDataset.current_a(:);
faultedDataset.voltage_v_true = baseDataset.voltage_v(:);

sigma_v = cfg.voltage_std_mv / 1000;
voltage_half_range = sqrt(3) * sigma_v;
voltage_noise = voltage_half_range * (2 * rand(size(faultedDataset.voltage_v_true)) - 1);

faultedDataset.current_a = cfg.current_gain * faultedDataset.current_a_true + cfg.current_offset_a;
faultedDataset.voltage_v = faultedDataset.voltage_v_true + voltage_noise;

faultedDataset.fault_current_gain = cfg.current_gain;
faultedDataset.fault_current_offset_a = cfg.current_offset_a;
faultedDataset.fault_voltage_std_mv = cfg.voltage_std_mv;
faultedDataset.fault_voltage_noise_v = voltage_noise;
faultedDataset.fault_model = 'current_gain_offset + uniform_voltage_noise';
faultedDataset.source_dataset = sourceInfo.label;
faultedDataset.fault_dataset_file = savePath;
faultedDataset.voltage_name = sprintf('Faulted (gain=%.3g, offset=%.3g A, %.0f mV)', ...
    cfg.current_gain, cfg.current_offset_a, cfg.voltage_std_mv);
if ~isempty(cfg.random_seed)
    faultedDataset.fault_random_seed = cfg.random_seed;
end

metadata = struct(); %#ok<NASGU>
metadata.source_dataset = sourceInfo.label;
metadata.source_dataset_file = sourceInfo.path;
metadata.current_gain = cfg.current_gain;
metadata.current_offset_a = cfg.current_offset_a;
metadata.voltage_std_mv = cfg.voltage_std_mv;
metadata.random_seed = cfg.random_seed;
metadata.generated_at = datestr(now, 'yyyy-mm-dd HH:MM:SS');
metadata.generated_by = mfilename;

ensureParentFolder(savePath);
dataset = faultedDataset; %#ok<NASGU>
save(savePath, 'dataset', 'metadata');
end

function cfg = normalizeFaultConfig(cfg)
cfg.current_gain = getCfg(cfg, 'current_gain', 1.1);
cfg.current_offset_a = getCfg(cfg, 'current_offset_a', 0.1);
cfg.voltage_std_mv = getCfg(cfg, 'voltage_std_mv', 300);
cfg.random_seed = getCfg(cfg, 'random_seed', []);
cfg.overwrite = getCfg(cfg, 'overwrite', true);

if ~isscalar(cfg.current_gain) || ~isfinite(cfg.current_gain)
    error('perturbFaultData:BadCurrentGain', 'cfg.current_gain must be a finite scalar.');
end
if ~isscalar(cfg.current_offset_a) || ~isfinite(cfg.current_offset_a)
    error('perturbFaultData:BadCurrentOffset', 'cfg.current_offset_a must be a finite scalar.');
end
if ~isscalar(cfg.voltage_std_mv) || ~isfinite(cfg.voltage_std_mv) || cfg.voltage_std_mv < 0
    error('perturbFaultData:BadVoltageStd', 'cfg.voltage_std_mv must be a nonnegative scalar.');
end
if ~isempty(cfg.random_seed) && ...
        (~isscalar(cfg.random_seed) || ~isnumeric(cfg.random_seed) || ~isfinite(cfg.random_seed))
    error('perturbFaultData:BadRandomSeed', 'cfg.random_seed must be empty or a finite scalar.');
end
end

function value = getCfg(cfg, fieldName, defaultValue)
if isfield(cfg, fieldName) && ~isempty(cfg.(fieldName))
    value = cfg.(fieldName);
else
    value = defaultValue;
end
end

function [dataset, info] = loadDatasetInput(datasetInput, repo_root)
default_path = fullfile(repo_root, 'Evaluation', 'ROMSimData', 'datasets', 'rom_bus_coreBattery_dataset.mat');

if isempty(datasetInput)
    datasetInput = default_path;
end

if isstruct(datasetInput)
    dataset = datasetInput;
    info = struct('path', '', 'label', 'in_memory_dataset', 'base_name', 'dataset');
    return;
end

if isstring(datasetInput)
    datasetInput = char(datasetInput);
end

if ~ischar(datasetInput)
    error('perturbFaultData:BadDatasetInput', ...
        'datasetInput must be a dataset struct or a MAT file path.');
end

if exist(datasetInput, 'file') ~= 2
    error('perturbFaultData:MissingDatasetFile', 'Dataset file not found: %s', datasetInput);
end

loaded = load(datasetInput);
dataset = extractSavedDataset(loaded, datasetInput, 'perturbFaultData');
 [~, base_name] = fileparts(datasetInput);
info = struct('path', datasetInput, 'label', datasetInput, 'base_name', base_name);
end

function dataset = extractSavedDataset(loaded, file_path, caller_name)
if isfield(loaded, 'dataset')
    dataset = loaded.dataset;
elseif isfield(loaded, 'evalDataset')
    dataset = loaded.evalDataset;
else
    error('%s:BadDatasetFile', caller_name, ...
        'Expected variable "dataset" or "evalDataset" in %s.', file_path);
end
end

function validateSourceDataset(dataset, dataset_label, caller_name)
required = {'current_a', 'voltage_v'};
for idx = 1:numel(required)
    if ~isfield(dataset, required{idx}) || isempty(dataset.(required{idx}))
        error('%s:MissingField', caller_name, ...
            'Source dataset %s is missing dataset.%s.', dataset_label, required{idx});
    end
end
end

function savePath = defaultFaultSavePath(sourceInfo, cfg, repo_root)
save_dir = fullfile(repo_root, 'Evaluation', 'tests', 'datasets');
base_name = sprintf('%s_fault_gain_%s_offset_%sA_vstd_%smV', ...
    sourceInfo.base_name, ...
    sanitizeNumericToken(cfg.current_gain), ...
    sanitizeNumericToken(cfg.current_offset_a), ...
    sanitizeNumericToken(cfg.voltage_std_mv));
if ~isempty(cfg.random_seed)
    base_name = sprintf('%s_seed_%d', base_name, round(cfg.random_seed));
end
savePath = fullfile(save_dir, [base_name '.mat']);
end

function token = sanitizeNumericToken(value)
token = regexprep(sprintf('%.12g', value), '[^0-9A-Za-z]+', 'p');
token = regexprep(token, 'p+', 'p');
token = regexprep(token, '^p|p$', '');
if isempty(token)
    token = '0';
end
end

function ensureParentFolder(filePath)
folder_path = fileparts(filePath);
if ~isempty(folder_path) && exist(folder_path, 'dir') ~= 7
    mkdir(folder_path);
end
end
