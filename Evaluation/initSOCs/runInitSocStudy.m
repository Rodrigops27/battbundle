function sweepResults = runInitSocStudy(socRangePercent, socStepPercent, cfg)
% runInitSocStudy Wrapper for the ESC initial-SOC convergence study.
%
% Examples:
%   runInitSocStudy
%   runInitSocStudy([45 80], 2)
%   runInitSocStudy([45 80], 2, cfg)
%
% The wrapper owns the default tuning and plotting choices, then calls
% sweepInitSocStudy with those settings.

if nargin < 1 || isempty(socRangePercent)
    socRangePercent = [0 100];
end
if nargin < 2 || isempty(socStepPercent)
    socStepPercent = 10;
end
if nargin < 3 || isempty(cfg)
    cfg = struct();
end

cfg = resolveWrapperInputs(cfg);

defaults = struct();
defaults.dataset_mode = 'esc';
defaults.tc = 25;
defaults.ts = 1;
defaults.SweepSummaryfigs = false;
defaults.PlotSocEstimationfigs = true;
defaults.PlotVoltageEstimationfigs = true;
defaults.SaveResults = true;
defaults.results_file = '';
defaults.parallel = struct( ...
    'use_parallel', false, ...
    'auto_start_pool', true, ...
    'pool_size', []);
defaults.estimator_names = defaultWrapperEstimatorNames();
defaults.tuning = defaultWrapperTuning();

cfg = mergeStructDefaults(cfg, defaults);
if ~isProfileSpec(cfg.tuning)
    cfg.tuning = mergeStructDefaults(cfg.tuning, defaultWrapperTuning());
end

sweepResults = sweepInitSocStudy(socRangePercent, socStepPercent, cfg);

if nargout == 0
    assignin('base', 'initSocSweepResults', sweepResults);
end
end

function tuning = defaultWrapperTuning()
tuning = struct();
tuning.SigmaX0_rc = 1e-6;
tuning.SigmaX0_hk = 1e-6;
tuning.SigmaX0_soc = 1e-3;
tuning.sigma_w_ekf = 1e2;
tuning.sigma_v_ekf = 1e-3;
tuning.sigma_w_esc = 1e-3;
tuning.sigma_v_esc = 1e-3;
tuning.SigmaR0 = 1e-6;
tuning.SigmaWR0 = 1e-16;
tuning.sigma_w_bias = 1e-3;
tuning.sigma_v_bias = 1e2;
tuning.current_bias_var0 = 1e-5;
tuning.output_bias_var0 = 1e-5;
tuning.single_bias_process_var = 1e-8;
end

function estimator_names = defaultWrapperEstimatorNames()
estimator_names = { ...
    'iterEbSPKF', 'iterESCSPKF', 'iterEBiSPKF', ...
    'iterEaEKF', 'iterEsSPKF', 'iterEDUKF'};
end

function cfg = resolveWrapperInputs(cfg)
scenario = firstScenarioOrEmpty(cfg);
estimator_set_spec = firstEstimatorSetSpecOrEmpty(cfg, scenario);
model_spec = firstModelSpecOrEmpty(cfg, scenario);
dataset_spec = firstDatasetSpecOrEmpty(cfg, scenario);

if ~isfield(cfg, 'estimator_names') || isempty(cfg.estimator_names)
    if isfield(estimator_set_spec, 'estimator_names') && ~isempty(estimator_set_spec.estimator_names)
        cfg.estimator_names = estimator_set_spec.estimator_names;
    elseif isfield(estimator_set_spec, 'registry_name') && ...
            strcmpi(char(estimator_set_spec.registry_name), 'all')
        cfg.estimator_names = fullWrapperEstimatorNames();
    end
end

if (~isfield(cfg, 'tuning') || isempty(cfg.tuning)) && ...
        isfield(estimator_set_spec, 'tuning') && ~isempty(estimator_set_spec.tuning)
    cfg.tuning = estimator_set_spec.tuning;
end

if (~isfield(cfg, 'tc') || isempty(cfg.tc)) && isfield(model_spec, 'tc') && ~isempty(model_spec.tc)
    cfg.tc = model_spec.tc;
end
if (~isfield(cfg, 'esc_model_file') || isempty(cfg.esc_model_file)) && ...
        isfield(model_spec, 'esc_model_file') && ~isempty(model_spec.esc_model_file)
    cfg.esc_model_file = model_spec.esc_model_file;
end
if (~isfield(cfg, 'rom_file') || isempty(cfg.rom_file)) && ...
        isfield(model_spec, 'rom_model_file') && ~isempty(model_spec.rom_model_file)
    cfg.rom_file = model_spec.rom_model_file;
end

if isfield(dataset_spec, 'dataset_file') && ~isempty(dataset_spec.dataset_file)
    if ~isfield(cfg, 'dataset_mode') || isempty(cfg.dataset_mode)
        cfg.dataset_mode = 'esc';
    end
    if strcmpi(char(cfg.dataset_mode), 'esc') && ...
            (~isfield(cfg, 'esc_dataset_file') || isempty(cfg.esc_dataset_file))
        cfg.esc_dataset_file = dataset_spec.dataset_file;
    elseif strcmpi(char(cfg.dataset_mode), 'rom') && ...
            (~isfield(cfg, 'rom_dataset_file') || isempty(cfg.rom_dataset_file))
        cfg.rom_dataset_file = dataset_spec.dataset_file;
    end
end
end

function estimator_names = fullWrapperEstimatorNames()
estimator_names = { ...
    'ROM-EKF', ...
    'ESC-SPKF', 'ESC-EKF', 'EaEKF', ...
    'EacrSPKF', 'EnacrSPKF', 'EDUKF', ...
    'EsSPKF', 'EbSPKF', 'EBiSPKF', 'Em7SPKF'};
end

function scenario = firstScenarioOrEmpty(cfg)
scenario = struct();
if isfield(cfg, 'scenarios') && ~isempty(cfg.scenarios)
    scenario = cfg.scenarios(1);
end
end

function estimator_set_spec = firstEstimatorSetSpecOrEmpty(cfg, scenario)
estimator_set_spec = struct();
if isfield(cfg, 'estimatorSetSpec') && ~isempty(cfg.estimatorSetSpec)
    estimator_set_spec = cfg.estimatorSetSpec;
elseif isfield(scenario, 'estimatorSetSpec') && ~isempty(scenario.estimatorSetSpec)
    estimator_set_spec = scenario.estimatorSetSpec;
end
end

function model_spec = firstModelSpecOrEmpty(cfg, scenario)
model_spec = struct();
if isfield(cfg, 'modelSpec') && ~isempty(cfg.modelSpec)
    model_spec = cfg.modelSpec;
elseif isfield(scenario, 'modelSpec') && ~isempty(scenario.modelSpec)
    model_spec = scenario.modelSpec;
end
end

function dataset_spec = firstDatasetSpecOrEmpty(cfg, scenario)
dataset_spec = struct();
if isfield(cfg, 'datasetSpec') && ~isempty(cfg.datasetSpec)
    dataset_spec = cfg.datasetSpec;
elseif isfield(scenario, 'benchmark_dataset_template') && ~isempty(scenario.benchmark_dataset_template)
    dataset_spec = scenario.benchmark_dataset_template;
elseif isfield(scenario, 'source_dataset') && isfield(scenario.source_dataset, 'dataset_file')
    dataset_spec = struct('dataset_file', scenario.source_dataset.dataset_file);
end
end

function out = mergeStructDefaults(in, defaults)
out = defaults;
names = fieldnames(in);
for idx = 1:numel(names)
    out.(names{idx}) = in.(names{idx});
end
end

function tf = isProfileSpec(tuning_spec)
tf = isstruct(tuning_spec) && ...
    (isfield(tuning_spec, 'param_file') || ...
    (isfield(tuning_spec, 'kind') && strcmpi(char(tuning_spec.kind), 'autotuning_profile')));
end
