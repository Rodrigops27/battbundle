function data = loadInjectionData(resultsInput)
% loadInjectionData Normalize aggregate and per-run injection study inputs.

if nargin < 1 || isempty(resultsInput)
    candidates = {'injectionResults', 'injResults'};
    for idx = 1:numel(candidates)
        if evalin('base', sprintf('exist(''%s'', ''var'')', candidates{idx}))
            resultsInput = evalin('base', candidates{idx});
            break;
        end
    end
end

if isempty(resultsInput)
    error('loadInjectionData:MissingInput', ...
        'Provide an injection results struct or MAT-file path.');
end

if isstring(resultsInput)
    resultsInput = char(resultsInput);
end

if ischar(resultsInput)
    if exist(resultsInput, 'file') ~= 2
        error('loadInjectionData:MissingFile', 'File not found: %s', resultsInput);
    end
    loaded = load(resultsInput);
    resultsInput = extractResultsStruct(loaded, resultsInput);
end

if isfield(resultsInput, 'runs')
    data = resultsInput;
    if ~isfield(data, 'summary_table') || isempty(data.summary_table)
        data.summary_table = buildInjectionSummaryTable(data.runs);
    end
    return;
end

if isfield(resultsInput, 'scenario_name') && isfield(resultsInput, 'benchmark_results_file')
    data = struct();
    data.kind = 'injection_results';
    data.runs = resultsInput;
    data.summary_table = buildInjectionSummaryTable(resultsInput);
    return;
end

error('loadInjectionData:BadInput', ...
    'Unrecognized injection results input.');
end

function result_struct = extractResultsStruct(loaded, file_path)
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
    if isstruct(candidate) && isfield(candidate, 'scenario_name') && isfield(candidate, 'benchmark_results_file')
        result_struct = candidate;
        return;
    end
end
error('loadInjectionData:NoResultsStruct', ...
    'Could not find an injection results struct in %s.', file_path);
end
