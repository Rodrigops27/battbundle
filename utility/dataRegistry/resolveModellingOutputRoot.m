function path_out = resolveModellingOutputRoot(repo_root, lifecycle, varargin)
% resolveModellingOutputRoot Build a canonical modelling output root.

if nargin < 1 || isempty(repo_root)
    repo_root = inferRepoRoot();
end
if nargin < 2 || isempty(lifecycle)
    error('resolveModellingOutputRoot:MissingLifecycle', ...
        'lifecycle is required.');
end

opts = struct('category', '', 'chemistry', '', 'create_dir', true);
if nargin >= 3 && ~isempty(varargin)
    opts = parseNameValue(opts, varargin{:});
end

paths = ensureDataRegistryLayout(repo_root);
lifecycle = lower(char(lifecycle));
switch lifecycle
    case {'raw', 'interim', 'processed', 'synthetic', 'derived'}
        path_out = paths.modelling.(lifecycle);
    otherwise
        error('resolveModellingOutputRoot:BadLifecycle', ...
            'Unsupported lifecycle "%s".', lifecycle);
end

if ~isempty(opts.category)
    path_out = fullfile(path_out, char(opts.category));
end
if ~isempty(opts.chemistry)
    path_out = fullfile(path_out, char(opts.chemistry));
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
    error('resolveModellingOutputRoot:BadNameValue', ...
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
