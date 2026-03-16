function sweepResults = runOneEstSweeNoise(sigmaWRange, sigmaVRange, stepMultiplier, cfg)
% runOneEstSweeNoise Wrapper for single-estimator noise sweeps.
%
% Defaults:
%   estimator_name = 'ROM-EKF'
%   sigma_w range  = [1e0 1e2]
%   sigma_v range  = [1e-6 2e-1]
%   fixed sigma_w  = 1e2
%   fixed sigma_v  = 1e-2
%   sweep_mode     = 'both'
%
% Examples:
%   runOneEstSweeNoise
%   runOneEstSweeNoise([], [], [], struct('sweep_mode', 'sigma_w'))
%   runOneEstSweeNoise([], [], [], struct('sweep_mode', 'sigma_v'))

if nargin < 1 || isempty(sigmaWRange)
    sigmaWRange = [1e0 1e2];
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

switch cfg.sweep_mode
    case 'both'
        sigma_w_cfg = cfg;
        sigma_w_cfg.sweep_mode = 'sigma_w';
        sigma_w_results = oneEstSweeNoise(sigmaWRange, sigmaVRange, stepMultiplier, sigma_w_cfg);

        sigma_v_cfg = cfg;
        sigma_v_cfg.sweep_mode = 'sigma_v';
        sigma_v_results = oneEstSweeNoise(sigmaWRange, sigmaVRange, stepMultiplier, sigma_v_cfg);

        sweepResults = struct();
        sweepResults.mode = 'both';
        sweepResults.estimator_name = cfg.estimator_name;
        sweepResults.sigma_w_sweep = sigma_w_results;
        sweepResults.sigma_v_sweep = sigma_v_results;

    case {'sigma_w', 'sigma_v', 'grid'}
        sweepResults = oneEstSweeNoise(sigmaWRange, sigmaVRange, stepMultiplier, cfg);

    otherwise
        error('runOneEstSweeNoise:BadSweepMode', ...
            'cfg.sweep_mode must be "both", "sigma_w", "sigma_v", or "grid".');
end

if nargout == 0
    assignin('base', 'oneEstNoiseSweepResults', sweepResults);
end
end

function cfg = normalizeWrapperConfig(cfg)
defaults = struct();
defaults.estimator_name = 'ROM-EKF';
defaults.sweep_mode = 'both';
defaults.fixed_sigma_w = 1e2;
defaults.fixed_sigma_v = 1e-2;
defaults.dataset_mode = 'rom';
defaults.tc = 25;
defaults.ts = 1;
defaults.PlotSocMetricfigs = true;
defaults.PlotVoltageMetricfigs = true;
defaults.PlotInnovationMetricfigs = true;
defaults.tuning = defaultWrapperTuning();

cfg = mergeStructDefaults(cfg, defaults);
cfg.tuning = mergeStructDefaults(cfg.tuning, defaultWrapperTuning());
cfg.sweep_mode = lower(cfg.sweep_mode);
end

function tuning = defaultWrapperTuning()
tuning = struct();
tuning.nx_rom = 12;
tuning.sigma_x0_rom_tail = 2e6;
end

function out = mergeStructDefaults(in, defaults)
out = defaults;
names = fieldnames(in);
for idx = 1:numel(names)
    out.(names{idx}) = in.(names{idx});
end
end
