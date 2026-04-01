function manifest = readDerivedDatasetManifest(path_in)
% readDerivedDatasetManifest Read a JSON or MAT derived-dataset manifest.

if nargin < 1 || isempty(path_in)
    error('readDerivedDatasetManifest:MissingPath', ...
        'A manifest path is required.');
end

path_in = char(path_in);
if exist(path_in, 'dir') == 7
    if exist(fullfile(path_in, 'manifest.json'), 'file') == 2
        path_in = fullfile(path_in, 'manifest.json');
    elseif exist(fullfile(path_in, 'manifest.mat'), 'file') == 2
        path_in = fullfile(path_in, 'manifest.mat');
    else
        error('readDerivedDatasetManifest:MissingManifest', ...
            'No manifest.json or manifest.mat was found in %s.', path_in);
    end
end

[~, ~, ext] = fileparts(path_in);
switch lower(ext)
    case '.json'
        manifest = jsondecode(fileread(path_in));
    case '.mat'
        src = load(path_in);
        if isfield(src, 'manifest_metadata')
            manifest = src.manifest_metadata;
        else
            error('readDerivedDatasetManifest:BadMatManifest', ...
                'Expected variable manifest_metadata in %s.', path_in);
        end
    otherwise
        error('readDerivedDatasetManifest:BadExtension', ...
            'Unsupported manifest extension %s.', ext);
end
end
