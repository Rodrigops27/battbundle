function injectedDataset = InjNoiseData(datasetInput, savePath, cfg)
% InjNoiseData Create and save a sensor-fault injected dataset.
%
% Usage:
%   injectedDataset = InjNoiseData()
%   injectedDataset = InjNoiseData(datasetInput, savePath, cfg)
%
% Inputs:
%   datasetInput  Dataset struct or MAT file path containing variable
%                 "dataset". Default:
%                 Evaluation/ROMSimData/datasets/rom_bus_coreBattery_dataset.mat
%   savePath      Output MAT file path. Default:
%                 Evaluation/tests/datasets/<source>_inj_*.mat
%   cfg           Injection configuration struct:
%                   current_gain             default 1.1
%                   current_offset_a         default 0.1
%                   voltage_gain_fault       scalar or [min max], default [3e-4 1e-3]
%                   voltage_offset_mv_range  scalar or [min max], default [1 4]
%                   random_seed             optional scalar
%                   overwrite               default true
%
% Output:
%   injectedDataset Saved/returned dataset struct with injected current and
%                   voltage sensor faults.

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
cfg = normalizeInjectConfig(cfg);
[baseDataset, sourceInfo] = loadDatasetInput(datasetInput, repo_root);

if isempty(savePath)
    savePath = defaultInjectSavePath(sourceInfo, cfg, repo_root);
end

if exist(savePath, 'file') == 2 && ~cfg.overwrite
    loaded = load(savePath);
    injectedDataset = extractSavedDataset(loaded, savePath, 'InjNoiseData');
    return;
end

validateSourceDataset(baseDataset, sourceInfo.label, 'InjNoiseData');

if ~isempty(cfg.random_seed)
    rng(cfg.random_seed);
end

[voltage_gain_fault, voltage_offset_v] = sampleVoltageFault(cfg);

injectedDataset = baseDataset;
injectedDataset.current_a_true = baseDataset.current_a(:);
injectedDataset.voltage_v_true = baseDataset.voltage_v(:);

injectedDataset.current_a = cfg.current_gain * injectedDataset.current_a_true + cfg.current_offset_a;
injectedDataset.voltage_v = (1 + voltage_gain_fault) * injectedDataset.voltage_v_true + voltage_offset_v;

injectedDataset.injected_current_gain = cfg.current_gain;
injectedDataset.injected_current_offset_a = cfg.current_offset_a;
injectedDataset.injected_voltage_gain_fault = voltage_gain_fault;
injectedDataset.injected_voltage_offset_v = voltage_offset_v;
injectedDataset.injected_voltage_offset_mv = 1000 * voltage_offset_v;
injectedDataset.injected_voltage_gain_fault_range = cfg.voltage_gain_fault;
injectedDataset.injected_voltage_offset_mv_range = cfg.voltage_offset_mv_range;
injectedDataset.injected_model = 'current_gain_offset + voltage_gain_offset';
injectedDataset.source_dataset = sourceInfo.label;
injectedDataset.noisy_dataset_file = savePath;
injectedDataset.voltage_name = sprintf('Injected (Ig=%.3g, Io=%.3g A, Vg=%.4g, Vo=%.3f mV)', ...
    cfg.current_gain, cfg.current_offset_a, voltage_gain_fault, 1000 * voltage_offset_v);
if ~isempty(cfg.random_seed)
    injectedDataset.injected_random_seed = cfg.random_seed;
end

metadata = struct(); %#ok<NASGU>
metadata.source_dataset = sourceInfo.label;
metadata.source_dataset_file = sourceInfo.path;
metadata.current_gain = cfg.current_gain;
metadata.current_offset_a = cfg.current_offset_a;
metadata.voltage_gain_fault = voltage_gain_fault;
metadata.voltage_gain_fault_request = cfg.voltage_gain_fault;
metadata.voltage_offset_v = voltage_offset_v;
metadata.voltage_offset_mv_range = cfg.voltage_offset_mv_range;
metadata.random_seed = cfg.random_seed;
metadata.generated_at = datestr(now, 'yyyy-mm-dd HH:MM:SS');
metadata.generated_by = mfilename;

ensureParentFolder(savePath);
dataset = injectedDataset; %#ok<NASGU>
save(savePath, 'dataset', 'metadata');
end

function cfg = normalizeInjectConfig(cfg)
cfg.current_gain = getCfg(cfg, 'current_gain', 1.1);
cfg.current_offset_a = getCfg(cfg, 'current_offset_a', 0.1);
cfg.voltage_gain_fault = getCfg(cfg, 'voltage_gain_fault', [3e-4 1e-3]);
cfg.voltage_offset_mv_range = getCfg(cfg, 'voltage_offset_mv_range', [1 4]);
cfg.random_seed = getCfg(cfg, 'random_seed', []);
cfg.overwrite = getCfg(cfg, 'overwrite', true);

if ~isscalar(cfg.current_gain) || ~isfinite(cfg.current_gain)
    error('InjNoiseData:BadCurrentGain', 'cfg.current_gain must be a finite scalar.');
end
if ~isscalar(cfg.current_offset_a) || ~isfinite(cfg.current_offset_a)
    error('InjNoiseData:BadCurrentOffset', 'cfg.current_offset_a must be a finite scalar.');
end
cfg.voltage_gain_fault = normalizeScalarOrRange(cfg.voltage_gain_fault, 'InjNoiseData:BadVoltageGainFault');
cfg.voltage_offset_mv_range = normalizePositiveRange(cfg.voltage_offset_mv_range, 'InjNoiseData:BadVoltageOffsetRange');
if ~isempty(cfg.random_seed) && ...
        (~isscalar(cfg.random_seed) || ~isnumeric(cfg.random_seed) || ~isfinite(cfg.random_seed))
    error('InjNoiseData:BadRandomSeed', 'cfg.random_seed must be empty or a finite scalar.');
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
    error('InjNoiseData:BadDatasetInput', ...
        'datasetInput must be a dataset struct or a MAT file path.');
end

if exist(datasetInput, 'file') ~= 2
    error('InjNoiseData:MissingDatasetFile', 'Dataset file not found: %s', datasetInput);
end

loaded = load(datasetInput);
dataset = extractSavedDataset(loaded, datasetInput, 'InjNoiseData');
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

function [gain_fault, offset_v] = sampleVoltageFault(cfg)
gain_fault = sampleScalarOrRange(cfg.voltage_gain_fault);
offset_mag_mv = sampleScalarOrRange(cfg.voltage_offset_mv_range);
offset_sign = sign(rand - 0.5);
if offset_sign == 0
    offset_sign = 1;
end
offset_v = offset_sign * offset_mag_mv / 1000;
end

function range = normalizeScalarOrRange(value, error_id)
if isscalar(value) && isfinite(value)
    range = double(value);
    return;
end
if isnumeric(value) && numel(value) == 2 && all(isfinite(value))
    range = sort(double(value(:).'));
    return;
end
error(error_id, 'Value must be a finite scalar or a two-element numeric range.');
end

function range = normalizePositiveRange(value, error_id)
range = normalizeScalarOrRange(value, error_id);
if any(range < 0)
    error(error_id, 'Voltage offset magnitude range must be nonnegative.');
end
end

function value = sampleScalarOrRange(range)
if isscalar(range)
    value = range;
else
    value = range(1) + (range(2) - range(1)) * rand;
end
end

function savePath = defaultInjectSavePath(sourceInfo, cfg, repo_root)
save_dir = fullfile(repo_root, 'Evaluation', 'tests', 'datasets');
base_name = sprintf('%s_inj_Ig_%s_Io_%sA_Vg_%s_to_%s_Vo_%s_to_%smV', ...
    sourceInfo.base_name, ...
    sanitizeNumericToken(cfg.current_gain), ...
    sanitizeNumericToken(cfg.current_offset_a), ...
    sanitizeNumericToken(rangeMin(cfg.voltage_gain_fault)), ...
    sanitizeNumericToken(rangeMax(cfg.voltage_gain_fault)), ...
    sanitizeNumericToken(rangeMin(cfg.voltage_offset_mv_range)), ...
    sanitizeNumericToken(rangeMax(cfg.voltage_offset_mv_range)));
if ~isempty(cfg.random_seed)
    base_name = sprintf('%s_seed_%d', base_name, round(cfg.random_seed));
end
savePath = fullfile(save_dir, [base_name '.mat']);
end

function value = rangeMin(x)
if isscalar(x), value = x; else, value = x(1); end
end

function value = rangeMax(x)
if isscalar(x), value = x; else, value = x(end); end
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
