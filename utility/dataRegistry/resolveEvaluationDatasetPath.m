function path_out = resolveEvaluationDatasetPath(path_in, repo_root, varargin)
% resolveEvaluationDatasetPath Resolve canonical evaluation dataset paths.

if nargin < 1 || isempty(path_in)
    error('resolveEvaluationDatasetPath:MissingPath', ...
        'An evaluation dataset path is required.');
end
if nargin < 2 || isempty(repo_root)
    repo_root = inferRepoRoot();
end

opts = struct('access', 'benchmark', 'must_exist', false);
if nargin >= 3 && ~isempty(varargin)
    opts = parseNameValue(opts, varargin{:});
end

paths = ensureDataRegistryLayout(repo_root);
path_out = resolveAbsolutePath(path_in, repo_root);
path_norm = normalizePath(path_out);
input_norm = normalizePath(char(path_in));

legacy_roots = { ...
    'evaluation/escsimdata/datasets/', ...
    'evaluation/romsimdata/datasets/', ...
    'evaluation/injection/datasets/', ...
    'data/__evaluation_legacy_tmp/', ...
    '__evaluation_legacy_tmp/'};
rejectLegacyRoot(input_norm, path_norm, legacy_roots, path_in);

allowed_roots = { ...
    normalizePath(paths.evaluation.processed), ...
    normalizePath(paths.evaluation.derived)};

switch lower(char(opts.access))
    case {'benchmark', 'runtime'}
        % Benchmark/runtime reads may only use processed or derived datasets.
    case {'builder', 'conversion', 'builder_source'}
        allowed_roots{end + 1} = normalizePath(paths.evaluation.raw); %#ok<AGROW>
    otherwise
        error('resolveEvaluationDatasetPath:BadAccessMode', ...
            'Unsupported access mode "%s".', char(opts.access));
end

if ~isUnderAnyRoot(path_norm, allowed_roots)
    error('resolveEvaluationDatasetPath:NonCanonicalPath', ...
        ['Benchmark/runtime evaluation dataset reads must resolve only under ', ...
         'data/evaluation/processed or data/evaluation/derived.\n', ...
         'Source-profile builders and conversion scripts may read from ', ...
         'data/evaluation/raw/...\n', ...
         'Received: %s'], char(path_in));
end

if opts.must_exist && exist(path_out, 'file') ~= 2 && exist(path_out, 'dir') ~= 7
    error('resolveEvaluationDatasetPath:MissingPath', ...
        'Resolved evaluation path does not exist: %s', path_out);
end
end

function rejectLegacyRoot(input_norm, path_norm, legacy_roots, original_input)
for idx = 1:numel(legacy_roots)
    if contains(input_norm, legacy_roots{idx}) || contains(path_norm, ['/' legacy_roots{idx}])
        error('resolveEvaluationDatasetPath:LegacyPath', ...
            ['Legacy evaluation dataset roots are no longer supported: %s\n', ...
             'Benchmark/runtime evaluation dataset reads must resolve only under ', ...
             'data/evaluation/processed or data/evaluation/derived.\n', ...
             'Source-profile builders and conversion scripts may read from ', ...
             'data/evaluation/raw/...'], char(original_input));
    end
end
end

function tf = isUnderAnyRoot(path_norm, roots)
tf = false;
for idx = 1:numel(roots)
    root_norm = normalizePath(roots{idx});
    if strcmp(path_norm, root_norm) || startsWith(path_norm, [root_norm '/'])
        tf = true;
        return;
    end
end
end

function path_out = resolveAbsolutePath(path_in, repo_root)
path_in = char(path_in);
if isAbsolutePath(path_in)
    path_out = path_in;
else
    path_out = fullfile(repo_root, path_in);
end
end

function tf = isAbsolutePath(path_in)
path_in = char(path_in);
tf = numel(path_in) >= 2 && path_in(2) == ':';
end

function path_norm = normalizePath(path_in)
path_norm = lower(strrep(char(path_in), '\', '/'));
path_norm = regexprep(path_norm, '/+', '/');
end

function opts = parseNameValue(opts, varargin)
if mod(numel(varargin), 2) ~= 0
    error('resolveEvaluationDatasetPath:BadNameValue', ...
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
