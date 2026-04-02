function comparison = compareOcvModels(model_a_input, model_b_input, data_input, temperature_degC, cfg)
% compareOcvModels Visually compare two model OCV curves against raw OCV traces.
%
% Usage:
%   comparison = compareOcvModels(model_a_input, model_b_input, data_input, temperature_degC)
%   comparison = compareOcvModels(model_a_input, model_b_input, data_input, temperature_degC, cfg)
%
% Inputs:
%   model_a_input     ESC/OCV model MAT-file path or model struct.
%   model_b_input     ESC/OCV model MAT-file path or model struct.
%   data_input        OCV source:
%                       - MAT-file path containing OCVData
%                       - folder containing <prefix>_OCV_*.mat files
%                       - processOCV-style struct array
%                       - single processOCV-style struct
%   temperature_degC  Temperature to visualize. Use [] to infer it from
%                     a single-file input.
%   cfg               Optional struct with fields:
%                       enabled_plot: true/false, default true
%                       data_prefix: file prefix for folder inputs
%                       model_a_name: custom display label
%                       model_b_name: custom display label
%                       soc_grid: SOC grid for plotting model OCVs
%
% Output:
%   comparison        Struct containing the raw charge/discharge traces,
%                     both model OCV curves, the model-to-model delta, and
%                     the comparison figure handle.

if nargin < 5 || isempty(cfg)
    cfg = struct();
end
if nargin < 4
    temperature_degC = [];
end

enabled_plot = true;
if isfield(cfg, 'enabled_plot') && ~isempty(cfg.enabled_plot)
    enabled_plot = logical(cfg.enabled_plot);
end

soc_grid = fieldOr(cfg, 'soc_grid', (0:0.005:1).');
soc_grid = double(soc_grid(:));
if isempty(soc_grid) || any(~isfinite(soc_grid))
    error('compareOcvModels:InvalidSocGrid', ...
        'cfg.soc_grid must be a finite numeric vector.');
end

script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(script_dir);
addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'utility')));

raw_data = loadOcvInputData(data_input, temperature_degC, cfg);
temperature_degC = resolveTemperature(raw_data, temperature_degC);
reference = buildVisualReference(raw_data, temperature_degC);

[model_a, model_a_source] = loadEscLikeModel(model_a_input);
[model_b, model_b_source] = loadEscLikeModel(model_b_input);
model_a_label = resolveModelLabel(model_a, model_a_source, cfg, 'model_a_name', 'Model A');
model_b_label = resolveModelLabel(model_b, model_b_source, cfg, 'model_b_name', 'Model B');

model_a_ocv = OCVfromSOCtemp(soc_grid, temperature_degC, model_a);
model_b_ocv = OCVfromSOCtemp(soc_grid, temperature_degC, model_b);
model_delta_mv = 1000 * (model_a_ocv(:) - model_b_ocv(:));

comparison = struct();
comparison.name = 'OCV model visual comparison';
comparison.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
comparison.temperature_degC = temperature_degC;
comparison.enabled_plot = enabled_plot;
comparison.soc_grid = soc_grid(:);
comparison.reference = reference;
comparison.model_a = struct( ...
    'label', model_a_label, ...
    'source', model_a_source, ...
    'ocv', model_a_ocv(:));
comparison.model_b = struct( ...
    'label', model_b_label, ...
    'source', model_b_source, ...
    'ocv', model_b_ocv(:));
comparison.model_delta_mv = model_delta_mv(:);
comparison.figure_handle = [];

printSummary(comparison);
if enabled_plot
    comparison.figure_handle = plotComparison(comparison);
end

if nargout == 0
    assignin('base', 'ocvModelComparison', comparison);
end
end

function raw_data = loadOcvInputData(data_input, temperature_degC, cfg)
if ischar(data_input) || (isstring(data_input) && isscalar(data_input))
    data_path = char(data_input);
    if exist(data_path, 'dir') == 7
        raw_data = loadOcvDataFromDir(data_path, temperature_degC, cfg);
        return;
    end
    if exist(data_path, 'file') ~= 2
        error('compareOcvModels:MissingInput', ...
            'OCV input path not found: %s', data_path);
    end
    raw_data = loadSingleOcvFile(data_path, temperature_degC);
    return;
end

if isstruct(data_input)
    raw_data = data_input(:);
    if numel(raw_data) == 1 && (~isfield(raw_data, 'temp') || isempty(raw_data.temp))
        if isempty(temperature_degC)
            error('compareOcvModels:MissingTemperature', ...
                'Single OCV struct input requires temperature_degC or a temp field.');
        end
        raw_data.temp = temperature_degC;
    end
    return;
end

error('compareOcvModels:UnsupportedInput', ...
    'Unsupported OCV input of class %s.', class(data_input));
end

function raw_data = loadSingleOcvFile(data_path, requested_temperature_degC)
src = load(data_path);
if isfield(src, 'OCVData')
    raw_data = src.OCVData;
elseif isstruct(src)
    names = fieldnames(src);
    if numel(names) == 1 && isstruct(src.(names{1}))
        raw_data = src.(names{1});
    else
        raw_data = src;
    end
else
    error('compareOcvModels:UnsupportedFile', ...
        'Unsupported OCV file contents in %s.', data_path);
end

if ~isfield(raw_data, 'temp') || isempty(raw_data.temp)
    inferred_temperature_degC = inferTemperatureFromPath(data_path);
    if isempty(requested_temperature_degC) && isempty(inferred_temperature_degC)
        error('compareOcvModels:MissingFileTemperature', ...
            'Could not infer temperature from %s.', data_path);
    end
    raw_data.temp = chooseTemperature(requested_temperature_degC, inferred_temperature_degC);
end
raw_data = raw_data(:);
end

function raw_data = loadOcvDataFromDir(data_dir, requested_temperature_degC, cfg)
if isempty(requested_temperature_degC) || ~isfinite(requested_temperature_degC)
    error('compareOcvModels:MissingDirectoryTemperature', ...
        'Folder-based OCV input requires an explicit temperature_degC.');
end

required_temps = unique([25, requested_temperature_degC], 'stable');
data_prefix = fieldOr(cfg, 'data_prefix', 'ATL');
raw_data = repmat(struct('temp', [], 'script1', [], 'script2', [], 'script3', [], 'script4', []), numel(required_temps), 1);

for idx = 1:numel(required_temps)
    tc = required_temps(idx);
    if tc < 0
        filename = fullfile(data_dir, sprintf('%s_OCV_N%02d.mat', data_prefix, abs(tc)));
    else
        filename = fullfile(data_dir, sprintf('%s_OCV_P%02d.mat', data_prefix, tc));
    end
    src = load(filename);
    if ~isfield(src, 'OCVData')
        error('compareOcvModels:MissingOcvData', ...
            'File %s does not contain OCVData.', filename);
    end
    raw_data(idx) = src.OCVData;
    raw_data(idx).temp = tc;
end
end

function temperature_degC = resolveTemperature(raw_data, requested_temperature_degC)
temperature_degC = requested_temperature_degC;
if ~isempty(temperature_degC)
    return;
end

if numel(raw_data) == 1 && isfield(raw_data, 'temp') && ~isempty(raw_data.temp)
    temperature_degC = double(raw_data.temp);
    return;
end

error('compareOcvModels:MissingTemperature', ...
    'temperature_degC is required unless it can be inferred from a single-file input.');
end

function temperature_degC = chooseTemperature(requested_temperature_degC, inferred_temperature_degC)
temperature_degC = requested_temperature_degC;
if isempty(temperature_degC)
    temperature_degC = inferred_temperature_degC;
end
end

function inferred_temperature_degC = inferTemperatureFromPath(data_path)
inferred_temperature_degC = [];
tokens = regexp(data_path, '_([PN])(\d{2})\.mat$', 'tokens', 'once');
if isempty(tokens)
    return;
end

magnitude = str2double(tokens{2});
if strcmpi(tokens{1}, 'N')
    inferred_temperature_degC = -magnitude;
else
    inferred_temperature_degC = magnitude;
end
end

function reference = buildVisualReference(raw_data, temperature_degC)
raw_data = raw_data(:);
temps = [raw_data.temp];
target_idx = find(temps == temperature_degC, 1, 'first');
if isempty(target_idx)
    error('compareOcvModels:MissingTargetTemperature', ...
        'The OCV input does not contain %g degC.', temperature_degC);
end

base_idx = find(temps == 25, 1, 'first');
if isempty(base_idx)
    error('compareOcvModels:Missing25CReference', ...
        ['OCV visual comparison requires the 25 degC OCV record to normalize ' ...
         'the charge/discharge traces.']);
end

base_case = raw_data(base_idx);
eta25 = computeEta25(base_case);
base_case = scaleAllChargeScripts(base_case, eta25);
Q25 = computeQ25(base_case);

target_case = raw_data(target_idx);
if temperature_degC == 25
    target_case = base_case;
    eta_target = eta25;
else
    target_case.script2.chgAh = eta25 * target_case.script2.chgAh;
    target_case.script4.chgAh = eta25 * target_case.script4.chgAh;
    eta_target = computeTargetEta(target_case);
    target_case.script1.chgAh = eta_target * target_case.script1.chgAh;
    target_case.script3.chgAh = eta_target * target_case.script3.chgAh;
end

indD = find(target_case.script1.step == 2);
indC = find(target_case.script3.step == 2);
if isempty(indD) || isempty(indC)
    error('compareOcvModels:MissingScriptSteps', ...
        'Could not find slow discharge/charge step 2 in the selected OCV dataset.');
end

discharge_soc = 1 - target_case.script1.disAh(indD) / Q25;
discharge_soc = discharge_soc + (1 - discharge_soc(1));
charge_soc = target_case.script3.chgAh(indC) / Q25;
charge_soc = charge_soc - charge_soc(1);

reference = struct();
reference.temperature_degC = temperature_degC;
reference.Q25_Ah = Q25;
reference.eta25 = eta25;
reference.eta_target = eta_target;
reference.discharge_soc = discharge_soc(:);
reference.discharge_voltage = target_case.script1.voltage(indD);
reference.charge_soc = charge_soc(:);
reference.charge_voltage = target_case.script3.voltage(indC);
end

function eta25 = computeEta25(test_case)
tot_dis_ah = test_case.script1.disAh(end) + test_case.script2.disAh(end) + ...
    test_case.script3.disAh(end) + test_case.script4.disAh(end);
tot_chg_ah = test_case.script1.chgAh(end) + test_case.script2.chgAh(end) + ...
    test_case.script3.chgAh(end) + test_case.script4.chgAh(end);
eta25 = tot_dis_ah / tot_chg_ah;
end

function test_case = scaleAllChargeScripts(test_case, eta_scale)
test_case.script1.chgAh = eta_scale * test_case.script1.chgAh;
test_case.script2.chgAh = eta_scale * test_case.script2.chgAh;
test_case.script3.chgAh = eta_scale * test_case.script3.chgAh;
test_case.script4.chgAh = eta_scale * test_case.script4.chgAh;
end

function Q25 = computeQ25(test_case)
Q25 = test_case.script1.disAh(end) + test_case.script2.disAh(end) - ...
    test_case.script1.chgAh(end) - test_case.script2.chgAh(end);
end

function eta_target = computeTargetEta(test_case)
eta_target = (test_case.script1.disAh(end) + test_case.script2.disAh(end) + ...
    test_case.script3.disAh(end) + test_case.script4.disAh(end) - ...
    test_case.script2.chgAh(end) - test_case.script4.chgAh(end)) / ...
    (test_case.script1.chgAh(end) + test_case.script3.chgAh(end));
end

function [model, source_name] = loadEscLikeModel(model_input)
if ischar(model_input) || (isstring(model_input) && isscalar(model_input))
    model_file = char(model_input);
    src = load(model_file);
    source_name = model_file;
else
    src = model_input;
    source_name = '<struct>';
end

model = unwrapModelStruct(src);
required = {'SOC', 'OCV0', 'OCVrel'};
if ~all(isfield(model, required))
    error('compareOcvModels:MissingOcvFields', ...
        'The supplied model does not expose the OCV fields required by OCVfromSOCtemp.');
end
end

function model = unwrapModelStruct(src)
if isfield(src, 'model') && isstruct(src.model)
    model = src.model;
    return;
end
if isfield(src, 'nmc30_model') && isstruct(src.nmc30_model)
    model = src.nmc30_model;
    return;
end
if all(isfield(src, {'SOC', 'OCV0', 'OCVrel'}))
    model = src;
    return;
end

names = fieldnames(src);
if numel(names) == 1 && isstruct(src.(names{1}))
    candidate = src.(names{1});
    if all(isfield(candidate, {'SOC', 'OCV0', 'OCVrel'}))
        model = candidate;
        return;
    end
end

error('compareOcvModels:AmbiguousModel', ...
    'Could not infer an ESC-style OCV model struct from the supplied input.');
end

function label = resolveModelLabel(model, source_name, cfg, cfg_field, fallback_label)
if isfield(cfg, cfg_field) && ~isempty(cfg.(cfg_field))
    label = char(cfg.(cfg_field));
    return;
end
if isfield(model, 'name') && ~isempty(model.name)
    label = char(model.name);
    return;
end
if ~strcmp(source_name, '<struct>')
    [~, label] = fileparts(source_name);
    return;
end
label = fallback_label;
end

function printSummary(comparison)
fprintf('\n%s\n', comparison.name);
fprintf('  Temperature: %g degC\n', comparison.temperature_degC);
fprintf('  %s vs %s\n', comparison.model_a.label, comparison.model_b.label);
fprintf('  Visual-only comparison: raw charge/discharge traces plus model OCV curves.\n\n');
end

function fig = plotComparison(comparison)
soc_pct = 100 * comparison.soc_grid(:);
fig = figure( ...
    'Name', sprintf('%s vs %s OCV %g degC', ...
        comparison.model_a.label, comparison.model_b.label, comparison.temperature_degC), ...
    'Color', 'w');

tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile
plot(100 * comparison.reference.discharge_soc, comparison.reference.discharge_voltage, 'k--', ...
    'LineWidth', 1.0, 'DisplayName', 'Raw discharge'); hold on
plot(100 * comparison.reference.charge_soc, comparison.reference.charge_voltage, 'k-.', ...
    'LineWidth', 1.0, 'DisplayName', 'Raw charge');
plot(soc_pct, comparison.model_a.ocv, 'LineWidth', 1.6, ...
    'DisplayName', sprintf('%s OCV', comparison.model_a.label));
plot(soc_pct, comparison.model_b.ocv, 'LineWidth', 1.6, ...
    'DisplayName', sprintf('%s OCV', comparison.model_b.label));
grid on
xlabel('SOC (%)');
ylabel('Voltage (V)');
xlim([0 100]);
title(sprintf('OCV curves at %g degC', comparison.temperature_degC));
legend('Location', 'best');

nexttile
plot(soc_pct, comparison.model_delta_mv, 'LineWidth', 1.4, ...
    'DisplayName', sprintf('%s - %s', comparison.model_a.label, comparison.model_b.label));
yline(0, 'k--', 'HandleVisibility', 'off');
grid on
xlabel('SOC (%)');
ylabel('Delta OCV (mV)');
xlim([0 100]);
title(sprintf('Model-to-model delta | max abs %.1f mV', max(abs(comparison.model_delta_mv))));
legend('Location', 'best');
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end
