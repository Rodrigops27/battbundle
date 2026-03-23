function fig_handles = plotAutotunedResults(resultsInput, cfg)
% plotAutotunedResults Re-plot the saved best benchmark results for tuned runs.

if nargin < 2 || isempty(cfg)
    cfg = struct();
end

plot_eval_cfg = struct();
if isfield(cfg, 'plot_eval_cfg') && ~isempty(cfg.plot_eval_cfg)
    plot_eval_cfg = cfg.plot_eval_cfg;
end

data = loadAutotuningData(resultsInput);
fig_handles = cell(numel(data.runs), 1);

for idx = 1:numel(data.runs)
    results_file = fieldOr(data.runs(idx), 'best_benchmark_results_file', '');
    if isempty(results_file) || exist(results_file, 'file') ~= 2
        fig_handles{idx} = [];
        continue;
    end
    fig_handles{idx} = plotEvalResults(results_file, plot_eval_cfg);
end
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end
