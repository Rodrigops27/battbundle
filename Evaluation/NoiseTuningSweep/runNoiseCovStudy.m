function sweepResults = runNoiseCovStudy(sigmaWRange, sigmaVRange, stepMultiplier, cfg)
% runNoiseCovStudy Wrapper for estimator noise-covariance sweep studies.
%
% Examples:
%   runNoiseCovStudy
%   runNoiseCovStudy([1e-4 1e0], [1e-4 1e0], 2)
%   runNoiseCovStudy([], [], [], struct('sweep_mode', 'sigma_w'))
%
% The wrapper owns the default tuning and plotting choices. By default it
% runs the full 2D sigma_w / sigma_v grid sweep.
% Results are saved to Evaluation/NoiseTuningSweep/results/ by default.
%
% Set cfg.sweep_mode to:
%   'both'    lighter pair of 1D sweeps
%   'sigma_w' process-noise only
%   'sigma_v' sensor-noise only
%   'grid'    default full 2D sigma_w / sigma_v sweep
%
% Set cfg.SaveResults = false to disable saving.
% Set cfg.results_file to override the default .mat output path.

if nargin < 1 || isempty(sigmaWRange)
    sigmaWRange = [1e-3 1e2];
end
if nargin < 2 || isempty(sigmaVRange)
    sigmaVRange = [1e-6 2e-1];
end
if nargin < 3 || isempty(stepMultiplier)
    stepMultiplier = 5;
end
if nargin < 4 || isempty(cfg)
    cfg = struct();
end

cfg = resolveWrapperInputs(cfg);
cfg = normalizeWrapperConfig(cfg);
cfg = ensureParallelPool(cfg);
study_timer = tic;

switch cfg.sweep_mode
    case 'both'
        sigma_w_cfg = cfg;
        sigma_w_cfg.sweep_mode = 'sigma_w';
        sigma_w_results = sweepNoiseStudy(sigmaWRange, sigmaVRange, stepMultiplier, sigma_w_cfg);
        if cfg.PlotEaEkfCovfigs
            plotEaEkfCovarianceSweeps(sigma_w_results);
        end

        sigma_v_cfg = cfg;
        sigma_v_cfg.sweep_mode = 'sigma_v';
        sigma_v_results = sweepNoiseStudy(sigmaWRange, sigmaVRange, stepMultiplier, sigma_v_cfg);
        if cfg.PlotEaEkfCovfigs
            plotEaEkfCovarianceSweeps(sigma_v_results);
        end

        sweepResults = struct();
        sweepResults.mode = 'both';
        sweepResults.sigma_w_sweep = sigma_w_results;
        sweepResults.sigma_v_sweep = sigma_v_results;

    case {'sigma_w', 'sigma_v', 'grid'}
        sweepResults = sweepNoiseStudy(sigmaWRange, sigmaVRange, stepMultiplier, cfg);
        if cfg.PlotEaEkfCovfigs
            plotEaEkfCovarianceSweeps(sweepResults);
        end

    otherwise
        error('runNoiseCovStudy:BadSweepMode', ...
            'cfg.sweep_mode must be "both", "sigma_w", "sigma_v", or "grid".');
end

elapsed_seconds = toc(study_timer);
fprintf('\nrunNoiseCovStudy completed in %.1f s (%.2f min, %.2f h)\n', ...
    elapsed_seconds, elapsed_seconds / 60, elapsed_seconds / 3600);

if isstruct(sweepResults)
    sweepResults.elapsed_seconds = elapsed_seconds;
    sweepResults.wrapper_cfg = cfg;
    sweepResults.sigmaWRange = sigmaWRange;
    sweepResults.sigmaVRange = sigmaVRange;
    sweepResults.stepMultiplier = stepMultiplier;
end

saved_results_file = '';
if cfg.SaveResults
    saved_results_file = saveWrapperResults(sweepResults, cfg, sigmaWRange, sigmaVRange, stepMultiplier);
    if isstruct(sweepResults)
        sweepResults.saved_results_file = saved_results_file;
    end
    fprintf('Saved runNoiseCovStudy results to %s\n', saved_results_file);
end

if nargout == 0
    assignin('base', 'noiseCovSweepResults', sweepResults);
end
end

function cfg = normalizeWrapperConfig(cfg)
defaults = struct();
defaults.dataset_mode = 'esc';
defaults.tc = 25;
defaults.ts = 1;
defaults.sweep_mode = 'grid';
defaults.fixed_sigma_w = 1e-3;
defaults.fixed_sigma_v = 1e-3;
defaults.NoiseSummaryfigs = false;
defaults.PlotSocRmsefigs = true;
defaults.PlotVoltageRmsefigs = true;
defaults.PlotEaEkfCovfigs = true;
defaults.SaveResults = true;
defaults.results_file = '';
defaults.use_parallel = false;
defaults.tuning = defaultWrapperTuning();

cfg = mergeStructDefaults(cfg, defaults);
cfg.tuning = mergeStructDefaults(cfg.tuning, defaultWrapperTuning());
cfg.sweep_mode = lower(cfg.sweep_mode);
end

function results_file = saveWrapperResults(sweepResults, cfg, sigmaWRange, sigmaVRange, stepMultiplier)
script_dir = fileparts(mfilename('fullpath'));
default_results_dir = fullfile(script_dir, 'results');

results_file = cfg.results_file;
if isempty(results_file)
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    results_file = fullfile(default_results_dir, sprintf('runNoiseCovStudy_%s.mat', timestamp));
end

results_file = char(results_file);
[results_dir, ~, ext] = fileparts(results_file);
if isempty(results_dir)
    results_dir = default_results_dir;
    results_file = fullfile(results_dir, results_file);
end
if isempty(ext)
    results_file = [results_file '.mat'];
end

if exist(results_dir, 'dir') ~= 7
    mkdir(results_dir);
end

save(results_file, 'sweepResults', 'cfg', 'sigmaWRange', 'sigmaVRange', 'stepMultiplier', '-v7.3');
end

function tuning = defaultWrapperTuning()
tuning = struct();
tuning.SigmaX0_rc = 1e-6;
tuning.SigmaX0_hk = 1e-6;
tuning.SigmaX0_soc = 1e-3;
tuning.sigma_x0_rom_tail = 2e6;
tuning.nx_rom = 12;
tuning.SigmaR0 = 1e-6;
tuning.SigmaWR0 = 1e-16;
tuning.current_bias_var0 = 1e-5;
tuning.single_bias_process_var = 1e-8;
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

if isfield(cfg, 'parallel') && isstruct(cfg.parallel)
    if (~isfield(cfg, 'use_parallel') || isempty(cfg.use_parallel)) && ...
            isfield(cfg.parallel, 'use_parallel') && ~isempty(cfg.parallel.use_parallel)
        cfg.use_parallel = cfg.parallel.use_parallel;
    end
    if ~isfield(cfg, 'auto_start_pool') || isempty(cfg.auto_start_pool)
        cfg.auto_start_pool = getFieldOr(cfg.parallel, 'auto_start_pool', true);
    end
    if ~isfield(cfg, 'pool_size') || isempty(cfg.pool_size)
        cfg.pool_size = getFieldOr(cfg.parallel, 'pool_size', []);
    end
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

function cfg = ensureParallelPool(cfg)
cfg.use_parallel = logical(getFieldOr(cfg, 'use_parallel', false));
cfg.auto_start_pool = logical(getFieldOr(cfg, 'auto_start_pool', true));
cfg.pool_size = getFieldOr(cfg, 'pool_size', []);

if ~cfg.use_parallel || ~cfg.auto_start_pool
    return;
end
if exist('gcp', 'file') ~= 2 || exist('parpool', 'file') ~= 2
    return;
end
if ~license('test', 'Distrib_Computing_Toolbox')
    return;
end

pool = gcp('nocreate');
if ~isempty(pool)
    return;
end

try
    if isempty(cfg.pool_size)
        parpool('local');
    else
        parpool('local', cfg.pool_size);
    end
catch ME
    fprintf('Parallel noise sweep requested but a pool could not be started (%s). The study will fall back to serial mode if no pool exists.\n', ...
        ME.message);
    cfg.use_parallel = false;
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

function value = getFieldOr(s, field_name, default_value)
if isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end

function out = mergeStructDefaults(in, defaults)
out = defaults;
names = fieldnames(in);
for idx = 1:numel(names)
    out.(names{idx}) = in.(names{idx});
end
end
