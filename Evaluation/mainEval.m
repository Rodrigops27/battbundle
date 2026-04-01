% mainEval.m
% Structured ATL benchmark entry point using the ESC bus_coreBattery dataset.

clear;
clear iterEKF iterESCSPKF iterESCEKF iterEaEKF iterEacrSPKF iterEnacrSPKF;
clear iterEDUKF iterEsSPKF iterEbSPKF iterEBiSPKF;

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
repo_root = fileparts(here);
addpath(genpath('..'));

%% Settings
tc = 25;
dataset_file = fullfile('..', 'data', 'evaluation', 'processed', 'desktop_atl20_bss_v1', 'nominal', 'esc_bus_coreBattery_dataset.mat');
profile_file = fullfile('..', 'data', 'evaluation', 'raw', 'omtlife8ahc_hp', 'Bus_CoreBatteryData_Data.mat');
dataset_file = resolveEvaluationDatasetPath(dataset_file, repo_root, 'access', 'benchmark', 'must_exist', false);
profile_file = resolveEvaluationDatasetPath(profile_file, repo_root, 'access', 'builder', 'must_exist', false);
esc_model_file = firstExistingFile({ ...
    fullfile('..', 'models', 'ATLmodel.mat'), ...
    fullfile('..', 'ESC_Id', 'FullESCmodels', 'LFP', 'ATLmodel.mat')}, ...
    'mainEval:MissingESCModel', ...
    'No ATL ESC model file found.');
rom_file = firstExistingFileOrEmpty({ ...
    fullfile('..', 'models', 'ROM_ATL20_beta.mat')});

%% Load dataset and models
dataset = loadOrBuildEscDataset(dataset_file, profile_file, esc_model_file, tc);
esc_src = load(esc_model_file);
esc_model = extractEscModelStruct(esc_src);

if ~isfield(esc_model, 'RCParam')
    error('mainEval:MissingRCParam', 'Loaded ESC model is not a full ESC model.');
end

rom_status = assessRomCompatibility(rom_file, esc_model, esc_model_file);
if rom_status.can_use
    rom_src = load(rom_file);
    if ~isfield(rom_src, 'ROM')
        warning('mainEval:BadROMFile', ...
            'Skipping ROM-EKF because %s does not contain variable "ROM".', rom_file);
        rom_status.can_use = false;
        rom_status.reason = 'ROM file does not contain variable "ROM".';
    else
        ROM = rom_src.ROM;
    end
end

if ~rom_status.can_use
    warning('mainEval:SkippingROMEKF', ...
        ['Skipping ROM-EKF because iterKF requires a compatible ROM for the evaluated chemistry. ', ...
        'Reason: %s'], rom_status.reason);
end

temperature_c = selectTemperatureTrace(dataset, tc);
soc_init_reference = inferReferenceSoc0(dataset);
soc_init_kf = soc_init_reference;

evalDataset = struct();
evalDataset.time_s = dataset.time_s(:);
evalDataset.current_a = dataset.current_a(:);
evalDataset.voltage_v = dataset.voltage_v(:);
evalDataset.temperature_c = temperature_c(:);
evalDataset.dataset_soc = getOptionalField(dataset, 'soc_true', []);
evalDataset.soc_init_reference = soc_init_reference;
evalDataset.capacity_ah = getParamESC('QParam', tc, esc_model);
evalDataset.reference_name = 'Reference';
evalDataset.voltage_name = 'ESC';
evalDataset.title_prefix = rom_status.chemistry_label;
evalDataset.r0_reference = getParamESC('R0Param', tc, esc_model);

%% Shared tuning
n_rc = numel(getParamESC('RCParam', tc, esc_model));
sigma_w_ekf = 1e2;
sigma_v_ekf = 1e-3;

SigmaX0 = diag([1e-6 * ones(1, n_rc), 1e-6, 1e-3]);
sigma_w_esc = 1e-3; sigma_v_esc = 1e-3;

SigmaR0 = 1e-6; SigmaWR0 = 1e-16;
R0init = getParamESC('R0Param', tc, esc_model);

current_bias_var0 = 1e-5;
single_bias_process_var = 1e-8;

%% Estimator initialization
estimators = repmat(estimatorTemplate(), 9 + double(rom_status.can_use), 1);
est_idx = 0;

if rom_status.can_use
    n_rom_states = inferRomTransientStateCount(ROM, []);
    sigma_x0_rom = diag([ones(1, n_rom_states), 2e6]);
    est_idx = est_idx + 1;
    estimators(est_idx) = makeEstimator( ...
        'ROM-EKF', ...
        initKF(soc_init_kf, tc, sigma_x0_rom, sigma_v_ekf, sigma_w_ekf, 'OutB', ROM), ...
        @stepRomEkf, soc_init_kf, [0.64 0.08 0.18], '-');
end

est_idx = est_idx + 1;
estimators(est_idx) = makeEstimator( ...
    'ESC-SPKF', ...
    initESCSPKF(soc_init_kf, tc, SigmaX0, sigma_v_esc, sigma_w_esc, esc_model), ...
    @stepEscSpkf, soc_init_kf, [0.00 0.45 0.74], ':');

est_idx = est_idx + 1;
estimators(est_idx) = makeEstimator( ...
    'ESC-EKF', ...
    initESCSPKF(soc_init_kf, tc, SigmaX0, sigma_v_esc, sigma_w_esc, esc_model), ...
    @stepEscEkf, soc_init_kf, [0.85 0.33 0.10], '--');

est_idx = est_idx + 1;
estimators(est_idx) = makeEstimator( ...
    'EaEKF', ...
    initEaEKF(soc_init_kf, tc, SigmaX0, sigma_v_esc, sigma_w_esc, esc_model), ...
    @stepEaEkf, soc_init_kf, [0.93 0.69 0.13], '-.');

est_idx = est_idx + 1;
estimators(est_idx) = makeEstimator( ...
    'EacrSPKF', ...
    initESCSPKF(soc_init_kf, tc, SigmaX0, sigma_v_esc, sigma_w_esc, esc_model), ...
    @stepEacrSpkf, soc_init_kf, [0.49 0.18 0.56], '-');

est_idx = est_idx + 1;
estimators(est_idx) = makeEstimator( ...
    'EnacrSPKF', ...
    initESCSPKF(soc_init_kf, tc, SigmaX0, sigma_v_esc, sigma_w_esc, esc_model), ...
    @stepEnacrSpkf, soc_init_kf, [0.47 0.67 0.19], '--');

est_idx = est_idx + 1;
estimators(est_idx) = makeEstimator( ...
    'EDUKF', ...
    initEDUKF(soc_init_kf, R0init, tc, SigmaX0, sigma_v_esc, sigma_w_esc, ...
    SigmaR0, SigmaWR0, esc_model), ...
    @stepEdukf, soc_init_kf, [0.30 0.75 0.93], '-');
estimators(est_idx).tracksR0 = true;
estimators(est_idx).r0_init = estimators(est_idx).kfData.R0hat;

est_idx = est_idx + 1;
estimators(est_idx) = makeEstimator( ...
    'EsSPKF', ...
    initEDUKF(soc_init_kf, R0init, tc, SigmaX0, sigma_v_esc, sigma_w_esc, ...
    SigmaR0, SigmaWR0, esc_model), ...
    @stepEsSpkf, soc_init_kf, [0.13 0.55 0.13], '--');
estimators(est_idx).tracksR0 = true;
estimators(est_idx).r0_init = estimators(est_idx).kfData.R0hat;

est_idx = est_idx + 1;
estimators(est_idx) = makeEstimator( ...
    'EbSPKF', ...
    initEbSpkf(soc_init_kf, tc, SigmaX0, sigma_v_esc, sigma_w_esc, ...
    single_bias_process_var, current_bias_var0, esc_model), ...
    @stepEbSpkf, soc_init_kf, [0.25 0.25 0.25], ':');
estimators(est_idx).bias_dim = 1;
estimators(est_idx).bias_init = estimators(est_idx).kfData.xhat(estimators(est_idx).kfData.ibInd);
estimators(est_idx).bias_bnd_init = 3 * sqrt(max(estimators(est_idx).kfData.SigmaX(estimators(est_idx).kfData.ibInd, estimators(est_idx).kfData.ibInd), 0));

est_idx = est_idx + 1;
estimators(est_idx) = makeEstimator( ...
    'EBiSPKF', ...
    initEbiSpkf(soc_init_kf, tc, SigmaX0, sigma_v_esc, sigma_w_esc, current_bias_var0, esc_model), ...
    @stepEbiSpkf, soc_init_kf, [0.64 0.08 0.18], '-.');
estimators(est_idx).bias_dim = 1;
estimators(est_idx).bias_init = estimators(est_idx).kfData.bhat(:).';
estimators(est_idx).bias_bnd_init = 3 * sqrt(max(diag(estimators(est_idx).kfData.SigmaB), 0)).';

%% Flags
flags = struct();
flags.SOCfigs = false;
flags.Vfigs = false;
flags.Biasfigs = true;
flags.R0figs = true;
flags.InnovationACFPACFfigs = true;
flags.default_temperature_c = tc;

%% Evaluate
results = xKFeval(evalDataset, estimators, flags); %#ok<NASGU>

function estimator = makeEstimator(name, kfData, stepFcn, soc0_percent, color, lineStyle)
estimator = estimatorTemplate();
estimator.name = name;
estimator.kfData = kfData;
estimator.stepFcn = stepFcn;
estimator.soc0_percent = soc0_percent;
estimator.color = color;
estimator.lineStyle = lineStyle;
end

function estimator = estimatorTemplate()
estimator = struct( ...
    'name', '', ...
    'kfData', struct(), ...
    'stepFcn', [], ...
    'soc0_percent', NaN, ...
    'color', [], ...
    'lineStyle', '-', ...
    'tracksR0', false, ...
    'r0_init', NaN, ...
    'bias_dim', 0, ...
    'bias_init', [], ...
    'bias_bnd_init', []);
end

function step = stepRomEkf(vk, ik, Tk, ~, kfData)
[zk, boundzk, kfData] = iterEKF(vk, ik, Tk, kfData);
step = baseStepStruct(zk(end), zk(end-1), boundzk(end), boundzk(end-1), kfData);
end

function step = stepEscSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd] = iterESCSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
end

function step = stepEscEkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd] = iterESCEKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
end

function step = stepEaEkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd] = iterEaEKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
end

function step = stepEacrSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd] = iterEacrSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
end

function step = stepEnacrSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd] = iterEnacrSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
end

function step = stepEdukf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd, r0_est, r0_bnd] = iterEDUKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
step.r0 = r0_est;
step.r0_bnd = r0_bnd;
end

function step = stepEsSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd, r0_est, r0_bnd] = iterEsSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
step.r0 = r0_est;
step.r0_bnd = r0_bnd;
end

function step = stepEbSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd, ib_est, ib_bnd] = iterEbSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
step.bias = ib_est;
step.bias_bnd = ib_bnd;
end

function step = stepEbiSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd, ib_est, ib_bnd] = iterEBiSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
step.bias = ib_est;
step.bias_bnd = ib_bnd;
end

function step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData)
step = struct();
step.soc = soc;
step.voltage = v_pred;
step.soc_bnd = soc_bnd;
step.voltage_bnd = v_bnd;
step.kfData = kfData;
step.innovation_pre = getFieldOr(kfData, 'lastInnovationPre', NaN);
step.sk = getFieldOr(kfData, 'lastSk', NaN);
step.r0 = NaN;
step.r0_bnd = NaN;
step.bias = [];
step.bias_bnd = [];
end

function kfData = initEbSpkf(soc0, T0, SigmaX0, SigmaV, sigma_w_current, sigma_w_bias, sigma_ib0, model)
clear iterEbSPKF;

kfData = initESCSPKF(soc0, T0, SigmaX0, SigmaV, [sigma_w_current; sigma_w_bias], model);
kfData.ibInd = kfData.Nx + 1;
kfData.currentNoiseInd = 1;
kfData.biasNoiseInd = 2;
kfData.xhat = [kfData.xhat; 0];
kfData.SigmaX = blkdiag(kfData.SigmaX, sigma_ib0);
kfData.Nx = kfData.Nx + 1;
kfData.Na = kfData.Nx + kfData.Nw + kfData.Nv;
kfData.Snoise = real(chol(diag([kfData.SigmaW(:); kfData.SigmaV(:)]), 'lower'));

h = sqrt(3);
kfData.h = h;
weight1 = (h * h - kfData.Na) / (h * h);
weight2 = 1 / (2 * h * h);
kfData.Wm = [weight1; weight2 * ones(2 * kfData.Na, 1)];
kfData.Wc = kfData.Wm;
end

function kfData = initEbiSpkf(soc0, T0, SigmaX0, SigmaV, SigmaW, sigma_ib0, model)
biasCfg = struct();
biasCfg.nb = 1;
biasCfg.bhat0 = 0;
biasCfg.SigmaB0 = sigma_ib0;
biasCfg.currentBiasInd = 1;
kfData = initESCSPKF(soc0, T0, SigmaX0, SigmaV, SigmaW, model, biasCfg);
end

function dataset = loadOrBuildEscDataset(dataset_file, profile_file, esc_model_file, tc)
if exist(dataset_file, 'file') == 2
    raw = load(dataset_file);
    if ~isfield(raw, 'dataset')
        error('mainEval:BadDatasetFile', 'Expected variable "dataset" in %s.', dataset_file);
    end
    dataset = raw.dataset;
    if isfield(dataset, 'esc_model_file') && ...
            pathsMatchPortable(dataset.esc_model_file, esc_model_file)
        return;
    end
end

cfg = struct();
cfg.profile_file = profile_file;
cfg.source_capacity_ah = 8;
cfg.tc = tc;
cfg.model_file = esc_model_file;
dataset = BSSsimESCdata(dataset_file, cfg);
end

function temperature_c = selectTemperatureTrace(dataset, default_temp)
n_samples = numel(dataset.time_s);
if isfield(dataset, 'temperature_c') && numel(dataset.temperature_c) == n_samples
    temperature_c = dataset.temperature_c(:);
else
    temperature_c = default_temp * ones(n_samples, 1);
end
end

function soc0 = inferReferenceSoc0(dataset)
if isfield(dataset, 'soc_true') && ~isempty(dataset.soc_true) && isfinite(dataset.soc_true(1))
    soc0 = 100 * dataset.soc_true(1);
elseif isfield(dataset, 'soc_init_percent') && ~isempty(dataset.soc_init_percent) && isfinite(dataset.soc_init_percent)
    soc0 = double(dataset.soc_init_percent);
else
    error('mainEval:MissingReferenceSOC0', ...
        'No initial SOC is available from dataset.soc_true(1) or dataset.soc_init_percent.');
end
end

function value = getOptionalField(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function value = getFieldOr(s, fieldName, defaultValue)
if isfield(s, fieldName)
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function model = extractEscModelStruct(raw)
if isfield(raw, 'nmc30_model')
    model = raw.nmc30_model;
elseif isfield(raw, 'model')
    model = raw.model;
else
    error('mainEval:BadESCModelFile', ...
        'Expected variable "nmc30_model" or "model" in the ESC model file.');
end
end

function status = assessRomCompatibility(rom_file, esc_model, esc_model_file)
status = struct();
status.can_use = false;
status.reason = '';
status.chemistry_label = inferChemistryLabel(esc_model, esc_model_file);

if isempty(rom_file)
    status.reason = 'No ROM file was found.';
    return;
end

rom_src = load(rom_file);
if ~isfield(rom_src, 'ROM')
    status.reason = sprintf('ROM file %s does not contain variable "ROM".', rom_file);
    return;
end

rom_tag = '';
if isfield(rom_src.ROM, 'meta') && isstruct(rom_src.ROM.meta)
    if isfield(rom_src.ROM.meta, 'ocv_source_model_name') && ~isempty(rom_src.ROM.meta.ocv_source_model_name)
        rom_tag = char(rom_src.ROM.meta.ocv_source_model_name);
    elseif isfield(rom_src.ROM.meta, 'chemistry') && ~isempty(rom_src.ROM.meta.chemistry)
        rom_tag = char(rom_src.ROM.meta.chemistry);
    end
end

if isempty(rom_tag)
    status.reason = sprintf('ROM file %s has no chemistry metadata for compatibility checks.', rom_file);
    return;
end

if chemistryTagsMatch(rom_tag, status.chemistry_label)
    status.can_use = true;
else
    status.reason = sprintf('ROM chemistry tag "%s" does not match ESC chemistry "%s".', ...
        rom_tag, status.chemistry_label);
end
end

function label = inferChemistryLabel(model, model_file)
if isfield(model, 'name') && ~isempty(model.name)
    label = char(model.name);
else
    [~, label] = fileparts(model_file);
end
end

function tf = chemistryTagsMatch(tag_a, tag_b)
tag_a = normalizeChemistryTag(tag_a);
tag_b = normalizeChemistryTag(tag_b);
tf = strcmp(tag_a, tag_b) || startsWith(tag_a, tag_b) || startsWith(tag_b, tag_a) || ...
    contains(tag_a, tag_b) || contains(tag_b, tag_a);
end

function tag = normalizeChemistryTag(tag)
tag = extractChemistryToken(tag);
tag = upper(char(tag));
tag = regexprep(tag, '[^A-Z0-9]', '');
end

function tag = extractChemistryToken(tag)
tag = upper(char(tag));
tag = regexprep(tag, '[^A-Z0-9]', '');
tokens = regexp(tag, '(NMC\d+|ATL\d*|LFP\d*|NCA\d*|LCO\d*|LMO\d*|LTO\d*|OMTLIFE\d*)', ...
    'match', 'once');
if ~isempty(tokens)
    tag = tokens;
end
end

function n_states = inferRomTransientStateCount(ROM, fallback_value)
if nargin < 2
    fallback_value = [];
end

if isfield(ROM, 'ROMmdls') && ~isempty(ROM.ROMmdls)
    n_states = size(ROM.ROMmdls(1).A, 1) - 1;
    return;
end

if ~isempty(fallback_value)
    n_states = fallback_value;
    return;
end

error('mainEval:MissingROMStateCount', ...
    'Could not infer the ROM transient-state count from ROM.ROMmdls.');
end

function path_out = normalizePath(path_in)
path_out = strrep(char(path_in), '/', filesep);
path_out = strrep(path_out, '\', filesep);
end

function tf = pathsMatchPortable(path_a, path_b)
a = comparablePath(path_a);
b = comparablePath(path_b);
tf = strcmpi(a, b) || endsWith(a, stripLeadingSeparators(b), 'IgnoreCase', true) || ...
    endsWith(b, stripLeadingSeparators(a), 'IgnoreCase', true);
end

function path_out = comparablePath(path_in)
path_out = lower(normalizePath(path_in));
path_out = regexprep(path_out, [regexptranslate('escape', filesep), '+'], filesep);
end

function path_out = stripLeadingSeparators(path_in)
path_out = regexprep(char(path_in), '^[\\/]+', '');
end

function file_path = firstExistingFile(candidates, error_id, error_msg)
file_path = '';
for idx = 1:numel(candidates)
    if exist(candidates{idx}, 'file') == 2
        file_path = candidates{idx};
        return;
    end
end

searched = sprintf('\n  - %s', candidates{:});
error(error_id, '%s Searched:%s', error_msg, searched);
end

function file_path = firstExistingFileOrEmpty(candidates)
file_path = '';
for idx = 1:numel(candidates)
    if exist(candidates{idx}, 'file') == 2
        file_path = candidates{idx};
        return;
    end
end
end
