function fig_handles = plotOcvModelFit(validation_input, cfg)
% plotOcvModelFit Plot OCV model fit against raw OCV references.

if nargin < 1 || isempty(validation_input)
    error('plotOcvModelFit:MissingInput', ...
        'A validation struct or MAT-file path is required.');
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end

validation = loadValidation(validation_input);
cfg = normalizeConfig(cfg, validation);

selected_models = selectModels(validation.models, cfg.model_names);
temps_degC = selectTemps(validation.reference.filedata, cfg.temps_degC);
fig_handles = gobjects(numel(temps_degC), 1);

for temp_idx = 1:numel(temps_degC)
    tc = temps_degC(temp_idx);
    ref_idx = find([validation.reference.filedata.temp] == tc, 1, 'first');
    reference = validation.reference.filedata(ref_idx);

    fig_handles(temp_idx) = figure( ...
        'Name', sprintf('%s OCV Validation %g degC', cfg.title_prefix, tc), ...
        'NumberTitle', 'off', ...
        'Color', 'w');

    plot(100 * validation.reference.soc, reference.rawocv, 'LineWidth', 1.8, ...
        'DisplayName', 'Approximate OCV from data'); hold on

    metric_lines = cell(numel(selected_models), 1);
    for model_idx = 1:numel(selected_models)
        model_entry = selected_models(model_idx);
        per_temp_idx = find([model_entry.per_temp.temp_degC] == tc, 1, 'first');
        if isempty(per_temp_idx), continue; end
        temp_result = model_entry.per_temp(per_temp_idx);
        plot(100 * temp_result.soc, temp_result.predicted_ocv, 'LineWidth', 1.6, ...
            'DisplayName', sprintf('%s prediction', model_entry.name));
        metric_lines{model_idx} = sprintf('%s RMSE = %.1f mV | ME = %.1f mV', ...
            model_entry.name, temp_result.metrics.rmse_mv, temp_result.metrics.mean_error_mv);
    end

    plot(100 * reference.disZ, reference.disV, 'k--', 'LineWidth', 1.0, ...
        'DisplayName', 'Raw discharge data');
    plot(100 * reference.chgZ, reference.chgV, 'k-.', 'LineWidth', 1.0, ...
        'DisplayName', 'Raw charge data');

    xlabel('SOC (%)');
    ylabel('OCV (V)');
    xlim([0 100]);
    ylim([cfg.min_v - 0.1 cfg.max_v + 0.1]);
    title(sprintf('%s OCV fit at temp = %g degC [%s]', ...
        cfg.title_prefix, tc, validation.reference.ocv_method));
    grid on

    metric_lines = metric_lines(~cellfun(@isempty, metric_lines));
    if ~isempty(metric_lines)
        text(2, cfg.max_v - 0.15, strjoin(metric_lines, newline), ...
            'FontSize', 11, 'VerticalAlignment', 'top', ...
            'BackgroundColor', 'w', 'Margin', 4);
    end

    legend('Location', 'southeast');
end
end

function validation = loadValidation(validation_input)
if isstruct(validation_input)
    if isfield(validation_input, 'summary_table') && isfield(validation_input, 'models')
        validation = validation_input;
        return;
    end
    if isfield(validation_input, 'validation')
        validation = validation_input.validation;
        return;
    end
    if isfield(validation_input, 'results') && isfield(validation_input.results, 'validation')
        validation = validation_input.results.validation;
        return;
    end
end

mat_file = char(validation_input);
src = load(mat_file);
validation = loadValidation(src);
end

function cfg = normalizeConfig(cfg, validation)
cfg.model_names = fieldOr(cfg, 'model_names', {});
cfg.temps_degC = fieldOr(cfg, 'temps_degC', []);
all_dis_v = cellfun(@(x) x(:), {validation.reference.filedata.disV}, 'UniformOutput', false);
all_chg_v = cellfun(@(x) x(:), {validation.reference.filedata.chgV}, 'UniformOutput', false);
cfg.min_v = fieldOr(cfg, 'min_v', min(cellfun(@min, all_dis_v)));
cfg.max_v = fieldOr(cfg, 'max_v', max(cellfun(@max, all_chg_v)));
cfg.title_prefix = fieldOr(cfg, 'title_prefix', char(validation.reference.cell_id));
end

function models = selectModels(all_models, requested_names)
if isempty(requested_names)
    models = all_models;
    return;
end
if ischar(requested_names) || (isstring(requested_names) && isscalar(requested_names))
    requested_names = cellstr(requested_names);
end
keep = false(numel(all_models), 1);
for idx = 1:numel(all_models)
    keep(idx) = any(strcmpi(all_models(idx).name, requested_names));
end
models = all_models(keep);
end

function temps_degC = selectTemps(filedata, requested_temps)
available_temps = [filedata.temp];
if isempty(requested_temps)
    temps_degC = available_temps;
else
    temps_degC = requested_temps(:).';
end
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end
