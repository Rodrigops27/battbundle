function paths = ensureDataRegistryLayout(repo_root, varargin)
% ensureDataRegistryLayout Create the canonical data registry scaffold.

if nargin < 1 || isempty(repo_root)
    repo_root = inferRepoRoot();
end

opts = struct();
opts.suite_versions = {};
if nargin >= 2 && ~isempty(varargin)
    opts = parseNameValue(opts, varargin{:});
end

data_root = fullfile(repo_root, 'data');

paths = struct();
paths.data_root = data_root;
paths.evaluation_root = fullfile(data_root, 'evaluation');
paths.modelling_root = fullfile(data_root, 'modelling');
paths.shared_root = fullfile(data_root, 'shared');

paths.evaluation = struct( ...
    'raw', fullfile(paths.evaluation_root, 'raw'), ...
    'interim', fullfile(paths.evaluation_root, 'interim'), ...
    'synthetic', fullfile(paths.evaluation_root, 'synthetic'), ...
    'processed', fullfile(paths.evaluation_root, 'processed'), ...
    'derived', fullfile(paths.evaluation_root, 'derived'));

paths.modelling = struct( ...
    'raw', fullfile(paths.modelling_root, 'raw'), ...
    'interim', fullfile(paths.modelling_root, 'interim'), ...
    'processed', fullfile(paths.modelling_root, 'processed'), ...
    'synthetic', fullfile(paths.modelling_root, 'synthetic'), ...
    'derived', fullfile(paths.modelling_root, 'derived'));

required_dirs = { ...
    paths.data_root, ...
    paths.evaluation_root, ...
    paths.evaluation.raw, ...
    paths.evaluation.interim, ...
    paths.evaluation.synthetic, ...
    paths.evaluation.processed, ...
    paths.evaluation.derived, ...
    paths.modelling_root, ...
    paths.modelling.raw, ...
    paths.modelling.interim, ...
    paths.modelling.processed, ...
    paths.modelling.synthetic, ...
    paths.modelling.derived, ...
    paths.shared_root};

for idx = 1:numel(required_dirs)
    ensureDir(required_dirs{idx});
end

suite_versions = normalizeCellstr(fieldOr(opts, 'suite_versions', {}));
for idx = 1:numel(suite_versions)
    suite_version = suite_versions{idx};
    ensureDir(fullfile(paths.evaluation.processed, suite_version, 'nominal'));
    ensureDir(fullfile(paths.evaluation.derived, suite_version, 'nominal'));
    ensureDir(fullfile(paths.evaluation.derived, suite_version, 'stochastic_sensor'));
    ensureDir(fullfile(paths.evaluation.derived, suite_version, 'dropout'));
end
end

function ensureDir(dir_path)
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
    error('ensureDataRegistryLayout:BadSuiteVersions', ...
        'suite_versions must be a char vector, string array, or cell array.');
end
end

function opts = parseNameValue(opts, varargin)
if mod(numel(varargin), 2) ~= 0
    error('ensureDataRegistryLayout:BadNameValue', ...
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
