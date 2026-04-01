function summary = summarizeEvaluationSuiteManifests(suite_input, repo_root)
% summarizeEvaluationSuiteManifests Summarize nominal and derived dataset manifests.

if nargin < 1 || isempty(suite_input)
    error('summarizeEvaluationSuiteManifests:MissingSuite', ...
        'Provide a suite version or suite root path.');
end
if nargin < 2 || isempty(repo_root)
    repo_root = inferRepoRoot();
end

paths = ensureDataRegistryLayout(repo_root);

suite_input = char(suite_input);
if isAbsolutePath(suite_input) || exist(suite_input, 'dir') == 7
    suite_root = suite_input;
    [~, suite_version] = fileparts(suite_root);
else
    suite_version = suite_input;
    suite_root = fullfile(paths.evaluation.derived, suite_version);
end

if exist(suite_root, 'dir') ~= 7
    error('summarizeEvaluationSuiteManifests:MissingSuiteRoot', ...
        'Suite root not found: %s', suite_root);
end

manifest_files = collectManifestFiles(suite_root);
nominal = struct([]);
derived = struct([]);
nominal_idx = 0;
derived_idx = 0;

for idx = 1:numel(manifest_files)
    manifest_path = manifest_files{idx};
    manifest = readDerivedDatasetManifest(manifest_path);
    entry = buildSummaryEntry(manifest, manifest_path);
    if isfield(manifest, 'dataset_family') && strcmpi(char(manifest.dataset_family), 'nominal')
        nominal_idx = nominal_idx + 1;
        nominal(nominal_idx, 1) = entry; %#ok<AGROW>
    else
        derived_idx = derived_idx + 1;
        derived(derived_idx, 1) = entry; %#ok<AGROW>
    end
end

summary = struct();
summary.suite_version = suite_version;
summary.suite_root = suite_root;
summary.nominal_datasets = nominal;
summary.derived_datasets = derived;
summary.derived_by_family = groupDerivedByFamily(derived);
summary.available_families = unique([collectFamilies(nominal), collectFamilies(derived)], 'stable');
end

function entry = buildSummaryEntry(manifest, manifest_path)
entry = struct();
entry.dataset_id = fieldOr(manifest, 'dataset_id', '');
entry.parent_dataset_id = fieldOr(manifest, 'parent_dataset_id', '');
entry.suite_version = fieldOr(manifest, 'suite_version', '');
entry.dataset_family = fieldOr(manifest, 'dataset_family', '');
entry.augmentation_type = fieldOr(manifest, 'augmentation_type', '');
entry.case_id = fieldOr(manifest, 'case_id', '');
entry.manifest_path = manifest_path;
entry.dataset_path = fieldOr(manifest, 'resolved_output_path', '');
end

function files = collectManifestFiles(root_dir)
files = {};
listing = dir(root_dir);
for idx = 1:numel(listing)
    name = listing(idx).name;
    if strcmp(name, '.') || strcmp(name, '..')
        continue;
    end

    full_path = fullfile(listing(idx).folder, name);
    if listing(idx).isdir
        child_files = collectManifestFiles(full_path);
        files = [files; child_files]; %#ok<AGROW>
    elseif strcmpi(name, 'manifest.json')
        files{end + 1, 1} = full_path; %#ok<AGROW>
    end
end
end

function families = collectFamilies(entries)
families = {};
for idx = 1:numel(entries)
    families{end + 1} = entries(idx).dataset_family; %#ok<AGROW>
end
end

function grouped = groupDerivedByFamily(entries)
grouped = struct();
for idx = 1:numel(entries)
    family = matlab.lang.makeValidName(char(entries(idx).dataset_family));
    if ~isfield(grouped, family)
        grouped.(family) = entries(idx);
    else
        grouped.(family)(end + 1, 1) = entries(idx); %#ok<AGROW>
    end
end
end

function value = fieldOr(s, field_name, default_value)
if isstruct(s) && isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end

function tf = isAbsolutePath(path_in)
path_in = char(path_in);
tf = numel(path_in) >= 2 && path_in(2) == ':';
end

function repo_root = inferRepoRoot()
helper_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(helper_dir));
end
