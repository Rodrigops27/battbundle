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

cfg = normalizeWrapperConfig(cfg);
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

function out = mergeStructDefaults(in, defaults)
out = defaults;
names = fieldnames(in);
for idx = 1:numel(names)
    out.(names{idx}) = in.(names{idx});
end
end
