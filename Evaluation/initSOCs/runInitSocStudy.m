function sweepResults = runInitSocStudy(socRangePercent, socStepPercent)
% runInitSocStudy Wrapper for the ESC initial-SOC convergence study.
%
% Examples:
%   runInitSocStudy
%   runInitSocStudy([45 80], 2)
%
% The wrapper owns the default tuning and plotting choices, then calls
% sweepInitSocStudy with those settings.

if nargin < 1 || isempty(socRangePercent)
    socRangePercent = [0 100];
end
if nargin < 2 || isempty(socStepPercent)
    socStepPercent = 10;
end

cfg = struct();
cfg.dataset_mode = 'rom';
cfg.tc = 25;
cfg.ts = 1;
cfg.SweepSummaryfigs = false;
cfg.PlotSocEstimationfigs = true;
cfg.PlotVoltageEstimationfigs = true;
cfg.tuning = defaultWrapperTuning();

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
