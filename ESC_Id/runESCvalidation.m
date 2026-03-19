function batch = runESCvalidation(modelFiles, dataInputs, enabledPlot)
% runESCvalidation Batch wrapper around ESCvalidation.
%
% Usage:
%   batch = runESCvalidation()
%   batch = runESCvalidation(modelFiles)
%   batch = runESCvalidation(modelFiles, dataInputs)
%   batch = runESCvalidation(modelFiles, dataInputs, enabledPlot)
%
% Supported expansion rules:
%   - one model, many datasets
%   - many models, one dataset
%   - same number of models and datasets
%   - explicit struct array with fields modelFile, data, enabledPlot, name

if nargin < 1
    modelFiles = [];
end
if nargin < 2
    dataInputs = [];
end
if nargin < 3 || isempty(enabledPlot)
    enabledPlot = [];
end

jobs = normalizeJobs(modelFiles, dataInputs, enabledPlot);
entries_list = cell(numel(jobs), 1);
for idx = 1:numel(jobs)
    entry = struct();
    entry.name = jobs(idx).name;
    entry.result = ESCvalidation(jobs(idx).modelFile, jobs(idx).data, jobs(idx).enabledPlot);
    entries_list{idx} = entry;
end
entries = [entries_list{:}]';

batch = struct();
batch.name = 'ESC validation batch';
batch.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
batch.job_count = numel(entries);
batch.entries = entries;
batch.summary_table = buildBatchTable(entries);

printBatchSummary(batch);

if nargout == 0
    assignin('base', 'escValidationBatch', batch);
end
end

function jobs = normalizeJobs(modelFiles, dataInputs, enabledPlot)
if isstruct(modelFiles) && all(isfield(modelFiles, {'modelFile', 'data'}))
    jobs = modelFiles(:);
    for idx = 1:numel(jobs)
        if ~isfield(jobs, 'enabledPlot') || isempty(jobs(idx).enabledPlot)
            jobs(idx).enabledPlot = resolveEnabledPlot(enabledPlot, numel(jobs));
        end
        if ~isfield(jobs, 'name') || isempty(jobs(idx).name)
            jobs(idx).name = sprintf('job_%d', idx);
        end
    end
    return;
end

model_list = toCellList(modelFiles);
data_list = toCellList(dataInputs);

if isempty(model_list)
    model_list = {[]};
end
if isempty(data_list)
    data_list = {[]};
end

if numel(model_list) == 1 && numel(data_list) > 1
    model_list = repmat(model_list, size(data_list));
elseif numel(data_list) == 1 && numel(model_list) > 1
    data_list = repmat(data_list, size(model_list));
elseif numel(model_list) ~= numel(data_list)
    error('runESCvalidation:SizeMismatch', ...
        'Model and dataset counts must match, or one side must be scalar.');
end

plot_flag = resolveEnabledPlot(enabledPlot, numel(model_list));
jobs = repmat(struct('modelFile', [], 'data', [], 'enabledPlot', false, 'name', ''), numel(model_list), 1);
for idx = 1:numel(model_list)
    jobs(idx).modelFile = model_list{idx};
    jobs(idx).data = data_list{idx};
    jobs(idx).enabledPlot = plot_flag && numel(model_list) == 1;
    jobs(idx).name = sprintf('job_%d', idx);
end
end

function out = toCellList(value)
if nargin == 0 || isempty(value)
    out = {};
elseif iscell(value)
    out = value(:);
else
    out = {value};
end
end

function enabled = resolveEnabledPlot(enabledPlot, n_jobs)
if nargin < 1 || isempty(enabledPlot)
    enabled = (n_jobs == 1);
else
    enabled = logical(enabledPlot);
end
end

function summary_table = buildBatchTable(entries)
job_name = cell(numel(entries), 1);
model_name = cell(numel(entries), 1);
case_count = NaN(numel(entries), 1);
mean_rmse_mv = NaN(numel(entries), 1);
max_rmse_mv = NaN(numel(entries), 1);

for idx = 1:numel(entries)
    job_name{idx} = entries(idx).name;
    model_name{idx} = entries(idx).result.model_name;
    case_count(idx) = entries(idx).result.case_count;
    mean_rmse_mv(idx) = entries(idx).result.metrics.mean_voltage_rmse_mv;
    max_rmse_mv(idx) = entries(idx).result.metrics.max_voltage_rmse_mv;
end

summary_table = table(job_name, model_name, case_count, mean_rmse_mv, max_rmse_mv, ...
    'VariableNames', {'job_name', 'model_name', 'case_count', 'mean_voltage_rmse_mv', 'max_voltage_rmse_mv'});
end

function printBatchSummary(batch)
fprintf('\n%s\n', batch.name);
fprintf('  Jobs: %d\n', batch.job_count);
for idx = 1:numel(batch.entries)
    result = batch.entries(idx).result;
    fprintf('  [%d] %s | %s | mean RMSE %.2f mV | max RMSE %.2f mV\n', ...
        idx, batch.entries(idx).name, result.model_name, ...
        result.metrics.mean_voltage_rmse_mv, result.metrics.max_voltage_rmse_mv);
end
fprintf('\n');
end
