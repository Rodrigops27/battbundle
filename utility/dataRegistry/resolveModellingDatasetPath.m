function path_out = resolveModellingDatasetPath(path_in, repo_root, varargin)
% resolveModellingDatasetPath Resolve canonical modelling dataset paths.

if nargin < 1 || isempty(path_in)
    error('resolveModellingDatasetPath:MissingPath', ...
        'A modelling path is required.');
end
if nargin < 2 || isempty(repo_root)
    repo_root = inferRepoRoot();
end

opts = struct('must_exist', false);
if nargin >= 3 && ~isempty(varargin)
    opts = parseNameValue(opts, varargin{:});
end

paths = ensureDataRegistryLayout(repo_root);
path_out = resolveAbsolutePath(path_in, repo_root);
path_norm = normalizePath(path_out);
input_norm = normalizePath(char(path_in));

legacy_roots = { ...
    'esc_id/dyn_files/', ...
    'esc_id/ocv_files/', ...
    'esc_id/ocv_models/', ...
    'data/__modelling_legacy_tmp/', ...
    '__modelling_legacy_tmp/'};

for idx = 1:numel(legacy_roots)
    if contains(input_norm, legacy_roots{idx}) || contains(path_norm, ['/' legacy_roots{idx}])
        error('resolveModellingDatasetPath:LegacyPath', ...
            ['Legacy modelling dataset roots are no longer supported: %s\n', ...
             'Canonical modelling reads and writes must resolve under ', ...
             'data/modelling/{raw,interim,processed,synthetic,derived}.'], char(path_in));
    end
end

allowed_roots = { ...
    normalizePath(paths.modelling.raw), ...
    normalizePath(paths.modelling.interim), ...
    normalizePath(paths.modelling.processed), ...
    normalizePath(paths.modelling.synthetic), ...
    normalizePath(paths.modelling.derived)};

if ~isUnderAnyRoot(path_norm, allowed_roots)
    error('resolveModellingDatasetPath:NonCanonicalPath', ...
        ['Canonical modelling reads and writes must resolve under ', ...
         'data/modelling/{raw,interim,processed,synthetic,derived}.\n', ...
         'Received: %s'], char(path_in));
end

if opts.must_exist && exist(path_out, 'file') ~= 2 && exist(path_out, 'dir') ~= 7
    error('resolveModellingDatasetPath:MissingPath', ...
        'Resolved modelling path does not exist: %s', path_out);
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
    error('resolveModellingDatasetPath:BadNameValue', ...
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
