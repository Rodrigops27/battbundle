function results = runInjTest(cfg)
% runInjTest Evaluate selected filters on an injected NMC30 dataset.
%
% Filters:
%   1. ROM-EKF
%   2. ESC-EKF
%   3. EnacrSPKF
%   4. EaEKF
%   5. EbSPKF
%   6. EsSPKF
%
% Default saved test datasets:
%   1. NMC30_noisInj_15mV_5pctA.mat
%   2. NMC30_FaultInj_volt30mVG1mVO_curr1.1G0.1O.mat
%
% If the selected test dataset does not exist yet, this wrapper creates it
% from the clean ROM dataset and then evaluates the filters. Estimators are
% initialized to 105% of the reference initial SOC.
%
% Example custom regenerations:
%   cfg = struct();
%   cfg.test_case = 'noise';
%   cfg.regenerate_test_data = true;
%   cfg.noise_cfg = struct('voltage_std_mv', 20, ...
%                          'current_error_percent', 3, ...
%                          'random_seed', 7);
%   runInjTest(cfg)
%
%   cfg = struct();
%   cfg.test_case = 'fault';
%   cfg.regenerate_test_data = true;
%   cfg.fault_cfg = struct('current_gain', 1.05, ...
%                          'current_offset_a', 0.05, ...
%                          'voltage_gain_equiv_mv', 25, ...
%                          'voltage_offset_mv_range', 2, ...
%                          'random_seed', 11);
%   runInjTest(cfg)

clear iterEKF iterESCEKF iterEnacrSPKF iterEaEKF iterEbSPKF iterEsSPKF;

if nargin < 1 || isempty(cfg)
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
addpath(genpath(repo_root));

cfg = normalizeRunConfig(cfg, repo_root);

dataset = loadOrCreateInjectedDataset(cfg, repo_root);
rom_src = load(cfg.rom_file);
esc_src = load(cfg.esc_model_file);

if ~isfield(rom_src, 'ROM')
    error('runInjTest:BadROMFile', 'Expected variable "ROM" in %s.', cfg.rom_file);
end
ROM = rom_src.ROM;
nmc30_esc = extractEscModelStruct(esc_src);

evalDataset = buildEvalDataset(dataset, nmc30_esc, cfg);
estimators = buildEstimators(evalDataset.soc_init_kf, cfg, ROM, nmc30_esc);

flags = struct();
flags.SOCfigs = cfg.SOCfigs;
flags.Vfigs = cfg.Vfigs;
flags.Biasfigs = cfg.Biasfigs;
flags.R0figs = cfg.R0figs;
flags.InnovationACFPACFfigs = cfg.InnovationACFPACFfigs;
flags.default_temperature_c = cfg.tc;

results = xKFeval(evalDataset, estimators, flags);
results.injected_dataset_file = getDatasetFile(dataset, cfg.injected_dataset_file);
results.test_case = cfg.test_case;
end

function cfg = normalizeRunConfig(cfg, repo_root)
evaluation_root = fullfile(repo_root, 'Evaluation');
tests_root = fullfile(evaluation_root, 'tests');

cfg.tc = getCfg(cfg, 'tc', 25);
cfg.ts = getCfg(cfg, 'ts', 1);
cfg.soc_init_scale = getCfg(cfg, 'soc_init_scale', 1.05);

cfg.SOCfigs = getCfg(cfg, 'SOCfigs', false);
cfg.Vfigs = getCfg(cfg, 'Vfigs', false);
cfg.Biasfigs = getCfg(cfg, 'Biasfigs', true);
cfg.R0figs = getCfg(cfg, 'R0figs', true);
cfg.InnovationACFPACFfigs = getCfg(cfg, 'InnovationACFPACFfigs', true);

cfg.source_dataset_file = getCfg(cfg, 'source_dataset_file', ...
    fullfile(evaluation_root, 'ROMSimData', 'datasets', 'rom_bus_coreBattery_dataset.mat'));
cfg.test_case = lower(getCfg(cfg, 'test_case', 'noise'));
cfg.test_data_dir = getCfg(cfg, 'test_data_dir', fullfile(tests_root, 'datasets'));
cfg.test_dataset_file = getCfg(cfg, 'test_dataset_file', '');
cfg.regenerate_test_data = getCfg(cfg, 'regenerate_test_data', false);
cfg.noise_cfg = mergeStructDefaults(getCfg(cfg, 'noise_cfg', struct()), defaultNoiseCfg());
cfg.fault_cfg = mergeStructDefaults(getCfg(cfg, 'fault_cfg', struct()), defaultFaultCfg());

if isempty(cfg.test_dataset_file)
    cfg.injected_dataset_file = defaultTestDatasetFile(cfg);
else
    cfg.injected_dataset_file = cfg.test_dataset_file;
end

cfg.rom_file = getCfg(cfg, 'rom_file', ...
    firstExistingFile({ ...
    fullfile(repo_root, 'models', 'ROM_NMC30_HRA12.mat'), ...
    fullfile(repo_root, 'models', 'ROM_NMC30_HRA.mat')}, ...
    'runInjTest:MissingROMFile', ...
    'No ROM model file found.'));
cfg.esc_model_file = getCfg(cfg, 'esc_model_file', ...
    firstExistingFile({ ...
    fullfile(repo_root, 'models', 'NMC30model.mat'), ...
    fullfile(repo_root, 'ESC_Id', 'NMC30', 'NMC30model.mat')}, ...
    'runInjTest:MissingESCModel', ...
    'No NMC30 ESC model file found.'));

cfg.tuning = getCfg(cfg, 'tuning', defaultRunTuning());
cfg.tuning = mergeStructDefaults(cfg.tuning, defaultRunTuning());
end

function noise_cfg = defaultNoiseCfg()
noise_cfg = struct();
noise_cfg.voltage_std_mv = 15;
noise_cfg.current_error_percent = 5;
noise_cfg.random_seed = [];
end

function fault_cfg = defaultFaultCfg()
fault_cfg = struct();
fault_cfg.current_gain = 1.1;
fault_cfg.current_offset_a = 0.1;
fault_cfg.voltage_gain_equiv_mv = 30;
fault_cfg.voltage_offset_mv_range = 1;
fault_cfg.random_seed = [];
fault_cfg.overwrite = true;
end

function tuning = defaultRunTuning()
tuning = struct();
tuning.nx_rom = 12;
tuning.sigma_x0_rom_tail = 2e6;
tuning.sigma_w_ekf = 1e2;
tuning.sigma_v_ekf = 1e-3;
tuning.SigmaX0_rc = 1e-6;
tuning.SigmaX0_hk = 1e-6;
tuning.SigmaX0_soc = 1e-3;
tuning.sigma_w_esc = 1e-3;
tuning.sigma_v_esc = 1e-3;
tuning.SigmaR0 = 1e-6;
tuning.SigmaWR0 = 1e-16;
tuning.current_bias_var0 = 1e-5;
tuning.single_bias_process_var = 1e-8;
end

function dataset = loadOrCreateInjectedDataset(cfg, repo_root)
if exist(cfg.injected_dataset_file, 'file') == 2 && ~cfg.regenerate_test_data
    loaded = load(cfg.injected_dataset_file);
    dataset = extractSavedDataset(loaded, cfg.injected_dataset_file);
    return;
end

switch cfg.test_case
    case 'noise'
        dataset = createNoiseDataset(cfg);
    case 'fault'
        dataset = createFaultDataset(cfg, repo_root);
    otherwise
        error('runInjTest:BadTestCase', ...
            'cfg.test_case must be "noise" or "fault".');
end

if isstruct(dataset)
    if ~isfield(dataset, 'noisy_dataset_file') && ~isfield(dataset, 'fault_dataset_file')
        dataset.noisy_dataset_file = cfg.injected_dataset_file;
    end
end
end

function dataset = createNoiseDataset(cfg)
loaded = load(cfg.source_dataset_file);
base_dataset = extractSavedDataset(loaded, cfg.source_dataset_file);
noise_cfg = cfg.noise_cfg;

dataset = perturbInputDS( ...
    base_dataset, ...
    noise_cfg.voltage_std_mv, ...
    noise_cfg.current_error_percent, ...
    'RandomSeed', noise_cfg.random_seed);

dataset.source_dataset = cfg.source_dataset_file;
dataset.noisy_dataset_file = cfg.injected_dataset_file;
dataset.voltage_name = sprintf('Noise Inj (%.0f mV, %.1f%% I)', ...
    noise_cfg.voltage_std_mv, noise_cfg.current_error_percent);

metadata = struct(); %#ok<NASGU>
metadata.source_dataset = cfg.source_dataset_file;
metadata.test_case = 'noise';
metadata.voltage_std_mv = noise_cfg.voltage_std_mv;
metadata.current_error_percent = noise_cfg.current_error_percent;
metadata.random_seed = noise_cfg.random_seed;
metadata.generated_at = datestr(now, 'yyyy-mm-dd HH:MM:SS');
metadata.generated_by = mfilename;

ensureParentFolder(cfg.injected_dataset_file);
save(cfg.injected_dataset_file, 'dataset', 'metadata');
end

function dataset = createFaultDataset(cfg, repo_root)
loaded = load(cfg.source_dataset_file);
base_dataset = extractSavedDataset(loaded, cfg.source_dataset_file);
fault_cfg = cfg.fault_cfg;

if ~isfield(fault_cfg, 'voltage_gain_fault') || isempty(fault_cfg.voltage_gain_fault)
    nominal_voltage = mean(base_dataset.voltage_v(:), 'omitnan');
    if ~isfinite(nominal_voltage) || nominal_voltage <= 0
        nominal_voltage = 3.6;
    end
    fault_cfg.voltage_gain_fault = (fault_cfg.voltage_gain_equiv_mv / 1000) / nominal_voltage;
end

fault_cfg.overwrite = true;
dataset = InjNoiseData(base_dataset, cfg.injected_dataset_file, fault_cfg);
dataset.source_dataset = cfg.source_dataset_file;
dataset.fault_dataset_file = cfg.injected_dataset_file;

metadata = load(cfg.injected_dataset_file);
if isfield(metadata, 'metadata')
    metadata = metadata.metadata; %#ok<NASGU>
else
    metadata = struct(); %#ok<NASGU>
end
metadata.test_case = 'fault';
metadata.voltage_gain_equiv_mv = getOptionalField(cfg.fault_cfg, 'voltage_gain_equiv_mv', []);
metadata.generated_by = mfilename;
save(cfg.injected_dataset_file, 'dataset', 'metadata');
end

function file_path = defaultTestDatasetFile(cfg)
switch cfg.test_case
    case 'noise'
        filename = 'NMC30_noisInj_15mV_5pctA.mat';
    case 'fault'
        filename = 'NMC30_FaultInj_volt30mVG1mVO_curr1.1G0.1O.mat';
    otherwise
        error('runInjTest:BadTestCase', ...
            'cfg.test_case must be "noise" or "fault".');
end
file_path = fullfile(cfg.test_data_dir, filename);
end

function evalDataset = buildEvalDataset(dataset, model, cfg)
temperature_c = selectTemperatureTrace(dataset, cfg.tc);
soc_init_reference = inferReferenceSoc0(dataset);
soc_init_kf = min(105, cfg.soc_init_scale * soc_init_reference);

evalDataset = struct();
evalDataset.time_s = dataset.time_s(:);
evalDataset.current_a = dataset.current_a(:);
evalDataset.voltage_v = dataset.voltage_v(:);
evalDataset.temperature_c = temperature_c(:);
evalDataset.dataset_soc = getOptionalField(dataset, 'soc_true', []);
evalDataset.dataset_soc_name = 'Dataset SOC';
evalDataset.metric_soc = evalDataset.dataset_soc;
evalDataset.metric_soc_name = evalDataset.dataset_soc_name;
evalDataset.metric_voltage = getOptionalField(dataset, 'voltage_v_true', []);
evalDataset.metric_voltage_name = 'Original Voltage';
evalDataset.soc_init_reference = soc_init_reference;
evalDataset.soc_init_kf = soc_init_kf;
evalDataset.capacity_ah = getParamESC('QParam', cfg.tc, model);
evalDataset.reference_name = 'Reference CC';
evalDataset.voltage_name = getOptionalField(dataset, 'voltage_name', 'Injected');
evalDataset.title_prefix = 'NMC30 Injected Test';
evalDataset.r0_reference = getParamESC('R0Param', cfg.tc, model);
end

function estimators = buildEstimators(soc_init_kf, cfg, ROM, model)
tuning = cfg.tuning;
n_rc = numel(getParamESC('RCParam', cfg.tc, model));

sigma_x0_rom = diag([ones(1, tuning.nx_rom), tuning.sigma_x0_rom_tail]);
SigmaX0 = diag([ ...
    tuning.SigmaX0_rc * ones(1, n_rc), ...
    tuning.SigmaX0_hk, ...
    tuning.SigmaX0_soc]);
R0init = getParamESC('R0Param', cfg.tc, model);

estimators = repmat(estimatorTemplate(), 6, 1);

estimators(1) = makeEstimator( ...
    'ROM-EKF', ...
    initKF(soc_init_kf, cfg.tc, sigma_x0_rom, tuning.sigma_v_ekf, tuning.sigma_w_ekf, 'OutB', ROM), ...
    @stepRomEkf, soc_init_kf, [0.64 0.08 0.18], '-');

estimators(2) = makeEstimator( ...
    'ESC-EKF', ...
    initESCSPKF(soc_init_kf, cfg.tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, model), ...
    @stepEscEkf, soc_init_kf, [0.85 0.33 0.10], '--');

estimators(3) = makeEstimator( ...
    'EnacrSPKF', ...
    initESCSPKF(soc_init_kf, cfg.tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, model), ...
    @stepEnacrSpkf, soc_init_kf, [0.47 0.67 0.19], '--');

estimators(4) = makeEstimator( ...
    'EaEKF', ...
    initEaEKF(soc_init_kf, cfg.tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, model), ...
    @stepEaEkf, soc_init_kf, [0.93 0.69 0.13], '-.');

estimators(5) = makeEstimator( ...
    'EbSPKF', ...
    initEbSpkf(soc_init_kf, cfg.tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, ...
    tuning.single_bias_process_var, tuning.current_bias_var0, model), ...
    @stepEbSpkf, soc_init_kf, [0.25 0.25 0.25], ':');
estimators(5).bias_dim = 1;
estimators(5).bias_init = estimators(5).kfData.xhat(estimators(5).kfData.ibInd);
estimators(5).bias_bnd_init = 3 * sqrt(max( ...
    estimators(5).kfData.SigmaX(estimators(5).kfData.ibInd, estimators(5).kfData.ibInd), 0));

estimators(6) = makeEstimator( ...
    'EsSPKF', ...
    initEDUKF(soc_init_kf, R0init, cfg.tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, ...
    tuning.SigmaR0, tuning.SigmaWR0, model), ...
    @stepEsSpkf, soc_init_kf, [0.13 0.55 0.13], '--');
estimators(6).tracksR0 = true;
estimators(6).r0_init = estimators(6).kfData.R0hat;
end

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

function step = stepEscEkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd] = iterESCEKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
end

function step = stepEnacrSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd] = iterEnacrSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
end

function step = stepEaEkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd] = iterEaEKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
end

function step = stepEbSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd, ib_est, ib_bnd] = iterEbSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
step.bias = ib_est;
step.bias_bnd = ib_bnd;
end

function step = stepEsSpkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd, r0_est, r0_bnd] = iterEsSPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
step.r0 = r0_est;
step.r0_bnd = r0_bnd;
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

function dataset = extractSavedDataset(loaded, file_path)
if isfield(loaded, 'dataset')
    dataset = loaded.dataset;
elseif isfield(loaded, 'evalDataset')
    dataset = loaded.evalDataset;
else
    error('runInjTest:BadDatasetFile', ...
        'Expected variable "dataset" or "evalDataset" in %s.', file_path);
end
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
    error('runInjTest:MissingReferenceSOC0', ...
        'No initial SOC is available from dataset.soc_true(1) or dataset.soc_init_percent.');
end
end

function value = getCfg(cfg, fieldName, defaultValue)
if isfield(cfg, fieldName) && ~isempty(cfg.(fieldName))
    value = cfg.(fieldName);
else
    value = defaultValue;
end
end

function out = mergeStructDefaults(in, defaults)
out = defaults;
names = fieldnames(in);
for idx = 1:numel(names)
    out.(names{idx}) = in.(names{idx});
end
end

function value = getOptionalField(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function value = getDatasetFile(dataset, defaultValue)
if isfield(dataset, 'noisy_dataset_file') && ~isempty(dataset.noisy_dataset_file)
    value = dataset.noisy_dataset_file;
elseif isfield(dataset, 'fault_dataset_file') && ~isempty(dataset.fault_dataset_file)
    value = dataset.fault_dataset_file;
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
    error('runInjTest:BadESCModelFile', ...
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

function ensureParentFolder(filePath)
folder_path = fileparts(filePath);
if ~isempty(folder_path) && exist(folder_path, 'dir') ~= 7
    mkdir(folder_path);
end
end
