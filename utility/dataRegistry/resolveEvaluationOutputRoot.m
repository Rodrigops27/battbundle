function path_out = resolveEvaluationOutputRoot(repo_root, suite_version, dataset_family, varargin)
% resolveEvaluationOutputRoot Build a canonical evaluation output root.

if nargin < 1 || isempty(repo_root)
    repo_root = inferRepoRoot();
end
if nargin < 2 || isempty(suite_version)
    error('resolveEvaluationOutputRoot:MissingSuiteVersion', ...
        'suite_version is required.');
end
if nargin < 3 || isempty(dataset_family)
    error('resolveEvaluationOutputRoot:MissingFamily', ...
        'dataset_family is required.');
end

opts = struct('kind', 'derived', 'case_id', '', 'create_dir', true);
if nargin >= 4 && ~isempty(varargin)
    opts = parseNameValue(opts, varargin{:});
end

paths = ensureDataRegistryLayout(repo_root, 'suite_versions', {suite_version});
kind = lower(char(opts.kind));

switch kind
    case 'processed'
        path_out = fullfile(paths.evaluation.processed, char(suite_version), char(dataset_family));
    case 'derived'
        path_out = fullfile(paths.evaluation.derived, char(suite_version), char(dataset_family));
        if ~isempty(opts.case_id)
            path_out = fullfile(path_out, char(opts.case_id));
        end
    otherwise
        error('resolveEvaluationOutputRoot:BadKind', ...
            'kind must be either ''processed'' or ''derived''.');
end

if opts.create_dir
    ensureDir(path_out);
end
end

function ensureDir(dir_path)
if exist(dir_path, 'dir') ~= 7
    mkdir(dir_path);
end
end

function opts = parseNameValue(opts, varargin)
if mod(numel(varargin), 2) ~= 0
    error('resolveEvaluationOutputRoot:BadNameValue', ...
        'Optional arguments must be provided as name/value pairs.');
end
for idx = 1:2:numel(varargin)
    opts.(char(varargin{idx})) = varargin{idx + 1};
end
end

function repo_root = inferRepoRoot()
helper_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(helper_dir));
end
