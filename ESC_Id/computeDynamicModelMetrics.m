function results = computeDynamicModelMetrics(model_input, data_input, cfg)
% computeDynamicModelMetrics Compute dynamic-fit metrics for an ESC model.
%
% This is the ESC_Id dynamic-identification metrics entry point. It reuses
% ESCvalidation because that already supports legacy processDynamic-style
% script1 data and reports RMSE and mean error.

if nargin < 3 || isempty(cfg)
    cfg = struct();
end
enabled_plot = false;
if isfield(cfg, 'enabled_plot') && ~isempty(cfg.enabled_plot)
    enabled_plot = logical(cfg.enabled_plot);
end

results = ESCvalidation(model_input, data_input, enabled_plot);
end
