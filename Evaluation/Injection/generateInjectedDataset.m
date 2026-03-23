function [dataset, metadata] = generateInjectedDataset(sourceInput, save_file, cfg)
% generateInjectedDataset Create and optionally save a noise or perturbance dataset.

if nargin < 1 || isempty(sourceInput)
    error('generateInjectedDataset:MissingSource', ...
        'Provide a source dataset struct or MAT file path.');
end
if nargin < 2
    save_file = '';
end
if nargin < 3 || isempty(cfg)
    cfg = struct();
end

cfg = normalizeConfig(cfg);
[dataset, metadata] = deal(struct(), struct());

if ~isempty(save_file) && exist(save_file, 'file') == 2 && ~cfg.overwrite
    loaded = load(save_file);
    if ~isfield(loaded, 'dataset')
        error('generateInjectedDataset:BadSavedFile', ...
            'Expected variable "dataset" in %s.', save_file);
    end
    dataset = loaded.dataset;
    if isfield(loaded, 'metadata')
        metadata = loaded.metadata;
    end
    return;
end

[source_dataset, source_label] = loadSourceDataset(sourceInput);

if ~isempty(cfg.random_seed)
    rng(cfg.random_seed);
end

dataset = source_dataset;
dataset.current_a_true = source_dataset.current_a(:);
dataset.voltage_v_true = source_dataset.voltage_v(:);
dataset.source_current_a = dataset.current_a_true;
dataset.source_voltage_v = dataset.voltage_v_true;
dataset.source_dataset = source_label;
dataset.injection_case = cfg.name;
dataset.injection_mode = cfg.mode;
dataset.injection_random_seed = cfg.random_seed;
dataset.metric_voltage_name = 'Clean voltage';
dataset.dataset_soc_name = 'Clean SOC';

if isfield(source_dataset, 'soc_true') && ~isempty(source_dataset.soc_true)
    dataset.source_soc_ref = source_dataset.soc_true(:);
end
if isfield(source_dataset, 'temperature_c') && ~isempty(source_dataset.temperature_c)
    dataset.source_temperature_c = source_dataset.temperature_c(:);
end

switch cfg.mode
    case 'noise'
        sigma_v = cfg.voltage_std_mv / 1000;
        voltage_half_range = sqrt(3) * sigma_v;
        voltage_noise = voltage_half_range * (2 * rand(size(dataset.voltage_v_true)) - 1);
        current_scale = 1 + (cfg.current_error_percent / 100) * (2 * rand(size(dataset.current_a_true)) - 1);

        dataset.voltage_v = dataset.voltage_v_true + voltage_noise;
        dataset.current_a = dataset.current_a_true .* current_scale;
        dataset.injected_voltage_noise_v = voltage_noise;
        dataset.injected_current_scale = current_scale;
        dataset.injected_voltage_std_mv = cfg.voltage_std_mv;
        dataset.injected_current_error_percent = cfg.current_error_percent;
        dataset.voltage_name = sprintf('Noise Inj (%.0f mV, %.1f%% I)', ...
            cfg.voltage_std_mv, cfg.current_error_percent);

        metadata = struct( ...
            'mode', cfg.mode, ...
            'name', cfg.name, ...
            'voltage_std_mv', cfg.voltage_std_mv, ...
            'current_error_percent', cfg.current_error_percent, ...
            'random_seed', cfg.random_seed);

    case 'perturbance'
        voltage_gain = sampleScalarOrRange(cfg.voltage_gain_fault);
        voltage_offset_mv = sampleScalarOrRange(cfg.voltage_offset_mv);
        voltage_offset_v = voltage_offset_mv / 1000;

        dataset.current_a = cfg.current_gain * dataset.current_a_true + cfg.current_offset_a;
        dataset.voltage_v = (1 + voltage_gain) * dataset.voltage_v_true + voltage_offset_v;
        dataset.injected_current_gain = cfg.current_gain;
        dataset.injected_current_offset_a = cfg.current_offset_a;
        dataset.injected_voltage_gain_fault = voltage_gain;
        dataset.injected_voltage_offset_v = voltage_offset_v;
        dataset.injected_voltage_offset_mv = voltage_offset_mv;
        dataset.voltage_name = sprintf('Perturbance Inj (Ig=%.3g, Io=%.3g A, Vg=%.4g, Vo=%.2f mV)', ...
            cfg.current_gain, cfg.current_offset_a, voltage_gain, voltage_offset_mv);

        metadata = struct( ...
            'mode', cfg.mode, ...
            'name', cfg.name, ...
            'current_gain', cfg.current_gain, ...
            'current_offset_a', cfg.current_offset_a, ...
            'voltage_gain_fault', voltage_gain, ...
            'voltage_offset_mv', voltage_offset_mv, ...
            'random_seed', cfg.random_seed);

    otherwise
        error('generateInjectedDataset:BadMode', ...
            'cfg.mode must be "noise" or "perturbance".');
end

metadata.source_dataset = source_label;
metadata.generated_at = datestr(now, 'yyyy-mm-dd HH:MM:SS');
metadata.generated_by = mfilename;

if ~isempty(save_file)
    ensureParentFolder(save_file);
    dataset_file = save_file; %#ok<NASGU>
    save(save_file, 'dataset', 'metadata');
end
end

function cfg = normalizeConfig(cfg)
cfg.name = getCfg(cfg, 'name', getCfg(cfg, 'mode', 'noise'));
cfg.mode = lower(getCfg(cfg, 'mode', 'noise'));
cfg.random_seed = getCfg(cfg, 'random_seed', []);
cfg.overwrite = getCfg(cfg, 'overwrite', true);

cfg.voltage_std_mv = getCfg(cfg, 'voltage_std_mv', 15);
cfg.current_error_percent = getCfg(cfg, 'current_error_percent', 5);

cfg.current_gain = getCfg(cfg, 'current_gain', 1.1);
cfg.current_offset_a = getCfg(cfg, 'current_offset_a', 0.1);
cfg.voltage_gain_fault = getCfg(cfg, 'voltage_gain_fault', 6e-4);
cfg.voltage_offset_mv = getCfg(cfg, 'voltage_offset_mv', 2);
end

function [dataset, source_label] = loadSourceDataset(sourceInput)
if isstruct(sourceInput)
    dataset = sourceInput;
    source_label = getFieldOr(dataset, 'name', 'in_memory_dataset');
    return;
end

if isstring(sourceInput)
    sourceInput = char(sourceInput);
end
if ~ischar(sourceInput) || exist(sourceInput, 'file') ~= 2
    error('generateInjectedDataset:BadSourceInput', ...
        'sourceInput must be a dataset struct or an existing MAT file.');
end

loaded = load(sourceInput);
if ~isfield(loaded, 'dataset')
    error('generateInjectedDataset:BadSourceFile', ...
        'Expected variable "dataset" in %s.', sourceInput);
end
dataset = loaded.dataset;
source_label = sourceInput;
end

function value = sampleScalarOrRange(raw_value)
if isscalar(raw_value)
    value = raw_value;
    return;
end
raw_value = sort(double(raw_value(:).'));
value = raw_value(1) + (raw_value(2) - raw_value(1)) * rand;
end

function ensureParentFolder(file_path)
folder_path = fileparts(file_path);
if ~isempty(folder_path) && exist(folder_path, 'dir') ~= 7
    mkdir(folder_path);
end
end

function value = getCfg(cfg, field_name, default_value)
if isfield(cfg, field_name) && ~isempty(cfg.(field_name))
    value = cfg.(field_name);
else
    value = default_value;
end
end

function value = getFieldOr(s, field_name, default_value)
if isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end
