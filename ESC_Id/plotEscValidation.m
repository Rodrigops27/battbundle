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
%     load('ESC_validation_results.mat');
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
    
    figure('Name', sprintf('ESCvalidation - %s', case_result.name), 'Color', 'w');
    tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    % Voltage overlay plot
    nexttile
    plot(t, case_result.voltage_v, 'k', 'LineWidth', 1.0); 
    hold on
    plot(t, case_result.voltage_est_v, 'LineWidth', 1.0);
    ylabel('Voltage (V)');
    title(sprintf('%s | RMSE %.2f mV', case_result.name, case_result.metrics.voltage_rmse_mv));
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
