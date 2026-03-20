function diagnosis = plotEaEkfCovarianceSweeps(sweepResults)
% plotEaEkfCovarianceSweeps Plot final EaEKF SigmaW and SigmaV across a sweep.
%
% The figures focus on 2D curve comparisons rather than heat maps:
%   - for 1D sweeps, final estimated covariances are plotted against the
%     swept axis;
%   - for 2D grid sweeps, families of curves are shown so each line can be
%     interpreted like an initial-condition comparison, with the legend
%     reporting the held-constant value of the other sweep axis.
%
% The helper also assigns a formal diagnosis to the final covariance
% response:
%   - convergent adaptive covariance estimation
%   - initialization-dominated covariance scaling

if isWrapperBothResult(sweepResults)
    diagnosis = struct();
    diagnosis.sigma_w_sweep = plotEaEkfCovarianceSweeps(sweepResults.sigma_w_sweep);
    diagnosis.sigma_v_sweep = plotEaEkfCovarianceSweeps(sweepResults.sigma_v_sweep);
    return;
end

ea_idx = find(strcmp(sweepResults.estimator_names, 'EaEKF'), 1, 'first');
if isempty(ea_idx)
    warning('plotEaEkfCovarianceSweeps:MissingEaEKF', ...
        'EaEKF was not found in the sweep results.');
    diagnosis = struct();
    return;
end

[process_diag, sensor_noise] = extractEaEkfCovariances(sweepResults, ea_idx);
if isempty(process_diag) || isempty(sensor_noise)
    warning('plotEaEkfCovarianceSweeps:MissingEaEKFCovariance', ...
        'EaEKF final SigmaW/SigmaV were not available in the sweep results.');
    diagnosis = struct();
    return;
end

sigma_w_values = sweepResults.sigma_w_values(:);
sigma_v_values = sweepResults.sigma_v_values(:);
n_states = size(process_diag, 3);
diagnosis = buildCovarianceDiagnosis(sigma_w_values, sigma_v_values, process_diag, sensor_noise);

if numel(sigma_w_values) > 1 && numel(sigma_v_values) > 1
    plotGridProcessVsSigmaW(sigma_w_values, sigma_v_values, process_diag, n_states, diagnosis.process_sigma_w);
    plotGridProcessVsSigmaV(sigma_w_values, sigma_v_values, process_diag, n_states, diagnosis.process_sigma_w);
    plotGridSensorVsSigmaV(sigma_w_values, sigma_v_values, sensor_noise, diagnosis.sensor_sigma_v);
    plotGridSensorVsSigmaW(sigma_w_values, sigma_v_values, sensor_noise, diagnosis.sensor_sigma_v);
else
    swept_values = sigma_w_values;
    swept_label = '\sigma_w';
    process_diag_summary = diagnosis.process_sigma_w;
    sensor_diag_summary = diagnosis.sensor_sigma_v;
    if numel(sigma_v_values) > 1
        swept_values = sigma_v_values;
        swept_label = '\sigma_v';
    end

    figure('Name', 'EaEKF Estimated Process Noise', 'NumberTitle', 'off');
    tiledlayout(n_states, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    for state_idx = 1:n_states
        nexttile;
        semilogx(swept_values, extractLine(process_diag(:, :, state_idx)), '-o', 'LineWidth', 1.3);
        grid on;
        xlabel(sprintf('Input %s', swept_label));
        ylabel('Estimated \Sigma_W');
        title({ ...
            sprintf('EaEKF Final Process Noise Q(%d,%d)', state_idx, state_idx), ...
            process_diag_summary(state_idx).summary});
    end

    figure('Name', 'EaEKF Estimated Sensor Noise', 'NumberTitle', 'off');
    semilogx(swept_values, extractLine(sensor_noise), '-o', 'LineWidth', 1.3);
    grid on;
    xlabel(sprintf('Input %s', swept_label));
    ylabel('Estimated \Sigma_V / R');
    title({'EaEKF Final Sensor Noise R', sensor_diag_summary.summary});
end
end

function plotGridProcessVsSigmaW(sigma_w_values, sigma_v_values, process_diag, n_states, diagnosis)
palette = lines(numel(sigma_v_values));

figure('Name', 'EaEKF Estimated Process Noise vs SigmaW', 'NumberTitle', 'off');
tiledlayout(n_states, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for state_idx = 1:n_states
    nexttile;
    hold on;
    for v_idx = 1:numel(sigma_v_values)
        semilogx(sigma_w_values, squeeze(process_diag(:, v_idx, state_idx)), '-o', ...
            'LineWidth', 1.3, ...
            'Color', palette(v_idx, :), ...
            'DisplayName', sprintf('fixed \\sigma_v = %.3g', sigma_v_values(v_idx)));
    end
    semilogx(sigma_w_values, sigma_w_values, 'k--', 'LineWidth', 1.0, ...
        'DisplayName', 'input \sigma_w');
    grid on;
    xlabel('Input \sigma_w');
    ylabel('Estimated \Sigma_W');
    title({ ...
        sprintf('EaEKF Final Process Noise Q(%d,%d) vs \sigma_w', state_idx, state_idx), ...
        diagnosis(state_idx).summary});
    if state_idx == 1
        legend('Location', 'best');
    end
end
end

function plotGridProcessVsSigmaV(sigma_w_values, sigma_v_values, process_diag, n_states, diagnosis)
palette = lines(numel(sigma_w_values));

figure('Name', 'EaEKF Estimated Process Noise vs SigmaV', 'NumberTitle', 'off');
tiledlayout(n_states, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for state_idx = 1:n_states
    nexttile;
    hold on;
    for w_idx = 1:numel(sigma_w_values)
        semilogx(sigma_v_values, squeeze(process_diag(w_idx, :, state_idx)), '-o', ...
            'LineWidth', 1.3, ...
            'Color', palette(w_idx, :), ...
            'DisplayName', sprintf('fixed \\sigma_w = %.3g', sigma_w_values(w_idx)));
    end
    grid on;
    xlabel('Input \sigma_v');
    ylabel('Estimated \Sigma_W');
    title({ ...
        sprintf('EaEKF Final Process Noise Q(%d,%d) vs \sigma_v', state_idx, state_idx), ...
        diagnosis(state_idx).summary});
    if state_idx == 1
        legend('Location', 'best');
    end
end
end

function plotGridSensorVsSigmaV(sigma_w_values, sigma_v_values, sensor_noise, diagnosis)
palette = lines(numel(sigma_w_values));

figure('Name', 'EaEKF Estimated Sensor Noise vs SigmaV', 'NumberTitle', 'off');
hold on;
for w_idx = 1:numel(sigma_w_values)
    semilogx(sigma_v_values, sensor_noise(w_idx, :), '-o', ...
        'LineWidth', 1.3, ...
        'Color', palette(w_idx, :), ...
        'DisplayName', sprintf('fixed \\sigma_w = %.3g', sigma_w_values(w_idx)));
end
semilogx(sigma_v_values, sigma_v_values, 'k--', 'LineWidth', 1.0, ...
    'DisplayName', 'input \sigma_v');
grid on;
xlabel('Input \sigma_v');
ylabel('Estimated \Sigma_V / R');
title({'EaEKF Final Sensor Noise R vs \sigma_v', diagnosis.summary});
legend('Location', 'best');
end

function plotGridSensorVsSigmaW(sigma_w_values, sigma_v_values, sensor_noise, diagnosis)
palette = lines(numel(sigma_v_values));

figure('Name', 'EaEKF Estimated Sensor Noise vs SigmaW', 'NumberTitle', 'off');
hold on;
for v_idx = 1:numel(sigma_v_values)
    semilogx(sigma_w_values, sensor_noise(:, v_idx), '-o', ...
        'LineWidth', 1.3, ...
        'Color', palette(v_idx, :), ...
        'DisplayName', sprintf('fixed \\sigma_v = %.3g', sigma_v_values(v_idx)));
end
grid on;
xlabel('Input \sigma_w');
ylabel('Estimated \Sigma_V / R');
title({'EaEKF Final Sensor Noise R vs \sigma_w', diagnosis.summary});
legend('Location', 'best');
end

function diagnosis = buildCovarianceDiagnosis(sigma_w_values, sigma_v_values, process_diag, sensor_noise)
n_states = size(process_diag, 3);
process_sigma_w = repmat(struct('label', '', 'summary', '', 'slope', NaN, ...
    'range_ratio', NaN, 'confidence', NaN), n_states, 1);
for state_idx = 1:n_states
    init_grid = repmat(log10(sigma_w_values(:)), 1, numel(sigma_v_values));
    process_sigma_w(state_idx) = diagnoseResponse(process_diag(:, :, state_idx), init_grid);
end

sensor_init_grid = repmat(log10(sigma_v_values(:)).', numel(sigma_w_values), 1);
sensor_sigma_v = diagnoseResponse(sensor_noise, sensor_init_grid);

diagnosis = struct();
diagnosis.process_sigma_w = process_sigma_w;
diagnosis.sensor_sigma_v = sensor_sigma_v;
end

function diag_result = diagnoseResponse(value_grid, init_log_grid)
diag_result = struct();
diag_result.label = 'diagnosis unavailable';
diag_result.summary = 'Diagnosis unavailable';
diag_result.slope = NaN;
diag_result.range_ratio = NaN;
diag_result.confidence = NaN;

valid = isfinite(value_grid) & value_grid > 0 & isfinite(init_log_grid);
if nnz(valid) < 3
    return;
end

x = init_log_grid(valid);
y = log10(value_grid(valid));
if range(x) <= eps
    return;
end

slope = sum((x - mean(x)) .* (y - mean(y))) / sum((x - mean(x)).^2);
range_ratio = range(y) / max(range(x), eps);

dist_convergent = hypot(slope, range_ratio);
dist_initialization = hypot(slope - 1, range_ratio - 1);
if dist_convergent <= dist_initialization
    label = 'convergent adaptive covariance estimation';
    best_dist = dist_convergent;
    other_dist = dist_initialization;
else
    label = 'initialization-dominated covariance scaling';
    best_dist = dist_initialization;
    other_dist = dist_convergent;
end

confidence = max(0, min(1, (other_dist - best_dist) / max(other_dist + best_dist, eps)));

diag_result.label = label;
diag_result.summary = sprintf('%s | slope = %.2f, range ratio = %.2f, confidence = %.2f', ...
    label, slope, range_ratio, confidence);
diag_result.slope = slope;
diag_result.range_ratio = range_ratio;
diag_result.confidence = confidence;
end

function [process_diag, sensor_noise] = extractEaEkfCovariances(sweepResults, ea_idx)
n_w = numel(sweepResults.sigma_w_values);
n_v = numel(sweepResults.sigma_v_values);
process_diag = [];
sensor_noise = NaN(n_w, n_v);

for w_idx = 1:n_w
    for v_idx = 1:n_v
        run_results = sweepResults.all_results{w_idx, v_idx};
        if isempty(run_results) || numel(run_results.estimators) < ea_idx
            continue;
        end

        kfData = run_results.estimators(ea_idx).kfDataFinal;
        if ~isstruct(kfData)
            continue;
        end

        q_diag = extractCovarianceDiagonal(kfData, 'SigmaW');
        if isempty(q_diag)
            continue;
        end
        if isempty(process_diag)
            process_diag = NaN(n_w, n_v, numel(q_diag));
        end
        process_diag(w_idx, v_idx, :) = q_diag(:);

        r_diag = extractCovarianceDiagonal(kfData, 'SigmaV');
        if ~isempty(r_diag)
            sensor_noise(w_idx, v_idx) = r_diag(1);
        end
    end
end
end

function diag_values = extractCovarianceDiagonal(kfData, field_name)
diag_values = [];
if ~isfield(kfData, field_name) || isempty(kfData.(field_name))
    return;
end

cov_value = kfData.(field_name);
if isscalar(cov_value)
    diag_values = double(cov_value);
elseif isvector(cov_value)
    diag_values = double(cov_value(:));
elseif ismatrix(cov_value)
    diag_values = double(diag(cov_value));
end
end

function labels = formatTickLabels(values)
labels = arrayfun(@(x) sprintf('%.3g', x), values, 'UniformOutput', false);
end

function line_values = extractLine(values)
if isvector(values)
    line_values = values(:);
elseif size(values, 1) == 1
    line_values = values(:);
else
    line_values = values(:, 1);
end
end

function tf = isWrapperBothResult(sweepResults)
tf = isstruct(sweepResults) && isfield(sweepResults, 'mode') && ...
    strcmpi(char(sweepResults.mode), 'both') && ...
    isfield(sweepResults, 'sigma_w_sweep') && isfield(sweepResults, 'sigma_v_sweep');
end
