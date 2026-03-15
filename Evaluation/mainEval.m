% mainEval.m
% Structured NMC30 benchmark entry point using the ROM bus_coreBattery dataset.

clear;
clear iterEKF iterESCSPKF iterESCEKF iterEaEKF iterEnacrSPKF;
clear iterEsSPKF iterEbSPKF;

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
addpath(genpath('..'));

%% Settings
tc = 25;
ts = 1;
dataset_file = fullfile(pwd, 'ROMSimData', 'datasets', 'rom_bus_coreBattery_dataset.mat');
profile_file = fullfile(pwd, 'OMTLIFE8AHC-HP', 'Bus_CoreBatteryData_Data.mat');

rom_file = firstExistingFile({ ...
    fullfile('..', 'models', 'ROM_NMC30_HRA12.mat'), ...
    fullfile('..', 'models', 'ROM_NMC30_HRA.mat')}, ...
    'mainEval:MissingROMFile', ...
    'No ROM model file found.');
esc_model_file = firstExistingFile({ ...
    fullfile('..', 'models', 'NMC30model.mat'), ...
    fullfile('..', 'ESC_Id', 'NMC30', 'NMC30model.mat')}, ...
    'mainEval:MissingESCModel', ...
    'No NMC30 ESC model file found.');

%% Load dataset and models
dataset = loadOrBuildRomDataset(dataset_file, profile_file, tc);
rom_src = load(rom_file);
esc_src = load(esc_model_file);

if ~isfield(rom_src, 'ROM')
    error('mainEval:BadROMFile', 'Expected variable "ROM" in %s.', rom_file);
end
ROM = rom_src.ROM;
nmc30_esc = extractEscModelStruct(esc_src);

if ~isfield(nmc30_esc, 'RCParam')
    error('mainEval:MissingRCParam', 'Loaded ESC model is not a full ESC model.');
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
evalDataset.capacity_ah = getParamESC('QParam', tc, nmc30_esc);
evalDataset.reference_name = 'Reference';
evalDataset.voltage_name = 'ROM';
evalDataset.title_prefix = 'NMC30';
evalDataset.r0_reference = getParamESC('R0Param', tc, nmc30_esc);

%% Shared tuning
n_rc = numel(getParamESC('RCParam', tc, nmc30_esc));
nx_rom = 12;
sigma_x0_rom = diag([ones(1, nx_rom), 2e6]);
sigma_w_ekf = 1e2;
sigma_v_ekf = 1e-3;

SigmaX0 = diag([1e-6 * ones(1, n_rc), 1e-6, 1e-3]);
sigma_w_esc = 1e-3; sigma_v_esc = 1e-3;

SigmaR0 = 1e-6; SigmaWR0 = 1e-16;
R0init = getParamESC('R0Param', tc, nmc30_esc);

current_bias_var0 = 1e-5;
single_bias_process_var = 1e-8;

%% Estimator initialization
estimators = repmat(estimatorTemplate(), 7, 1);

estimators(1) = makeEstimator( ...
    'ROM-EKF', ...
    initKF(soc_init_kf, tc, sigma_x0_rom, sigma_v_ekf, sigma_w_ekf, 'OutB', ROM), ...
    @stepRomEkf, soc_init_kf, [0.64 0.08 0.18], '-');

estimators(2) = makeEstimator( ...
    'ESC-SPKF', ...
    initESCSPKF(soc_init_kf, tc, SigmaX0, sigma_v_esc, sigma_w_esc, nmc30_esc), ...
    @stepEscSpkf, soc_init_kf, [0.00 0.45 0.74], ':');

estimators(3) = makeEstimator( ...
    'ESC-EKF', ...
    initESCSPKF(soc_init_kf, tc, SigmaX0, sigma_v_esc, sigma_w_esc, nmc30_esc), ...
    @stepEscEkf, soc_init_kf, [0.85 0.33 0.10], '--');

estimators(4) = makeEstimator( ...
    'EaEKF', ...
    initEaEKF(soc_init_kf, tc, SigmaX0, sigma_v_esc, sigma_w_esc, nmc30_esc), ...
    @stepEaEkf, soc_init_kf, [0.93 0.69 0.13], '-.');

estimators(5) = makeEstimator( ...
    'EnacrSPKF', ...
    initESCSPKF(soc_init_kf, tc, SigmaX0, sigma_v_esc, sigma_w_esc, nmc30_esc), ...
    @stepEnacrSpkf, soc_init_kf, [0.47 0.67 0.19], '--');

estimators(6) = makeEstimator( ...
    'EsSPKF', ...
    initEDUKF(soc_init_kf, R0init, tc, SigmaX0, sigma_v_esc, sigma_w_esc, ...
    SigmaR0, SigmaWR0, nmc30_esc), ...
    @stepEsSpkf, soc_init_kf, [0.13 0.55 0.13], '--');
estimators(6).tracksR0 = true;
estimators(6).r0_init = estimators(6).kfData.R0hat;

estimators(7) = makeEstimator( ...
    'EbSPKF', ...
    initEbSpkf(soc_init_kf, tc, SigmaX0, sigma_v_esc, sigma_w_esc, ...
    single_bias_process_var, current_bias_var0, nmc30_esc), ...
    @stepEbSpkf, soc_init_kf, [0.25 0.25 0.25], ':');
estimators(7).bias_dim = 1;
estimators(7).bias_init = estimators(7).kfData.xhat(estimators(7).kfData.ibInd);
estimators(7).bias_bnd_init = 3 * sqrt(max(estimators(7).kfData.SigmaX(estimators(7).kfData.ibInd, estimators(7).kfData.ibInd), 0));

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

function step = stepEnacrSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd] = iterEnacrSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
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

function dataset = loadOrBuildRomDataset(dataset_file, profile_file, tc)
if exist(dataset_file, 'file') == 2
    raw = load(dataset_file);
    if ~isfield(raw, 'dataset')
        error('mainEval:BadDatasetFile', 'Expected variable "dataset" in %s.', dataset_file);
    end
    dataset = raw.dataset;
    return;
end

cfg = struct();
cfg.profile_file = profile_file;
cfg.source_capacity_ah = 8;
cfg.tc = tc;
dataset = createBusCoreBatterySyntheticDataset(dataset_file, cfg);
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
