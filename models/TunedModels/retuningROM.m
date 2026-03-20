function ROM = retuningROM(output_file, cfg)
% retuningROM Create a beta ATL ROM by retuning the NMC30 ROM OCV.

script_fullpath = mfilename('fullpath');
script_dir = fileparts(script_fullpath);
models_dir = fileparts(script_dir);
repo_root = fileparts(models_dir);

addpath(genpath(repo_root));

if nargin < 1 || isempty(output_file)
    output_file = fullfile(models_dir, 'ROM_ATL20_beta.mat');
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end

if ~isfield(cfg, 'base_rom_file') || isempty(cfg.base_rom_file)
    cfg.base_rom_file = fullfile(models_dir, 'ROM_NMC30_HRA.mat');
end
if ~isfield(cfg, 'esc_model_file') || isempty(cfg.esc_model_file)
    cfg.esc_model_file = fullfile(models_dir, 'ATLmodel.mat');
end
if ~isfield(cfg, 'tc') || isempty(cfg.tc)
    cfg.tc = 25;
end

rom_src = load(cfg.base_rom_file);
if ~isfield(rom_src, 'ROM')
    error('retuningROM:BadROMFile', ...
        'Expected variable "ROM" in %s.', cfg.base_rom_file);
end
ROM = rom_src.ROM;

esc_src = load(cfg.esc_model_file);
esc_model = extractEscModelStruct(esc_src);

required = {'cellData', 'xraData', 'ROMmdls'};
for idx = 1:numel(required)
    if ~isfield(ROM, required{idx})
        error('retuningROM:IncompleteROM', ...
            'Base ROM is missing field %s.', required{idx});
    end
end

if ~isfield(ROM.cellData, 'function') || ...
        ~isfield(ROM.cellData.function, 'neg') || ...
        ~isfield(ROM.cellData.function, 'pos')
    error('retuningROM:BadCellData', ...
        'Base ROM cellData.function.{neg,pos} must exist.');
end

theta0n = double(ROM.cellData.function.neg.theta0());
theta100n = double(ROM.cellData.function.neg.theta100());
theta0p = double(ROM.cellData.function.pos.theta0());
theta100p = double(ROM.cellData.function.pos.theta100());

ROM.cellData.function.neg.Uocp = ...
    @(theta, T) retunedHalfCellUocp(theta, T, esc_model, theta0n, theta100n, -0.5);
ROM.cellData.function.pos.Uocp = ...
    @(theta, T) retunedHalfCellUocp(theta, T, esc_model, theta0p, theta100p, +0.5);
ROM.cellData.function.neg.dUocp = ...
    @(theta, T) retunedHalfCelldUocp(theta, T, esc_model, theta0n, theta100n, -0.5);
ROM.cellData.function.pos.dUocp = ...
    @(theta, T) retunedHalfCelldUocp(theta, T, esc_model, theta0p, theta100p, +0.5);

ROM.meta = struct();
ROM.meta.name = 'ROM_ATL20_beta';
ROM.meta.chemistry = 'ATL20';
ROM.meta.base_rom_file = toProjectRelativePath(cfg.base_rom_file, repo_root);
ROM.meta.base_rom_name = getStructFieldOr(ROM, 'name', 'ROM_NMC30_HRA');
ROM.meta.ocv_source_model_file = toProjectRelativePath(cfg.esc_model_file, repo_root);
ROM.meta.ocv_source_model_name = getStructFieldOr(esc_model, 'name', 'ATL');
ROM.meta.ocv_source_temperature_c = cfg.tc;
ROM.meta.notes = 'OCV retuned from ATL ESC model; ROM dynamics remain from the NMC30 HRA ROM.';
ROM.meta.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');

save(output_file, 'ROM');

fprintf('\nRetuned ROM saved: %s\n', output_file);
fprintf('  Base ROM: %s\n', cfg.base_rom_file);
fprintf('  OCV source model: %s\n', cfg.esc_model_file);
fprintf('  Temperature: %.1f degC\n', cfg.tc);
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

function value = retunedHalfCellUocp(theta, temp_in, esc_model, theta0, theta100, scale_factor)
cell_soc = thetaToCellSoc(theta, theta0, theta100);
temp_c = normalizeRomTemperatureToC(temp_in);
value = scale_factor * OCVfromSOCtemp(cell_soc, temp_c, esc_model);
end

function value = retunedHalfCelldUocp(theta, temp_in, esc_model, theta0, theta100, scale_factor)
cell_soc = thetaToCellSoc(theta, theta0, theta100);
temp_c = normalizeRomTemperatureToC(temp_in);
soc_lo = max(cell_soc - 1e-4, 0);
soc_hi = min(cell_soc + 1e-4, 1);
slope_soc = (OCVfromSOCtemp(soc_hi, temp_c, esc_model) - ...
    OCVfromSOCtemp(soc_lo, temp_c, esc_model)) ./ max(soc_hi - soc_lo, eps);
value = scale_factor * slope_soc ./ (theta100 - theta0);
end

function cell_soc = thetaToCellSoc(theta, theta0, theta100)
cell_soc = (theta - theta0) ./ (theta100 - theta0);
cell_soc = min(max(cell_soc, 0), 1);
end

function temp_c = normalizeRomTemperatureToC(temp_in)
temp_c = temp_in;
if any(temp_in(:) > 100)
    temp_c = temp_in - 273.15;
end
end

function model = extractEscModelStruct(raw)
if isfield(raw, 'model')
    model = raw.model;
elseif isfield(raw, 'nmc30_model')
    model = raw.nmc30_model;
else
    error('retuningROM:BadESCModelFile', ...
        'Expected variable "model" or "nmc30_model" in the ESC model file.');
end
end

function value = getStructFieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end
