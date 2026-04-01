% script compareATL20OcvModels.m
%   Compares the original ATLmodel-ocv.mat against the derived ATL20
%   OCV model by evaluating both on a common SOC grid.

clearvars
close all
clc

script_dir = fileparts(mfilename('fullpath'));
esc_root = fileparts(script_dir);
repo_root = fileparts(esc_root);
original_file = fullfile(repo_root, 'data', 'modelling', 'derived', 'ocv_models', 'atl', 'ATLmodel-ocv.mat');
candidate_file = fullfile(repo_root, 'data', 'modelling', 'derived', 'ocv_models', 'atl20', 'ATL20model-ocv-vavgFT.mat');
results_file = fullfile(script_dir, 'ATL20model-ocv-validation.mat');

addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'utility')));
addpath(genpath(esc_root));

compare_temps_degC = [-25 -15 -5 5 15 25 35 45];
soc = linspace(0, 1, 201).';

original_model = loadModelStruct(original_file);
candidate_model = loadModelStruct(candidate_file);
validation = computeAtl20OcvValidationMetrics({original_file, candidate_file});

original_ocv = zeros(numel(soc), numel(compare_temps_degC));
candidate_ocv = zeros(numel(soc), numel(compare_temps_degC));
diff_mv = zeros(numel(soc), numel(compare_temps_degC));
rmse_mv = zeros(numel(compare_temps_degC), 1);
mae_mv = zeros(numel(compare_temps_degC), 1);
max_abs_mv = zeros(numel(compare_temps_degC), 1);

for k = 1:numel(compare_temps_degC)
    tc = compare_temps_degC(k);
    original_ocv(:, k) = OCVfromSOCtemp(soc, tc, original_model);
    candidate_ocv(:, k) = OCVfromSOCtemp(soc, tc, candidate_model);

    delta = 1000 * (candidate_ocv(:, k) - original_ocv(:, k));
    diff_mv(:, k) = delta;
    rmse_mv(k) = sqrt(mean(delta .^ 2));
    mae_mv(k) = mean(abs(delta));
    max_abs_mv(k) = max(abs(delta));
end

results = struct();
results.original_file = original_file;
results.candidate_file = candidate_file;
results.temps_degC = compare_temps_degC(:);
results.soc = soc;
results.original_ocv = original_ocv;
results.candidate_ocv = candidate_ocv;
results.diff_mv = diff_mv;
results.metrics = table(compare_temps_degC(:), rmse_mv, mae_mv, max_abs_mv, ...
    'VariableNames', {'temp_degC', 'rmse_mv', 'mae_mv', 'max_abs_mv'});
results.validation = validation;

save(results_file, 'results');

fprintf('\nComparison summary for %s vs %s\n', ...
    getModelName(candidate_model), getModelName(original_model));
disp(results.metrics);
fprintf('\nRaw OCV validation summary\n');
disp(validation.summary_table);
fprintf('\nRanking by mean RMSE across temperatures\n');
disp(validation.model_summary_table);
fprintf('Saved comparison results to:\n  %s\n', results_file);

figure('Name', 'ATL OCV Model Comparison', 'Color', 'w');
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ind25 = find(compare_temps_degC == 25, 1, 'first');

nexttile
plot(100 * soc, original_ocv(:, ind25), 'LineWidth', 1.6); hold on
plot(100 * soc, candidate_ocv(:, ind25), '--', 'LineWidth', 1.6);
xlabel('SOC (%)');
ylabel('OCV (V)');
title('25 degC OCV Overlay');
legend(getModelName(original_model), getModelName(candidate_model), ...
    'Location', 'best');
grid on

nexttile
plot(100 * soc, diff_mv, 'LineWidth', 1.2);
xlabel('SOC (%)');
ylabel('Delta OCV (mV)');
title('ATL20 minus ATL across temperature');
legend(compose('%d degC', compare_temps_degC), 'Location', 'eastoutside');
grid on

nexttile
plot(compare_temps_degC, rmse_mv, 'o-', 'LineWidth', 1.4, 'MarkerSize', 6); hold on
plot(compare_temps_degC, max_abs_mv, 's--', 'LineWidth', 1.4, 'MarkerSize', 6);
xlabel('Temperature (degC)');
ylabel('Voltage difference (mV)');
title('Per-temperature comparison metrics');
legend('RMSE', 'Max abs', 'Location', 'best');
grid on

function model = loadModelStruct(mat_file)
if ~exist(mat_file, 'file')
    error('compareATL20OcvModels:MissingFile', ...
        'Required model file not found: %s', mat_file);
end

src = load(mat_file);
var_names = fieldnames(src);
for k = 1:numel(var_names)
    value = src.(var_names{k});
    if isstruct(value) && all(isfield(value, {'SOC', 'OCV0', 'OCVrel'}))
        model = value;
        return;
    end
end

error('compareATL20OcvModels:MissingModelStruct', ...
    'No OCV model struct was found in %s', mat_file);
end

function name = getModelName(model)
if isfield(model, 'name') && ~isempty(model.name)
    name = char(model.name);
else
    name = 'unnamed-model';
end
end
