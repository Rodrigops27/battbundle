function validation = retuningROMVal(cfg)
% retuningROMVal Validate ROM_ATL20_beta on the legacy 90-to-10 profile.
%
% Usage:
%   validation = retuningROMVal()
%   validation = retuningROMVal(cfg)
%
% Useful cfg fields:
%   rom_file         Tuned ROM file. Default: models/ROM_ATL20_beta.mat
%   esc_model_file   Reference ESC model. Default: models/ATLmodel.mat
%   tc               Temperature in degC. Default: 25
%   ts               Sample time in seconds. Default: ROM Tsamp
%   soc_init         Initial SOC in percent. Default: 100
%   show_plots       Default true

if nargin < 1 || isempty(cfg)
    cfg = struct();
end

script_fullpath = mfilename('fullpath');
script_dir = fileparts(script_fullpath);
models_dir = fileparts(script_dir);
repo_root = fileparts(models_dir);

addpath(genpath(repo_root));

cfg = normalizeConfig(cfg, models_dir);
[ROM, rom_file, rom_name] = loadRomModel(cfg.rom_file);
[esc_model, esc_model_file, esc_model_name] = loadEscModel(cfg.esc_model_file);

capacity_ah = abs(double(getParamESC('QParam', cfg.tc, esc_model)));
[current_a, current_c_rate, step_id, time_s, cfg] = ...
    resolveValidationProfile(cfg, repo_root, esc_model_name, capacity_ah, ROM);
if ~any(abs(current_a) > sqrt(eps))
    error('retuningROMVal:ZeroCurrentProfile', ...
        'The script-1 current profile is zero after scaling. Capacity = %.6g Ah.', capacity_ah);
end

esc_sim = simulateEscReference(current_a, cfg, esc_model);
rom_sim = simulateRomReference(current_a, cfg, ROM);

validation = buildValidationStruct( ...
    time_s, current_a, current_c_rate, step_id, cfg, ...
    esc_sim, rom_sim, rom_file, rom_name, esc_model_file, esc_model_name, capacity_ah);

printSummary(validation);
if cfg.show_plots
    plotRomValidation(validation);
end

if nargout == 0
    assignin('base', 'retuningRomValidation', validation);
end
end

function cfg = normalizeConfig(cfg, models_dir)
cfg.rom_file = fieldOr(cfg, 'rom_file', fullfile(models_dir, 'ROM_ATL20_beta.mat'));
cfg.esc_model_file = fieldOr(cfg, 'esc_model_file', fullfile(models_dir, 'ATLmodel.mat'));
cfg.tc = fieldOr(cfg, 'tc', 25);
cfg.ts = fieldOr(cfg, 'ts', []);
cfg.soc_init = fieldOr(cfg, 'soc_init', 100);
cfg.show_plots = fieldOr(cfg, 'show_plots', true);
cfg.dyn_file = fieldOr(cfg, 'dyn_file', '');
end

function [ROM, rom_file, rom_name] = loadRomModel(rom_file)
if exist(rom_file, 'file') ~= 2
    error('retuningROMVal:MissingROM', 'ROM file not found: %s', rom_file);
end
raw = load(rom_file);
if ~isfield(raw, 'ROM')
    error('retuningROMVal:BadROMFile', ...
        'Expected variable "ROM" in %s.', rom_file);
end
ROM = raw.ROM;
rom_name = displayNameFromPath(rom_file);
required = {'ROMmdls', 'xraData', 'cellData'};
for idx = 1:numel(required)
    if ~isfield(ROM, required{idx})
        error('retuningROMVal:IncompleteROM', ...
            'ROM is missing field %s.', required{idx});
    end
end
end

function [model, model_file, model_name] = loadEscModel(model_file)
if exist(model_file, 'file') ~= 2
    error('retuningROMVal:MissingESCModel', ...
        'ESC model file not found: %s', model_file);
end
raw = load(model_file);
model = extractEscModelStruct(raw);
model_name = displayNameFromPath(model_file);
required = {'QParam', 'RCParam', 'RParam', 'R0Param', 'MParam', 'M0Param', 'GParam', 'etaParam'};
for idx = 1:numel(required)
    if ~isfield(model, required{idx})
        error('retuningROMVal:IncompleteESCModel', ...
            'ESC model %s is missing field %s.', model_file, required{idx});
    end
end
end

function sim = simulateEscReference(current_a, cfg, esc_model)
n_rc = numel(getParamESC('RCParam', cfg.tc, esc_model));
[voltage_v, rc_current_a, hysteresis_state, soc_cc, instantaneous_hysteresis, ocv_v] = ...
    simCell(current_a(:), cfg.tc, cfg.ts, esc_model, cfg.soc_init / 100, zeros(n_rc, 1), 0);

sim = struct();
sim.voltage_v = voltage_v(:);
sim.soc = soc_cc(:);
sim.rc_current_a = rc_current_a;
sim.hysteresis_state = hysteresis_state(:);
sim.instantaneous_hysteresis = instantaneous_hysteresis(:);
sim.ocv_v = ocv_v(:);
sim.mssd_voltage_v2 = computeMssd(sim.voltage_v);
end

function sim = simulateRomReference(current_a, cfg, ROM)
n_samples = numel(current_a);
voltage_v = NaN(n_samples, 1);
soc_rom = NaN(n_samples, 1);
rom_state = [];
init_cfg = struct('SOC0', cfg.soc_init, 'warnOff', true);

for k = 1:n_samples
    if k == 1
        [voltage_v(k), obs, rom_state] = OB_step(current_a(k), cfg.tc, [], ROM, init_cfg);
    else
        [voltage_v(k), obs, rom_state] = OB_step(current_a(k), cfg.tc, rom_state, ROM, []);
    end
    if isstruct(obs) && isfield(obs, 'cellSOC')
        soc_rom(k) = obs.cellSOC;
    end
end

sim = struct();
sim.voltage_v = voltage_v(:);
sim.soc = soc_rom(:);
sim.mssd_voltage_v2 = computeMssd(sim.voltage_v);
end

function validation = buildValidationStruct(time_s, current_a, current_c_rate, step_id, cfg, esc_sim, rom_sim, rom_file, rom_name, esc_model_file, esc_model_name, capacity_ah)
validation = struct();
validation.name = sprintf('%s validation', shortChemistryLabel(rom_name));
validation.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
validation.tc = cfg.tc;
validation.ts = cfg.ts;
validation.soc_init_percent = cfg.soc_init;
validation.capacity_ah = capacity_ah;
validation.rom_file = rom_name;
validation.rom_name = rom_name;
validation.esc_model_file = esc_model_name;
validation.esc_model_name = esc_model_name;
validation.profile_name = cfg.profile_name;
validation.profile_source = cfg.profile_source;
validation.profile_file = cfg.profile_file;
validation.time_s = time_s(:);
validation.current_a = current_a(:);
validation.current_c_rate = current_c_rate(:);
validation.step_id = step_id(:);
validation.esc_voltage_v = esc_sim.voltage_v(:);
validation.rom_voltage_v = rom_sim.voltage_v(:);
validation.esc_soc = esc_sim.soc(:);
validation.rom_soc = rom_sim.soc(:);
validation.voltage_error_v = validation.esc_voltage_v - validation.rom_voltage_v;
validation.soc_error = validation.esc_soc - validation.rom_soc;

valid_voltage = isfinite(validation.esc_voltage_v) & isfinite(validation.rom_voltage_v);
valid_soc = isfinite(validation.esc_soc) & isfinite(validation.rom_soc);

validation.voltage_corr = NaN;
validation.voltage_fit = [NaN, NaN];
validation.voltage_rmse_v = NaN;
validation.voltage_me_v = NaN;
validation.voltage_max_abs_error_v = NaN;
if any(valid_voltage)
    validation.voltage_rmse_v = sqrt(mean(validation.voltage_error_v(valid_voltage) .^ 2));
    validation.voltage_me_v = mean(validation.voltage_error_v(valid_voltage));
    validation.voltage_max_abs_error_v = max(abs(validation.voltage_error_v(valid_voltage)));
end
if nnz(valid_voltage) >= 2
    corr_matrix = corrcoef(validation.esc_voltage_v(valid_voltage), validation.rom_voltage_v(valid_voltage));
    validation.voltage_corr = corr_matrix(1, 2);
    validation.voltage_fit = polyfit(validation.esc_voltage_v(valid_voltage), validation.rom_voltage_v(valid_voltage), 1);
end

validation.soc_rmse = NaN;
validation.soc_me = NaN;
validation.soc_max_abs_error = NaN;
if any(valid_soc)
    validation.soc_rmse = sqrt(mean(validation.soc_error(valid_soc) .^ 2));
    validation.soc_me = mean(validation.soc_error(valid_soc));
    validation.soc_max_abs_error = max(abs(validation.soc_error(valid_soc)));
end

validation.esc_voltage_mssd_mv2 = 1e6 * esc_sim.mssd_voltage_v2;
validation.rom_voltage_mssd_mv2 = 1e6 * rom_sim.mssd_voltage_v2;
validation.metrics = struct( ...
    'voltage_rmse_v', validation.voltage_rmse_v, ...
    'voltage_me_v', validation.voltage_me_v, ...
    'voltage_max_abs_error_v', validation.voltage_max_abs_error_v, ...
    'voltage_corr', validation.voltage_corr, ...
    'voltage_fit', validation.voltage_fit, ...
    'voltage_rmse_mv', 1000 * validation.voltage_rmse_v, ...
    'voltage_me_mv', 1000 * validation.voltage_me_v, ...
    'voltage_max_abs_error_mv', 1000 * validation.voltage_max_abs_error_v, ...
    'soc_rmse', validation.soc_rmse, ...
    'soc_me', validation.soc_me, ...
    'soc_max_abs_error', validation.soc_max_abs_error, ...
    'soc_rmse_percent', 100 * validation.soc_rmse, ...
    'soc_me_percent', 100 * validation.soc_me, ...
    'soc_max_abs_error_percent', 100 * validation.soc_max_abs_error, ...
    'esc_voltage_mssd_mv2', validation.esc_voltage_mssd_mv2, ...
    'rom_voltage_mssd_mv2', validation.rom_voltage_mssd_mv2);
end

function printSummary(validation)
fprintf('\n%s\n', validation.name);
fprintf('  Temperature: %.1f degC | Ts: %.6g s | Initial SOC: %.1f %%\n', ...
    validation.tc, validation.ts, validation.soc_init_percent);
fprintf('  Capacity: %.3f Ah | Samples: %d\n', validation.capacity_ah, numel(validation.time_s));
fprintf('  Current range: [%.3f, %.3f] A | Max C-rate: %.3fC\n', ...
    min(validation.current_a), max(validation.current_a), max(abs(validation.current_c_rate)));
fprintf('  Voltage RMSE: %.2f mV | Mean error: %.2f mV | Max abs: %.2f mV\n', ...
    1000 * validation.voltage_rmse_v, ...
    1000 * validation.voltage_me_v, ...
    1000 * validation.voltage_max_abs_error_v);
fprintf('  Voltage correlation: %.4f | Fit: Vrom = %.4f * Vesc + %.4f\n', ...
    validation.voltage_corr, validation.voltage_fit(1), validation.voltage_fit(2));
fprintf('  SOC RMSE: %.4f %% | Mean error: %.4f %% | Max abs: %.4f %%\n', ...
    100 * validation.soc_rmse, 100 * validation.soc_me, 100 * validation.soc_max_abs_error);
fprintf('  ESC voltage MSSD: %.4f mV^2 | ROM voltage MSSD: %.4f mV^2\n', ...
    validation.esc_voltage_mssd_mv2, validation.rom_voltage_mssd_mv2);
end



function value = computeMssd(signal)
signal = signal(:);
valid = isfinite(signal);
signal = signal(valid);
if numel(signal) < 2
    value = NaN;
    return;
end
value = mean(diff(signal) .^ 2);
end

function model = extractEscModelStruct(raw)
if isfield(raw, 'model')
    model = raw.model;
elseif isfield(raw, 'nmc30_model')
    model = raw.nmc30_model;
else
    names = fieldnames(raw);
    if numel(names) ~= 1
        error('retuningROMVal:BadESCModelFile', ...
            'Expected variable "model" or a single ESC model struct in the ESC model file.');
    end
    model = raw.(names{1});
end
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end

function name = displayNameFromPath(path_in)
[~, name, ext] = fileparts(path_in);
name = [name, ext];
end

function label = shortChemistryLabel(raw_label)
label = upper(displayNameFromPath(raw_label));
label = strrep(label, '.MAT', '');
label = strrep(label, 'ROM_', '');
label = strrep(label, '_BETA', '');
label = strrep(label, 'MODEL', '');
if contains(label, 'OMTLIFE') || contains(label, 'OMT8')
    label = 'OMT8';
elseif contains(label, 'ATL20')
    label = 'ATL20';
elseif contains(label, 'ATL')
    label = 'ATL';
elseif contains(label, 'NMC30')
    label = 'NMC30';
else
    label = strtrim(strrep(label, '_', ' '));
end
end

function [current_a, current_c_rate, step_id, time_s, cfg] = ...
        resolveValidationProfile(cfg, repo_root, esc_model_name, capacity_ah, ROM)
if isempty(cfg.ts)
    cfg.ts = double(ROM.xraData.Tsamp);
end

dyn_file = resolveDynProfileFile(cfg, repo_root, esc_model_name);
if ~isempty(dyn_file)
    [current_a, step_id, time_s, cfg.ts, cfg.profile_name] = ...
        loadDynScript1Profile(dyn_file, cfg.ts);
    cfg.profile_source = 'dyn_script1';
    cfg.profile_file = displayNameFromPath(dyn_file);
else
    [current_c_rate, step_id, time_s] = buildScript1NormalizedProfile(cfg.ts);
    current_a = capacity_ah * current_c_rate;
    cfg.profile_name = sprintf('%s_Dyn.mat', shortChemistryLabel(esc_model_name));
    cfg.profile_source = 'synthetic_script1';
    cfg.profile_file = '';
end

current_a = current_a(:);
time_s = time_s(:);
step_id = step_id(:);
current_c_rate = current_a / max(capacity_ah, eps);
end

function dyn_file = resolveDynProfileFile(cfg, repo_root, esc_model_name)
dyn_file = '';
if ~isempty(cfg.dyn_file)
    dyn_file = cfg.dyn_file;
    if exist(dyn_file, 'file') ~= 2
        dyn_file = fullfile(repo_root, dyn_file);
    end
    if exist(dyn_file, 'file') ~= 2
        error('retuningROMVal:MissingDynFile', ...
            'DYN profile file not found: %s', cfg.dyn_file);
    end
    return;
end

label = shortChemistryLabel(esc_model_name);
switch label
    case 'NMC30'
        candidates = {fullfile(repo_root, 'ESC_Id', 'DYN_Files', 'NMC30_DYN', 'NMC30_DYN_P25.mat')};
    case 'OMT8'
        candidates = {fullfile(repo_root, 'ESC_Id', 'DYN_Files', 'OMT8_DYN', 'OMT8_DYN_P25.mat')};
    case 'ATL'
        candidates = { ...
            fullfile(repo_root, 'ESC_Id', 'DYN_Files', 'ATL_DYN', 'ATL_DYN_P25.mat'), ...
            fullfile(repo_root, 'ESC_Id', 'DYN_Files', 'ATL_DYN', 'ATL_DYN_40_P25.mat')};
    otherwise
        candidates = {};
end

for idx = 1:numel(candidates)
    if exist(candidates{idx}, 'file') == 2
        dyn_file = candidates{idx};
        return;
    end
end
end

function [current_a, step_id, time_s, ts, profile_name] = ...
        loadDynScript1Profile(dyn_file, default_ts)
raw = load(dyn_file);
if ~isfield(raw, 'DYNData') || ~isstruct(raw.DYNData) || ~isfield(raw.DYNData, 'script1')
    error('retuningROMVal:BadDynFile', ...
        'Expected variable DYNData.script1 in %s.', dyn_file);
end

script1 = raw.DYNData.script1;
required = {'current', 'time'};
for idx = 1:numel(required)
    if ~isfield(script1, required{idx})
        error('retuningROMVal:IncompleteDynScript', ...
            'DYNData.script1 is missing field %s in %s.', required{idx}, dyn_file);
    end
end

current_a = double(script1.current(:));
if isfield(script1, 'step') && ~isempty(script1.step)
    step_id = double(script1.step(:));
else
    step_id = ones(size(current_a));
end
time_s = double(script1.time(:));
if numel(time_s) ~= numel(current_a)
    error('retuningROMVal:BadDynTimebase', ...
        'DYNData.script1.time and current size mismatch in %s.', dyn_file);
end

time_s = time_s - time_s(1);
dt = diff(time_s);
dt = dt(isfinite(dt) & dt > 0);
if isempty(dt)
    ts = default_ts;
    time_s = (0:numel(current_a)-1).' * ts;
else
    ts = median(dt);
end

[~, name, ext] = fileparts(dyn_file);
profile_name = [name, ext];
end
