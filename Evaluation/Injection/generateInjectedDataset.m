function [dataset, metadata] = generateInjectedDataset(sourceInput, save_file, cfg)
% generateInjectedDataset Create and optionally save a canonical injection dataset.

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
dataset.metric_soc_name = 'Clean SOC';

if isfield(source_dataset, 'soc_true') && ~isempty(source_dataset.soc_true)
    dataset.source_soc_ref = source_dataset.soc_true(:);
end
if isfield(source_dataset, 'temperature_c') && ~isempty(source_dataset.temperature_c)
    dataset.source_temperature_c = source_dataset.temperature_c(:);
end

switch cfg.mode
    case 'additive_measurement_noise'
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
        dataset.voltage_name = sprintf('Additive Measurement Noise (%.0f mV, %.1f%% I)', ...
            cfg.voltage_std_mv, cfg.current_error_percent);

        metadata = struct( ...
            'mode', cfg.mode, ...
            'name', cfg.name, ...
            'voltage_std_mv', cfg.voltage_std_mv, ...
            'current_error_percent', cfg.current_error_percent, ...
            'random_seed', cfg.random_seed);

    case 'sensor_gain_bias_fault'
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
        dataset.voltage_name = sprintf('Sensor Gain/Bias Fault (Ig=%.3g, Io=%.3g A, Vg=%.4g, Vo=%.2f mV)', ...
            cfg.current_gain, cfg.current_offset_a, voltage_gain, voltage_offset_mv);

        metadata = struct( ...
            'mode', cfg.mode, ...
            'name', cfg.name, ...
            'current_gain', cfg.current_gain, ...
            'current_offset_a', cfg.current_offset_a, ...
            'voltage_gain_fault', voltage_gain, ...
            'voltage_offset_mv', voltage_offset_mv, ...
            'random_seed', cfg.random_seed);

    case 'composite_measurement_error'
        resolved_cfg = resolveCompositeMeasurementErrorConfig(cfg, dataset);
        current_bias_a = buildCurrentBiasTrace(resolved_cfg, numel(dataset.current_a_true));
        current_analog_noise_a = resolved_cfg.current_noise_std_a * randn(size(dataset.current_a_true));
        current_prequant_a = (1 + resolved_cfg.current_gain_error) * dataset.current_a_true + ...
            current_bias_a + current_analog_noise_a;
        [current_measured_a, current_quantization_a] = quantizeCurrentTrace( ...
            current_prequant_a, resolved_cfg.current_quant_lsb_a);

        dataset.current_a = current_measured_a;
        dataset.voltage_v = dataset.voltage_v_true;
        dataset.injected_current_gain_error = resolved_cfg.current_gain_error;
        dataset.injected_current_bias_a = current_bias_a;
        dataset.injected_current_analog_noise_a = current_analog_noise_a;
        dataset.injected_current_quantization_a = current_quantization_a;
        dataset.injected_current_prequant_a = current_prequant_a;
        dataset.injected_current_measured_a = current_measured_a;
        dataset.injection_config_resolved = resolved_cfg;
        dataset.voltage_name = 'Composite measurement error (clean voltage)';

        metadata = struct( ...
            'mode', cfg.mode, ...
            'name', cfg.name, ...
            'current_gain_error', resolved_cfg.current_gain_error, ...
            'current_bias_mode', resolved_cfg.current_bias_mode, ...
            'current_bias_spec', resolved_cfg.current_bias_spec, ...
            'current_bias_a', resolved_cfg.current_bias_a, ...
            'current_bias_rw_std_a', resolved_cfg.current_bias_rw_std_a, ...
            'current_noise_std_a', resolved_cfg.current_noise_std_a, ...
            'current_quant_lsb_a', resolved_cfg.current_quant_lsb_a, ...
            'random_seed', cfg.random_seed, ...
            'injection_config_resolved', resolved_cfg);

    otherwise
        error('generateInjectedDataset:BadMode', ...
            ['cfg.mode must be "additive_measurement_noise", ' ...
             '"sensor_gain_bias_fault", or "composite_measurement_error".']);
end

dataset = assignDegradedSocTrace(dataset);

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
cfg = normalizeInjectionCaseConfig(cfg);
cfg.random_seed = getCfg(cfg, 'random_seed', []);
cfg.overwrite = getCfg(cfg, 'overwrite', true);

cfg.voltage_std_mv = getCfg(cfg, 'voltage_std_mv', 15);
cfg.current_error_percent = getCfg(cfg, 'current_error_percent', 5);

cfg.current_gain = getCfg(cfg, 'current_gain', 1.1);
cfg.current_offset_a = getCfg(cfg, 'current_offset_a', 0.1);
cfg.voltage_gain_fault = getCfg(cfg, 'voltage_gain_fault', 6e-4);
cfg.voltage_offset_mv = getCfg(cfg, 'voltage_offset_mv', 2);

cfg.current_gain_error = getCfg(cfg, 'current_gain_error', 0);
cfg.current_bias_mode = getCfg(cfg, 'current_bias_mode', 'constant');
cfg.current_bias_spec = getCfg(cfg, 'current_bias_spec', 'absolute_a');
cfg.current_bias_a = getCfg(cfg, 'current_bias_a', []);
cfg.current_bias_c_rate = getCfg(cfg, 'current_bias_c_rate', []);
cfg.capacity_ah = getCfg(cfg, 'capacity_ah', []);
cfg.current_bias_rw_std_a = getCfg(cfg, 'current_bias_rw_std_a', 0);
cfg.current_noise_std_a = getCfg(cfg, 'current_noise_std_a', 0);
cfg.current_quant_lsb_a = getCfg(cfg, 'current_quant_lsb_a', 0);
end

function resolved_cfg = resolveCompositeMeasurementErrorConfig(cfg, dataset)
resolved_cfg = struct();
resolved_cfg.current_gain_error = cfg.current_gain_error;
resolved_cfg.current_bias_mode = validateTextOption( ...
    cfg.current_bias_mode, {'constant', 'random_walk'}, ...
    'generateInjectedDataset:BadCurrentBiasMode', ...
    'cfg.current_bias_mode must be "constant" or "random_walk".');
resolved_cfg.current_bias_spec = validateTextOption( ...
    cfg.current_bias_spec, {'absolute_a', 'c_rate_scaled'}, ...
    'generateInjectedDataset:BadCurrentBiasSpec', ...
    'cfg.current_bias_spec must be "absolute_a" or "c_rate_scaled".');
resolved_cfg.current_bias_c_rate = cfg.current_bias_c_rate;
[resolved_cfg.capacity_ah, resolved_cfg.capacity_ah_source] = ...
    resolveCompositeMeasurementCapacity(cfg, dataset, resolved_cfg.current_bias_spec);
resolved_cfg.current_bias_a = resolveCurrentBiasScalar(cfg, resolved_cfg);
resolved_cfg.current_bias_rw_std_a = cfg.current_bias_rw_std_a;
resolved_cfg.current_noise_std_a = cfg.current_noise_std_a;
resolved_cfg.current_quant_lsb_a = cfg.current_quant_lsb_a;
end

function [capacity_ah, capacity_source] = resolveCompositeMeasurementCapacity(cfg, dataset, current_bias_spec)
capacity_ah = [];
capacity_source = '';
if ~strcmp(current_bias_spec, 'c_rate_scaled')
    return;
end

if isfield(cfg, 'capacity_ah') && ~isempty(cfg.capacity_ah)
    capacity_ah = cfg.capacity_ah;
    capacity_source = 'cfg.capacity_ah';
    return;
end

if isfield(dataset, 'capacity_ah') && ~isempty(dataset.capacity_ah) && ...
        isnumeric(dataset.capacity_ah) && isscalar(dataset.capacity_ah) && ...
        isfinite(dataset.capacity_ah) && dataset.capacity_ah > 0
    capacity_ah = dataset.capacity_ah;
    capacity_source = 'dataset.capacity_ah';
end
end

function current_bias_a = resolveCurrentBiasScalar(cfg, resolved_cfg)
switch resolved_cfg.current_bias_spec
    case 'absolute_a'
        if ~isfield(cfg, 'current_bias_a') || isempty(cfg.current_bias_a)
            error('generateInjectedDataset:MissingCurrentBiasA', ...
                ['cfg.current_bias_a is required when cfg.mode is ' ...
                 '"composite_measurement_error" and cfg.current_bias_spec is "absolute_a".']);
        end
        current_bias_a = cfg.current_bias_a;

    case 'c_rate_scaled'
        if ~isfield(cfg, 'current_bias_c_rate') || isempty(cfg.current_bias_c_rate)
            error('generateInjectedDataset:MissingCurrentBiasCRate', ...
                ['cfg.current_bias_c_rate is required when cfg.mode is ' ...
                 '"composite_measurement_error" and cfg.current_bias_spec is "c_rate_scaled".']);
        end
        if isempty(resolved_cfg.capacity_ah)
            error('generateInjectedDataset:MissingCapacityAh', ...
                ['capacity_ah is required when cfg.mode is ' ...
                 '"composite_measurement_error" and cfg.current_bias_spec is "c_rate_scaled". ', ...
                 'Provide cfg.capacity_ah or a source dataset with dataset.capacity_ah.']);
        end
        current_bias_a = cfg.current_bias_c_rate * resolved_cfg.capacity_ah;

    otherwise
        error('generateInjectedDataset:BadCurrentBiasSpec', ...
            'Unsupported current bias specification "%s".', resolved_cfg.current_bias_spec);
end
end

function current_bias_a = buildCurrentBiasTrace(resolved_cfg, n_samples)
switch resolved_cfg.current_bias_mode
    case 'constant'
        current_bias_a = resolved_cfg.current_bias_a * ones(n_samples, 1);

    case 'random_walk'
        current_bias_a = zeros(n_samples, 1);
        current_bias_a(1) = resolved_cfg.current_bias_a;
        if n_samples > 1
            current_bias_a(2:end) = current_bias_a(1) + cumsum( ...
                resolved_cfg.current_bias_rw_std_a * randn(n_samples - 1, 1));
        end

    otherwise
        error('generateInjectedDataset:BadCurrentBiasMode', ...
            'Unsupported current bias mode "%s".', resolved_cfg.current_bias_mode);
end
end

function [current_measured_a, current_quantization_a] = quantizeCurrentTrace(current_prequant_a, current_quant_lsb_a)
if current_quant_lsb_a > 0
    current_measured_a = current_quant_lsb_a * round(current_prequant_a ./ current_quant_lsb_a);
else
    current_measured_a = current_prequant_a;
end
current_quantization_a = current_measured_a - current_prequant_a;
end

function dataset = assignDegradedSocTrace(dataset)
if ~isfield(dataset, 'capacity_ah') || isempty(dataset.capacity_ah) || ~isfinite(dataset.capacity_ah) || dataset.capacity_ah <= 0
    return;
end

soc0 = resolveSocInitFraction(dataset);
if ~isfinite(soc0)
    return;
end

time_s = dataset.time_s(:);
current_a = dataset.current_a(:);
n_samples = numel(time_s);
degraded_soc = NaN(n_samples, 1);
degraded_soc(1) = clamp01(soc0);
for idx = 2:n_samples
    dt_s = time_s(idx) - time_s(idx - 1);
    degraded_soc(idx) = clamp01(degraded_soc(idx - 1) - ...
        (current_a(idx - 1) * dt_s) / (3600 * dataset.capacity_ah));
end

dataset.degraded_soc = degraded_soc;
dataset.reference_soc = degraded_soc;
dataset.reference_name = 'Degraded SOC';
if isfield(dataset, 'soc_esc')
    dataset = rmfield(dataset, 'soc_esc');
end
end

function soc0 = resolveSocInitFraction(dataset)
soc0 = NaN;
candidate_fields = {'source_soc_ref', 'soc_true', 'reference_soc', 'degraded_soc'};
for idx = 1:numel(candidate_fields)
    field_name = candidate_fields{idx};
    if isfield(dataset, field_name) && ~isempty(dataset.(field_name))
        value = dataset.(field_name);
        value = value(1);
        if isfinite(value)
            soc0 = value;
            return;
        end
    end
end
end

function value = clamp01(value)
value = min(max(value, 0), 1);
end

function value = validateTextOption(raw_value, allowed_values, error_id, error_message)
if isstring(raw_value)
    if ~isscalar(raw_value)
        error(error_id, '%s', error_message);
    end
    value = char(raw_value);
elseif ischar(raw_value)
    value = raw_value;
else
    error(error_id, '%s', error_message);
end

if ~any(strcmp(value, allowed_values))
    error(error_id, '%s', error_message);
end
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
