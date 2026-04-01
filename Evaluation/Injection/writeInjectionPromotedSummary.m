function artifact = writeInjectionPromotedSummary(results_file, summary_json_file, summary_md_file, suite_version, scenario_id)
% writeInjectionPromotedSummary Write promoted JSON/Markdown summaries for an injection study.

if nargin < 5
    error('writeInjectionPromotedSummary:MissingInputs', ...
        'results_file, summary_json_file, summary_md_file, suite_version, and scenario_id are required.');
end

repo_root = resolveRepoRoot();
results_file = resolveInputPath(results_file, repo_root);
summary_json_file = resolveOutputPath(summary_json_file, repo_root);
summary_md_file = resolveOutputPath(summary_md_file, repo_root);

ensureDir(fileparts(summary_json_file));
ensureDir(fileparts(summary_md_file));

data = loadInjectionData(results_file);
artifact = buildInjectionSummaryArtifact( ...
    data, results_file, summary_json_file, summary_md_file, suite_version, scenario_id);

writeJsonArtifact(summary_json_file, artifact);
writeMarkdownArtifact(summary_md_file, renderInjectionSummaryMarkdown(artifact));
end

function artifact = buildInjectionSummaryArtifact(data, heavy_results_file, summary_json_file, summary_md_file, suite_version, scenario_id)
artifact = struct();
artifact.artifact_class = 'summary';
artifact.kind = 'injection_summary';
artifact.layer = 'evaluation';
artifact.suite_version = char(suite_version);
artifact.scenario_id = char(scenario_id);
artifact.created_on = char(datetime('now', 'TimeZone', 'local', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
artifact.summary_json_file = normalizeStoredPath(summary_json_file);
artifact.summary_markdown_file = normalizeStoredPath(summary_md_file);
artifact.heavy_results_file = normalizeStoredPath(heavy_results_file);
artifact.saved_results_file = normalizeStoredPath(fieldOr(data, 'saved_results_file', ''));
artifact.run_count = numel(fieldOr(data, 'runs', struct([])));
artifact.summary_table = tableRows(fieldOr(data, 'summary_table', table()));
artifact.runs = summarizeRuns(fieldOr(data, 'runs', struct([])));
end

function runs = summarizeRuns(raw_runs)
if isempty(raw_runs)
    runs = struct([]);
    return;
end

runs = repmat(struct( ...
    'scenario_name', '', ...
    'case_name', '', ...
    'injection_mode', '', ...
    'case_id', '', ...
    'dataset_id', '', ...
    'parent_dataset_id', '', ...
    'injected_dataset_file', '', ...
    'benchmark_results_file', '', ...
    'validation_voltage_rmse_mv', NaN), numel(raw_runs), 1);

for idx = 1:numel(raw_runs)
    validation = fieldOr(raw_runs(idx), 'validation', struct());
    runs(idx).scenario_name = char(fieldOr(raw_runs(idx), 'scenario_name', ''));
    runs(idx).case_name = char(fieldOr(raw_runs(idx), 'case_name', ''));
    runs(idx).injection_mode = char(fieldOr(raw_runs(idx), 'injection_mode', ''));
    runs(idx).case_id = char(fieldOr(raw_runs(idx), 'case_id', ''));
    runs(idx).dataset_id = char(fieldOr(raw_runs(idx), 'dataset_id', ''));
    runs(idx).parent_dataset_id = char(fieldOr(raw_runs(idx), 'parent_dataset_id', ''));
    runs(idx).injected_dataset_file = normalizeStoredPath(fieldOr(raw_runs(idx), 'injected_dataset_file', ''));
    runs(idx).benchmark_results_file = normalizeStoredPath(fieldOr(raw_runs(idx), 'benchmark_results_file', ''));
    runs(idx).validation_voltage_rmse_mv = 1000 * fieldOr(validation, 'voltage_rmse', NaN);
end
end

function markdown_text = renderInjectionSummaryMarkdown(artifact)
lines = { ...
    '# Promoted Injection Study Summary', ...
    '', ...
    sprintf('- layer: `%s`', artifact.layer), ...
    sprintf('- suite: `%s`', artifact.suite_version), ...
    sprintf('- scenario: `%s`', artifact.scenario_id), ...
    sprintf('- generated: `%s`', artifact.created_on), ...
    sprintf('- promoted JSON: `%s`', artifact.summary_json_file), ...
    sprintf('- heavy MAT: `%s`', artifact.heavy_results_file), ...
    sprintf('- saved MAT: `%s`', artifact.saved_results_file), ...
    sprintf('- runs: `%d`', artifact.run_count), ...
    ''};
lines = lines(:);

lines = appendMarkdownLines(lines, {'## Run Summary'; ''});
lines = appendMarkdownLines(lines, markdownTableFromStructArray(artifact.runs));
lines = appendMarkdownLines(lines, {''; '## Per-Estimator Metrics'; ''});
lines = appendMarkdownLines(lines, markdownTableFromStructArray(artifact.summary_table));
lines = appendMarkdownLines(lines, {''});
markdown_text = strjoin(lines, newline);
end

function writeJsonArtifact(output_file, artifact)
fid = fopen(output_file, 'w');
if fid < 0
    error('writeInjectionPromotedSummary:OpenFailed', ...
        'Could not open %s for writing.', output_file);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', jsonencode(artifact, 'PrettyPrint', true));
end

function writeMarkdownArtifact(output_file, markdown_text)
fid = fopen(output_file, 'w');
if fid < 0
    error('writeInjectionPromotedSummary:OpenFailed', ...
        'Could not open %s for writing.', output_file);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', markdown_text);
end

function rows = tableRows(tbl)
if isempty(tbl)
    rows = struct([]);
    return;
end
if isstruct(tbl)
    rows = tbl;
    return;
end
rows = table2struct(tbl);
end

function lines = markdownTableFromStructArray(rows)
if isempty(rows)
    lines = {'_No rows available._'};
    return;
end
if ~isstruct(rows)
    error('writeInjectionPromotedSummary:BadMarkdownRows', ...
        'Expected a struct array to render a Markdown table.');
end
fields = fieldnames(rows);
header = ['| ' strjoin(fields.', ' | ') ' |'];
separator = ['| ' strjoin(repmat({'---'}, 1, numel(fields)), ' | ') ' |'];
lines = cell(numel(rows) + 2, 1);
lines{1} = header;
lines{2} = separator;
for row_idx = 1:numel(rows)
    values = cell(1, numel(fields));
    for field_idx = 1:numel(fields)
        values{field_idx} = scalarToMarkdownText(rows(row_idx).(fields{field_idx}));
    end
    lines{row_idx + 2} = ['| ' strjoin(values, ' | ') ' |'];
end
lines = normalizeMarkdownLines(lines);
end

function lines = appendMarkdownLines(lines, new_lines)
lines = normalizeMarkdownLines(lines);
lines = [lines; normalizeMarkdownLines(new_lines)];
end

function lines = normalizeMarkdownLines(lines)
if isstring(lines)
    lines = cellstr(lines(:));
elseif ischar(lines)
    lines = {lines};
elseif isempty(lines)
    lines = cell(0, 1);
elseif ~iscell(lines)
    error('writeInjectionPromotedSummary:BadMarkdownLines', ...
        'Expected Markdown content as a char vector, string array, or cell array.');
end
lines = lines(:);
end

function text = scalarToMarkdownText(value)
if ischar(value)
    text = escapeMarkdown(char(value));
elseif isstring(value) && isscalar(value)
    text = escapeMarkdown(char(value));
elseif isnumeric(value) && isscalar(value)
    if isnan(value)
        text = 'NaN';
    else
        text = num2str(value, '%.6g');
    end
elseif islogical(value) && isscalar(value)
    text = char(string(value));
elseif isempty(value)
    text = '';
elseif iscell(value)
    text = escapeMarkdown(strjoin(normalizeCellstr(value), ', '));
else
    text = escapeMarkdown(strrep(jsonencode(value), '|', '\|'));
end
text = strrep(text, newline, ' ');
end

function text = escapeMarkdown(text)
text = strrep(char(text), '|', '\|');
end

function ensureDir(dir_path)
if isempty(dir_path)
    return;
end
if exist(dir_path, 'dir') ~= 7
    mkdir(dir_path);
end
end

function value = fieldOr(s, field_name, default_value)
if isstruct(s) && isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end

function values = normalizeCellstr(values)
if ischar(values)
    values = {values};
elseif isa(values, 'string')
    values = cellstr(values(:));
elseif isempty(values)
    values = {};
elseif ~iscell(values)
    error('writeInjectionPromotedSummary:BadCellstr', ...
        'Expected a char vector, string array, or cell array.');
end
end

function path_out = normalizeStoredPath(path_in)
if isempty(path_in)
    path_out = '';
else
    path_out = relativizeRepoPath(path_in, resolveRepoRoot());
end
end

function path_out = relativizeRepoPath(path_in, repo_root)
path_out = strrep(char(path_in), '\', '/');
path_out = regexprep(path_out, '/+', '/');
repo_root = strrep(char(repo_root), '\', '/');
repo_root = regexprep(repo_root, '/+', '/');
repo_prefix = [repo_root '/'];
if strcmpi(path_out, repo_root)
    path_out = '.';
elseif strncmpi(path_out, repo_prefix, numel(repo_prefix))
    path_out = path_out(numel(repo_prefix) + 1:end);
end
end

function repo_root = resolveRepoRoot()
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end

function path_out = resolveInputPath(path_in, repo_root)
path_in = char(path_in);
if isAbsolutePath(path_in)
    path_out = path_in;
    return;
end
if exist(path_in, 'file') == 2
    path_out = path_in;
    return;
end
path_out = fullfile(repo_root, path_in);
end

function path_out = resolveOutputPath(path_in, repo_root)
path_in = char(path_in);
if isAbsolutePath(path_in)
    path_out = path_in;
else
    path_out = fullfile(repo_root, path_in);
end
end

function tf = isAbsolutePath(path_in)
tf = numel(path_in) >= 2 && path_in(2) == ':';
end
