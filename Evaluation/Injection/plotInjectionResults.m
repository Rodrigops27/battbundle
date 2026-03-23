function fig_handles = plotInjectionResults(resultsInput, cfg)
% plotInjectionResults Re-plot saved benchmark results from injection studies.

if nargin < 2 || isempty(cfg)
    cfg = struct();
end

plot_eval_cfg = struct();
if isfield(cfg, 'plot_eval_cfg') && ~isempty(cfg.plot_eval_cfg)
    plot_eval_cfg = cfg.plot_eval_cfg;
end

data = loadInjectionData(resultsInput);
fig_handles = cell(numel(data.runs), 1);

for idx = 1:numel(data.runs)
    results_file = data.runs(idx).benchmark_results_file;
    if isempty(results_file) || exist(results_file, 'file') ~= 2
        fig_handles{idx} = [];
        continue;
    end
    fig_handles{idx} = plotEvalResults(results_file, plot_eval_cfg);
end
end
