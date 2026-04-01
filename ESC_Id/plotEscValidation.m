function plotEscValidation(results)
% plotEscValidation Plot ESC model validation results
%
% Usage:
%   plotEscValidation(results)
%
% Input:
%   results  Struct output from ESCvalidation()
%
% Description:
%   Creates figures for each validation case showing:
%   1. Measured vs. simulated voltage with RMSE
%   2. Current profile
%   3. Voltage error trace
%
% Example:
%   Load and plot previous results:
%     load(fullfile('data', 'modelling', 'derived', 'validation_results', 'esc', 'ESC_validation_results.mat'));
%     plotEscValidation(result_atl);

if nargin < 1 || isempty(results)
    error('plotEscValidation:MissingInput', 'results struct required');
end

if ~isstruct(results) || ~isfield(results, 'cases')
    error('plotEscValidation:InvalidInput', ...
        'Input must be a results struct from ESCvalidation() with cases field');
end

for idx = 1:numel(results.cases)
    case_result = results.cases(idx);
    t = case_result.time_s(:);
    plot_title = buildEscPlotTitle(results, case_result);
    
    figure('Name', plot_title, 'Color', 'w');
    tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    % Voltage overlay plot
    nexttile
    plot(t, case_result.voltage_v, 'k', 'LineWidth', 1.0); 
    hold on
    plot(t, case_result.voltage_est_v, 'LineWidth', 1.0);
    ylabel('Voltage (V)');
    title(plot_title);
    legend('Measured', 'simCell', 'Location', 'best');
    grid on

    % Current plot
    nexttile
    plot(t, case_result.current_a, 'LineWidth', 1.0);
    ylabel('Current (A)');
    grid on

    % Error plot
    nexttile
    plot(t, 1000 * case_result.voltage_error_v, 'LineWidth', 1.0);
    xlabel('Time (s)');
    ylabel('Error (mV)');
    grid on

    % Voltage correlation scatter plot
    nexttile
    valid_voltage = isfinite(case_result.voltage_v) & isfinite(case_result.voltage_est_v);
    if any(valid_voltage)
        scatter(case_result.voltage_v(valid_voltage), case_result.voltage_est_v(valid_voltage), ...
            10, t(valid_voltage), 'filled');
        hold on;
        v_min = min([case_result.voltage_v(valid_voltage); case_result.voltage_est_v(valid_voltage)]);
        v_max = max([case_result.voltage_v(valid_voltage); case_result.voltage_est_v(valid_voltage)]);
        plot([v_min, v_max], [v_min, v_max], 'k--', 'LineWidth', 1.0, 'DisplayName', 'Unity line');
        if all(isfinite(case_result.metrics.voltage_fit))
            fit_x = linspace(v_min, v_max, 100);
            fit_y = polyval(case_result.metrics.voltage_fit, fit_x);
            plot(fit_x, fit_y, 'r-', 'LineWidth', 1.1, 'DisplayName', 'Linear fit');
        end
        grid on;
        xlabel('Measured Voltage (V)');
        ylabel('Simulated Voltage (V)');
        title(sprintf('Voltage Correlation (R = %.4f)', case_result.metrics.voltage_corr));
        cb = colorbar;
        cb.Label.String = 'Time (s)';
        legend('Location', 'best');
    else
        text(0.1, 0.5, 'No finite voltage pairs available', 'Units', 'normalized');
        axis off;
    end
end
end

function plot_title = buildEscPlotTitle(results, case_result)
model_label = normalizeEscModelLabel(results, case_result);
dataset_label = normalizeDatasetLabel(case_result.name, case_result.source_file, case_result.source_type);
plot_title = sprintf('%s %s | RMSE %.2f mV', model_label, dataset_label, case_result.metrics.voltage_rmse_mv);
plot_title = strtrim(regexprep(plot_title, '\s+', ' '));
end

function model_label = normalizeEscModelLabel(results, case_result)
model_label = '';
if isfield(case_result, 'model_name') && ~isempty(case_result.model_name)
    model_label = normalizeModelToken(case_result.model_name);
end
if isempty(model_label) && isfield(results, 'model_name') && ~isempty(results.model_name)
    model_label = normalizeModelToken(results.model_name);
end
if isempty(model_label)
    model_label = 'ESC';
end
end

function dataset_label = normalizeDatasetLabel(case_name, source_file, source_type)
search_text = lower(strjoin({charOrEmpty(case_name), charOrEmpty(source_file), charOrEmpty(source_type)}, ' '));
if contains(search_text, 'legacy_script1') || contains(search_text, 'script1') || contains(search_text, 'dyn')
    dataset_label = 'Dyn';
elseif contains(search_text, 'bus_corebattery') || contains(search_text, 'bus corebattery') || ...
        contains(search_text, 'bus core battery') || contains(search_text, 'bss')
    dataset_label = 'BSS';
else
    dataset_label = cleanupLabel(case_name);
end
end

function label = normalizeModelToken(raw_label)
label = cleanupLabel(raw_label);
label_upper = upper(label);
if contains(label_upper, 'OMTLIFE') || contains(label_upper, 'OMT8')
    label = 'OMT8';
elseif contains(label_upper, 'ATL20')
    label = 'ATL20';
elseif contains(label_upper, 'ATL')
    label = 'ATL';
elseif contains(label_upper, 'NMC30')
    label = 'NMC30';
elseif startsWith(label_upper, 'ROM ')
    label = strtrim(extractAfter(label, 4));
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
