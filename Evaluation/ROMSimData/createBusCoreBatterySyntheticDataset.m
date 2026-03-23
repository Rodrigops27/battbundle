function dataset = createBusCoreBatterySyntheticDataset(savePath, cfg)
% createBusCoreBatterySyntheticDataset Build a ROM dataset from bus_coreBattery data.

script_fullpath = mfilename('fullpath');
script_dir = fileparts(script_fullpath);
evaluation_root = fileparts(script_dir);
repo_root = fileparts(evaluation_root);

if nargin < 1 || isempty(savePath)
    savePath = fullfile(script_dir, 'datasets', 'rom_bus_coreBattery_dataset.mat');
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end

if ~isfield(cfg, 'tc') || isempty(cfg.tc), cfg.tc = 25; end
if ~isfield(cfg, 'soc_init'), cfg.soc_init = []; end
if ~isfield(cfg, 'profile_file') || isempty(cfg.profile_file)
    cfg.profile_file = fullfile(evaluation_root, 'OMTLIFE8AHC-HP', 'Bus_CoreBatteryData_Data.mat');
end
if ~isfield(cfg, 'source_capacity_ah'), cfg.source_capacity_ah = []; end
if ~isfield(cfg, 'original_capacity_ah'), cfg.original_capacity_ah = []; end
if ~isfield(cfg, 'original_1c_current_a'), cfg.original_1c_current_a = []; end
if ~isfield(cfg, 'current_sign'), cfg.current_sign = []; end
if ~isfield(cfg, 'source_field_map') || isempty(cfg.source_field_map)
    cfg.source_field_map = struct( ...
        'current', 'Total_Current_A', ...
        'voltage', 'Voltage_Vector_V', ...
        'soc', 'SOC_Vector_Percent');
end

profile = loadBusCoreBatteryProfile(cfg.profile_file);
[source_capacity_ah, capacity_source] = resolveSourceCapacity(profile, cfg);
[source_current_a, source_current_sign, current_sign_source] = orientCurrentToDischargePositive( ...
    profile.current_a, profile.time_s, profile.soc_ref, cfg);
profile.current_a = source_current_a(:);

target_capacity_ah = loadNMC30Capacity(repo_root);
target_ts = loadROMSampleTime(repo_root);
profile = resampleProfile(profile, target_ts);
source_current_a = profile.current_a(:);

source_c_rate = source_current_a / source_capacity_ah;
target_current_a = source_c_rate * target_capacity_ah;
current_scale_factor = target_capacity_ah / source_capacity_ah;

if isempty(cfg.soc_init)
    if any(~isnan(profile.soc_ref))
        soc_init_percent = 100 * profile.soc_ref(find(~isnan(profile.soc_ref), 1, 'first'));
    else
        soc_init_percent = 100;
    end
else
    soc_init_percent = double(cfg.soc_init);
end

source_voltage_v = profile.voltage_v(:);
if isempty(source_voltage_v)
    source_voltage_v = NaN(numel(target_current_a), 1);
end
source_soc_ref = profile.soc_ref(:);
if isempty(source_soc_ref)
    source_soc_ref = NaN(numel(target_current_a), 1);
end
source_step_id = profile.step_id(:);
if isempty(source_step_id)
    source_step_id = ones(numel(target_current_a), 1);
end

extra_fields = struct();
extra_fields.source_profile_file = toProjectRelativePath(profile.profile_file, repo_root);
extra_fields.source_profile_name = profile.profile_name;
extra_fields.source_time_s = profile.time_s(:);
extra_fields.source_current_a = source_current_a(:);
extra_fields.source_c_rate = source_c_rate(:);
extra_fields.source_voltage_v = source_voltage_v(:);
extra_fields.source_soc_ref = source_soc_ref(:);
extra_fields.source_capacity_ah = source_capacity_ah;
extra_fields.source_capacity_source = capacity_source;
extra_fields.source_current_sign = source_current_sign;
extra_fields.source_current_sign_source = current_sign_source;
extra_fields.current_scale_factor = current_scale_factor;
extra_fields.target_capacity_ah = target_capacity_ah;
extra_fields.assumed_temperature_c = cfg.tc;
extra_fields.source_signal_paths = profile.signal_paths;

sim_cfg = struct( ...
    'dataset_name', 'ROM bus_coreBattery synthetic dataset', ...
    'soc_init', soc_init_percent, ...
    'tc', cfg.tc, ...
    'time_s', profile.time_s(:), ...
    'step_id', source_step_id(:), ...
    'soc_true_ref', source_soc_ref(:), ...
    'savePath', savePath, ...
    'extra_fields', extra_fields);

dataset = simulateROMProfile(target_current_a(:), sim_cfg);
end

function path_out = toProjectRelativePath(path_in, repo_root)
if isempty(path_in)
    path_out = '';
    return;
end

path_in = normalizeStoredPath(path_in);
repo_root = normalizeStoredPath(repo_root);

if startsWith(lower(path_in), lower(repo_root))
    path_out = path_in(numel(repo_root)+1:end);
else
    path_out = path_in;
end

if isempty(path_out)
    path_out = '/';
elseif path_out(1) ~= '/'
    path_out = ['/', path_out];
end
end

function path_out = normalizeStoredPath(path_in)
path_out = strrep(char(path_in), '\', '/');
path_out = regexprep(path_out, '/+', '/');
end

function capacity_ah = loadNMC30Capacity(repo_root)
esc_id_root = fullfile(repo_root, 'ESC_Id');
esc_model_file = firstExistingFile({ ...
    fullfile(repo_root, 'models', 'NMC30model.mat'), ...
    fullfile(repo_root, 'NMC30model.mat'), ...
    fullfile(esc_id_root, 'NMC30model.mat')}, ...
    'createBusCoreBatterySyntheticDataset:MissingESCModel', ...
    'No NMC30 full ESC model found.');

esc_data = load(esc_model_file);
model = esc_data.nmc30_model;
capacity_ah = double(model.QParam);
end

function ts = loadROMSampleTime(repo_root)
rom_file = firstExistingFile({ ...
    fullfile(repo_root, 'models', 'ROM_NMC30_HRA12.mat'), ...
    fullfile(repo_root, 'ROM_NMC30_HRA12.mat')}, ...
    'createBusCoreBatterySyntheticDataset:MissingROMFile', ...
    'No ROM model file found.');

rom_data = load(rom_file);
ts = double(rom_data.ROM.xraData.Tsamp);
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

function profile = loadBusCoreBatteryProfile(profile_file)
profile_file = resolveLocalPath(profile_file);
if exist(profile_file, 'file') ~= 2
    error('createBusCoreBatterySyntheticDataset:MissingSourceProfile', ...
        'Source profile file not found: %s', profile_file);
end

raw = load(profile_file);
primary = choosePrimaryNode(raw);

profile = struct();
profile.profile_file = profile_file;
[~, name, ext] = fileparts(profile_file);
profile.profile_name = [name, ext];
profile.signal_paths = struct();

[current_raw, profile.signal_paths.current] = extractSignal(primary, {'Total_Current_A', 'Current_Vector_A'});
[voltage_raw, profile.signal_paths.voltage] = extractSignal(primary, {'Voltage_Vector_V', 'Total_Voltage_V'});
[soc_raw, profile.signal_paths.soc] = extractSignal(primary, {'SOC_Vector_Percent'});
[step_raw, profile.signal_paths.step] = extractSignal(primary, {'step', 'step_id', 'mode'});
[capacity_raw, profile.signal_paths.capacity] = extractSignal(primary, ...
    {'capacity_ah', 'capacity', 'qparam', 'nominalcapacityah', 'ratedcapacityah'});

current_a = coerceNumericVector(current_raw, false);
if isempty(current_a)
    error('createBusCoreBatterySyntheticDataset:MissingSourceCurrent', ...
        'Could not locate a current signal in %s.', profile_file);
end

if isa(current_raw, 'timeseries')
    time_s = normalizeTimeVector(current_raw.Time, numel(current_a), 'current.Time');
else
    time_s = (0:numel(current_a)-1).';
end

profile.time_s = time_s(:);
profile.current_a = current_a(:);
profile.voltage_v = normalizeOptionalSignal(voltage_raw, numel(current_a), 'voltage');
profile.soc_ref = normalizeSocSignal(normalizeOptionalSignal(soc_raw, numel(current_a), 'soc'));
profile.step_id = normalizeOptionalSignal(step_raw, numel(current_a), 'step');
profile.detected_capacity_ah = coerceNumericScalar(capacity_raw);
end

function local_path = resolveLocalPath(input_path)
if exist(input_path, 'file') == 2
    local_path = input_path;
    return;
end
script_fullpath = mfilename('fullpath');
script_dir = fileparts(script_fullpath);
evaluation_root = fileparts(script_dir);
repo_root = fileparts(evaluation_root);

candidates = { ...
    fullfile(script_dir, input_path), ...
    fullfile(evaluation_root, input_path), ...
    fullfile(repo_root, input_path)};

for idx = 1:numel(candidates)
    if exist(candidates{idx}, 'file') == 2
        local_path = candidates{idx};
        return;
    end
end
local_path = input_path;
end

function primary = choosePrimaryNode(raw)
names = fieldnames(raw);
if numel(names) == 1
    primary = raw.(names{1});
else
    primary = raw;
end
end

function [value, path_used] = extractSignal(node, selectors)
value = [];
path_used = '';
for idx = 1:numel(selectors)
    selector = selectors{idx};
    if isstruct(node) && isfield(node, selector)
        value = node.(selector);
        path_used = selector;
        return;
    end
end
end

function out = normalizeOptionalSignal(raw_value, n_expected, signal_name)
if isempty(raw_value)
    out = [];
    return;
end
out = coerceNumericVector(raw_value, false);
if isempty(out)
    out = [];
    return;
end
if numel(out) ~= n_expected
    error('createBusCoreBatterySyntheticDataset:SignalLengthMismatch', ...
        'Source %s signal has %d samples, expected %d.', signal_name, numel(out), n_expected);
end
out = out(:);
end

function value = coerceNumericVector(raw_value, allow_scalar)
value = [];
if isempty(raw_value)
    return;
end
if isa(raw_value, 'timeseries')
    value = coerceTimeseriesData(raw_value, allow_scalar);
    return;
end
if isnumeric(raw_value)
    if isscalar(raw_value)
        if allow_scalar
            value = double(raw_value);
        end
    elseif isvector(raw_value)
        value = double(raw_value(:));
    end
end
end

function value = coerceNumericScalar(raw_value)
value = [];
if isempty(raw_value)
    return;
end
if isa(raw_value, 'timeseries')
    data = coerceTimeseriesData(raw_value, true);
    if isnumeric(data) && isscalar(data) && isfinite(data)
        value = double(data);
    end
    return;
end
if isnumeric(raw_value) && isscalar(raw_value) && isfinite(raw_value)
    value = double(raw_value);
end
end

function value = coerceTimeseriesData(ts_obj, allow_scalar)
value = [];
data = ts_obj.Data;
if isempty(data) || ~isnumeric(data)
    return;
end

data = double(data);
if isvector(data)
    value = data(:);
    if isscalar(value) && ~allow_scalar
        value = [];
    end
    return;
end

data = reshape(data, size(data, 1), []);
if size(data, 2) == 1
    value = data(:, 1);
elseif allow_scalar && numel(data) == 1
    value = data(1);
else
    value = mean(data, 2, 'omitnan');
end
end

function time_s = normalizeTimeVector(time_raw, n_expected, signal_name)
if isdatetime(time_raw)
    time_raw = seconds(time_raw(:) - time_raw(1));
elseif isduration(time_raw)
    time_raw = seconds(time_raw(:));
else
    time_raw = double(time_raw(:));
end
if numel(time_raw) ~= n_expected
    error('createBusCoreBatterySyntheticDataset:TimeLengthMismatch', ...
        'Source %s vector has %d samples, expected %d.', signal_name, numel(time_raw), n_expected);
end
time_s = double(time_raw(:) - time_raw(1));
end

function soc = normalizeSocSignal(soc)
if isempty(soc)
    return;
end
soc = soc(:);
if any(abs(soc) > 1.5)
    soc = soc / 100;
end
soc = max(0, min(1, soc));
end

function profile = resampleProfile(profile, ts)
time_s = profile.time_s(:);
if numel(time_s) < 2
    return;
end

dt = diff(time_s);
if all(abs(dt - ts) <= 1e-9)
    return;
end

new_time = (time_s(1):ts:time_s(end)).';

profile.current_a = interp1(time_s, profile.current_a(:), new_time, 'previous', 'extrap');
if ~isempty(profile.voltage_v)
    profile.voltage_v = interp1(time_s, profile.voltage_v(:), new_time, 'linear', 'extrap');
end
if ~isempty(profile.soc_ref)
    profile.soc_ref = interp1(time_s, profile.soc_ref(:), new_time, 'linear', 'extrap');
    profile.soc_ref = normalizeSocSignal(profile.soc_ref);
end
if ~isempty(profile.step_id)
    profile.step_id = interp1(time_s, profile.step_id(:), new_time, 'previous', 'extrap');
    profile.step_id = round(profile.step_id);
end
profile.time_s = new_time(:);
end

function [source_capacity_ah, capacity_source] = resolveSourceCapacity(profile, cfg)
source_capacity_ah = [];
capacity_source = '';

if ~isempty(cfg.source_capacity_ah)
    source_capacity_ah = double(cfg.source_capacity_ah);
    capacity_source = 'cfg.source_capacity_ah';
    return;
end
if ~isempty(cfg.original_capacity_ah)
    source_capacity_ah = double(cfg.original_capacity_ah);
    capacity_source = 'cfg.original_capacity_ah';
    return;
end
if ~isempty(cfg.original_1c_current_a)
    source_capacity_ah = double(cfg.original_1c_current_a);
    capacity_source = 'cfg.original_1c_current_a';
    return;
end
if ~isempty(profile.detected_capacity_ah)
    source_capacity_ah = profile.detected_capacity_ah;
    capacity_source = 'dataset';
    return;
end

path_capacity = detectCapacityFromPath(profile.profile_file);
if ~isempty(path_capacity)
    source_capacity_ah = path_capacity;
    capacity_source = 'profile_path';
    return;
end

source_capacity_ah = 8;
capacity_source = 'assumed_8Ah_default';
warning('createBusCoreBatterySyntheticDataset:AssumedSourceCapacity', ...
    'No source capacity was found. Assuming %.1f Ah.', source_capacity_ah);
end

function capacity_ah = detectCapacityFromPath(profile_file)
capacity_ah = [];
tokens = regexp(upper(profile_file), '(\d+(?:P\d+)?)AH', 'tokens', 'once');
if isempty(tokens)
    return;
end
capacity_ah = str2double(strrep(tokens{1}, 'P', '.'));
if ~isfinite(capacity_ah)
    capacity_ah = [];
end
end

function [current_a, sign_multiplier, sign_source] = orientCurrentToDischargePositive(current_a, time_s, soc_ref, cfg)
current_a = current_a(:);
sign_multiplier = 1;
sign_source = 'assumed_discharge_positive';

if ~isempty(cfg.current_sign)
    sign_multiplier = sign(double(cfg.current_sign));
    if sign_multiplier == 0
        sign_multiplier = 1;
    end
    current_a = sign_multiplier * current_a;
    sign_source = 'cfg.current_sign';
    return;
end

if isempty(soc_ref) || all(isnan(soc_ref)) || numel(current_a) < 3
    return;
end

dt = diff(time_s(:));
dsoc = diff(soc_ref(:));
current_k = current_a(1:end-1);
valid = isfinite(dt) & dt > 0 & isfinite(dsoc) & isfinite(current_k) & abs(current_k) > 1e-9;
if ~any(valid)
    return;
end

alignment_score = sum(current_k(valid) .* (-dsoc(valid) ./ dt(valid)));
if alignment_score < 0
    sign_multiplier = -1;
end
current_a = sign_multiplier * current_a;
sign_source = 'auto_from_soc_trend';
end
