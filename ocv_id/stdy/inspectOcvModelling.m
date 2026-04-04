% inspectOcvModelling.m
% Inspect OCV models overlaid on raw OCV branches for all temperatures.
%
% If `ocvInspectionInput` exists in the base workspace, this script uses it.
% Otherwise it builds the inspection input for the ATL20 OCV folder.

clearvars -except ocvInspectionInput
% close all
% clc

script_dir = fileparts(mfilename('fullpath'));
study_root = script_dir;
ocv_root = fileparts(study_root);
repo_root = fileparts(ocv_root);

addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'utility')));
addpath(genpath(ocv_root));

if ~exist('ocvInspectionInput', 'var') || isempty(ocvInspectionInput)
  cfg = struct();
  cfg.ocv_data_input = fullfile(repo_root, 'data', 'modelling', 'processed', 'ocv', 'atl20');
  cfg.data_prefix = 'ATL';
  cfg.cell_id = 'ATL20';
  cfg.min_v = 2.0;
  cfg.max_v = 3.75;
  cfg.desired_temperatures = [];
  ocvInspectionInput = buildOcvInspectionInput(cfg);
end

inspection = ocvInspectionInput;
temps_degC = inspection.temps_degC(:).';
data = inspection.data;
methods = inspection.methods;
soc = (0:0.005:1).';
plotStyle = defaultInspectionPlotStyle();
reference = resolveReferenceData(inspection);
save_figures = fieldOr(inspection.config, 'save_inspection_figures', fieldOr(inspection.config, 'save_figures', false));
figure_format = char(fieldOr(inspection.config, 'inspection_figure_format', 'png'));
paths = resolveOcvInspectionPaths(inspection.config);
inspection.visual_inspection = struct( ...
  'save_figures', logical(save_figures), ...
  'figure_format', figure_format, ...
  'figure_root', BundleEvalHelpers.normalizeStoredPath(paths.figure_root_abs), ...
  'figure_outputs', struct([]));
figure_outputs = struct([]);

for idx = 1:numel(temps_degC)
  tc = temps_degC(idx);
  datum = selectDatum(data, tc);
  [rawDisZ, rawDisV, rawChgZ, rawChgV] = extractRawBranches(datum);
  referenceDatum = selectReferenceDatum(reference, tc);

  figure('Name', sprintf('%s OCV visual inspection @ %.0f degC', ...
    inspection.config.cell_id, tc), 'Color', 'w');
  ax = axes();
  hold(ax, 'on')
  plot(ax, 100 * rawDisZ, rawDisV, ...
    'Color', plotStyle.raw_discharge_color, ...
    'LineStyle', '--', ...
    'LineWidth', plotStyle.raw_line_width, ...
    'DisplayName', 'Raw discharging OCV');
  plot(ax, 100 * rawChgZ, rawChgV, ...
    'Color', plotStyle.raw_charge_color, ...
    'LineStyle', '-.', ...
    'LineWidth', plotStyle.raw_line_width, ...
    'DisplayName', 'Raw charging OCV');
  plot(ax, 100 * reference.soc, referenceDatum.rawocv, ...
    'Color', plotStyle.reference_color, ...
    'LineStyle', plotStyle.reference_line_style, ...
    'LineWidth', plotStyle.reference_line_width, ...
    'DisplayName', sprintf('Metrics reference OCV (%s)', reference.ocv_method));
  for method_idx = 1:numel(methods)
    if isfield(methods(method_idx), 'plot_enabled') && ~methods(method_idx).plot_enabled
      continue;
    end
    predicted_ocv = OCVfromSOCtemp(soc, tc, methods(method_idx).model);
    style = getMethodPlotStyle(methods(method_idx).display_name, plotStyle);
    plot(ax, 100 * soc, predicted_ocv, ...
      'Color', style.color, ...
      'LineStyle', style.line_style, ...
      'LineWidth', style.line_width, ...
      'DisplayName', methods(method_idx).display_name);
  end
  grid(ax, 'on')
  box(ax, 'on')
  xlabel(ax, 'SOC (%)');
  ylabel(ax, 'Voltage (V)');
  xlim(ax, [0 100]);
  ylim(ax, [inspection.config.min_v - 0.1, inspection.config.max_v + 0.1]);
  title(ax, sprintf('%s OCV methods @ %.0f degC', inspection.config.cell_id, tc));
  legend(ax, 'Location', 'southeast');

  if save_figures
    output_file = fullfile(paths.figure_root_abs, sprintf('%s_ocv_methods_%s.%s', ...
      BundleEvalHelpers.sanitizeToken(lower(inspection.config.cell_id)), ...
      formatTemperatureToken(tc), figure_format));
    BundleEvalHelpers.exportSingleFigure(gcf, output_file, figure_format);
    figure_outputs(end + 1).temp_degC = tc; %#ok<AGROW>
    figure_outputs(end).absolute_path = output_file; %#ok<AGROW>
    figure_outputs(end).relative_path = BundleEvalHelpers.normalizeStoredPath(output_file); %#ok<AGROW>
  end
end
inspection.visual_inspection.figure_outputs = figure_outputs;
ocvInspectionResults = inspection; %#ok<NASGU>
assignin('base', 'ocvInspectionResults', inspection);

function datum = selectDatum(data, tc)
match = find([data.temp] == tc, 1, 'first');
if isempty(match)
  error('inspectOcvModelling:MissingTemperature', ...
    'Temperature %.0f degC was not found in the inspection input.', tc);
end
datum = data(match);
end

function reference = resolveReferenceData(inspection)
if isfield(inspection, 'reference') && isfield(inspection.reference, 'filedata') ...
    && ~isempty(inspection.reference.filedata)
  reference = inspection.reference;
  return;
end

if isempty(inspection.methods) || ~isfield(inspection.methods(1), 'identification_results')
  error('inspectOcvModelling:MissingReferenceData', ...
    'No stored OCV metrics reference was found in the inspection input.');
end

reference = inspection.methods(1).identification_results.ocv_validation.reference;
end

function datum = selectReferenceDatum(reference, tc)
match = find([reference.filedata.temp] == tc, 1, 'first');
if isempty(match)
  error('inspectOcvModelling:MissingReferenceTemperature', ...
    'Reference OCV for %.0f degC was not found.', tc);
end
datum = reference.filedata(match);
end

function [disZ, disV, chgZ, chgV] = extractRawBranches(testdata)
eta25 = computeEta25(testdata);
testdata = scaleAllChargeScripts(testdata, eta25);
Q25 = computeQ25(testdata);

indD = find(testdata.script1.step == 2);
indC = find(testdata.script3.step == 2);
if isempty(indD) || isempty(indC)
  error('inspectOcvModelling:MissingScriptSteps', ...
    'Could not find slow discharge/charge step 2 in the selected OCV dataset.');
end

disZ = 1 - testdata.script1.disAh(indD) / Q25;
disZ = disZ + (1 - disZ(1));
chgZ = testdata.script3.chgAh(indC) / Q25;
chgZ = chgZ - chgZ(1);
disV = testdata.script1.voltage(indD);
chgV = testdata.script3.voltage(indC);
end

function eta25 = computeEta25(testdata)
totDisAh = testdata.script1.disAh(end) + testdata.script2.disAh(end) + ...
  testdata.script3.disAh(end) + testdata.script4.disAh(end);
totChgAh = testdata.script1.chgAh(end) + testdata.script2.chgAh(end) + ...
  testdata.script3.chgAh(end) + testdata.script4.chgAh(end);
eta25 = totDisAh / totChgAh;
end

function testdata = scaleAllChargeScripts(testdata, eta25)
testdata.script1.chgAh = testdata.script1.chgAh * eta25;
testdata.script2.chgAh = testdata.script2.chgAh * eta25;
testdata.script3.chgAh = testdata.script3.chgAh * eta25;
testdata.script4.chgAh = testdata.script4.chgAh * eta25;
end

function Q25 = computeQ25(testdata)
Q25 = testdata.script1.disAh(end) + testdata.script2.disAh(end) - ...
  testdata.script1.chgAh(end) - testdata.script2.chgAh(end);
end

function style = defaultInspectionPlotStyle()
style = struct();
style.raw_discharge_color = [0.00, 0.35, 0.85];
style.raw_charge_color = [0.85, 0.15, 0.15];
style.raw_line_width = 0.5;
style.reference_color = [0.00, 0.00, 0.00];
style.reference_line_style = ':';
style.reference_line_width = 1.5;
style.base_method_width = 1.0;
style.middle_curve_width = 2.0;
style.colors = struct( ...
  'Resistance_blend', [0.45, 0.45, 0.45], ...
  'Vavg', [0.55, 0.20, 0.75], ...
  'SOCavg', [0.95, 0.55, 0.10], ...
  'Middle_curve', [0.00, 0.60, 0.20], ...
  'Diag_useDis', [0.10, 0.55, 0.55], ...
  'Diag_useChg', [0.75, 0.45, 0.00], ...
  'Diag_useAvg', [0.20, 0.20, 0.20]);
end

function style = getMethodPlotStyle(display_name, plotStyle)
key = matlab.lang.makeValidName(strrep(display_name, ' ', '_'));
style = struct();
style.line_style = '-';
style.line_width = plotStyle.base_method_width;

if isfield(plotStyle.colors, key)
  style.color = plotStyle.colors.(key);
else
  style.color = [0.25, 0.25, 0.25];
end

if strcmp(display_name, 'Middle curve')
  style.color = plotStyle.colors.Middle_curve;
  style.line_width = plotStyle.middle_curve_width;
end
end

function token = formatTemperatureToken(temp_degC)
if temp_degC < 0
  token = sprintf('N%02d', abs(temp_degC));
else
  token = sprintf('P%02d', temp_degC);
end
end

function value = fieldOr(s, field_name, default_value)
if isfield(s, field_name) && ~isempty(s.(field_name))
  value = s.(field_name);
else
  value = default_value;
end
end
