function paths = resolveOcvInspectionPaths(cfg)
% resolveOcvInspectionPaths Resolve promoted summary and figure paths for OCV inspection runs.

if nargin < 1 || isempty(cfg)
    cfg = struct();
end

repo_root = BundleEvalHelpers.resolveBundleRepoRoot();
suite_version = inferSuiteVersion(cfg, repo_root);
scenario_id = fieldOr(cfg, 'report_scenario_id', fieldOr(cfg, 'scenario_id', 'ocv_modelling_inspection'));

summary_rel = BundleEvalHelpers.buildPromotedSummaryPaths('ocv', suite_version, scenario_id);
figure_root_rel = fullfile('results', 'figures', 'ocv', suite_version, BundleEvalHelpers.sanitizeToken(scenario_id));

paths = struct();
paths.repo_root = repo_root;
paths.suite_version = char(suite_version);
paths.scenario_id = char(scenario_id);
paths.summary_json_rel = summary_rel.json_file;
paths.summary_markdown_rel = summary_rel.markdown_file;
paths.summary_json_abs = fullfile(repo_root, summary_rel.json_file);
paths.summary_markdown_abs = fullfile(repo_root, summary_rel.markdown_file);
paths.figure_root_rel = figure_root_rel;
paths.figure_root_abs = fullfile(repo_root, figure_root_rel);
end

function suite_version = inferSuiteVersion(cfg, repo_root)
ocv_data_input = fieldOr(cfg, 'ocv_data_input', '');
if ischar(ocv_data_input) || (isstring(ocv_data_input) && isscalar(ocv_data_input))
    data_path = char(ocv_data_input);
    if ~BundleEvalHelpers.isAbsolutePath(data_path)
        data_path = fullfile(repo_root, data_path);
    end
    [~, suite_version] = fileparts(data_path);
else
    suite_version = lower(char(fieldOr(cfg, 'cell_id', 'ocv')));
end

suite_version = BundleEvalHelpers.sanitizeToken(lower(char(suite_version)));
end

function value = fieldOr(s, field_name, default_value)
if isstruct(s) && isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end
