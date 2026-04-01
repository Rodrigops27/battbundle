function validation = computeAtl20OcvValidationMetrics(model_inputs, cfg)
% computeAtl20OcvValidationMetrics ATL20 wrapper over computeOcvModelMetrics.

script_dir = fileparts(mfilename('fullpath'));
results_root = fileparts(script_dir);
esc_root = fileparts(results_root);
repo_root = fileparts(esc_root);

if nargin < 1 || isempty(model_inputs)
    model_inputs = { ...
        fullfile(repo_root, 'data', 'modelling', 'derived', 'ocv_models', 'atl', 'ATLmodel-ocv.mat'), ...
        fullfile(repo_root, 'data', 'modelling', 'derived', 'ocv_models', 'atl20', 'ATL20model-ocv-vavgFT.mat')};
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end

if ~isfield(cfg, 'cell_id') || isempty(cfg.cell_id)
    cfg.cell_id = 'ATL20';
end
if ~isfield(cfg, 'data_prefix') || isempty(cfg.data_prefix)
    cfg.data_prefix = 'ATL';
end
if ~isfield(cfg, 'temps_degC') || isempty(cfg.temps_degC)
    cfg.temps_degC = [-25 -15 -5 5 15 25 35 45];
end
if ~isfield(cfg, 'min_v') || isempty(cfg.min_v)
    cfg.min_v = 2.0;
end
if ~isfield(cfg, 'max_v') || isempty(cfg.max_v)
    cfg.max_v = 3.75;
end
if ~isfield(cfg, 'ocv_method') || isempty(cfg.ocv_method)
    cfg.ocv_method = 'diagAverage';
end
if ~isfield(cfg, 'data_dir') || isempty(cfg.data_dir)
    cfg.data_dir = fullfile(repo_root, 'data', 'modelling', 'processed', 'ocv', 'atl20');
end

validation = computeOcvModelMetrics(model_inputs, cfg.data_dir, cfg);
