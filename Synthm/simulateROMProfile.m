function dataset = simulateROMProfile(current_a, cfg)
% simulateROMProfile Master ROM simulator for synthetic profile playback.

script_fullpath = mfilename('fullpath');
script_dir = fileparts(script_fullpath);
project_root = fileparts(script_dir);
esc_id_root = fullfile(project_root, 'ESC_Id');

if nargin < 2 || isempty(cfg)
    cfg = struct();
end

if ~isfield(cfg, 'dataset_name') || isempty(cfg.dataset_name)
    cfg.dataset_name = 'ROM synthetic dataset';
end
if ~isfield(cfg, 'soc_init') || isempty(cfg.soc_init)
    cfg.soc_init = 100;
end
if ~isfield(cfg, 'tc') || isempty(cfg.tc)
    cfg.tc = 25;
end
if ~isfield(cfg, 'savePath')
    cfg.savePath = [];
end

rom_file = firstExistingFile({ ...
    fullfile(project_root, 'models', 'ROM_NMC30_HRA12.mat'), ...
    fullfile(project_root, 'ROM_NMC30_HRA12.mat')}, ...
    'simulateROMProfile:MissingROMFile', ...
    'No ROM model file found.');

esc_model_file = firstExistingFile({ ...
    fullfile(project_root, 'models', 'NMC30model.mat'), ...
    fullfile(project_root, 'NMC30model.mat'), ...
    fullfile(esc_id_root, 'NMC30model.mat')}, ...
    'simulateROMProfile:MissingESCModel', ...
    'No NMC30 full ESC model found.');

rom_data = load(rom_file);
ROM = rom_data.ROM;

esc_data = load(esc_model_file);
model = esc_data.nmc30_model;
if ~isfield(model, 'RCParam')
    error('simulateROMProfile:MissingRCParam', ...
        'Loaded ESC model is not full: RCParam is missing.');
end

capacity_ah = double(model.QParam);
sim_ts = double(ROM.xraData.Tsamp);
current_a = current_a(:);

if isfield(cfg, 'time_s') && ~isempty(cfg.time_s)
    time_s = cfg.time_s(:);
    if numel(time_s) ~= numel(current_a)
        error('simulateROMProfile:TimeLengthMismatch', ...
            'time_s has %d samples, current has %d.', numel(time_s), numel(current_a));
    end
    if numel(time_s) > 1
        dt = diff(time_s);
        if any(abs(dt - sim_ts) > 1e-9)
            error('simulateROMProfile:SampleTimeMismatch', ...
                'Profile time base must match ROM Tsamp %.6g s.', sim_ts);
        end
    end
else
    if isfield(cfg, 'ts') && ~isempty(cfg.ts) && abs(double(cfg.ts) - sim_ts) > 1e-12
        warning('simulateROMProfile:IgnoringTsOverride', ...
            'Ignoring cfg.ts=%.6g s and using ROM sample time %.6g s.', double(cfg.ts), sim_ts);
    end
    time_s = (0:numel(current_a)-1).' * sim_ts;
end

step_id = ones(numel(current_a), 1);
if isfield(cfg, 'step_id') && ~isempty(cfg.step_id)
    step_id = cfg.step_id(:);
    if numel(step_id) ~= numel(current_a)
        error('simulateROMProfile:StepLengthMismatch', ...
            'step_id has %d samples, current has %d.', numel(step_id), numel(current_a));
    end
end

temperature_c = cfg.tc * ones(numel(current_a), 1);
voltage_v = NaN(numel(time_s), 1);
soc_rom = NaN(numel(time_s), 1);
rom_state = [];
init_cfg = struct('SOC0', cfg.soc_init, 'warnOff', true);

for k = 1:numel(time_s)
    if k == 1
        [voltage_v(k), obs, rom_state] = OB_step(current_a(k), cfg.tc, [], ROM, init_cfg);
    else
        [voltage_v(k), obs, rom_state] = OB_step(current_a(k), cfg.tc, rom_state, ROM, []);
    end
    if isstruct(obs) && isfield(obs, 'cellSOC')
        soc_rom(k) = obs.cellSOC;
    end
end

soc_cc = NaN(numel(time_s), 1);
soc_cc(1) = cfg.soc_init / 100;
for k = 2:numel(soc_cc)
    soc_cc(k) = soc_cc(k-1) - (current_a(k-1) * sim_ts) / (3600 * capacity_ah);
    soc_cc(k) = max(0, min(1, soc_cc(k)));
end

soc_true = soc_cc;
if isfield(cfg, 'soc_true_ref') && ~isempty(cfg.soc_true_ref)
    soc_true_ref = cfg.soc_true_ref(:);
    if numel(soc_true_ref) ~= numel(current_a)
        error('simulateROMProfile:SocTrueLengthMismatch', ...
            'soc_true_ref has %d samples, current has %d.', numel(soc_true_ref), numel(current_a));
    end
    valid_ref = ~isnan(soc_true_ref);
    soc_true(valid_ref) = soc_true_ref(valid_ref);
end

dataset = struct();
dataset.name = cfg.dataset_name;
dataset.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
dataset.soc_init_percent = cfg.soc_init;
dataset.ts = sim_ts;
dataset.time_s = time_s;
dataset.current_a = current_a;
dataset.voltage_v = voltage_v;
dataset.temperature_c = temperature_c;
dataset.soc_true = soc_true;
dataset.soc_cc = soc_cc;
dataset.soc_rom = soc_rom;
dataset.capacity_ah = capacity_ah;
dataset.step_id = step_id;
dataset.rom_file = rom_file;
dataset.esc_model_file = esc_model_file;

if isfield(cfg, 'extra_fields') && isstruct(cfg.extra_fields)
    dataset = mergeStructFields(dataset, cfg.extra_fields);
end

if isfield(cfg, 'savePath') && ~isempty(cfg.savePath)
    out_dir = fileparts(cfg.savePath);
    if ~isempty(out_dir) && ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end
    save(cfg.savePath, 'dataset');
end
end

function dst = mergeStructFields(dst, src)
fields = fieldnames(src);
for idx = 1:numel(fields)
    dst.(fields{idx}) = src.(fields{idx});
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
