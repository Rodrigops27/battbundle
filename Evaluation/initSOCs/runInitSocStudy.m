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
defaults.estimator_names = { ...
    'iterEbSPKF', 'iterESCSPKF', 'iterEBiSPKF', ...
    'iterEaEKF', 'iterEsSPKF', 'iterEDUKF'};
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
