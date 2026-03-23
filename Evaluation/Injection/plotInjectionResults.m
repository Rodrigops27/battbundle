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
    run_data = data.runs(idx);
    results_struct = loadBenchmarkResults(run_data);
    if isempty(results_struct)
        fig_handles{idx} = [];
        continue;
    end
    results_struct = applyRunTitlePrefix(results_struct, run_data);
    fig_handles{idx} = plotEvalResults(results_struct, plot_eval_cfg);
end
end

function results_struct = loadBenchmarkResults(run_data)
results_struct = [];

if isfield(run_data, 'results') && ~isempty(run_data.results) && ...
        isfield(run_data.results, 'dataset') && isfield(run_data.results, 'estimators')
    results_struct = run_data.results;
    return;
end

results_file = fieldOr(run_data, 'benchmark_results_file', '');
if isempty(results_file) || exist(results_file, 'file') ~= 2
    return;
end

loaded = load(results_file);
names = fieldnames(loaded);
for idx = 1:numel(names)
    candidate = loaded.(names{idx});
    if isstruct(candidate) && isfield(candidate, 'dataset') && isfield(candidate, 'estimators')
        results_struct = candidate;
        return;
    end
end
end

function results_struct = applyRunTitlePrefix(results_struct, run_data)
title_prefix = buildRunTitlePrefix(run_data, results_struct);
if isempty(title_prefix)
    return;
end

if ~isfield(results_struct, 'dataset') || isempty(results_struct.dataset)
    results_struct.dataset = struct();
end
results_struct.dataset.title_prefix = title_prefix;
end

function title_prefix = buildRunTitlePrefix(run_data, results_struct)
chemistry_label = extractChemistryLabel(results_struct);
scenario_label = prettifyToken(fieldOr(run_data, 'scenario_name', ''));
case_label = prettifyToken(fieldOr(run_data, 'case_name', ''));

if ~isempty(chemistry_label) && startsWith(lower(scenario_label), lower(chemistry_label))
    scenario_label = strtrim(scenario_label(numel(chemistry_label) + 1:end));
end

parts = {};
if ~isempty(chemistry_label)
    parts{end + 1} = chemistry_label; %#ok<AGROW>
end
if ~isempty(scenario_label)
    parts{end + 1} = scenario_label; %#ok<AGROW>
end
if ~isempty(case_label)
    parts{end + 1} = case_label; %#ok<AGROW>
end
if ~isempty(parts)
    parts{end + 1} = 'Injection'; %#ok<AGROW>
    title_prefix = strjoin(parts, ' ');
    return;
end

title_prefix = '';
if isfield(results_struct, 'dataset') && isfield(results_struct.dataset, 'title_prefix') && ...
        ~isempty(results_struct.dataset.title_prefix)
    title_prefix = char(results_struct.dataset.title_prefix);
end
end

function chemistry_label = extractChemistryLabel(results_struct)
chemistry_label = '';
if ~isfield(results_struct, 'metadata') || ~isfield(results_struct.metadata, 'modelSpec')
    return;
end
model_spec = results_struct.metadata.modelSpec;
if isfield(model_spec, 'chemistry_label') && ~isempty(model_spec.chemistry_label)
    chemistry_label = char(model_spec.chemistry_label);
end
end

function pretty_value = prettifyToken(raw_value)
raw_value = strtrim(char(raw_value));
if isempty(raw_value)
    pretty_value = '';
    return;
end

tokens = regexp(lower(raw_value), '[_\-\s]+', 'split');
tokens = tokens(~cellfun('isempty', tokens));
acronyms = {'atl', 'bss', 'esc', 'rom', 'soc', 'ocv', 'ekf', 'ukf', 'spkf', 'dukf', 'nmc30'};

for idx = 1:numel(tokens)
    if any(strcmp(tokens{idx}, acronyms))
        tokens{idx} = upper(tokens{idx});
    else
        tokens{idx}(1) = upper(tokens{idx}(1));
    end
end

pretty_value = strjoin(tokens, ' ');
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end
