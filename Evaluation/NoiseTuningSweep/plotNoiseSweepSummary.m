function figure_handles = plotNoiseSweepSummary(sweepResults)
% plotNoiseSweepSummary Plot aggregate sweep-summary curves.
%
% Usage:
%   plotNoiseSweepSummary(sweepResults)
%
% Input:
%   sweepResults   Result struct returned by sweepNoiseStudy() or
%                  runNoiseCovStudy(). If the wrapper result contains
%                  mode = 'both', the helper plots both saved subruns.

if isWrapperBothResult(sweepResults)
    sigma_w_handles = plotNoiseSweepSummary(sweepResults.sigma_w_sweep);
    sigma_v_handles = plotNoiseSweepSummary(sweepResults.sigma_v_sweep);
    figure_handles = [sigma_w_handles(:); sigma_v_handles(:)];
    return;
end

validateSweepResultStruct(sweepResults);

sigma_w_values = sweepResults.sigma_w_values(:);
sigma_v_values = sweepResults.sigma_v_values(:);
estimator_names = sweepResults.estimator_names(:).';
sweep_mode = getFieldOr(sweepResults, 'sweep_mode', inferSweepMode(sigma_w_values, sigma_v_values));
palette = lines(numel(estimator_names));

if strcmp(sweep_mode, 'sigma_v') && numel(sigma_v_values) > 1
    x_values = sigma_v_values;
    x_label = '\sigma_v';
    soc_curves = squeeze(meanOverDim1OmitNan(sweepResults.soc_rmse_percent(:, :, :)));
    v_curves = squeeze(meanOverDim1OmitNan(sweepResults.voltage_rmse_mv(:, :, :)));
    soc_mssd_curves = squeeze(meanOverDim1OmitNan(sweepResults.soc_mssd_percent2(:, :, :)));
    v_mssd_curves = squeeze(meanOverDim1OmitNan(sweepResults.voltage_mssd_mv2(:, :, :)));
else
    x_values = sigma_w_values;
    x_label = '\sigma_w';
    soc_curves = squeeze(meanOverDim2OmitNan(sweepResults.soc_rmse_percent(:, :, :)));
    v_curves = squeeze(meanOverDim2OmitNan(sweepResults.voltage_rmse_mv(:, :, :)));
    soc_mssd_curves = squeeze(meanOverDim2OmitNan(sweepResults.soc_mssd_percent2(:, :, :)));
    v_mssd_curves = squeeze(meanOverDim2OmitNan(sweepResults.voltage_mssd_mv2(:, :, :)));
end

figure_handles = [
    plotAggregateFigure(x_values, x_label, soc_curves, estimator_names, palette, ...
        'Noise Sweep - Mean SOC RMSE', 'Mean SOC RMSE [%]', 'Noise Sweep Mean SOC RMSE vs %s')
    plotAggregateFigure(x_values, x_label, v_curves, estimator_names, palette, ...
        'Noise Sweep - Mean Voltage RMSE', 'Mean Voltage RMSE [mV]', 'Noise Sweep Mean Voltage RMSE vs %s')
    plotAggregateFigure(x_values, x_label, soc_mssd_curves, estimator_names, palette, ...
        'Noise Sweep - Mean SOC MSSD', 'Mean SOC MSSD [%^2]', 'Noise Sweep Mean SOC MSSD vs %s')
    plotAggregateFigure(x_values, x_label, v_mssd_curves, estimator_names, palette, ...
        'Noise Sweep - Mean Voltage MSSD', 'Mean Voltage MSSD [mV^2]', 'Noise Sweep Mean Voltage MSSD vs %s')
];
end

function fig = plotAggregateFigure(x_values, x_label, curve_matrix, estimator_names, palette, fig_name, y_label, title_format)
curve_matrix = normalizeCurveMatrix(curve_matrix, numel(x_values), numel(estimator_names));

fig = figure('Name', fig_name, 'NumberTitle', 'off');
hold on;
for est_idx = 1:numel(estimator_names)
    semilogx(x_values, curve_matrix(:, est_idx), '-o', ...
        'LineWidth', 1.4, 'Color', palette(est_idx, :), ...
        'DisplayName', estimator_names{est_idx});
end
grid on;
xlabel(x_label);
ylabel(y_label);
title(sprintf(title_format, x_label));
legend('Location', 'best');
end

function curve_matrix = normalizeCurveMatrix(curve_matrix, n_points, n_estimators)
if isvector(curve_matrix)
    curve_matrix = curve_matrix(:);
end
if size(curve_matrix, 1) ~= n_points || size(curve_matrix, 2) ~= n_estimators
    curve_matrix = reshape(curve_matrix, n_points, n_estimators);
end
end

function validateSweepResultStruct(sweepResults)
required_fields = { ...
    'sigma_w_values', 'sigma_v_values', 'estimator_names', ...
    'soc_rmse_percent', 'voltage_rmse_mv', ...
    'soc_mssd_percent2', 'voltage_mssd_mv2'};
for idx = 1:numel(required_fields)
    if ~isfield(sweepResults, required_fields{idx})
        error('plotNoiseSweepSummary:BadSweepResults', ...
            'sweepResults is missing required field "%s".', required_fields{idx});
    end
end
end

function tf = isWrapperBothResult(sweepResults)
tf = isstruct(sweepResults) && isfield(sweepResults, 'mode') && ...
    strcmpi(char(sweepResults.mode), 'both') && ...
    isfield(sweepResults, 'sigma_w_sweep') && isfield(sweepResults, 'sigma_v_sweep');
end

function values = meanOverDim2OmitNan(data)
valid_counts = sum(isfinite(data), 2);
data(~isfinite(data)) = 0;
values = sum(data, 2) ./ max(valid_counts, 1);
values(valid_counts == 0) = NaN;
end

function values = meanOverDim1OmitNan(data)
valid_counts = sum(isfinite(data), 1);
data(~isfinite(data)) = 0;
values = sum(data, 1) ./ max(valid_counts, 1);
values(valid_counts == 0) = NaN;
end

function value = getFieldOr(s, field_name, default_value)
if isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end

function sweep_mode = inferSweepMode(sigma_w_values, sigma_v_values)
if numel(sigma_w_values) > 1 && numel(sigma_v_values) > 1
    sweep_mode = 'grid';
elseif numel(sigma_v_values) > 1
    sweep_mode = 'sigma_v';
else
    sweep_mode = 'sigma_w';
end
end
