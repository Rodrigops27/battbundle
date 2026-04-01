function [manifest_path, manifest] = writeDerivedDatasetManifest(output_dir, manifest, varargin)
% writeDerivedDatasetManifest Write JSON metadata for a derived dataset.

if nargin < 1 || isempty(output_dir)
    error('writeDerivedDatasetManifest:MissingOutputDir', ...
        'output_dir is required.');
end
if nargin < 2 || ~isstruct(manifest)
    error('writeDerivedDatasetManifest:BadManifest', ...
        'manifest must be provided as a struct.');
end

opts = struct('manifest_name', 'manifest.json', 'write_mat_metadata', false);
if nargin >= 3 && ~isempty(varargin)
    opts = parseNameValue(opts, varargin{:});
end

ensureDir(output_dir);

if ~isfield(manifest, 'generated_at') || isempty(manifest.generated_at)
    manifest.generated_at = datestr(now, 'yyyy-mm-dd HH:MM:SS');
end
if ~isfield(manifest, 'generated_by') || isempty(manifest.generated_by)
    manifest.generated_by = mfilename;
end

manifest_path = fullfile(output_dir, char(opts.manifest_name));
fid = fopen(manifest_path, 'w');
if fid < 0
    error('writeDerivedDatasetManifest:OpenFailed', ...
        'Could not open %s for writing.', manifest_path);
end

cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', jsonencode(manifest));

if opts.write_mat_metadata
    manifest_metadata = manifest; %#ok<NASGU>
    save(fullfile(output_dir, 'manifest.mat'), 'manifest_metadata');
end
end

function ensureDir(dir_path)
if exist(dir_path, 'dir') ~= 7
    mkdir(dir_path);
end
end

function opts = parseNameValue(opts, varargin)
if mod(numel(varargin), 2) ~= 0
    error('writeDerivedDatasetManifest:BadNameValue', ...
        'Optional arguments must be provided as name/value pairs.');
end
for idx = 1:2:numel(varargin)
    opts.(char(varargin{idx})) = varargin{idx + 1};
end
end
