function validation = computeOcvModelMetrics(model_inputs, data_input, cfg)
% computeOcvModelMetrics Validate one or more OCV models against OCV test data.
%
% Usage:
%   validation = computeOcvModelMetrics(model_inputs, data_input)
%   validation = computeOcvModelMetrics(model_inputs, data_input, cfg)
%
% Inputs:
%   model_inputs  MAT-file path, model struct, or cell array of either.
%   data_input    OCV data source:
%                   - processOCV/DiagProcessOCV-style struct array with
%                     fields temp, script1, script2, script3, script4
%                   - folder containing <prefix>_OCV_*.mat files
%                   - [] to use cfg.data_dir
%   cfg           Optional struct:
%                   .data_dir
%                   .data_prefix
%                   .cell_id
%                   .temps_degC
%                   .min_v
%                   .max_v
%                   .ocv_method   'diagAverage', 'resistanceBlend', or
%                                 'voltageAverage'
%
% Output:
%   validation    Struct with per-model OCV metrics and raw-fit references.

script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(script_dir);

addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'utility')));

if nargin < 1 || isempty(model_inputs)
    error('computeOcvModelMetrics:MissingModelInput', ...
        'At least one OCV model input is required.');
end
if nargin < 2
    data_input = [];
end
if nargin < 3 || isempty(cfg)
    cfg = struct();
end

cfg = normalizeConfig(cfg);
model_inputs = normalizeModelInputs(model_inputs);
raw_data = loadOcvInputData(data_input, cfg);
[filedata, ocv_eta, ocv_q] = buildOcvReference(raw_data, cfg);
soc = (0:0.005:1).';

models = repmat(struct( ...
    'name', '', ...
    'source', '', ...
    'model', struct(), ...
    'per_temp', [], ...
    'summary_table', table(), ...
    'metrics', struct()), numel(model_inputs), 1);

summary_rows = cell(numel(model_inputs) * numel(filedata), 8);
row_idx = 0;

for model_idx = 1:numel(model_inputs)
    [model, source_name] = loadModelStruct(model_inputs{model_idx});
    model_name = getModelName(model, source_name);

    per_temp = repmat(struct( ...
        'temp_degC', [], ...
        'soc', soc, ...
        'predicted_ocv', [], ...
        'rawocv', [], ...
        'error_v', [], ...
        'metrics', struct(), ...
        'disZ', [], ...
        'disV', [], ...
        'chgZ', [], ...
        'chgV', []), numel(filedata), 1);

    for temp_idx = 1:numel(filedata)
        reference = filedata(temp_idx);
        predicted_ocv = OCVfromSOCtemp(soc, reference.temp, model);
        error_v = reference.rawocv(:) - predicted_ocv(:);
        metrics = computeErrorMetrics(error_v);

        per_temp(temp_idx).temp_degC = reference.temp;
        per_temp(temp_idx).soc = soc;
        per_temp(temp_idx).predicted_ocv = predicted_ocv(:);
        per_temp(temp_idx).rawocv = reference.rawocv(:);
        per_temp(temp_idx).error_v = error_v(:);
        per_temp(temp_idx).metrics = metrics;
        per_temp(temp_idx).disZ = reference.disZ(:);
        per_temp(temp_idx).disV = reference.disV(:);
        per_temp(temp_idx).chgZ = reference.chgZ(:);
        per_temp(temp_idx).chgV = reference.chgV(:);

        row_idx = row_idx + 1;
        summary_rows(row_idx, :) = { ...
            model_name, char(source_name), reference.temp, ...
            metrics.rmse_mv, metrics.mean_error_mv, metrics.mae_mv, ...
            metrics.max_abs_error_mv, metrics.sample_count};
    end

    model_summary = cell2table(summary_rows(row_idx - numel(filedata) + 1:row_idx, :), ...
        'VariableNames', {'model_name', 'source', 'temp_degC', 'rmse_mv', ...
        'mean_error_mv', 'mae_mv', 'max_abs_error_mv', 'samples'});

    models(model_idx).name = model_name;
    models(model_idx).source = char(source_name);
    models(model_idx).model = model;
    models(model_idx).per_temp = per_temp;
    models(model_idx).summary_table = model_summary;
    models(model_idx).metrics = summarizeOcvMetrics(model_summary);
end

summary_rows = summary_rows(1:row_idx, :);
summary_table = cell2table(summary_rows, 'VariableNames', { ...
    'model_name', 'source', 'temp_degC', 'rmse_mv', 'mean_error_mv', ...
    'mae_mv', 'max_abs_error_mv', 'samples'});
summary_table = sortrows(summary_table, {'temp_degC', 'rmse_mv'}, {'ascend', 'ascend'});

model_names = strings(numel(models), 1);
mean_rmse_mv = NaN(numel(models), 1);
max_rmse_mv = NaN(numel(models), 1);
mean_me_mv = NaN(numel(models), 1);
for model_idx = 1:numel(models)
    model_names(model_idx) = string(models(model_idx).name);
    mean_rmse_mv(model_idx) = models(model_idx).metrics.mean_rmse_mv;
    max_rmse_mv(model_idx) = models(model_idx).metrics.max_rmse_mv;
    mean_me_mv(model_idx) = models(model_idx).metrics.mean_error_mv;
end

model_summary_table = table(model_names, mean_rmse_mv, max_rmse_mv, mean_me_mv, ...
    'VariableNames', {'model_name', 'mean_rmse_mv', 'max_rmse_mv', 'mean_error_mv'});
model_summary_table = sortrows(model_summary_table, 'mean_rmse_mv', 'ascend');
model_summary_table.rank = (1:height(model_summary_table)).';
model_summary_table = movevars(model_summary_table, 'rank', 'Before', 'model_name');

validation = struct();
validation.name = 'OCV model validation';
validation.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
validation.reference = struct( ...
    'cell_id', cfg.cell_id, ...
    'ocv_method', cfg.ocv_method, ...
    'soc', soc, ...
    'filedata', filedata, ...
    'ocv_eta', ocv_eta, ...
    'ocv_q', ocv_q);
validation.models = models;
validation.summary_table = summary_table;
validation.model_summary_table = model_summary_table;
validation.metrics = struct( ...
    'mean_model_rmse_mv', mean(mean_rmse_mv, 'omitnan'), ...
    'best_model_rmse_mv', min(mean_rmse_mv, [], 'omitnan'), ...
    'worst_model_rmse_mv', max(mean_rmse_mv, [], 'omitnan'));
end

function cfg = normalizeConfig(cfg)
cfg.data_dir = fieldOr(cfg, 'data_dir', '');
cfg.data_prefix = fieldOr(cfg, 'data_prefix', 'ATL');
cfg.cell_id = fieldOr(cfg, 'cell_id', cfg.data_prefix);
cfg.temps_degC = fieldOr(cfg, 'temps_degC', [-25 -15 -5 5 15 25 35 45]);
cfg.min_v = fieldOr(cfg, 'min_v', 2.0);
cfg.max_v = fieldOr(cfg, 'max_v', 3.75);
cfg.ocv_method = lower(fieldOr(cfg, 'ocv_method', 'diagAverage'));
end

function model_inputs = normalizeModelInputs(model_inputs)
if ~iscell(model_inputs)
    model_inputs = {model_inputs};
end
end

function data = loadOcvInputData(data_input, cfg)
if isempty(data_input)
    if isempty(cfg.data_dir)
        error('computeOcvModelMetrics:MissingOcvData', ...
            'Either data_input or cfg.data_dir is required.');
    end
    data = loadOcvDataFromDir(cfg.data_dir, cfg.data_prefix, cfg.temps_degC);
    return;
end

if isstruct(data_input)
    data = data_input(:);
    return;
end

if ischar(data_input) || (isstring(data_input) && isscalar(data_input))
    data = loadOcvDataFromDir(char(data_input), cfg.data_prefix, cfg.temps_degC);
    return;
end

error('computeOcvModelMetrics:UnsupportedDataInput', ...
    'Unsupported data_input of class %s.', class(data_input));
end

function data = loadOcvDataFromDir(data_dir, data_prefix, temps_degC)
if exist(data_dir, 'dir') ~= 7
    error('computeOcvModelMetrics:MissingDataDir', ...
        'OCV data folder not found: %s', data_dir);
end

data = repmat(struct( ...
    'temp', [], ...
    'script1', [], ...
    'script2', [], ...
    'script3', [], ...
    'script4', []), numel(temps_degC), 1);

for idx = 1:numel(temps_degC)
    tc = temps_degC(idx);
    if tc < 0
        filename = fullfile(data_dir, sprintf('%s_OCV_N%02d.mat', data_prefix, abs(tc)));
    else
        filename = fullfile(data_dir, sprintf('%s_OCV_P%02d.mat', data_prefix, tc));
    end
    src = load(filename, 'OCVData');
    if ~isfield(src, 'OCVData')
        error('computeOcvModelMetrics:MissingOcvData', ...
            'File %s does not contain OCVData.', filename);
    end
    data(idx).temp = tc;
    data(idx).script1 = src.OCVData.script1;
    data(idx).script2 = src.OCVData.script2;
    data(idx).script3 = src.OCVData.script3;
    data(idx).script4 = src.OCVData.script4;
end
end

function [filedata, eta, Q] = buildOcvReference(data, cfg)
switch cfg.ocv_method
    case 'diagaverage'
        [filedata, eta, Q] = buildDiagReference(data, cfg.cell_id, cfg.min_v, cfg.max_v);
    case 'resistanceblend'
        [filedata, eta, Q] = buildLegacyReference(data, cfg.min_v, cfg.max_v);
    case 'voltageaverage'
        [filedata, eta, Q] = buildVavgReference(data);
    otherwise
        error('computeOcvModelMetrics:UnsupportedMethod', ...
            'Unsupported ocv_method "%s".', cfg.ocv_method);
end
end

function [filedata, eta, Q] = buildDiagReference(data, cell_id, min_v, max_v)
filetemps = [data.temp];
numtemps = numel(filetemps);
ind25 = find(filetemps == 25, 1, 'first');
if isempty(ind25)
    error('computeOcvModelMetrics:Missing25C', 'Must have a test at 25degC');
end
not25 = find(filetemps ~= 25);

config = defaultDiagConfig(min_v, max_v);
filedata = repmat(struct('temp', [], 'disZ', [], 'disV', [], 'chgZ', [], 'chgV', [], 'rawocv', []), numtemps, 1);
eta = zeros(size(filetemps));
Q = zeros(size(filetemps));

k = ind25;
totDisAh = data(k).script1.disAh(end) + data(k).script2.disAh(end) + data(k).script3.disAh(end) + data(k).script4.disAh(end);
totChgAh = data(k).script1.chgAh(end) + data(k).script2.chgAh(end) + data(k).script3.chgAh(end) + data(k).script4.chgAh(end);
eta25 = totDisAh / totChgAh;
eta(k) = eta25;
data(k).script1.chgAh = data(k).script1.chgAh * eta25;
data(k).script2.chgAh = data(k).script2.chgAh * eta25;
data(k).script3.chgAh = data(k).script3.chgAh * eta25;
data(k).script4.chgAh = data(k).script4.chgAh * eta25;

Q25 = data(k).script1.disAh(end) + data(k).script2.disAh(end) - data(k).script1.chgAh(end) - data(k).script2.chgAh(end);
Q(k) = Q25;
filedata(k) = buildDiagFiledata(data(k), cell_id, Q25, config);

for k = not25
    data(k).script2.chgAh = data(k).script2.chgAh * eta25;
    data(k).script4.chgAh = data(k).script4.chgAh * eta25;
    eta(k) = (data(k).script1.disAh(end) + data(k).script2.disAh(end) + ...
        data(k).script3.disAh(end) + data(k).script4.disAh(end) - ...
        data(k).script2.chgAh(end) - data(k).script4.chgAh(end)) / ...
        (data(k).script1.chgAh(end) + data(k).script3.chgAh(end));
    data(k).script1.chgAh = eta(k) * data(k).script1.chgAh;
    data(k).script3.chgAh = eta(k) * data(k).script3.chgAh;
    Q(k) = data(k).script1.disAh(end) + data(k).script2.disAh(end) - data(k).script1.chgAh(end) - data(k).script2.chgAh(end);
    filedata(k) = buildDiagFiledata(data(k), cell_id, Q25, config);
end
end

function [filedata, eta, Q] = buildLegacyReference(data, min_v, max_v)
filetemps = [data.temp];
numtemps = numel(filetemps);
ind25 = find(filetemps == 25, 1, 'first');
if isempty(ind25)
    error('computeOcvModelMetrics:Missing25C', 'Must have a test at 25degC');
end
not25 = find(filetemps ~= 25);

SOC = 0:0.005:1;
filedata = repmat(struct('temp', [], 'disZ', [], 'disV', [], 'chgZ', [], 'chgV', [], 'rawocv', []), numtemps, 1);
eta = zeros(size(filetemps));
Q = zeros(size(filetemps));

k = ind25;
totDisAh = data(k).script1.disAh(end) + data(k).script2.disAh(end) + data(k).script3.disAh(end) + data(k).script4.disAh(end);
totChgAh = data(k).script1.chgAh(end) + data(k).script2.chgAh(end) + data(k).script3.chgAh(end) + data(k).script4.chgAh(end);
eta25 = totDisAh / totChgAh;
eta(k) = eta25;
data(k).script1.chgAh = data(k).script1.chgAh * eta25;
data(k).script2.chgAh = data(k).script2.chgAh * eta25;
data(k).script3.chgAh = data(k).script3.chgAh * eta25;
data(k).script4.chgAh = data(k).script4.chgAh * eta25;

Q25 = data(k).script1.disAh(end) + data(k).script2.disAh(end) - data(k).script1.chgAh(end) - data(k).script2.chgAh(end);
Q(k) = Q25;
filedata(k) = buildLegacyFiledata(data(k), Q25, SOC);

for k = not25
    data(k).script2.chgAh = data(k).script2.chgAh * eta25;
    data(k).script4.chgAh = data(k).script4.chgAh * eta25;
    eta(k) = (data(k).script1.disAh(end) + data(k).script2.disAh(end) + ...
        data(k).script3.disAh(end) + data(k).script4.disAh(end) - ...
        data(k).script2.chgAh(end) - data(k).script4.chgAh(end)) / ...
        (data(k).script1.chgAh(end) + data(k).script3.chgAh(end));
    data(k).script1.chgAh = eta(k) * data(k).script1.chgAh;
    data(k).script3.chgAh = eta(k) * data(k).script3.chgAh;
    Q(k) = data(k).script1.disAh(end) + data(k).script2.disAh(end) - data(k).script1.chgAh(end) - data(k).script2.chgAh(end);
    filedata(k) = buildLegacyFiledata(data(k), Q25, SOC);
end

% Keep ylim anchors available to callers even if unused here.
min_v = min_v; %#ok<NASGU>
max_v = max_v; %#ok<NASGU>
end

function [filedata, eta, Q] = buildVavgReference(data)
filetemps = [data.temp];
numtemps = numel(filetemps);
ind25 = find(filetemps == 25, 1, 'first');
if isempty(ind25)
    error('computeOcvModelMetrics:Missing25C', 'Must have a test at 25degC');
end
not25 = find(filetemps ~= 25);

filedata = repmat(struct('temp', [], 'disZ', [], 'disV', [], 'chgZ', [], 'chgV', [], 'rawocv', []), numtemps, 1);
eta = zeros(size(filetemps));
Q = zeros(size(filetemps));

k = ind25;
totDisAh = data(k).script1.disAh(end) + data(k).script2.disAh(end) + data(k).script3.disAh(end) + data(k).script4.disAh(end);
totChgAh = data(k).script1.chgAh(end) + data(k).script2.chgAh(end) + data(k).script3.chgAh(end) + data(k).script4.chgAh(end);
eta25 = totDisAh / totChgAh;
eta(k) = eta25;
data(k).script1.chgAh = data(k).script1.chgAh * eta25;
data(k).script2.chgAh = data(k).script2.chgAh * eta25;
data(k).script3.chgAh = data(k).script3.chgAh * eta25;
data(k).script4.chgAh = data(k).script4.chgAh * eta25;

Q25 = data(k).script1.disAh(end) + data(k).script2.disAh(end) - data(k).script1.chgAh(end) - data(k).script2.chgAh(end);
Q(k) = Q25;
filedata(k) = buildVavgFiledata(data(k), Q25);

for k = not25
    data(k).script2.chgAh = data(k).script2.chgAh * eta25;
    data(k).script4.chgAh = data(k).script4.chgAh * eta25;
    eta(k) = (data(k).script1.disAh(end) + data(k).script2.disAh(end) + ...
        data(k).script3.disAh(end) + data(k).script4.disAh(end) - ...
        data(k).script2.chgAh(end) - data(k).script4.chgAh(end)) / ...
        (data(k).script1.chgAh(end) + data(k).script3.chgAh(end));
    data(k).script1.chgAh = eta(k) * data(k).script1.chgAh;
    data(k).script3.chgAh = eta(k) * data(k).script3.chgAh;
    Q(k) = data(k).script1.disAh(end) + data(k).script2.disAh(end) - data(k).script1.chgAh(end) - data(k).script2.chgAh(end);
    filedata(k) = buildVavgFiledata(data(k), Q25);
end
end

function filedatum = buildLegacyFiledata(testdata, Q25, SOC)
indD = find(testdata.script1.step == 2);
IR1Da = testdata.script1.voltage(indD(1)-1) - testdata.script1.voltage(indD(1));
IR2Da = testdata.script1.voltage(indD(end)+1) - testdata.script1.voltage(indD(end));
indC = find(testdata.script3.step == 2);
IR1Ca = testdata.script3.voltage(indC(1)) - testdata.script3.voltage(indC(1)-1);
IR2Ca = testdata.script3.voltage(indC(end)) - testdata.script3.voltage(indC(end)+1);
IR1D = min(IR1Da, 2 * IR2Ca);
IR2D = min(IR2Da, 2 * IR1Ca);
IR1C = min(IR1Ca, 2 * IR2Da);
IR2C = min(IR2Ca, 2 * IR1Da);

blend = (0:length(indD)-1) / (length(indD)-1);
IRblend = IR1D + (IR2D - IR1D) * blend(:);
disV = testdata.script1.voltage(indD) + IRblend;
disZ = 1 - testdata.script1.disAh(indD) / Q25;
disZ = disZ + (1 - disZ(1));

blend = (0:length(indC)-1) / (length(indC)-1);
IRblend = IR1C + (IR2C - IR1C) * blend(:);
chgV = testdata.script3.voltage(indC) - IRblend;
chgZ = testdata.script3.chgAh(indC) / Q25;
chgZ = chgZ - chgZ(1);

deltaV50 = interp1(chgZ, chgV, 0.5) - interp1(disZ, disV, 0.5);
ind = find(chgZ < 0.5);
vChg = chgV(ind) - chgZ(ind) * deltaV50;
zChg = chgZ(ind);
ind = find(disZ > 0.5);
vDis = flipud(disV(ind) + (1 - disZ(ind)) * deltaV50);
zDis = flipud(disZ(ind));

filedatum.temp = testdata.temp;
filedatum.disZ = disZ(:);
filedatum.disV = testdata.script1.voltage(indD);
filedatum.chgZ = chgZ(:);
filedatum.chgV = testdata.script3.voltage(indC);
filedatum.rawocv = interp1([zChg; zDis], [vChg; vDis], SOC, 'linear', 'extrap').';
end

function filedatum = buildVavgFiledata(testdata, Q25)
indD = find(testdata.script1.step == 2);
indC = find(testdata.script3.step == 2);

disZ = 1 - testdata.script1.disAh(indD) / Q25;
disZ = disZ + (1 - disZ(1));
chgZ = testdata.script3.chgAh(indC) / Q25;
chgZ = chgZ - chgZ(1);

disV = testdata.script1.voltage(indD);
chgV = testdata.script3.voltage(indC);

stdZ = (0:0.002:1).';
avgDisV = linearinterp(disZ, disV, stdZ);
avgChgV = linearinterp(chgZ, chgV, stdZ);
avgU = (avgChgV + avgDisV) / 2;

filedatum.temp = testdata.temp;
filedatum.disZ = disZ(:);
filedatum.disV = disV(:);
filedatum.chgZ = chgZ(:);
filedatum.chgV = chgV(:);
filedatum.rawocv = interp1(stdZ, avgU, 0:0.005:1, 'linear', 'extrap').';
end

function filedatum = buildDiagFiledata(testdata, cell_id, Q25, config)
indD = find(testdata.script1.step == 2);
indC = find(testdata.script3.step == 2);

disZ = 1 - testdata.script1.disAh(indD) / Q25;
disZ = disZ + (1 - disZ(1));
chgZ = testdata.script3.chgAh(indC) / Q25;
chgZ = chgZ - chgZ(1);

disV = testdata.script1.voltage(indD);
chgV = testdata.script3.voltage(indC);

diag_data = struct();
diag_data.name = cell_id;
diag_data.TdegC = testdata.temp;
diag_data.orig.disZ = disZ(:);
diag_data.orig.disV = disV(:);
diag_data.orig.chgZ = chgZ(:);
diag_data.orig.chgV = chgV(:);
diag_data.interp = makeDiagInterpData(diag_data.orig, config);

[diagZ, diagU, diagInfo] = ocvDiagonalAverage(diag_data, config);

filedatum.temp = testdata.temp;
filedatum.disZ = disZ(:);
filedatum.disV = disV(:);
filedatum.chgZ = chgZ(:);
filedatum.chgV = chgV(:);
filedatum.rawocv = buildOverlapLimitedRawOcv(diag_data, diagZ, diagU, diagInfo);
end

function interp_data = makeDiagInterpData(orig, config)
stdV = (config.vmin:config.du:config.vmax).';
stdZ = (0:config.dz:1).';

interp_data.stdV = stdV;
interp_data.disZ = linearinterp(orig.disV, orig.disZ, stdV);
interp_data.chgZ = linearinterp(orig.chgV, orig.chgZ, stdV);
interp_data.stdZ = stdZ;
interp_data.disV = linearinterp(orig.disZ, orig.disV, stdZ);
interp_data.chgV = linearinterp(orig.chgZ, orig.chgV, stdZ);
end

function config = defaultDiagConfig(vmin, vmax)
config = struct();
config.vmin = vmin;
config.vmax = vmax;
config.du = 0.002;
config.dz = 0.002;
config.datype = 'useAvg';
config.debug = false;
config.retain_voltage_grid_output = false;
config.daxcorrfiltv = @(stdV) find(stdV >= vmin & stdV <= vmax);
config.daxcorrfiltz = @(stdZ) find(stdZ >= 0 & stdZ <= 1);
end

function [Z, U, info] = ocvDiagonalAverage(data, config)
stdV = data.interp.stdV;
disZ = data.interp.disZ;
chgZ = data.interp.chgZ;
stdZ = data.interp.stdZ;
disV = data.interp.disV;
chgV = data.interp.chgV;

du = mean(diff(stdV));
intervals = config.daxcorrfiltv(stdV);
if ~iscell(intervals), intervals = {intervals}; end
lagU = zeros(size(intervals));
for idx = 1:numel(intervals)
    ind = intervals{idx};
    dzdv1 = roughdiff(disZ(ind), stdV(ind));
    dzdv3 = roughdiff(chgZ(ind), stdV(ind));
    [c, lag] = xcorr(dzdv1, dzdv3);
    lagPeak = abs(lag(c == max(c)) * du);
    lagU(idx) = lagPeak(1);
end
lagU = mean(lagU);

dz = mean(diff(stdZ));
intervals = config.daxcorrfiltz(stdZ);
if ~iscell(intervals), intervals = {intervals}; end
lagZ = zeros(size(intervals));
for idx = 1:numel(intervals)
    ind = intervals{idx};
    dzdv1 = roughdiff(stdZ(ind), disV(ind));
    dzdv3 = roughdiff(stdZ(ind), chgV(ind));
    [c, lag] = xcorr(dzdv1, dzdv3);
    lagPeak = abs(lag(c == max(c)) * dz);
    lagZ(idx) = lagPeak(1);
end
lagZ = mean(lagZ);

uuD = data.orig.disV + lagU / 2;
zzD = data.orig.disZ + lagZ / 2;
U4D = interp1(zzD, uuD, stdZ, 'linear', NaN);
uuC = data.orig.chgV - lagU / 2;
zzC = data.orig.chgZ - lagZ / 2;
U4C = interp1(zzC, uuC, stdZ, 'linear', NaN);
overlapMask = isfinite(U4D) & isfinite(U4C);
U4 = NaN(size(stdZ));

switch config.datype
    case 'useDis'
        U4(overlapMask) = U4D(overlapMask);
    case 'useChg'
        U4(overlapMask) = U4C(overlapMask);
    otherwise
        U4(overlapMask) = (U4C(overlapMask) + U4D(overlapMask)) / 2;
end

Z = stdZ;
U = U4;
info = struct();
info.overlapMask = overlapMask;
info.U4D = U4D;
info.U4C = U4C;
info.lagU = lagU;
info.lagZ = lagZ;
end

function dy = roughdiff(y, x)
y = y(:);
x = x(:);
if numel(y) ~= numel(x)
    error('roughdiff requires vectors of equal length.');
end
if numel(y) < 2
    dy = zeros(size(y));
    return;
end

run_start = [true; diff(x) ~= 0];
run_id = cumsum(run_start);
n_runs = run_id(end);
xc = accumarray(run_id, x, [n_runs 1], @mean);
yc = accumarray(run_id, y, [n_runs 1], @mean);

if numel(xc) < 2
    dy = zeros(size(y));
    return;
end

dxc = diff(xc);
dyc = diff(yc) ./ dxc;
dyc(~isfinite(dyc)) = 0;
dyc = ([dyc(1); dyc] + [dyc; dyc(end)]) / 2;
dy = dyc(run_id);
end

function rawocv = buildOverlapLimitedRawOcv(diag_data, diagZ, diagU, diagInfo)
stdZ = diagZ(:);
lowTail = diag_data.interp.chgV(:);
highTail = diag_data.interp.disV(:);
rawStd = NaN(size(stdZ));

overlapIdx = find(diagInfo.overlapMask(:));
if isempty(overlapIdx)
    warning('computeOcvModelMetrics:NoDiagonalOverlap', ...
        ['No valid diagonal overlap remained after shifting; falling back ' ...
         'to simple voltage averaging on the standard SOC grid.']);
    rawStd = (lowTail + highTail) / 2;
else
    firstIdx = overlapIdx(1);
    lastIdx = overlapIdx(end);
    rawStd(overlapIdx) = diagU(overlapIdx);

    lowOffset = rawStd(firstIdx) - lowTail(firstIdx);
    highOffset = rawStd(lastIdx) - highTail(lastIdx);

    if firstIdx > 1
        rawStd(1:firstIdx-1) = lowTail(1:firstIdx-1) + lowOffset;
    end
    if lastIdx < numel(stdZ)
        rawStd(lastIdx+1:end) = highTail(lastIdx+1:end) + highOffset;
    end

    missingIdx = find(~isfinite(rawStd));
    if ~isempty(missingIdx)
        validIdx = find(isfinite(rawStd));
        rawStd(missingIdx) = interp1(stdZ(validIdx), rawStd(validIdx), ...
            stdZ(missingIdx), 'linear', 'extrap');
    end
end

rawocv = interp1(stdZ, rawStd, 0:0.005:1, 'linear');
end

function metrics = computeErrorMetrics(error_v)
valid_error = error_v(isfinite(error_v));
metrics = struct( ...
    'sample_count', numel(valid_error), ...
    'rmse_v', NaN, ...
    'rmse_mv', NaN, ...
    'mean_error_v', NaN, ...
    'mean_error_mv', NaN, ...
    'mae_v', NaN, ...
    'mae_mv', NaN, ...
    'max_abs_error_v', NaN, ...
    'max_abs_error_mv', NaN);
if isempty(valid_error), return; end
metrics.rmse_v = sqrt(mean(valid_error .^ 2));
metrics.rmse_mv = 1000 * metrics.rmse_v;
metrics.mean_error_v = mean(valid_error);
metrics.mean_error_mv = 1000 * metrics.mean_error_v;
metrics.mae_v = mean(abs(valid_error));
metrics.mae_mv = 1000 * metrics.mae_v;
metrics.max_abs_error_v = max(abs(valid_error));
metrics.max_abs_error_mv = 1000 * metrics.max_abs_error_v;
end

function metrics = summarizeOcvMetrics(summary_table)
metrics = struct();
metrics.mean_rmse_mv = mean(summary_table.rmse_mv, 'omitnan');
metrics.max_rmse_mv = max(summary_table.rmse_mv, [], 'omitnan');
metrics.mean_error_mv = mean(summary_table.mean_error_mv, 'omitnan');
metrics.mean_mae_mv = mean(summary_table.mae_mv, 'omitnan');
metrics.max_abs_error_mv = max(summary_table.max_abs_error_mv, [], 'omitnan');
metrics.case_count = height(summary_table);
end

function [model, source_name] = loadModelStruct(model_input)
if isstruct(model_input)
    model = model_input;
    source_name = 'in-memory';
    return;
end
model_file = char(model_input);
src = load(model_file);
source_name = model_file;
names = fieldnames(src);
for idx = 1:numel(names)
    value = src.(names{idx});
    if isstruct(value) && all(isfield(value, {'SOC', 'OCV0', 'OCVrel'}))
        model = value;
        return;
    end
end
error('computeOcvModelMetrics:MissingModelStruct', ...
    'No ESC-style OCV model struct found in %s', model_file);
end

function model_name = getModelName(model, source_name)
if isfield(model, 'name') && ~isempty(model.name)
    model_name = char(model.name);
else
    [~, model_name] = fileparts(char(source_name));
end
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end
