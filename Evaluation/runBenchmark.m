function results = runBenchmark(datasetSpec, modelSpec, estimatorSetSpec, flags)
% runBenchmark Configurable benchmark runner built on top of xKFeval.
%
% No-input default
%   results = runBenchmark()
%   Runs the repository's default ATL ESC-driven BSS benchmark using:
%     Evaluation/ESCSimData/datasets/esc_bus_coreBattery_dataset.mat
%     models/ATLmodel.mat
%     models/ROM_ATL20_beta.mat
%     estimator registry all
%
% Example
%   datasetSpec = struct( ...
%       'dataset_file', fullfile('Evaluation', 'ROMSimData', 'datasets', 'rom_bus_coreBattery_dataset.mat'), ...
%       'dataset_variable', 'dataset', ...
%       'dataset_soc_field', 'soc_true', ...
%       'metric_soc_field', 'soc_true', ...
%       'metric_voltage_field', 'voltage_v', ...
%       'reference_name', 'ROM reference', ...
%       'voltage_name', 'ROM voltage', ...
%       'title_prefix', 'NMC30');
%
%   modelSpec = struct( ...
%       'esc_model_file', fullfile('models', 'NMC30model.mat'), ...
%       'rom_model_file', fullfile('models', 'ROM_NMC30_HRA12.mat'), ...
%       'tc', 25, ...
%       'chemistry_label', 'NMC30');
%
%   estimatorSetSpec = struct('registry_name', 'mainEval10');
%   flags = struct('Summaryfigs', true, 'Verbose', true);
%   results = runBenchmark(datasetSpec, modelSpec, estimatorSetSpec, flags);
%
% Inputs
%   datasetSpec.dataset_file        MAT file containing a saved dataset struct.
%   datasetSpec.dataset_variable    MAT variable name. Default: 'dataset'
%   datasetSpec.builder_fcn         Optional dataset builder when the MAT file
%                                   is missing or rebuild_dataset = true.
%   datasetSpec.builder_cfg         Optional builder configuration struct.
%   datasetSpec.rebuild_dataset     Optional logical, default false.
%   datasetSpec.dataset_soc_field   Optional field for overlay SOC plotting.
%   datasetSpec.metric_soc_field    Optional field used for SOC metrics.
%   datasetSpec.metric_voltage_field Optional field used for voltage metrics.
%   datasetSpec.temperature_field   Optional temperature field override.
%   datasetSpec.reference_name      Optional label. Default: 'Reference'
%   datasetSpec.voltage_name        Optional label. Default: from dataset or 'Dataset Voltage'
%   datasetSpec.title_prefix        Optional title prefix. Default: chemistry label
%
%   modelSpec.esc_model_file        Required ESC model MAT file.
%   modelSpec.rom_model_file        Optional ROM MAT file used by ROM-EKF.
%   modelSpec.tc                    Temperature in degC. Default: 25.
%   modelSpec.chemistry_label       Optional chemistry label override.
%   modelSpec.require_rom_match     Default true. If true, ROM-EKF is skipped
%                                   when ROM chemistry does not match the ESC model.
%
%   estimatorSetSpec.registry_name  Optional estimator registry. Default: 'mainEval10'
%   estimatorSetSpec.estimator_names Optional cellstr/string estimator names.
%   estimatorSetSpec.allow_rom_skip Optional logical, default true.
%   estimatorSetSpec.soc0_percent   Optional estimator initial SOC override.
%   estimatorSetSpec.tuning         Optional tuning struct.
%
%   flags                           Passed through to xKFeval.
%   flags.SaveResults               Optional logical, default true.
%   flags.results_file              Optional MAT-file path for saved results.
%
% Output
%   results                         xKFeval output with benchmark metadata and
%                                   a metrics table in results.metadata.metrics_table.

use_builtin_default = (nargin < 1 || isempty(datasetSpec)) && ...
    (nargin < 2 || isempty(modelSpec)) && ...
    (nargin < 3 || isempty(estimatorSetSpec)) && ...
    (nargin < 4 || isempty(flags));

if nargin < 1 || isempty(datasetSpec)
    datasetSpec = struct();
end
if nargin < 2 || isempty(modelSpec)
    modelSpec = struct();
end
if nargin < 3 || isempty(estimatorSetSpec)
    estimatorSetSpec = struct();
end
if nargin < 4 || isempty(flags)
    flags = struct();
end

if ~isdeployed
    here = fileparts(which(mfilename));
    if isempty(here)
        here = fileparts(mfilename('fullpath'));
    end
    if isempty(here)
        here = pwd;
    end
else
    here = fileparts(mfilename('fullpath'));
end

repo_root = fileparts(here);
addpath(genpath(repo_root));

if use_builtin_default
    [datasetSpec, modelSpec, estimatorSetSpec, flags] = defaultBenchmarkConfig();
end

datasetSpec = normalizeDatasetSpec(datasetSpec, here, repo_root);
modelSpec = normalizeModelSpec(modelSpec, repo_root);
estimatorSetSpec = normalizeEstimatorSetSpec(estimatorSetSpec);
flags = normalizeBenchmarkFlags(flags, modelSpec.tc);

[esc_model, esc_model_file] = loadEscModel(modelSpec.esc_model_file);
[ROM, rom_status] = loadCompatibleRom(modelSpec, esc_model, esc_model_file, estimatorSetSpec);
dataset = loadDatasetFromSpec(datasetSpec);
evalDataset = buildEvalDataset(dataset, datasetSpec, esc_model, modelSpec, rom_status);
[estimators, estimator_meta] = buildEstimators(evalDataset, estimatorSetSpec, modelSpec.tc, esc_model, ROM, rom_status);

results = xKFeval(evalDataset, estimators, flags);
results.metadata = struct();
results.metadata.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
results.metadata.dataset_file = datasetSpec.dataset_file;
results.metadata.dataset_variable = datasetSpec.dataset_variable;
results.metadata.dataset_name = getFieldOr(dataset, 'name', '');
results.metadata.esc_model_file = esc_model_file;
results.metadata.rom_model_file = rom_status.file;
results.metadata.chemistry_label = rom_status.chemistry_label;
results.metadata.rom_status = rom_status;
results.metadata.estimator_registry = estimatorSetSpec.registry_name;
results.metadata.estimator_names_requested = estimatorSetSpec.estimator_names(:).';
results.metadata.estimator_names_run = {results.estimators.name};
results.metadata.skipped_estimators = estimator_meta.skipped_estimators;
results.metadata.metrics_table = buildMetricsTable(results.estimators);
results.metadata.datasetSpec = stripBuilderHandle(datasetSpec);
results.metadata.modelSpec = modelSpec;
results.metadata.estimatorSetSpec = estimatorSetSpec;
results.metadata.saved_results_file = '';

results = saveResultsIfRequested(results, flags, here, repo_root);

if nargout == 0
    assignin('base', 'benchmarkResults', results);
end
end

function datasetSpec = normalizeDatasetSpec(datasetSpec, evaluation_root, repo_root)
if ~isfield(datasetSpec, 'dataset_file') || isempty(datasetSpec.dataset_file)
    error('runBenchmark:MissingDatasetFile', 'datasetSpec.dataset_file is required.');
end
if ~isfield(datasetSpec, 'dataset_variable') || isempty(datasetSpec.dataset_variable)
    datasetSpec.dataset_variable = 'dataset';
end
if ~isfield(datasetSpec, 'builder_fcn')
    datasetSpec.builder_fcn = [];
end
if ~isfield(datasetSpec, 'builder_cfg') || isempty(datasetSpec.builder_cfg)
    datasetSpec.builder_cfg = struct();
end
if ~isfield(datasetSpec, 'rebuild_dataset') || isempty(datasetSpec.rebuild_dataset)
    datasetSpec.rebuild_dataset = false;
end
if ~isfield(datasetSpec, 'dataset_soc_field'), datasetSpec.dataset_soc_field = ''; end
if ~isfield(datasetSpec, 'metric_soc_field'), datasetSpec.metric_soc_field = ''; end
if ~isfield(datasetSpec, 'metric_voltage_field'), datasetSpec.metric_voltage_field = ''; end
if ~isfield(datasetSpec, 'temperature_field'), datasetSpec.temperature_field = ''; end
if ~isfield(datasetSpec, 'reference_name') || isempty(datasetSpec.reference_name)
    datasetSpec.reference_name = 'Reference';
end
if ~isfield(datasetSpec, 'voltage_name'), datasetSpec.voltage_name = ''; end
if ~isfield(datasetSpec, 'title_prefix'), datasetSpec.title_prefix = ''; end

datasetSpec.dataset_file = resolvePathForReadOrWrite(datasetSpec.dataset_file, evaluation_root, repo_root);
end

function modelSpec = normalizeModelSpec(modelSpec, repo_root)
if ~isfield(modelSpec, 'esc_model_file') || isempty(modelSpec.esc_model_file)
    error('runBenchmark:MissingEscModel', 'modelSpec.esc_model_file is required.');
end
if ~isfield(modelSpec, 'rom_model_file')
    modelSpec.rom_model_file = '';
end
if ~isfield(modelSpec, 'tc') || isempty(modelSpec.tc)
    modelSpec.tc = 25;
end
if ~isfield(modelSpec, 'chemistry_label')
    modelSpec.chemistry_label = '';
end
if ~isfield(modelSpec, 'require_rom_match') || isempty(modelSpec.require_rom_match)
    modelSpec.require_rom_match = true;
end

modelSpec.esc_model_file = resolvePathForRead(modelSpec.esc_model_file, repo_root);
if ~isempty(modelSpec.rom_model_file)
    modelSpec.rom_model_file = resolvePathForRead(modelSpec.rom_model_file, repo_root);
end
end

function estimatorSetSpec = normalizeEstimatorSetSpec(estimatorSetSpec)
if ~isfield(estimatorSetSpec, 'registry_name') || isempty(estimatorSetSpec.registry_name)
    estimatorSetSpec.registry_name = 'mainEval10';
end
if ~isfield(estimatorSetSpec, 'estimator_names') || isempty(estimatorSetSpec.estimator_names)
    estimatorSetSpec.estimator_names = registryEstimatorNames(estimatorSetSpec.registry_name);
end
estimatorSetSpec.estimator_names = normalizeNameList(estimatorSetSpec.estimator_names);

if ~isfield(estimatorSetSpec, 'allow_rom_skip') || isempty(estimatorSetSpec.allow_rom_skip)
    estimatorSetSpec.allow_rom_skip = true;
end
if ~isfield(estimatorSetSpec, 'soc0_percent')
    estimatorSetSpec.soc0_percent = [];
end
defaults = defaultEstimatorTuning();
if ~isfield(estimatorSetSpec, 'tuning') || isempty(estimatorSetSpec.tuning)
    estimatorSetSpec.tuning = defaults;
else
    estimatorSetSpec.tuning = mergeStructDefaults(estimatorSetSpec.tuning, defaults);
end
end

function flags = normalizeBenchmarkFlags(flags, tc)
if ~isfield(flags, 'default_temperature_c') || isempty(flags.default_temperature_c)
    flags.default_temperature_c = tc;
end
if ~isfield(flags, 'SaveResults') || isempty(flags.SaveResults)
    flags.SaveResults = true;
end
if ~isfield(flags, 'results_file')
    flags.results_file = '';
end
end

function [model, model_file] = loadEscModel(model_file)
raw = load(model_file);
model = extractEscModelStruct(raw);
if ~isfield(model, 'RCParam')
    error('runBenchmark:BadESCModel', ...
        'ESC model %s is not a full ESC model.', model_file);
end
end

function [ROM, status] = loadCompatibleRom(modelSpec, esc_model, esc_model_file, estimatorSetSpec)
ROM = [];
status = struct();
status.can_use = false;
status.file = modelSpec.rom_model_file;
status.reason = '';
status.requested = any(strcmpi(estimatorSetSpec.estimator_names, 'ROM-EKF'));
status.chemistry_label = inferChemistryLabel(esc_model, esc_model_file, modelSpec);
status.rom_tag = '';

if ~status.requested
    status.reason = 'ROM-EKF not requested.';
    return;
end
if isempty(modelSpec.rom_model_file)
    status.reason = 'No ROM model file was provided.';
    return;
end
if exist(modelSpec.rom_model_file, 'file') ~= 2
    status.reason = sprintf('ROM model file not found: %s', modelSpec.rom_model_file);
    return;
end

try
    raw = load(modelSpec.rom_model_file);
catch ME
    status.reason = sprintf('Could not load ROM model file %s (%s).', ...
        modelSpec.rom_model_file, ME.message);
    return;
end
if ~isfield(raw, 'ROM')
    status.reason = sprintf('ROM file %s does not contain variable "ROM".', modelSpec.rom_model_file);
    return;
end

ROM = raw.ROM;
status.rom_tag = inferRomChemistryTag(ROM, modelSpec.rom_model_file);
if modelSpec.require_rom_match && ...
        ~chemistryTagsMatch(status.rom_tag, status.chemistry_label)
    status.reason = sprintf('ROM chemistry tag "%s" does not match ESC chemistry "%s".', ...
        status.rom_tag, status.chemistry_label);
    ROM = [];
    return;
end

status.can_use = true;
status.reason = 'ROM is available and accepted.';
end

function dataset = loadDatasetFromSpec(datasetSpec)
if datasetSpec.rebuild_dataset || exist(datasetSpec.dataset_file, 'file') ~= 2
    if isempty(datasetSpec.builder_fcn)
        error('runBenchmark:MissingDataset', ...
            'Dataset file not found and no datasetSpec.builder_fcn was provided: %s', ...
            datasetSpec.dataset_file);
    end
    builder_fcn = resolveFunctionHandle(datasetSpec.builder_fcn);
    dataset = builder_fcn(datasetSpec.dataset_file, datasetSpec.builder_cfg);
    if ~isstruct(dataset)
        loaded = load(datasetSpec.dataset_file);
        dataset = extractSavedDataset(loaded, datasetSpec.dataset_file, datasetSpec.dataset_variable);
    end
    return;
end

loaded = load(datasetSpec.dataset_file);
dataset = extractSavedDataset(loaded, datasetSpec.dataset_file, datasetSpec.dataset_variable);
end

function evalDataset = buildEvalDataset(dataset, datasetSpec, esc_model, modelSpec, rom_status)
temperature_c = selectTemperatureTrace(dataset, modelSpec.tc, datasetSpec.temperature_field);
soc_init_reference = inferReferenceSoc0(dataset);

evalDataset = struct();
evalDataset.time_s = dataset.time_s(:);
evalDataset.current_a = dataset.current_a(:);
evalDataset.voltage_v = dataset.voltage_v(:);
evalDataset.temperature_c = temperature_c(:);
evalDataset.dataset_soc = extractPreferredField(dataset, datasetSpec.dataset_soc_field, {'soc_true', 'source_soc_ref'});
if ~isempty(datasetSpec.metric_soc_field)
    evalDataset.metric_soc = extractPreferredField(dataset, datasetSpec.metric_soc_field, {});
end
if ~isempty(datasetSpec.metric_voltage_field)
    evalDataset.metric_voltage = extractPreferredField(dataset, datasetSpec.metric_voltage_field, {});
end
evalDataset.soc_init_reference = soc_init_reference;
evalDataset.capacity_ah = getParamESC('QParam', modelSpec.tc, esc_model);
evalDataset.reference_name = datasetSpec.reference_name;
evalDataset.voltage_name = inferVoltageLabel(dataset, datasetSpec, rom_status);
evalDataset.title_prefix = inferTitlePrefix(datasetSpec, rom_status);
evalDataset.r0_reference = getParamESC('R0Param', modelSpec.tc, esc_model);

if isfield(dataset, 'reference_soc') && ~isempty(dataset.reference_soc)
    evalDataset.reference_soc = dataset.reference_soc(:);
end
if isfield(dataset, 'dataset_soc_name') && ~isempty(dataset.dataset_soc_name)
    evalDataset.dataset_soc_name = dataset.dataset_soc_name;
elseif ~isempty(evalDataset.dataset_soc)
    evalDataset.dataset_soc_name = 'Dataset SOC';
end
if isfield(dataset, 'metric_soc_name') && ~isempty(dataset.metric_soc_name)
    evalDataset.metric_soc_name = dataset.metric_soc_name;
end
if isfield(dataset, 'metric_voltage_name') && ~isempty(dataset.metric_voltage_name)
    evalDataset.metric_voltage_name = dataset.metric_voltage_name;
end
end

function [estimators, meta] = buildEstimators(evalDataset, estimatorSetSpec, tc, esc_model, ROM, rom_status)
tuning = estimatorSetSpec.tuning;
requested = estimatorSetSpec.estimator_names(:);
estimators = repmat(estimatorTemplate(), numel(requested), 1);
skipped = {};
idx = 0;

n_rc = numel(getParamESC('RCParam', tc, esc_model));
SigmaX0 = diag([ ...
    tuning.SigmaX0_rc * ones(1, n_rc), ...
    tuning.SigmaX0_hk, ...
    tuning.SigmaX0_soc]);
R0init = getParamESC('R0Param', tc, esc_model);

if isempty(estimatorSetSpec.soc0_percent)
    soc0 = evalDataset.soc_init_reference;
else
    soc0 = double(estimatorSetSpec.soc0_percent);
end

for name_idx = 1:numel(requested)
    name = requested{name_idx};
    if strcmpi(name, 'ROM-EKF')
        if ~rom_status.can_use
            if estimatorSetSpec.allow_rom_skip
                warning('runBenchmark:SkippingROMEKF', ...
                    'Skipping ROM-EKF. %s', rom_status.reason);
                skipped{end+1} = name; %#ok<AGROW>
                continue;
            end
            error('runBenchmark:MissingCompatibleROM', ...
                'ROM-EKF requested but no compatible ROM is available. %s', rom_status.reason);
        end
        n_rom_states = inferRomTransientStateCount(ROM, getFieldOr(tuning, 'nx_rom', []));
        sigma_x0_rom = diag([ones(1, n_rom_states), tuning.sigma_x0_rom_tail]);
        idx = idx + 1;
        estimators(idx) = makeEstimator( ...
            'ROM-EKF', ...
            initKF(soc0, tc, sigma_x0_rom, tuning.sigma_v_ekf, tuning.sigma_w_ekf, 'OutB', ROM), ...
            @stepRomEkf, soc0, [0.64 0.08 0.18], '-');
        continue;
    end

    idx = idx + 1;
    estimators(idx) = buildEscEstimator(name, soc0, tc, SigmaX0, tuning, R0init, esc_model);
end

if idx == 0
    error('runBenchmark:NoEstimatorsToRun', ...
        'No estimator remains after applying the benchmark configuration.');
end

estimators = estimators(1:idx);
meta = struct();
meta.skipped_estimators = skipped;
end

function estimator = buildEscEstimator(name, soc0, tc, SigmaX0, tuning, R0init, esc_model)
switch upper(name)
    case 'ESC-SPKF'
        estimator = makeEstimator( ...
            'ESC-SPKF', ...
            initESCSPKF(soc0, tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, esc_model), ...
            @stepEscSpkf, soc0, [0.00 0.45 0.74], ':');

    case 'ESC-EKF'
        estimator = makeEstimator( ...
            'ESC-EKF', ...
            initESCSPKF(soc0, tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, esc_model), ...
            @stepEscEkf, soc0, [0.85 0.33 0.10], '--');

    case 'EAEKF'
        estimator = makeEstimator( ...
            'EaEKF', ...
            initEaEKF(soc0, tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, esc_model), ...
            @stepEaEkf, soc0, [0.93 0.69 0.13], '-.');

    case 'EACRSPKF'
        estimator = makeEstimator( ...
            'EacrSPKF', ...
            initESCSPKF(soc0, tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, esc_model), ...
            @stepEacrSpkf, soc0, [0.49 0.18 0.56], '-');

    case 'ENACRSPKF'
        estimator = makeEstimator( ...
            'EnacrSPKF', ...
            initESCSPKF(soc0, tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, esc_model), ...
            @stepEnacrSpkf, soc0, [0.47 0.67 0.19], '--');

    case 'EDUKF'
        estimator = makeEstimator( ...
            'EDUKF', ...
            initEDUKF(soc0, R0init, tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, ...
            tuning.SigmaR0, tuning.SigmaWR0, esc_model), ...
            @stepEdukf, soc0, [0.30 0.75 0.93], '-');
        estimator.tracksR0 = true;
        estimator.r0_init = estimator.kfData.R0hat;

    case 'ESSPKF'
        estimator = makeEstimator( ...
            'EsSPKF', ...
            initEDUKF(soc0, R0init, tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, ...
            tuning.SigmaR0, tuning.SigmaWR0, esc_model), ...
            @stepEsSpkf, soc0, [0.13 0.55 0.13], '--');
        estimator.tracksR0 = true;
        estimator.r0_init = estimator.kfData.R0hat;

    case 'EBSPKF'
        estimator = makeEstimator( ...
            'EbSPKF', ...
            initEbSpkf(soc0, tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, ...
            tuning.single_bias_process_var, tuning.current_bias_var0, esc_model), ...
            @stepEbSpkf, soc0, [0.25 0.25 0.25], ':');
        estimator.bias_dim = 1;
        estimator.bias_init = estimator.kfData.xhat(estimator.kfData.ibInd);
        estimator.bias_bnd_init = 3 * sqrt(max( ...
            estimator.kfData.SigmaX(estimator.kfData.ibInd, estimator.kfData.ibInd), 0));

    case 'EBISPKF'
        estimator = makeEstimator( ...
            'EBiSPKF', ...
            initEbiSpkf(soc0, tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, ...
            tuning.current_bias_var0, esc_model), ...
            @stepEbiSpkf, soc0, [0.64 0.08 0.18], '-.');
        estimator.bias_dim = 1;
        estimator.bias_init = estimator.kfData.bhat(:).';
        estimator.bias_bnd_init = 3 * sqrt(max(diag(estimator.kfData.SigmaB), 0)).';

    case 'EM7SPKF'
        estimator = makeEstimator( ...
            'Em7SPKF', ...
            initEm7Spkf(soc0, R0init, tc, SigmaX0, tuning.sigma_v_esc, tuning.sigma_w_esc, ...
            tuning.SigmaR0, tuning.SigmaWR0, tuning.current_bias_var0, esc_model), ...
            @stepEm7Spkf, soc0, [0.82 0.23 0.47], '-');
        estimator.tracksR0 = true;
        estimator.r0_init = estimator.kfData.R0hat;
        estimator.bias_dim = 1;
        estimator.bias_init = estimator.kfData.bhat(:).';
        estimator.bias_bnd_init = 3 * sqrt(max(diag(estimator.kfData.SigmaB), 0)).';

    otherwise
        error('runBenchmark:UnknownEstimator', ...
            'Unknown estimator name "%s".', name);
end
end

function table_out = buildMetricsTable(estimator_results)
n_estimators = numel(estimator_results);
names = cell(n_estimators, 1);
soc_rmse_pct = NaN(n_estimators, 1);
soc_me_pct = NaN(n_estimators, 1);
soc_mssd_pct2 = NaN(n_estimators, 1);
voltage_rmse_mv = NaN(n_estimators, 1);
voltage_me_mv = NaN(n_estimators, 1);
voltage_mssd_mv2 = NaN(n_estimators, 1);

for idx = 1:n_estimators
    names{idx} = estimator_results(idx).name;
    soc_rmse_pct(idx) = 100 * estimator_results(idx).rmse_soc;
    soc_me_pct(idx) = 100 * estimator_results(idx).me_soc;
    soc_mssd_pct2(idx) = 1e4 * estimator_results(idx).mssd_soc;
    voltage_rmse_mv(idx) = 1000 * estimator_results(idx).rmse_voltage;
    voltage_me_mv(idx) = 1000 * estimator_results(idx).me_voltage;
    voltage_mssd_mv2(idx) = 1e6 * estimator_results(idx).mssd_voltage;
end

table_out = table( ...
    names, soc_rmse_pct, soc_me_pct, soc_mssd_pct2, ...
    voltage_rmse_mv, voltage_me_mv, voltage_mssd_mv2, ...
    'VariableNames', {'Estimator', 'SocRmsePct', 'SocMePct', 'SocMssdPct2', ...
    'VoltageRmseMv', 'VoltageMeMv', 'VoltageMssdMv2'});
end

function names = registryEstimatorNames(registry_name)
switch lower(char(registry_name))
    case {'all', 'maineval10', 'default_esc_with_optional_rom'}
        names = { ...
            'ROM-EKF', 'ESC-SPKF', 'ESC-EKF', 'EaEKF', 'EacrSPKF', ...
            'EnacrSPKF', 'EDUKF', 'EsSPKF', 'EbSPKF', 'EBiSPKF', 'Em7SPKF'};
    case {'esc9', 'default_esc_only'}
        names = { ...
            'ESC-SPKF', 'ESC-EKF', 'EaEKF', 'EacrSPKF', 'EnacrSPKF', ...
            'EDUKF', 'EsSPKF', 'EbSPKF', 'EBiSPKF', 'Em7SPKF'};
    otherwise
        error('runBenchmark:UnknownRegistry', ...
            'Unknown estimator registry "%s".', registry_name);
end
end

function tuning = defaultEstimatorTuning()
tuning = struct();
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

function step = stepEm7Spkf(vk, ik, Tk, dt, kfData)
[soc, v_pred, soc_bnd, kfData, v_bnd, bias_est, bias_bnd, r0_est, r0_bnd] = Em7SPKF(vk, ik, Tk, dt, kfData);
step = baseStepStruct(soc, v_pred, soc_bnd, v_bnd, kfData);
step.r0 = r0_est;
step.r0_bnd = r0_bnd;
step.bias = bias_est;
step.bias_bnd = bias_bnd;
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

function kfData = initEm7Spkf(soc0, R0init, T0, SigmaX0, SigmaV, SigmaW, SigmaR0, SigmaWR0, sigma_ib0, model)
biasCfg = struct();
biasCfg.nb = 1;
biasCfg.bhat0 = 0;
biasCfg.SigmaB0 = sigma_ib0;
biasCfg.currentBiasInd = 1;
kfData = Em7init(soc0, R0init, T0, SigmaX0, SigmaV, SigmaW, SigmaR0, SigmaWR0, model, biasCfg);
end

function temperature_c = selectTemperatureTrace(dataset, default_temp, override_field)
n_samples = numel(dataset.time_s);
if nargin >= 3 && ~isempty(override_field) && isfield(dataset, override_field)
    raw = dataset.(override_field);
elseif isfield(dataset, 'temperature_c')
    raw = dataset.temperature_c;
else
    raw = [];
end

if isempty(raw)
    temperature_c = default_temp * ones(n_samples, 1);
    return;
end

raw = raw(:);
if numel(raw) == 1
    temperature_c = raw * ones(n_samples, 1);
elseif numel(raw) == n_samples
    temperature_c = raw;
else
    error('runBenchmark:TemperatureLengthMismatch', ...
        'Dataset temperature field length does not match dataset.time_s.');
end
end

function soc0 = inferReferenceSoc0(dataset)
if isfield(dataset, 'soc_true') && ~isempty(dataset.soc_true) && isfinite(dataset.soc_true(1))
    soc0 = 100 * dataset.soc_true(1);
elseif isfield(dataset, 'soc_init_percent') && ~isempty(dataset.soc_init_percent) && isfinite(dataset.soc_init_percent)
    soc0 = double(dataset.soc_init_percent);
elseif isfield(dataset, 'source_soc_ref') && ~isempty(dataset.source_soc_ref) && isfinite(dataset.source_soc_ref(1))
    soc0 = 100 * dataset.source_soc_ref(1);
else
    error('runBenchmark:MissingReferenceSOC0', ...
        'No initial SOC is available from dataset.soc_true, dataset.source_soc_ref, or dataset.soc_init_percent.');
end
end

function field_value = extractPreferredField(dataset, explicit_field, fallback_fields)
field_value = [];
search_order = fallback_fields;
if nargin >= 2 && ~isempty(explicit_field)
    search_order = [{char(explicit_field)}, fallback_fields];
end

for idx = 1:numel(search_order)
    field_name = search_order{idx};
    if isfield(dataset, field_name) && ~isempty(dataset.(field_name))
        field_value = dataset.(field_name)(:);
        return;
    end
end
end

function label = inferVoltageLabel(dataset, datasetSpec, rom_status)
if isfield(datasetSpec, 'voltage_name') && ~isempty(datasetSpec.voltage_name)
    label = datasetSpec.voltage_name;
elseif isfield(dataset, 'voltage_name') && ~isempty(dataset.voltage_name)
    label = dataset.voltage_name;
elseif contains(upper(getFieldOr(dataset, 'name', '')), 'ROM')
    label = 'ROM';
else
    label = 'Dataset Voltage';
end
end

function prefix = inferTitlePrefix(datasetSpec, rom_status)
if ~isempty(datasetSpec.title_prefix)
    prefix = datasetSpec.title_prefix;
else
    prefix = rom_status.chemistry_label;
end
end

function tag = inferRomChemistryTag(ROM, rom_file)
tag = '';
if isfield(ROM, 'meta') && isstruct(ROM.meta)
    if isfield(ROM.meta, 'ocv_source_model_name') && ~isempty(ROM.meta.ocv_source_model_name)
        tag = char(ROM.meta.ocv_source_model_name);
        return;
    end
    if isfield(ROM.meta, 'chemistry') && ~isempty(ROM.meta.chemistry)
        tag = char(ROM.meta.chemistry);
        return;
    end
end
if isfield(ROM, 'name') && ~isempty(ROM.name)
    tag = extractChemistryToken(char(ROM.name));
    return;
end
[~, tag] = fileparts(rom_file);
tag = extractChemistryToken(tag);
end

function label = inferChemistryLabel(model, model_file, modelSpec)
if isfield(modelSpec, 'chemistry_label') && ~isempty(modelSpec.chemistry_label)
    label = char(modelSpec.chemistry_label);
elseif isfield(model, 'name') && ~isempty(model.name)
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

error('runBenchmark:MissingROMStateCount', ...
    'Could not infer the ROM transient-state count from ROM.ROMmdls.');
end

function dataset = extractSavedDataset(loaded, file_path, variable_name)
if isfield(loaded, variable_name)
    dataset = loaded.(variable_name);
    return;
end

names = fieldnames(loaded);
if numel(names) == 1 && isstruct(loaded.(names{1}))
    dataset = loaded.(names{1});
    return;
end

error('runBenchmark:BadDatasetFile', ...
    'Expected variable "%s" in %s.', variable_name, file_path);
end

function value = getFieldOr(s, fieldName, defaultValue)
if isfield(s, fieldName)
    value = s.(fieldName);
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

function model = extractEscModelStruct(raw)
if isfield(raw, 'nmc30_model')
    model = raw.nmc30_model;
elseif isfield(raw, 'model')
    model = raw.model;
else
    error('runBenchmark:BadESCModelFile', ...
        'Expected variable "nmc30_model" or "model" in the ESC model file.');
end
end

function names = normalizeNameList(raw_names)
if ischar(raw_names)
    names = {raw_names};
elseif isa(raw_names, 'string')
    names = cellstr(raw_names(:));
elseif iscell(raw_names)
    names = raw_names(:);
else
    error('runBenchmark:BadEstimatorNames', ...
        'estimator_names must be a char vector, string array, or cell array of char vectors.');
end
end

function path_out = resolvePathForRead(path_in, repo_root)
if exist(path_in, 'file') == 2
    path_out = path_in;
    return;
end
candidate = fullfile(repo_root, path_in);
if exist(candidate, 'file') == 2
    path_out = candidate;
    return;
end
path_out = path_in;
end

function path_out = resolvePathForReadOrWrite(path_in, evaluation_root, repo_root)
if exist(path_in, 'file') == 2
    path_out = path_in;
    return;
end

candidates = { ...
    fullfile(evaluation_root, path_in), ...
    fullfile(repo_root, path_in)};

for idx = 1:numel(candidates)
    candidate = candidates{idx};
    if exist(candidate, 'file') == 2
        path_out = candidate;
        return;
    end
end

if isAbsolutePath(path_in)
    path_out = path_in;
else
    path_out = fullfile(repo_root, path_in);
end
end

function tf = isAbsolutePath(path_in)
path_in = char(path_in);
tf = numel(path_in) >= 2 && path_in(2) == ':';
end

function fcn = resolveFunctionHandle(raw_fcn)
if isa(raw_fcn, 'function_handle')
    fcn = raw_fcn;
elseif ischar(raw_fcn) || (isa(raw_fcn, 'string') && isscalar(raw_fcn))
    fcn = str2func(char(raw_fcn));
else
    error('runBenchmark:BadBuilderFcn', ...
        'datasetSpec.builder_fcn must be a function handle or function name.');
end
end

function spec = stripBuilderHandle(spec)
if isfield(spec, 'builder_fcn') && isa(spec.builder_fcn, 'function_handle')
    spec.builder_fcn = func2str(spec.builder_fcn);
end
end

function results = saveResultsIfRequested(results, flags, evaluation_root, repo_root)
if ~flags.SaveResults
    return;
end

results_file = flags.results_file;
if isempty(results_file)
    results_file = defaultResultsFile(results, evaluation_root);
else
    results_file = resolveSavePath(results_file, evaluation_root, repo_root);
end

results_dir = fileparts(results_file);
if ~isempty(results_dir) && exist(results_dir, 'dir') ~= 7
    mkdir(results_dir);
end

save(results_file, 'results');
results.metadata.saved_results_file = results_file;
end

function results_file = defaultResultsFile(results, evaluation_root)
base_name = sanitizeFileToken(extractResultsLabel(results));
if isempty(base_name)
    base_name = 'benchmark';
end
results_file = fullfile(evaluation_root, 'results', [base_name '_benchmark_results.mat']);
end

function label = extractResultsLabel(results)
label = '';
if isfield(results, 'dataset') && isfield(results.dataset, 'title_prefix') && ~isempty(results.dataset.title_prefix)
    label = char(results.dataset.title_prefix);
elseif isfield(results, 'metadata') && isfield(results.metadata, 'modelSpec') && ...
        isfield(results.metadata.modelSpec, 'chemistry_label') && ~isempty(results.metadata.modelSpec.chemistry_label)
    label = char(results.metadata.modelSpec.chemistry_label);
end
end

function token = sanitizeFileToken(raw_label)
token = lower(char(raw_label));
token = regexprep(token, '[^a-z0-9]+', '_');
token = regexprep(token, '_+', '_');
token = regexprep(token, '^_|_$', '');
end

function path_out = resolveSavePath(path_in, evaluation_root, repo_root)
if isAbsolutePath(path_in)
    path_out = path_in;
    return;
end

path_out = fullfile(evaluation_root, path_in);
parent_dir = fileparts(path_out);
if ~isempty(parent_dir) && exist(parent_dir, 'dir') == 7
    return;
end

path_out = fullfile(repo_root, path_in);
end

function [datasetSpec, modelSpec, estimatorSetSpec, flags] = defaultBenchmarkConfig()
datasetSpec = struct( ...
    'dataset_file', fullfile('Evaluation', 'ESCSimData', 'datasets', 'esc_bus_coreBattery_dataset.mat'), ...
    'dataset_variable', 'dataset', ...
    'builder_fcn', 'BSSsimESCdata', ...
    'builder_cfg', struct( ...
        'model_file', fullfile('models', 'ATLmodel.mat'), ...
        'tc', 25), ...
    'dataset_soc_field', 'soc_true', ...
    'metric_soc_field', 'soc_true', ...
    'metric_voltage_field', 'voltage_v', ...
    'reference_name', 'ESC reference', ...
    'voltage_name', 'ESC voltage', ...
    'title_prefix', 'ATL BSS');

modelSpec = struct( ...
    'esc_model_file', fullfile('models', 'ATLmodel.mat'), ...
    'rom_model_file', fullfile('models', 'ROM_ATL20_beta.mat'), ...
    'tc', 25, ...
    'chemistry_label', 'ATL', ...
    'require_rom_match', true);

estimatorSetSpec = struct( ...
    'registry_name', 'all', ...
    'allow_rom_skip', true);

flags = struct( ...
    'SOCfigs', false, ...
    'Vfigs', false, ...
    'Biasfigs', true, ...
    'R0figs', true, ...
    'InnovationACFPACFfigs', true, ...
    'Summaryfigs', true, ...
    'Verbose', true, ...
    'SaveResults', true);
end
