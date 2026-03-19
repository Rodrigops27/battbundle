function plotRomValidation(validation)
% plotRomValidation Plot ROM validation results
%
% Usage:
%   plotRomValidation(validation)
%
% Input:
%   validation  Struct output from retuningROMVal()
%
% Description:
%   Creates two figures with comprehensive validation plots:
%   1. Current and SOC overlay with error traces
%   2. Voltage overlay with correlation scatter plot
%
% Example:
%   Load and plot previous results:
%     load('ROM_validation_results.mat');
%     plotRomValidation(result_atl);

if nargin < 1 || isempty(validation)
    error('plotRomValidation:MissingInput', 'validation struct required');
end

if ~isstruct(validation) || ~isfield(validation, 'time_s')
    error('plotRomValidation:InvalidInput', ...
        'Input must be a validation struct with time_s field');
end

t = validation.time_s(:);
plot_title = buildRomPlotTitle(validation);
profile_label = normalizeRomProfileLabel(validation);
series_label = strtrim(regexprep(sprintf('%s %s', normalizeRomModelLabel(validation), profile_label), '\s+', ' '));

% Figure 1: Current and SOC
figure('Name', sprintf('%s | Current & SOC', series_label), 'NumberTitle', 'off');
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(t, validation.current_a, 'k-', 'LineWidth', 1.3);
grid on;
xlabel('Time [s]');
ylabel('Current [A]');
title(sprintf('%s Current Profile', series_label));

nexttile;
plot(t, 100 * validation.esc_soc, 'k-', 'LineWidth', 1.5, 'DisplayName', 'ESC Model SOC');
hold on;
plot(t, 100 * validation.rom_soc, 'r--', 'LineWidth', 1.3, 'DisplayName', 'ROM SOC');
grid on;
xlabel('Time [s]');
ylabel('SOC [%]');
title(sprintf('SOC Overlay (RMSE %.3f%%)', 100 * validation.soc_rmse));
legend('Location', 'best');

nexttile;
plot(t, 100 * validation.soc_error, 'b-', 'LineWidth', 1.2);
grid on;
xlabel('Time [s]');
ylabel('SOC Error [%]');
title(sprintf('SOC Error: ESC - ROM (Mean Error %.3f%%)', 100 * validation.soc_me));

% Figure 2: Voltage Analysis
figure('Name', plot_title, 'NumberTitle', 'off');
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(t, validation.esc_voltage_v, 'k-', 'LineWidth', 1.5, 'DisplayName', 'ESC Model Voltage');
hold on;
plot(t, validation.rom_voltage_v, 'r--', 'LineWidth', 1.3, 'DisplayName', 'ROM Voltage');
grid on;
xlabel('Time [s]');
ylabel('Voltage [V]');
title(plot_title);
legend('Location', 'best');

nexttile;
plot(t, 1000 * validation.voltage_error_v, 'b-', 'LineWidth', 1.2);
grid on;
xlabel('Time [s]');
ylabel('Voltage Error [mV]');
title(sprintf('Voltage Error: ESC - ROM (Mean Error %.2f mV)', 1000 * validation.voltage_me_v));

nexttile;
valid_voltage = isfinite(validation.esc_voltage_v) & isfinite(validation.rom_voltage_v);
if any(valid_voltage)
    scatter(validation.esc_voltage_v(valid_voltage), validation.rom_voltage_v(valid_voltage), ...
        10, t(valid_voltage), 'filled');
    hold on;
    v_min = min([validation.esc_voltage_v(valid_voltage); validation.rom_voltage_v(valid_voltage)]);
    v_max = max([validation.esc_voltage_v(valid_voltage); validation.rom_voltage_v(valid_voltage)]);
    plot([v_min, v_max], [v_min, v_max], 'k--', 'LineWidth', 1.0, 'DisplayName', 'Unity line');
    if all(isfinite(validation.voltage_fit))
        fit_x = linspace(v_min, v_max, 100);
        fit_y = polyval(validation.voltage_fit, fit_x);
        plot(fit_x, fit_y, 'r-', 'LineWidth', 1.1, 'DisplayName', 'Linear fit');
    end
    grid on;
    xlabel('ESC Model Voltage [V]');
    ylabel('ROM Voltage [V]');
    title(sprintf('Voltage Correlation (R = %.4f)', validation.voltage_corr));
    cb = colorbar;
    cb.Label.String = 'Time [s]';
    legend('Location', 'best');
else
    text(0.1, 0.5, 'No finite voltage pairs available', 'Units', 'normalized');
    axis off;
end
end

function plot_title = buildRomPlotTitle(validation)
model_label = normalizeRomModelLabel(validation);
dataset_label = normalizeRomProfileLabel(validation);
plot_title = sprintf('%s %s | RMSE %.2f mV', model_label, dataset_label, 1000 * validation.voltage_rmse_v);
plot_title = strtrim(regexprep(plot_title, '\s+', ' '));
end

function model_label = normalizeRomModelLabel(validation)
model_label = '';
if isfield(validation, 'rom_file') && ~isempty(validation.rom_file)
    model_label = cleanupLabel(validation.rom_file);
elseif isfield(validation, 'rom_name') && ~isempty(validation.rom_name)
    model_label = cleanupLabel(validation.rom_name);
end
label_upper = upper(model_label);
if contains(label_upper, 'OMTLIFE') || contains(label_upper, 'OMT8')
    model_label = 'OMT8';
elseif contains(label_upper, 'ATL20')
    model_label = 'ATL20';
elseif contains(label_upper, 'ATL')
    model_label = 'ATL';
elseif contains(label_upper, 'NMC30')
    model_label = 'NMC30';
end
if isempty(model_label)
    model_label = 'ROM';
end
end

function dataset_label = normalizeRomProfileLabel(validation)
search_text = lower(strjoin({charOrEmpty(fieldOr(validation, 'name', '')), charOrEmpty(fieldOr(validation, 'profile_name', ''))}, ' '));
if contains(search_text, 'bus_corebattery') || contains(search_text, 'bus corebattery') || ...
        contains(search_text, 'bus core battery') || contains(search_text, 'bss')
    dataset_label = 'BSS';
else
    dataset_label = 'Dyn';
end
end

function value = fieldOr(s, field_name, default_value)
if isstruct(s) && isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end

function label = cleanupLabel(raw_label)
label = charOrEmpty(raw_label);
[~, label, ~] = fileparts(label);
label = strrep(label, 'ROM_', '');
label = strrep(label, 'model', '');
label = strrep(label, 'Model', '');
label = strrep(label, '_beta', '');
label = strrep(label, '_', ' ');
label = strtrim(regexprep(label, '\s+', ' '));
end

function out = charOrEmpty(value)
if isempty(value)
    out = '';
elseif isstring(value)
    out = char(value);
else
    out = value;
end
end
