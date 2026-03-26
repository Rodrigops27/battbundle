function fig_handle = plotOcvCurves(ocvInput, cfg)
% plotOcvCurves Plot OCV interpolation curves or ESC-style OCV models.
%
% Usage:
%   plotOcvCurves(ocvStruct)
%   plotOcvCurves('path_to_ocv.mat')
%   fig = plotOcvCurves(ocvInput, cfg)
%
% Inputs:
%   ocvInput   OCV struct or MAT file path. Supported shapes:
%                - OCV_interp with fields .cha/.dch and .SOC/.volt
%                - ESC-style model with SOC, OCV0, OCVrel
%                - MAT files containing variables such as OCV_interp,
%                  model, or a single struct variable of either form
%   cfg        Optional struct:
%                variable_name   preferred MAT variable name
%                figure_name     custom figure name
%                title_prefix    custom title prefix
%                temps           model temperatures to plot [degC]
%                show_midpoint   for OCV_interp, overlay midpoint, default true
%
% Output:
%   fig_handle Created figure handle.

if nargin < 1 || isempty(ocvInput)
    error('plotOcvCurves:MissingInput', ...
        'An OCV struct or MAT file path is required.');
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end

cfg = normalizeConfig(cfg);
[ocv_data, ocv_kind, source_name] = loadOcvInput(ocvInput, cfg.variable_name);

fig_handle = figure( ...
    'Name', buildFigureName(source_name, cfg), ...
    'NumberTitle', 'off');

switch ocv_kind
    case 'interp'
        plotInterpCurves(ocv_data, source_name, cfg);
    case 'model'
        plotModelCurves(ocv_data, source_name, cfg);
    otherwise
        error('plotOcvCurves:UnsupportedKind', ...
            'Unsupported OCV data kind: %s', ocv_kind);
end
end

function cfg = normalizeConfig(cfg)
cfg.variable_name = fieldOr(cfg, 'variable_name', '');
cfg.figure_name = fieldOr(cfg, 'figure_name', '');
cfg.title_prefix = fieldOr(cfg, 'title_prefix', '');
cfg.temps = fieldOr(cfg, 'temps', []);
cfg.show_midpoint = fieldOr(cfg, 'show_midpoint', true);
end

function [ocv_data, ocv_kind, source_name] = loadOcvInput(ocvInput, preferred_name)
if isstruct(ocvInput)
    [ocv_data, ocv_kind, source_name] = extractOcvStruct(ocvInput, preferred_name);
    return;
end

if ~(ischar(ocvInput) || (isstring(ocvInput) && isscalar(ocvInput)))
    error('plotOcvCurves:BadInput', ...
        'ocvInput must be a struct or MAT file path.');
end

ocv_path = char(ocvInput);
if exist(ocv_path, 'file') ~= 2
    fallback_path = resolveLegacyOcvPath(ocv_path);
    if isempty(fallback_path)
        error('plotOcvCurves:MissingFile', ...
            'OCV file not found: %s', ocv_path);
    end
    ocv_path = fallback_path;
end

loaded = load(ocv_path);
if ~isempty(preferred_name)
    if ~isfield(loaded, preferred_name)
        error('plotOcvCurves:MissingVariable', ...
            'Variable "%s" was not found in %s.', preferred_name, ocv_path);
    end
    [ocv_data, ocv_kind] = detectOcvStruct(loaded.(preferred_name));
    source_name = preferred_name;
    return;
end

names = fieldnames(loaded);
for idx = 1:numel(names)
    candidate = loaded.(names{idx});
    [ocv_data, ocv_kind] = detectOcvStruct(candidate);
    if ~isempty(ocv_kind)
        source_name = names{idx};
        return;
    end
end

error('plotOcvCurves:MissingOcvStruct', ...
    'Could not find a supported OCV struct in %s.', ocv_path);
end

function [ocv_data, ocv_kind, source_name] = extractOcvStruct(input_struct, preferred_name)
if ~isempty(preferred_name) && isfield(input_struct, preferred_name)
    [ocv_data, ocv_kind] = detectOcvStruct(input_struct.(preferred_name));
    if ~isempty(ocv_kind)
        source_name = preferred_name;
        return;
    end
end

[ocv_data, ocv_kind] = detectOcvStruct(input_struct);
if ~isempty(ocv_kind)
    if isfield(input_struct, 'name') && ~isempty(input_struct.name)
        source_name = char(input_struct.name);
    else
        source_name = 'OCV';
    end
    return;
end

names = fieldnames(input_struct);
for idx = 1:numel(names)
    candidate = input_struct.(names{idx});
    [ocv_data, ocv_kind] = detectOcvStruct(candidate);
    if ~isempty(ocv_kind)
        source_name = names{idx};
        return;
    end
end

error('plotOcvCurves:UnsupportedStruct', ...
    'Input struct does not match a supported OCV format.');
end

function [ocv_data, ocv_kind] = detectOcvStruct(candidate)
ocv_data = [];
ocv_kind = '';

if ~isstruct(candidate) || isempty(candidate)
    return;
end

if isfield(candidate, 'cha') && isfield(candidate, 'dch') && ...
        isstruct(candidate.cha) && isstruct(candidate.dch) && ...
        isfield(candidate.cha, 'SOC') && isfield(candidate.cha, 'volt') && ...
        isfield(candidate.dch, 'SOC') && isfield(candidate.dch, 'volt')
    ocv_data = candidate;
    ocv_kind = 'interp';
    return;
end

if isfield(candidate, 'SOC') && isfield(candidate, 'OCV0') && isfield(candidate, 'OCVrel')
    ocv_data = candidate;
    ocv_kind = 'model';
end
end

function plotInterpCurves(ocv_interp, source_name, cfg)
soc_pct = toSocPercent(ocv_interp.cha.SOC);
cha_v = double(ocv_interp.cha.volt(:));
dch_v = double(ocv_interp.dch.volt(:));

plot(soc_pct, cha_v, 'LineWidth', 1.6, 'DisplayName', 'Charge');
hold on;
plot(soc_pct, dch_v, 'LineWidth', 1.6, 'DisplayName', 'Discharge');
if cfg.show_midpoint
    plot(soc_pct, 0.5 * (cha_v + dch_v), '--', 'LineWidth', 1.2, ...
        'DisplayName', 'Midpoint');
end
grid on;
xlabel('SOC [%]');
ylabel('Voltage [V]');
title(sprintf('%sOCV Curves', buildTitlePrefix(source_name, cfg)));
legend('Location', 'best');
end

function plotModelCurves(model, source_name, cfg)
soc_pct = toSocPercent(model.SOC);
plot_temps = selectModelTemps(model, cfg.temps);

hold on;
for idx = 1:numel(plot_temps)
    temp_degC = plot_temps(idx);
    ocv_curve = double(model.OCV0(:)) + temp_degC * double(model.OCVrel(:));
    plot(soc_pct, ocv_curve, 'LineWidth', 1.6, ...
        'DisplayName', sprintf('OCV @ %.1f degC', temp_degC));
end
grid on;
xlabel('SOC [%]');
ylabel('OCV [V]');
title(sprintf('%sOCV Model Curves', buildTitlePrefix(source_name, cfg)));
legend('Location', 'best');
end

function temps = selectModelTemps(model, cfg_temps)
if ~isempty(cfg_temps)
    temps = cfg_temps(:).';
    return;
end

if isfield(model, 'temps') && ~isempty(model.temps)
    temps = double(model.temps(:)).';
    return;
end

temps = 25;
end

function soc_pct = toSocPercent(soc_data)
soc_vec = double(soc_data(:));
if isempty(soc_vec)
    soc_pct = soc_vec;
elseif max(abs(soc_vec)) <= 1.5
    soc_pct = 100 * soc_vec;
else
    soc_pct = soc_vec;
end
end

function fig_name = buildFigureName(source_name, cfg)
if ~isempty(cfg.figure_name)
    fig_name = cfg.figure_name;
elseif ~isempty(source_name)
    fig_name = sprintf('%s - OCV', source_name);
else
    fig_name = 'OCV Curves';
end
end

function prefix = buildTitlePrefix(source_name, cfg)
if ~isempty(cfg.title_prefix)
    prefix = [cfg.title_prefix ' '];
elseif ~isempty(source_name)
    prefix = [char(source_name) ' '];
else
    prefix = '';
end
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end

function fallback_path = resolveLegacyOcvPath(ocv_path)
fallback_path = '';

legacy_prefix = fullfile('ESC_Id', 'OCV_Files');
if ~startsWith(ocv_path, legacy_prefix, 'IgnoreCase', true)
    return;
end

relative_suffix = extractAfter(ocv_path, strlength(legacy_prefix));
relative_suffix = char(relative_suffix);
while ~isempty(relative_suffix) && any(relative_suffix(1) == ['\' '/'])
    relative_suffix(1) = [];
end

candidate_path = fullfile('data', 'Modelling', 'OCV_Files', relative_suffix);
if exist(candidate_path, 'file') == 2
    fallback_path = candidate_path;
end
end
