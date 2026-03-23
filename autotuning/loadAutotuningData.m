function data = loadAutotuningData(resultsInput)
% loadAutotuningData Normalize aggregate, per-estimator, and checkpoint inputs.

if nargin < 1 || isempty(resultsInput)
    candidates = {'autotuningResults', 'autotuneResults'};
    for idx = 1:numel(candidates)
        if evalin('base', sprintf('exist(''%s'', ''var'')', candidates{idx}))
            resultsInput = evalin('base', candidates{idx});
            break;
        end
    end
end

if isempty(resultsInput)
    error('loadAutotuningData:MissingInput', ...
        'Provide an autotuning struct or MAT-file path.');
end

if isstring(resultsInput)
    resultsInput = char(resultsInput);
end

if ischar(resultsInput)
    if exist(resultsInput, 'file') ~= 2
        error('loadAutotuningData:MissingFile', 'File not found: %s', resultsInput);
    end
    loaded = load(resultsInput);
    resultsInput = extractAutotuningStruct(loaded, resultsInput);
end

if ~isstruct(resultsInput)
    error('loadAutotuningData:BadInput', ...
        'Input must be an autotuning struct or MAT-file path.');
end

if isfield(resultsInput, 'runs')
    data = resultsInput;
    if ~isfield(data, 'summary_table') || isempty(data.summary_table)
        data.summary_table = buildAutotuningSummaryTable(data.runs);
    end
    return;
end

if isfield(resultsInput, 'history_table') && isfield(resultsInput, 'estimator_name')
    data = struct();
    data.kind = 'autotuning_results';
    data.runs = resultsInput;
    data.summary_table = buildAutotuningSummaryTable(resultsInput);
    return;
end

error('loadAutotuningData:UnrecognizedStruct', ...
    'The provided struct is not a recognized autotuning result.');
end

function result_struct = extractAutotuningStruct(loaded, file_path)
names = fieldnames(loaded);
for idx = 1:numel(names)
    candidate = loaded.(names{idx});
    if isstruct(candidate) && isfield(candidate, 'runs')
        result_struct = candidate;
        return;
    end
end

for idx = 1:numel(names)
    candidate = loaded.(names{idx});
    if isstruct(candidate) && isfield(candidate, 'history_table') && isfield(candidate, 'estimator_name')
        result_struct = candidate;
        return;
    end
end

error('loadAutotuningData:NoAutotuningStruct', ...
    'Could not find an autotuning result struct in %s.', file_path);
end
