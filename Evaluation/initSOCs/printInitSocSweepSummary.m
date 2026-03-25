function summary = printInitSocSweepSummary(resultsInput, cfg)
% printInitSocSweepSummary Print compact summary tables for an initial-SOC sweep.
%
% Usage:
%   printInitSocSweepSummary()
%   printInitSocSweepSummary('saved_results.mat')
%   summary = printInitSocSweepSummary(resultsStruct)
%   summary = printInitSocSweepSummary(resultsInput, cfg)
%
% Inputs:
%   resultsInput  sweepInitSocStudy results struct, extracted summary struct,
%                 or MAT file path.
%   cfg           Optional struct:
%                   result_variable  default ''
%
% Output:
%   summary       Extracted summary struct.

if nargin < 1
    resultsInput = [];
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end

if isstruct(resultsInput) && ...
        isfield(resultsInput, 'aggregate_table') && ...
        isfield(resultsInput, 'best_point_table') && ...
        isfield(resultsInput, 'selected_points_table')
    summary = resultsInput;
else
    extract_cfg = struct();
    if isfield(cfg, 'result_variable')
        extract_cfg.result_variable = cfg.result_variable;
    end
    extract_cfg.display_tables = false;
    summary = extractInitSocSweepResults(resultsInput, extract_cfg);
end

if isempty(summary.aggregate_table)
    fprintf('No initial-SOC sweep summary rows were found.\n');
    return;
end

fprintf('\nInitial-SOC Sweep Summary\n');
if isfield(summary, 'source_file') && ~isempty(summary.source_file)
    fprintf('Source file: %s\n', summary.source_file);
end

fprintf('\nAggregate summary across initial SOC sweep\n');
disp(summary.aggregate_table);

fprintf('Best initial-SOC point per estimator\n');
disp(summary.best_point_table);

fprintf('Selected sweep points\n');
disp(summary.selected_points_table);
end
