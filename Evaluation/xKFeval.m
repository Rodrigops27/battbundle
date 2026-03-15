function results = xKFeval(dataset, estimators, flags)
% xKFeval Generic evaluation runner for KF-based cell estimators.
%
% Inputs
%   dataset.current_a          Required current trace, +I = discharge.
%   dataset.voltage_v          Required voltage trace.
%   dataset.time_s             Optional time vector. Default: 0,1,2,...
%   dataset.temperature_c      Optional temperature trace. Default: 25 degC.
%   dataset.reference_soc      Optional reference SOC trace in [0,1].
%   dataset.soc_init_reference Optional initial SOC [%] for Coulomb counting.
%   dataset.capacity_ah        Required when reference_soc is not supplied.
%   dataset.dataset_soc        Optional source SOC trace for plotting.
%   dataset.metric_soc         Optional SOC trace used for RMSE/ME metrics.
%   dataset.metric_voltage     Optional voltage trace used for RMSE/ME metrics.
%   dataset.reference_name     Optional label, default "Reference".
%   dataset.voltage_name       Optional label, default "Measured".
%   dataset.title_prefix       Optional figure title prefix.
%
%   estimators(k).name         Display name.
%   estimators(k).kfData       Initialized estimator state/data.
%   estimators(k).stepFcn      Handle returning standardized step output.
%   estimators(k).soc0_percent Optional initial SOC [%] for plotting.
%   estimators(k).color        Optional RGB triplet.
%   estimators(k).lineStyle    Optional line style.
%   estimators(k).bias_dim     Optional number of bias states.
%
%   flags.SOCfigs              Optional per-estimator SOC error figures.
%   flags.Vfigs                Optional per-estimator voltage error figures.
%   flags.InnovationACFPACFfigs Optional innovation ACF/PACF figure.
%   flags.R0figs               Optional R0 summary figure. Default true if available.
%   flags.Biasfigs             Optional bias summary figure. Default true if available.
%   flags.default_temperature_c Optional scalar, default 25.

dataset = normalizeDataset(dataset, flags);
flags = normalizeFlags(flags);
estimators = normalizeEstimators(estimators, dataset);

n_samples = numel(dataset.time_s);
n_estimators = numel(estimators);

for idx = 1:n_estimators
    est = estimators(idx);
    est_result = initializeEstimatorResult(est, dataset, n_samples);

    for k = 2:n_samples
        dt = dataset.delta_t_s(k-1);
        step = est.stepFcn(dataset.voltage_v(k), dataset.current_a(k), ...
            dataset.temperature_c(k), dt, est.kfData);
        est.kfData = step.kfData;

        est_result.soc(k) = clamp01(step.soc);
        est_result.voltage(k) = step.voltage;
        est_result.soc_bnd(k) = step.soc_bnd;
        est_result.voltage_bnd(k) = step.voltage_bnd;
        est_result.innovation_pre(k) = step.innovation_pre;
        est_result.sk(k) = step.sk;

        if est_result.has_r0
            est_result.r0(k) = step.r0;
            est_result.r0_bnd(k) = step.r0_bnd;
        end
        if est_result.has_bias
            est_result.bias(k, :) = reshape(step.bias, 1, []);
            est_result.bias_bnd(k, :) = reshape(step.bias_bnd, 1, []);
        end
    end

    est_result.error_soc = dataset.metric_soc - est_result.soc;
    est_result.error_voltage = dataset.metric_voltage - est_result.voltage;
    est_result.rmse_soc = sqrt(mean(est_result.error_soc(~isnan(est_result.error_soc)).^2));
    est_result.rmse_voltage = sqrt(mean(est_result.error_voltage(~isnan(est_result.error_voltage)).^2));
    est_result.me_soc = mean(est_result.error_soc(~isnan(est_result.error_soc)));
    est_result.me_voltage = mean(est_result.error_voltage(~isnan(est_result.error_voltage)));

    estimators(idx) = est;
    results.estimators(idx) = est_result; %#ok<AGROW>
end

results.dataset = dataset;
results.flags = flags;

if flags.Verbose
    printSummary(results);
    printDiagnostics(results);
end
if flags.Summaryfigs
    makeSummaryFigures(results);
end
makeOptionalFigures(results);
end

function dataset = normalizeDataset(dataset, flags)
required = {'current_a', 'voltage_v'};
for idx = 1:numel(required)
    if ~isfield(dataset, required{idx}) || isempty(dataset.(required{idx}))
        error('xKFeval:MissingDatasetField', 'Dataset.%s is required.', required{idx});
    end
end

dataset.current_a = dataset.current_a(:);
dataset.voltage_v = dataset.voltage_v(:);
n_samples = numel(dataset.current_a);
if numel(dataset.voltage_v) ~= n_samples
    error('xKFeval:LengthMismatch', 'Dataset current and voltage must have the same length.');
end

if ~isfield(dataset, 'time_s') || isempty(dataset.time_s)
    dataset.time_s = (0:n_samples-1).';
else
    dataset.time_s = dataset.time_s(:);
end
if numel(dataset.time_s) ~= n_samples
    error('xKFeval:TimeLengthMismatch', 'Dataset time vector length must match the signal length.');
end

if ~isfield(dataset, 'temperature_c') || isempty(dataset.temperature_c)
    dataset.temperature_c = getFlag(flags, 'default_temperature_c', 25) * ones(n_samples, 1);
else
    dataset.temperature_c = dataset.temperature_c(:);
    if numel(dataset.temperature_c) == 1
        dataset.temperature_c = dataset.temperature_c * ones(n_samples, 1);
    elseif numel(dataset.temperature_c) ~= n_samples
        error('xKFeval:TemperatureLengthMismatch', ...
            'Dataset temperature vector length must match the signal length.');
    end
end

if ~isfield(dataset, 'dataset_soc') || isempty(dataset.dataset_soc)
    dataset.dataset_soc = [];
else
    dataset.dataset_soc = dataset.dataset_soc(:);
end
if isfield(dataset, 'metric_soc') && ~isempty(dataset.metric_soc)
    dataset.metric_soc = dataset.metric_soc(:);
    if numel(dataset.metric_soc) ~= n_samples
        error('xKFeval:MetricSocLengthMismatch', ...
            'Dataset metric_soc length must match the signal length.');
    end
end
if isfield(dataset, 'metric_voltage') && ~isempty(dataset.metric_voltage)
    dataset.metric_voltage = dataset.metric_voltage(:);
    if numel(dataset.metric_voltage) ~= n_samples
        error('xKFeval:MetricVoltageLengthMismatch', ...
            'Dataset metric_voltage length must match the signal length.');
    end
end

if ~isfield(dataset, 'reference_name') || isempty(dataset.reference_name)
    dataset.reference_name = 'Reference';
end
if ~isfield(dataset, 'dataset_soc_name') || isempty(dataset.dataset_soc_name)
    dataset.dataset_soc_name = 'Dataset SOC';
end
if ~isfield(dataset, 'metric_soc_name') || isempty(dataset.metric_soc_name)
    dataset.metric_soc_name = dataset.dataset_soc_name;
end
if ~isfield(dataset, 'voltage_name') || isempty(dataset.voltage_name)
    dataset.voltage_name = 'Measured';
end
if ~isfield(dataset, 'metric_voltage_name') || isempty(dataset.metric_voltage_name)
    dataset.metric_voltage_name = 'Original Voltage';
end
if ~isfield(dataset, 'title_prefix')
    dataset.title_prefix = '';
end

dt = diff(dataset.time_s);
if isempty(dt)
    dt = 1;
end
dataset.delta_t_s = dt(:);

if isfield(dataset, 'reference_soc') && ~isempty(dataset.reference_soc)
    dataset.reference_soc = dataset.reference_soc(:);
    if numel(dataset.reference_soc) ~= n_samples
        error('xKFeval:ReferenceLengthMismatch', ...
            'Dataset reference_soc length must match the signal length.');
    end
else
    if ~isfield(dataset, 'soc_init_reference') || isempty(dataset.soc_init_reference)
        error('xKFeval:MissingReference', ...
            'Provide dataset.reference_soc or dataset.soc_init_reference + dataset.capacity_ah.');
    end
    if ~isfield(dataset, 'capacity_ah') || isempty(dataset.capacity_ah)
        error('xKFeval:MissingCapacity', ...
            'Provide dataset.capacity_ah when dataset.reference_soc is not supplied.');
    end
    dataset.reference_soc = NaN(n_samples, 1);
    dataset.reference_soc(1) = dataset.soc_init_reference / 100;
    for k = 2:n_samples
        dataset.reference_soc(k) = dataset.reference_soc(k-1) - ...
            (dataset.current_a(k-1) * dataset.delta_t_s(k-1)) / (3600 * dataset.capacity_ah);
        dataset.reference_soc(k) = clamp01(dataset.reference_soc(k));
    end
end

if ~isfield(dataset, 'metric_soc') || isempty(dataset.metric_soc)
    dataset.metric_soc = dataset.reference_soc;
    dataset.metric_soc_name = dataset.reference_name;
end
if ~isfield(dataset, 'metric_voltage') || isempty(dataset.metric_voltage)
    dataset.metric_voltage = dataset.voltage_v;
    dataset.metric_voltage_name = dataset.voltage_name;
end
end

function flags = normalizeFlags(flags)
if nargin < 1 || isempty(flags)
    flags = struct();
end
flags.SOCfigs = getFlag(flags, 'SOCfigs', false);
flags.Vfigs = getFlag(flags, 'Vfigs', false);
flags.Summaryfigs = getFlag(flags, 'Summaryfigs', true);
flags.InnovationACFPACFfigs = getFlag(flags, 'InnovationACFPACFfigs', true);
flags.R0figs = getFlag(flags, 'R0figs', true);
flags.Biasfigs = getFlag(flags, 'Biasfigs', true);
flags.default_temperature_c = getFlag(flags, 'default_temperature_c', 25);
flags.Verbose = getFlag(flags, 'Verbose', true);
end

function estimators = normalizeEstimators(estimators, dataset)
if isempty(estimators)
    error('xKFeval:NoEstimators', 'At least one estimator definition is required.');
end
palette = lines(numel(estimators));
style_cycle = {'-', '--', ':', '-.', '-'};

for idx = 1:numel(estimators)
    if ~isfield(estimators(idx), 'name') || isempty(estimators(idx).name)
        error('xKFeval:BadEstimator', 'Each estimator needs a name.');
    end
    if ~isfield(estimators(idx), 'kfData')
        error('xKFeval:BadEstimator', 'Estimator "%s" is missing kfData.', estimators(idx).name);
    end
    if ~isfield(estimators(idx), 'stepFcn') || isempty(estimators(idx).stepFcn)
        error('xKFeval:BadEstimator', 'Estimator "%s" is missing stepFcn.', estimators(idx).name);
    end
    if ~isfield(estimators(idx), 'soc0_percent') || isempty(estimators(idx).soc0_percent)
        estimators(idx).soc0_percent = 100 * dataset.reference_soc(1);
    end
    if ~isfield(estimators(idx), 'lineStyle') || isempty(estimators(idx).lineStyle)
        estimators(idx).lineStyle = style_cycle{1 + mod(idx-1, numel(style_cycle))};
    end
    if ~isfield(estimators(idx), 'color') || isempty(estimators(idx).color)
        estimators(idx).color = palette(idx, :);
    end
    if ~isfield(estimators(idx), 'bias_dim') || isempty(estimators(idx).bias_dim)
        estimators(idx).bias_dim = 0;
    end
end
end

function est_result = initializeEstimatorResult(estimator, dataset, n_samples)
est_result = struct();
est_result.name = estimator.name;
est_result.color = estimator.color;
est_result.lineStyle = estimator.lineStyle;
est_result.soc = NaN(n_samples, 1);
est_result.voltage = NaN(n_samples, 1);
est_result.soc_bnd = NaN(n_samples, 1);
est_result.voltage_bnd = NaN(n_samples, 1);
est_result.innovation_pre = NaN(n_samples, 1);
est_result.sk = NaN(n_samples, 1);
est_result.soc(1) = estimator.soc0_percent / 100;
est_result.voltage(1) = dataset.voltage_v(1);
est_result.r0 = NaN(n_samples, 1);
est_result.r0_bnd = NaN(n_samples, 1);
est_result.bias = NaN(n_samples, estimator.bias_dim);
est_result.bias_bnd = NaN(n_samples, estimator.bias_dim);

est_result.has_r0 = false;
if isfield(estimator, 'tracksR0') && estimator.tracksR0
    est_result.has_r0 = true;
end
if est_result.has_r0 && isfield(estimator, 'r0_init') && ~isempty(estimator.r0_init)
    est_result.r0(1) = estimator.r0_init;
end

est_result.has_bias = estimator.bias_dim > 0;
if est_result.has_bias
    if isfield(estimator, 'bias_init') && ~isempty(estimator.bias_init)
        est_result.bias(1, :) = reshape(estimator.bias_init, 1, []);
    end
    if isfield(estimator, 'bias_bnd_init') && ~isempty(estimator.bias_bnd_init)
        est_result.bias_bnd(1, :) = reshape(estimator.bias_bnd_init, 1, []);
    end
end
end

function printSummary(results)
fprintf('\n%s Results (SOC metrics vs %s, voltage metrics vs %s)\n', ...
    getTitlePrefix(results.dataset), ...
    results.dataset.metric_soc_name, ...
    results.dataset.metric_voltage_name);
for idx = 1:numel(results.estimators)
    est = results.estimators(idx);
    fprintf('  %-10s SOC RMSE = %.4f%%, SOC ME = %.4f%%, V RMSE = %.2f mV, V ME = %.2f mV\n', ...
        est.name, 100 * est.rmse_soc, 100 * est.me_soc, ...
        1000 * est.rmse_voltage, 1000 * est.me_voltage);
end
end

function printDiagnostics(results)
fprintf('\nBias / Innovation Diagnostics (error = metric trace - estimate):\n');
for idx = 1:numel(results.estimators)
    est = results.estimators(idx);
    printEstimatorBiasMetrics(est.name, est.error_soc, est.error_voltage, est.innovation_pre, est.sk);
end
end

function makeSummaryFigures(results)
dataset = results.dataset;
estimators = results.estimators;
t = dataset.time_s;

figure('Name', sprintf('%sCell Voltage', getTitlePrefix(dataset)), 'NumberTitle', 'off');
hold on;
if ~isempty(dataset.metric_voltage) && any(isfinite(dataset.metric_voltage))
    plot(t, dataset.metric_voltage, 'k-', 'LineWidth', 2.5, ...
        'DisplayName', dataset.metric_voltage_name);
end
plot(t, dataset.voltage_v, 'k--', 'LineWidth', 1.2, 'DisplayName', dataset.voltage_name);
for idx = 1:numel(estimators)
    est = estimators(idx);
    plot(t, est.voltage, 'LineStyle', est.lineStyle, 'Color', est.color, ...
        'LineWidth', 1.5, 'DisplayName', est.name);
end
grid on; xlabel('Time [s]'); ylabel('Voltage [V]');
title(sprintf('%sCell Voltage', getTitlePrefix(dataset)));
legend('Location', 'best');

figure('Name', sprintf('%sSOC Comparison', getTitlePrefix(dataset)), 'NumberTitle', 'off');
hold on;
if ~isempty(dataset.dataset_soc) && any(isfinite(dataset.dataset_soc))
    plot(t, 100 * dataset.dataset_soc, 'k-', 'LineWidth', 2.5, ...
        'DisplayName', dataset.dataset_soc_name);
end
plot(t, 100 * dataset.reference_soc, 'k--', 'LineWidth', 1.2, ...
    'DisplayName', dataset.reference_name);
for idx = 1:numel(estimators)
    est = estimators(idx);
    plot(t, 100 * est.soc, 'LineStyle', est.lineStyle, 'Color', est.color, ...
        'LineWidth', 1.5, 'DisplayName', sprintf('%s (RMSE=%.3f%%)', est.name, 100 * est.rmse_soc));
end
grid on; xlabel('Time [s]'); ylabel('SOC [%]');
title(sprintf('%sSOC Estimation Comparison', getTitlePrefix(dataset)));
legend('Location', 'best');

figure('Name', sprintf('%sSOC Errors', getTitlePrefix(dataset)), 'NumberTitle', 'off');
hold on;
for idx = 1:numel(estimators)
    est = estimators(idx);
    plot(t, 100 * est.error_soc, 'LineStyle', est.lineStyle, 'Color', est.color, ...
        'LineWidth', 1.5, 'DisplayName', sprintf('%s (RMSE=%.3f%%)', est.name, 100 * est.rmse_soc));
end
grid on; xlabel('Time [s]'); ylabel('SOC Error [%]');
title(sprintf('%sSOC Estimation Errors vs %s', getTitlePrefix(dataset), dataset.metric_soc_name));
legend('Location', 'best');

figure('Name', sprintf('%sVoltage Errors', getTitlePrefix(dataset)), 'NumberTitle', 'off');
hold on;
for idx = 1:numel(estimators)
    est = estimators(idx);
    plot(t, est.error_voltage, 'LineStyle', est.lineStyle, 'Color', est.color, ...
        'LineWidth', 1.5, 'DisplayName', sprintf('%s (RMSE=%.2f mV)', est.name, 1000 * est.rmse_voltage));
end
grid on; xlabel('Time [s]'); ylabel('Voltage Error [V]');
title(sprintf('%sVoltage Estimation Errors vs %s', getTitlePrefix(dataset), dataset.metric_voltage_name));
legend('Location', 'best');

has_r0 = any(arrayfun(@(e) e.has_r0, estimators));
if has_r0 && results.flags.R0figs
    figure('Name', sprintf('%sR0 Comparison', getTitlePrefix(dataset)), 'NumberTitle', 'off');
    hold on;
    has_r0_ref = isfield(dataset, 'r0_reference') && ~isempty(dataset.r0_reference);
    if has_r0_ref
        if isscalar(dataset.r0_reference)
            plot(t, 1000 * dataset.r0_reference * ones(size(t)), 'k-', 'LineWidth', 2, 'DisplayName', 'Model R0');
        else
            plot(t, 1000 * dataset.r0_reference(:), 'k-', 'LineWidth', 2, 'DisplayName', 'Model R0');
        end
    end
    for idx = 1:numel(estimators)
        est = estimators(idx);
        if ~est.has_r0
            continue;
        end
        plot(t, 1000 * est.r0, 'LineStyle', est.lineStyle, 'Color', est.color, ...
            'LineWidth', 1.5, 'DisplayName', sprintf('%s R0', est.name));
        plot(t, 1000 * (est.r0 + est.r0_bnd), ':', 'Color', est.color, ...
            'LineWidth', 1.0, 'DisplayName', sprintf('%s +3\\sigma', est.name));
        plot(t, 1000 * (est.r0 - est.r0_bnd), ':', 'Color', est.color, ...
            'LineWidth', 1.0, 'HandleVisibility', 'off');
    end
    grid on; xlabel('Time [s]'); ylabel('R0 [m\Omega]');
    title(sprintf('%sR0 Estimates and Bounds', getTitlePrefix(dataset)));
    legend('Location', 'best');
end

has_bias = any(arrayfun(@(e) e.has_bias, estimators));
if has_bias && results.flags.Biasfigs
    bias_dim = max(arrayfun(@(e) sizeSafe(e.bias, 2), estimators));
    bias_names = {'Current Bias', 'Output Bias'};
    bias_units = {'A', 'V'};
    figure('Name', sprintf('%sBias Estimates', getTitlePrefix(dataset)), 'NumberTitle', 'off');
    tiledlayout(bias_dim, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    for biasIdx = 1:bias_dim
        nexttile
        hold on;
        for estIdx = 1:numel(estimators)
            est = estimators(estIdx);
            if ~est.has_bias || size(est.bias, 2) < biasIdx
                continue;
            end
            plot(t, est.bias(:, biasIdx), 'LineStyle', est.lineStyle, 'Color', est.color, ...
                'LineWidth', 1.5, 'DisplayName', est.name);
            plot(t, est.bias(:, biasIdx) + est.bias_bnd(:, biasIdx), ':', 'Color', est.color, ...
                'LineWidth', 1.0, 'DisplayName', sprintf('%s +3\\sigma', est.name));
            plot(t, est.bias(:, biasIdx) - est.bias_bnd(:, biasIdx), ':', 'Color', est.color, ...
                'LineWidth', 1.0, 'HandleVisibility', 'off');
        end
        grid on;
        ylabel(sprintf('%s [%s]', bias_names{min(biasIdx, numel(bias_names))}, ...
            bias_units{min(biasIdx, numel(bias_units))}));
        title(sprintf('%sEstimate', bias_names{min(biasIdx, numel(bias_names))}));
        legend('Location', 'best');
    end
    xlabel('Time [s]');
end
end

function makeOptionalFigures(results)
dataset = results.dataset;
estimators = results.estimators;
t = dataset.time_s;
methodNames = {estimators.name};

if results.flags.InnovationACFPACFfigs
    innovations = cell(1, numel(estimators));
    for idx = 1:numel(estimators)
        innovations{idx} = estimators(idx).innovation_pre;
    end
    plotInnovationAcfPacf(innovations, methodNames, 60, ...
        sprintf('Pre-fit Innovation ACF/PACF (%s)', strtrim(getTitlePrefix(dataset))));
end

if results.flags.SOCfigs
    for idx = 1:numel(estimators)
        est = estimators(idx);
        figure('Name', ['SOC Error (' est.name ')'], 'NumberTitle', 'off');
        plot(t, 100 * est.error_soc, 'LineWidth', 1.3); hold on; grid on;
        set(gca, 'colororderindex', 1); plot(t, 100 * est.soc_bnd, ':');
        set(gca, 'colororderindex', 1); plot(t, -100 * est.soc_bnd, ':');
        title(sprintf('SOC estimation error (percent, %s)', est.name));
        legend('Error', '+3\sigma', '-3\sigma', 'Location', 'best');
    end
end

if results.flags.Vfigs
    for idx = 1:numel(estimators)
        est = estimators(idx);
        figure('Name', ['Voltage Error (' est.name ')'], 'NumberTitle', 'off');
        plot(t, est.error_voltage, 'LineWidth', 1.3); hold on; grid on;
        set(gca, 'colororderindex', 1); plot(t, est.voltage_bnd, ':');
        set(gca, 'colororderindex', 1); plot(t, -est.voltage_bnd, ':');
        title(sprintf('Voltage estimation error (%s)', est.name));
        legend('Error', '+3\sigma', '-3\sigma', 'Location', 'best');
    end
end
end

function prefix = getTitlePrefix(dataset)
if isfield(dataset, 'title_prefix') && ~isempty(dataset.title_prefix)
    prefix = [dataset.title_prefix ' '];
else
    prefix = '';
end
end

function value = sizeSafe(arrayValue, dim)
if isempty(arrayValue)
    value = 0;
else
    value = size(arrayValue, dim);
end
end

function value = getFlag(flags, fieldName, defaultValue)
if isfield(flags, fieldName) && ~isempty(flags.(fieldName))
    value = flags.(fieldName);
else
    value = defaultValue;
end
end

function x = clamp01(x)
x = min(max(x, 0), 1);
end
