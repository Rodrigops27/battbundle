function fig_handles = plotAutotuningHistory(resultsInput)
% plotAutotuningHistory Plot objective and covariance traces from autotuning output.

data = loadAutotuningData(resultsInput);
fig_handles = gobjects(numel(data.runs), 1);

for idx = 1:numel(data.runs)
    run = data.runs(idx);
    history_table = fieldOr(run, 'history_table', table());
    if isempty(history_table) || height(history_table) == 0
        continue;
    end

    fig_handles(idx) = figure( ...
        'Name', sprintf('Autotuning History - %s - %s', run.scenario_name, run.estimator_name), ...
        'NumberTitle', 'off');

    tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    hold on;
    plot(history_table.Evaluation, history_table.Objective, 'o-', 'LineWidth', 1.2, ...
        'DisplayName', 'Objective');
    plot(history_table.Evaluation, history_table.BestObjective, '-', 'LineWidth', 1.5, ...
        'DisplayName', 'Best So Far');
    grid on;
    xlabel('Evaluation');
    ylabel(run.objective_metric);
    title(sprintf('%s | %s Objective', run.scenario_name, run.estimator_name), 'Interpreter', 'none');
    legend('Location', 'best');

    nexttile;
    semilogy(history_table.Evaluation, history_table.ProcessNoise, 'o-', 'LineWidth', 1.2);
    grid on;
    xlabel('Evaluation');
    ylabel(run.process_noise_field);
    title('Process Noise', 'Interpreter', 'none');

    nexttile;
    semilogy(history_table.Evaluation, history_table.SensorNoise, 'o-', 'LineWidth', 1.2);
    grid on;
    xlabel('Evaluation');
    ylabel(run.sensor_noise_field);
    title('Sensor Noise', 'Interpreter', 'none');
end
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end
