function figure_handles = plotNoiseSweepHeatmaps(sweepResults, metric_names)
% plotNoiseSweepHeatmaps Plot per-estimator sweep heatmaps or 1D curves.
%
% Usage:
%   plotNoiseSweepHeatmaps(sweepResults)
%   plotNoiseSweepHeatmaps(sweepResults, {'soc_rmse_percent', 'voltage_rmse_mv'})
%
% Inputs:
%   sweepResults   Result struct returned by sweepNoiseStudy() or
%                  runNoiseCovStudy(). If the wrapper result contains
%                  sweep_mode = 'both', the helper plots both saved subruns.
%   metric_names   Optional metric selector or cell array. Supported values:
%                  'soc_rmse_percent', 'soc_mssd_percent2',
%                  'voltage_rmse_mv', 'voltage_mssd_mv2',
%                  'soc_me_percent', 'voltage_me_mv'

if nargin < 2 || isempty(metric_names)
    metric_names = defaultMetricNames();
end

if isWrapperBothResult(sweepResults)
    sigma_w_handles = plotNoiseSweepHeatmaps(sweepResults.sigma_w_sweep, metric_names);
    sigma_v_handles = plotNoiseSweepHeatmaps(sweepResults.sigma_v_sweep, metric_names);
    figure_handles = [sigma_w_handles(:); sigma_v_handles(:)];
    return;
end

validateSweepResultStruct(sweepResults);
metric_names = normalizeMetricSelection(metric_names);

sigma_w_values = sweepResults.sigma_w_values(:);
sigma_v_values = sweepResults.sigma_v_values(:);
estimator_names = sweepResults.estimator_names(:).';
sweep_mode = getFieldOr(sweepResults, 'sweep_mode', inferSweepMode(sigma_w_values, sigma_v_values));

figure_handles = gobjects(0);
for idx = 1:numel(metric_names)
    spec = metricSpec(metric_names{idx});
    data_cube = sweepResults.(spec.field_name);
    if numel(sigma_w_values) > 1 && numel(sigma_v_values) > 1
        handles = plotPerEstimatorHeatmaps(sigma_w_values, sigma_v_values, data_cube, estimator_names, spec.colorbar_label, spec.figure_prefix);
    else
        handles = plotPerEstimatorCurves(sigma_w_values, sigma_v_values, data_cube, estimator_names, spec.colorbar_label, spec.figure_prefix, sweep_mode);
    end
    figure_handles = [figure_handles; handles(:)]; %#ok<AGROW>
end
end

function handles = plotPerEstimatorHeatmaps(sigma_w_values, sigma_v_values, data_cube, estimator_names, colorbar_label, figure_prefix)
handles = gobjects(numel(estimator_names), 1);
for est_idx = 1:numel(estimator_names)
    handles(est_idx) = figure('Name', sprintf('%s - %s', figure_prefix, estimator_names{est_idx}), 'NumberTitle', 'off');
    imagesc(log10(sigma_v_values), log10(sigma_w_values), data_cube(:, :, est_idx));
    axis xy;
    grid on;
    xlabel('log_{10}(\sigma_v)');
    ylabel('log_{10}(\sigma_w)');
    title(sprintf('%s Sweep - %s', figure_prefix, estimator_names{est_idx}));
    cb = colorbar;
    ylabel(cb, colorbar_label);
    xticks(log10(sigma_v_values));
    xticklabels(formatTickLabels(sigma_v_values));
    yticks(log10(sigma_w_values));
    yticklabels(formatTickLabels(sigma_w_values));
end
end

function handles = plotPerEstimatorCurves(sigma_w_values, sigma_v_values, data_cube, estimator_names, y_label, figure_prefix, sweep_mode)
if strcmp(sweep_mode, 'sigma_v') && numel(sigma_v_values) > 1
    x_values = sigma_v_values;
    data_matrix = squeeze(data_cube(1, :, :));
    x_label = '\sigma_v';
else
    x_values = sigma_w_values;
    data_matrix = squeeze(data_cube(:, 1, :));
    x_label = '\sigma_w';
end

if isvector(data_matrix)
    data_matrix = data_matrix(:);
end
if size(data_matrix, 2) ~= numel(estimator_names)
    data_matrix = reshape(data_matrix, numel(x_values), numel(estimator_names));
end

handles = gobjects(numel(estimator_names), 1);
for est_idx = 1:numel(estimator_names)
    handles(est_idx) = figure('Name', sprintf('%s - %s', figure_prefix, estimator_names{est_idx}), 'NumberTitle', 'off');
    semilogx(x_values, data_matrix(:, est_idx), '-o', 'LineWidth', 1.4);
    grid on;
    xlabel(x_label);
    ylabel(y_label);
    title(sprintf('%s Sweep - %s', figure_prefix, estimator_names{est_idx}));
end
end

function validateSweepResultStruct(sweepResults)
required_fields = {'sigma_w_values', 'sigma_v_values', 'estimator_names'};
for idx = 1:numel(required_fields)
    if ~isfield(sweepResults, required_fields{idx})
        error('plotNoiseSweepHeatmaps:BadSweepResults', ...
            'sweepResults is missing required field "%s".', required_fields{idx});
    end
end
end

function tf = isWrapperBothResult(sweepResults)
tf = isstruct(sweepResults) && isfield(sweepResults, 'mode') && ...
    strcmpi(char(sweepResults.mode), 'both') && ...
    isfield(sweepResults, 'sigma_w_sweep') && isfield(sweepResults, 'sigma_v_sweep');
end

function metric_names = defaultMetricNames()
metric_names = {'soc_rmse_percent', 'soc_mssd_percent2', 'voltage_rmse_mv', 'voltage_mssd_mv2'};
end

function metric_names = normalizeMetricSelection(metric_names)
if ischar(metric_names)
    metric_names = {metric_names};
elseif isa(metric_names, 'string')
    metric_names = cellstr(metric_names(:));
elseif ~iscell(metric_names)
    error('plotNoiseSweepHeatmaps:BadMetricSelection', ...
        'metric_names must be a char vector, string array, or cell array.');
end

for idx = 1:numel(metric_names)
    spec = metricSpec(metric_names{idx});
    metric_names{idx} = spec.field_name;
end
metric_names = unique(metric_names, 'stable');
end

function spec = metricSpec(metric_name)
key = regexprep(upper(char(metric_name)), '[^A-Z0-9]', '');
switch key
    case {'SOCRMSE', 'SOCRMSEPERCENT', 'SOCRMSEPCT'}
        spec = struct('field_name', 'soc_rmse_percent', 'colorbar_label', 'SOC RMSE [%]', 'figure_prefix', 'SOC');
    case {'SOCMSSD', 'SOCMSSDPERCENT2', 'SOCMSSDPCT2'}
        spec = struct('field_name', 'soc_mssd_percent2', 'colorbar_label', 'SOC MSSD [%^2]', 'figure_prefix', 'SOC MSSD');
    case {'VOLTAGERMSE', 'VOLTAGERMSEMV'}
        spec = struct('field_name', 'voltage_rmse_mv', 'colorbar_label', 'Voltage RMSE [mV]', 'figure_prefix', 'Voltage');
    case {'VOLTAGEMSSD', 'VOLTAGEMSSDMV2'}
        spec = struct('field_name', 'voltage_mssd_mv2', 'colorbar_label', 'Voltage MSSD [mV^2]', 'figure_prefix', 'Voltage MSSD');
    case {'SOCME', 'SOCMEPERCENT', 'SOCMEPCT'}
        spec = struct('field_name', 'soc_me_percent', 'colorbar_label', 'SOC ME [%]', 'figure_prefix', 'SOC ME');
    case {'VOLTAGEME', 'VOLTAGEMEMV'}
        spec = struct('field_name', 'voltage_me_mv', 'colorbar_label', 'Voltage ME [mV]', 'figure_prefix', 'Voltage ME');
    otherwise
        error('plotNoiseSweepHeatmaps:UnsupportedMetric', ...
            'Unsupported metric selector "%s".', char(metric_name));
end
end

function labels = formatTickLabels(values)
labels = arrayfun(@(x) sprintf('%.3g', x), values, 'UniformOutput', false);
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
