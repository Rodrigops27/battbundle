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

model_input = normalizeModelInput(model_input);
results = ESCvalidation(model_input, data_input, enabled_plot);
end

function model_input = normalizeModelInput(model_input)
if ~isstruct(model_input)
    return;
end

if isfield(model_input, 'model') || isfield(model_input, 'nmc30_model')
    return;
end

required = {'QParam', 'RCParam', 'RParam', 'R0Param', 'MParam', 'M0Param', 'GParam', 'etaParam'};
if all(isfield(model_input, required))
    model_input = struct('model', model_input);
end
end
