function fig_handles = plotAtl20OcvValidation(validation_input, cfg)
% plotAtl20OcvValidation ATL20 wrapper over plotOcvModelFit.

if nargin < 2 || isempty(cfg)
    cfg = struct();
end
if ~isfield(cfg, 'title_prefix') || isempty(cfg.title_prefix)
    cfg.title_prefix = 'ATL20';
end
if ~isfield(cfg, 'min_v') || isempty(cfg.min_v)
    cfg.min_v = 2.0;
end
if ~isfield(cfg, 'max_v') || isempty(cfg.max_v)
    cfg.max_v = 3.75;
end

fig_handles = plotOcvModelFit(validation_input, cfg);
