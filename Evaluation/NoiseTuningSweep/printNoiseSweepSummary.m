function summary_out = printNoiseSweepSummary(resultsInput, cfg)
% printNoiseSweepSummary Reprint saved multi-estimator noise-sweep summaries.
%
% Usage:
%   printNoiseSweepSummary(results)
%   printNoiseSweepSummary('saved_results.mat')
%   summary_out = printNoiseSweepSummary(results, cfg)
%
% Inputs:
%   resultsInput  sweepNoiseStudy/runNoiseCovStudy results struct or MAT file path.
%   cfg           Optional struct:
%                   result_variable default ''
%
% Output:
%   summary_out   Struct containing the printed summary table(s).

if nargin < 1 || isempty(resultsInput)
    resultsInput = [];
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end

cfg = normalizeConfig(cfg);
results = loadResultsInput(resultsInput, cfg);

if isWrapperBothResult(results)
    fprintf('\n=== SIGMA_W SWEEP ===\n');
    sigma_w_summary = printSingleSweepSummary(results.sigma_w_sweep);
    fprintf('\n=== SIGMA_V SWEEP ===\n');
    sigma_v_summary = printSingleSweepSummary(results.sigma_v_sweep);

    summary_out = struct();
    summary_out.mode = 'both';
    summary_out.sigma_w_sweep = sigma_w_summary;
    summary_out.sigma_v_sweep = sigma_v_summary;
    return;
end

summary_out = printSingleSweepSummary(results);
end

function summary_out = printSingleSweepSummary(results)
validateResultsStruct(results);

fprintf('\nNoise-covariance sweep summary (%s dataset)\n', upper(fieldOr(results, 'dataset_mode', 'unknown')));
fprintf('Sweep mode: %s\n', upper(fieldOr(results, 'sweep_mode', inferSweepMode(results))));
fprintf('sigma_w range: %s\n', formatSweepVector(results.sigma_w_values(:)));
fprintf('sigma_v range: %s\n', formatSweepVector(results.sigma_v_values(:)));
disp(results.summary_table);

fprintf('\nAggregate summary across sigma_w / sigma_v sweep\n');
for est_idx = 1:numel(results.estimator_names)
    soc_vals = results.soc_rmse_percent(:, :, est_idx);
    v_vals = results.voltage_rmse_mv(:, :, est_idx);
    soc_mssd_vals = results.soc_mssd_percent2(:, :, est_idx);
    v_mssd_vals = results.voltage_mssd_mv2(:, :, est_idx);

    fprintf('  %-10s mean SOC RMSE = %.3f%%, best = %.3f%%, worst = %.3f%% | ', ...
        results.estimator_names{est_idx}, ...
        finiteMean(soc_vals(:)), finiteMin(soc_vals(:)), finiteMax(soc_vals(:)));
    fprintf('mean SOC MSSD = %.6f %%^2 | ', finiteMean(soc_mssd_vals(:)));
    fprintf('mean V RMSE = %.2f mV, best = %.2f mV, worst = %.2f mV | ', ...
        finiteMean(v_vals(:)), finiteMin(v_vals(:)), finiteMax(v_vals(:)));
    fprintf('mean V MSSD = %.4f mV^2\n', finiteMean(v_mssd_vals(:)));
end

summary_out = struct();
summary_out.summary_table = results.summary_table;
summary_out.estimator_names = results.estimator_names(:).';
summary_out.dataset_mode = fieldOr(results, 'dataset_mode', 'unknown');
summary_out.sweep_mode = fieldOr(results, 'sweep_mode', inferSweepMode(results));
end

function cfg = normalizeConfig(cfg)
cfg.result_variable = fieldOr(cfg, 'result_variable', '');
end

function results = loadResultsInput(resultsInput, cfg)
if isstruct(resultsInput)
    results = resultsInput;
    return;
end

if isempty(resultsInput)
    candidates = {'noiseCovSweepResults', 'sweepResults'};
    for idx = 1:numel(candidates)
        if evalin('base', sprintf('exist(''%s'', ''var'')', candidates{idx}))
            results = evalin('base', candidates{idx});
            return;
        end
    end
    error('printNoiseSweepSummary:MissingInput', ...
        'Provide a results struct, MAT file path, or a base-workspace results variable.');
end

if isstring(resultsInput)
    resultsInput = char(resultsInput);
end
if ~ischar(resultsInput)
    error('printNoiseSweepSummary:BadInput', ...
        'resultsInput must be a results struct or a MAT file path.');
end
if exist(resultsInput, 'file') ~= 2
    error('printNoiseSweepSummary:MissingFile', 'Results file not found: %s', resultsInput);
end

loaded = load(resultsInput);
results = extractResultsStruct(loaded, cfg.result_variable, resultsInput);
end

function results = extractResultsStruct(loaded, preferred_name, file_path)
if ~isempty(preferred_name)
    if isfield(loaded, preferred_name)
        results = loaded.(preferred_name);
        return;
    end
    error('printNoiseSweepSummary:MissingVariable', ...
        'Variable "%s" was not found in %s.', preferred_name, file_path);
end

names = fieldnames(loaded);
for idx = 1:numel(names)
    candidate = loaded.(names{idx});
    if isstruct(candidate) && isNoiseSweepStruct(candidate)
        results = candidate;
        return;
    end
end

error('printNoiseSweepSummary:NoResultsStruct', ...
    'Could not find a noise-sweep results struct in %s.', file_path);
end

function validateResultsStruct(results)
required = {'sigma_w_values', 'sigma_v_values', 'estimator_names', 'summary_table', ...
    'soc_rmse_percent', 'voltage_rmse_mv', 'soc_mssd_percent2', 'voltage_mssd_mv2'};
for idx = 1:numel(required)
    if ~isfield(results, required{idx})
        error('printNoiseSweepSummary:BadResultsStruct', ...
            'Results struct is missing field "%s".', required{idx});
    end
end
end

function tf = isNoiseSweepStruct(candidate)
tf = isstruct(candidate) && ( ...
    isWrapperBothResult(candidate) || ...
    (isfield(candidate, 'sigma_w_values') && isfield(candidate, 'sigma_v_values') && isfield(candidate, 'summary_table')));
end

function tf = isWrapperBothResult(results)
tf = isstruct(results) && isfield(results, 'mode') && strcmpi(char(results.mode), 'both') && ...
    isfield(results, 'sigma_w_sweep') && isfield(results, 'sigma_v_sweep');
end

function sweep_mode = inferSweepMode(results)
if numel(results.sigma_w_values) > 1 && numel(results.sigma_v_values) > 1
    sweep_mode = 'grid';
elseif numel(results.sigma_v_values) > 1
    sweep_mode = 'sigma_v';
else
    sweep_mode = 'sigma_w';
end
end

function text_value = formatSweepVector(values)
parts = arrayfun(@(x) sprintf('%.3g', x), values, 'UniformOutput', false);
text_value = strjoin(parts, ', ');
end

function value = finiteMean(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = mean(x);
end
end

function value = finiteMin(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = min(x);
end
end

function value = finiteMax(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = max(x);
end
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
else
    value = default_value;
end
end
