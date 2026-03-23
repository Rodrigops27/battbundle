function fig_handles = plotPerEstimatorVoltageConvergence(all_results, soc0_sweep_percent, estimator_names)
% plotPerEstimatorVoltageConvergence Plot per-estimator voltage traces across initial-SOC settings.

voltage_ref = all_results{1}.dataset.voltage_v;
voltage_name = all_results{1}.dataset.voltage_name;
time_s = all_results{1}.dataset.time_s;
palette = parula(max(numel(soc0_sweep_percent), 2));
fig_handles = gobjects(numel(estimator_names), 1);

for est_idx = 1:numel(estimator_names)
    fig_handles(est_idx) = figure( ...
        'Name', sprintf('Voltage Estimation - %s', estimator_names{est_idx}), ...
        'NumberTitle', 'off');
    plot(time_s, voltage_ref, 'k-', 'LineWidth', 2.5, 'DisplayName', voltage_name);
    hold on;
    for sweep_idx = 1:numel(all_results)
        est = all_results{sweep_idx}.estimators(est_idx);
        plot(time_s, est.voltage, '-', ...
            'Color', palette(sweep_idx, :), ...
            'LineWidth', 1.2, ...
            'DisplayName', sprintf('SOC0=%.2f%%', soc0_sweep_percent(sweep_idx)));
    end
    grid on;
    xlabel('Time [s]');
    ylabel('Voltage [V]');
    title(sprintf('Voltage Estimation Convergence - %s', estimator_names{est_idx}));
    legend('Location', 'best');
end
end
