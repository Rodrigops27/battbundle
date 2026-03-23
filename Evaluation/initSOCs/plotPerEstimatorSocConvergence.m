function fig_handles = plotPerEstimatorSocConvergence(all_results, soc0_sweep_percent, estimator_names)
% plotPerEstimatorSocConvergence Plot per-estimator SOC traces across initial-SOC settings.

reference = all_results{1}.dataset.reference_soc;
time_s = all_results{1}.dataset.time_s;
palette = parula(max(numel(soc0_sweep_percent), 2));
fig_handles = gobjects(numel(estimator_names), 1);

for est_idx = 1:numel(estimator_names)
    fig_handles(est_idx) = figure( ...
        'Name', sprintf('SOC Estimation - %s', estimator_names{est_idx}), ...
        'NumberTitle', 'off');
    plot(time_s, 100 * reference, 'k-', 'LineWidth', 2.5, 'DisplayName', 'Reference');
    hold on;
    for sweep_idx = 1:numel(all_results)
        est = all_results{sweep_idx}.estimators(est_idx);
        plot(time_s, 100 * est.soc, '-', ...
            'Color', palette(sweep_idx, :), ...
            'LineWidth', 1.2, ...
            'DisplayName', sprintf('SOC0=%.2f%%', soc0_sweep_percent(sweep_idx)));
    end
    grid on;
    xlabel('Time [s]');
    ylabel('SOC [%]');
    title(sprintf('SOC Estimation Convergence - %s', estimator_names{est_idx}));
    legend('Location', 'best');
end
end
