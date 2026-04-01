function artifact = writeInitSocPromotedSummary(results_file, extracted_summary_file, summary_json_file, summary_md_file, suite_version, scenario_id)
% writeInitSocPromotedSummary Write promoted JSON/Markdown summaries for an initial-SOC sweep.
%
% Usage:
%   artifact = writeInitSocPromotedSummary(results_file, extracted_summary_file, ...
%       summary_json_file, summary_md_file, suite_version, scenario_id)

if nargin < 6
    error('writeInitSocPromotedSummary:MissingInputs', ...
        'results_file, extracted_summary_file, summary_json_file, summary_md_file, suite_version, and scenario_id are required.');
end

repo_root = resolveRepoRoot();
results_file = resolveInputPath(results_file, repo_root);
extracted_summary_file = resolveOutputPath(extracted_summary_file, repo_root);
summary_json_file = resolveOutputPath(summary_json_file, repo_root);
summary_md_file = resolveOutputPath(summary_md_file, repo_root);

ensureDir(fileparts(extracted_summary_file));
ensureDir(fileparts(summary_json_file));
ensureDir(fileparts(summary_md_file));

summary = extractInitSocSweepResults(results_file, struct( ...
    'display_tables', false, ...
    'save_summary', true, ...
    'summary_file', extracted_summary_file));

artifact = buildInitSocSweepSummaryArtifact( ...
    summary, results_file, extracted_summary_file, ...
    summary_json_file, summary_md_file, suite_version, scenario_id);

writeJsonArtifact(summary_json_file, artifact);
writeMarkdownArtifact(summary_md_file, renderInitSocSweepSummaryMarkdown(artifact));
end

function artifact = buildInitSocSweepSummaryArtifact(summary, heavy_results_file, extracted_summary_file, summary_json_file, summary_md_file, suite_version, scenario_id)
artifact = struct();
artifact.artifact_class = 'summary';
artifact.kind = 'init_soc_summary';
artifact.layer = 'evaluation';
artifact.suite_version = char(suite_version);
artifact.scenario_id = char(scenario_id);
artifact.created_on = char(datetime('now', 'TimeZone', 'local', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
artifact.summary_json_file = normalizeStoredPath(summary_json_file);
artifact.summary_markdown_file = normalizeStoredPath(summary_md_file);
artifact.heavy_results_file = normalizeStoredPath(heavy_results_file);
artifact.extracted_summary_file = normalizeStoredPath(extracted_summary_file);
artifact.source_file = normalizeStoredPath(fieldOr(summary, 'source_file', ''));
artifact.dataset_mode = char(fieldOr(summary, 'dataset_mode', 'unknown'));
artifact.estimator_names = normalizeCellstr(fieldOr(summary, 'estimator_names', {}));
artifact.soc0_sweep_percent = reshape(fieldOr(summary, 'soc0_sweep_percent', []), 1, []);
artifact.n_sweep_points = numel(artifact.soc0_sweep_percent);
artifact.aggregate_table = tableRows(fieldOr(summary, 'aggregate_table', table()));
artifact.best_point_table = tableRows(fieldOr(summary, 'best_point_table', table()));
artifact.selected_points_table = tableRows(fieldOr(summary, 'selected_points_table', table()));
end

function markdown_text = renderInitSocSweepSummaryMarkdown(artifact)
lines = { ...
    '# Promoted Initial-SOC Sweep Summary', ...
    '', ...
    sprintf('- layer: `%s`', artifact.layer), ...
    sprintf('- suite: `%s`', artifact.suite_version), ...
    sprintf('- scenario: `%s`', artifact.scenario_id), ...
    sprintf('- generated: `%s`', artifact.created_on), ...
    sprintf('- promoted JSON: `%s`', artifact.summary_json_file), ...
    sprintf('- heavy MAT: `%s`', artifact.heavy_results_file), ...
    sprintf('- extracted summary MAT: `%s`', artifact.extracted_summary_file), ...
    sprintf('- source file: `%s`', artifact.source_file), ...
    sprintf('- dataset mode: `%s`', artifact.dataset_mode), ...
    sprintf('- estimators: `%d`', numel(artifact.estimator_names)), ...
    sprintf('- sweep points: `%d`', artifact.n_sweep_points), ...
    sprintf('- initial SOC axis: `%s`', escapeMarkdown(strjoin(cellstr(string(artifact.soc0_sweep_percent)), ', '))), ...
    ''};
lines = lines(:);

lines = appendMarkdownLines(lines, {'## Aggregate Summary'; ''});
lines = appendMarkdownLines(lines, markdownTableFromStructArray(artifact.aggregate_table));
lines = appendMarkdownLines(lines, {''; '## Best Point Per Estimator'; ''});
lines = appendMarkdownLines(lines, markdownTableFromStructArray(artifact.best_point_table));
lines = appendMarkdownLines(lines, {''; '## Selected Sweep Points'; ''});
lines = appendMarkdownLines(lines, markdownTableFromStructArray(artifact.selected_points_table));
lines = appendMarkdownLines(lines, {''});
markdown_text = strjoin(lines, newline);
end

function writeJsonArtifact(output_file, artifact)
fid = fopen(output_file, 'w');
if fid < 0
    error('writeInitSocPromotedSummary:OpenFailed', ...
        'Could not open %s for writing.', output_file);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', jsonencode(artifact, 'PrettyPrint', true));
end

function writeMarkdownArtifact(output_file, markdown_text)
fid = fopen(output_file, 'w');
if fid < 0
    error('writeInitSocPromotedSummary:OpenFailed', ...
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
    error('writeInitSocPromotedSummary:BadMarkdownRows', ...
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
    error('writeInitSocPromotedSummary:BadMarkdownLines', ...
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
    error('writeInitSocPromotedSummary:BadCellstr', ...
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
