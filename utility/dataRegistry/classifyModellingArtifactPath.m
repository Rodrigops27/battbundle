function classification = classifyModellingArtifactPath(path_in, repo_root)
% classifyModellingArtifactPath Classify reusable vs reporting modelling artifacts.

if nargin < 1 || isempty(path_in)
    error('classifyModellingArtifactPath:MissingPath', ...
        'path_in is required.');
end
if nargin < 2 || isempty(repo_root)
    repo_root = inferRepoRoot();
end

path_abs = resolveAbsolutePath(path_in, repo_root);
path_norm = normalizePath(path_abs);
[~, name, ext] = fileparts(path_abs);

classification = struct();
classification.source_path = path_abs;
classification.classification = 'ambiguous';
classification.lifecycle = '';
classification.reusable = false;
classification.target_path = '';
classification.reason = 'No automatic classification rule matched.';

if contains(path_norm, '/esc_id/results/ocv/') || contains(path_norm, '/results/ocv/') || ...
        contains(path_norm, '/results/figures/ocv/') || strcmpi(ext, '.fig') || ...
        strcmpi(ext, '.png') || strcmpi(ext, '.md')
    classification.classification = 'reporting_artifact';
    classification.reason = 'User-facing plotting, figure, or reporting artifact kept outside data/.';
    return;
end

if strcmpi(ext, '.m')
    classification.classification = 'reporting_support_script';
    classification.reason = 'MATLAB helper script in results/ kept outside data/.';
    return;
end

if contains(path_norm, '/esc_id/results/atl20_ocv_identification_results.mat')
    classification.classification = 'reusable_modelling_artifact';
    classification.lifecycle = 'derived';
    classification.reusable = true;
    classification.target_path = fullfile(repo_root, 'data', 'modelling', 'derived', ...
        'identification_results', 'atl20', 'ATL20_ocv_identification_results.mat');
    classification.reason = 'OCV identification result reused by modelling workflows.';
    return;
end

if contains(path_norm, '/esc_id/results/atl20model_p25_identification_results.mat')
    classification.classification = 'reusable_modelling_artifact';
    classification.lifecycle = 'derived';
    classification.reusable = true;
    classification.target_path = fullfile(repo_root, 'data', 'modelling', 'derived', ...
        'identification_results', 'atl20', 'ATL20model_P25_identification_results.mat');
    classification.reason = 'Dynamic identification result reused by modelling workflows.';
    return;
end

if contains(path_norm, '/esc_id/results/esc_validation_results.mat')
    classification.classification = 'reusable_modelling_artifact';
    classification.lifecycle = 'derived';
    classification.reusable = true;
    classification.target_path = fullfile(repo_root, 'data', 'modelling', 'derived', ...
        'validation_results', 'esc', 'ESC_validation_results.mat');
    classification.reason = 'Structured ESC validation output can be consumed programmatically.';
    return;
end

if contains(path_norm, '/esc_id/ocv_models/') && strcmpi(ext, '.mat')
    chemistry = inferChemistryFolder(name);
    classification.classification = 'reusable_modelling_artifact';
    classification.lifecycle = 'derived';
    classification.reusable = true;
    classification.target_path = fullfile(repo_root, 'data', 'modelling', 'derived', ...
        'ocv_models', chemistry, [name ext]);
    classification.reason = 'Intermediate OCV model artifact reused by dynamic identification workflows.';
end
end

function chemistry = inferChemistryFolder(name)
key = upper(char(name));
if contains(key, 'NMC30')
    chemistry = 'nmc30';
elseif contains(key, 'OMTLIFE')
    chemistry = 'omtlife8ahc_hp';
elseif contains(key, 'ATL20')
    chemistry = 'atl20';
elseif contains(key, 'ATL')
    chemistry = 'atl';
else
    chemistry = 'misc';
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

function repo_root = inferRepoRoot()
helper_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(helper_dir));
end
