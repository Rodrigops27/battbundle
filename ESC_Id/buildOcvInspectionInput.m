function inspection = buildOcvInspectionInput(cfg)
% buildOcvInspectionInput Build multi-method OCV inspection inputs.
%
% This helper runs the configured OCV-identification methods and returns
% the raw OCV datasets plus the identified models for visual inspection.

if nargin < 1 || isempty(cfg)
  cfg = defaultInspectionConfig();
else
  cfg = mergeStructDefaults(cfg, defaultInspectionConfig());
end

raw_data = loadOcvInputData(cfg.ocv_data_input, cfg.data_prefix);
temps_degC = sort(unique([raw_data.temp]), 'ascend');
selected_temps = resolveRequestedTemperatures(temps_degC, cfg.desired_temperatures);
raw_data = selectOcvDataByTemperature(raw_data, selected_temps);
methods = methodDefinitions(cfg);

inspection = struct();
inspection.kind = 'ocv_inspection_input';
inspection.created_on = datestr(now, 'yyyy-mm-dd HH:MM:SS');
inspection.config = cfg;
inspection.temps_degC = selected_temps(:).';
inspection.data = raw_data;
inspection.reference = struct( ...
  'ocv_method', cfg.reference_ocv_method, ...
  'soc', [], ...
  'filedata', []);
inspection.methods = repmat(struct( ...
  'display_name', '', ...
  'engine', '', ...
  'diag_type', '', ...
  'plot_enabled', true, ...
  'identification_results', struct(), ...
  'model', struct(), ...
  'metrics', struct()), numel(methods), 1);

for idx = 1:numel(methods)
  run_cfg = struct();
  run_cfg.run_name = sprintf('%s %s OCV identification', cfg.cell_id, methods(idx).display_name);
  run_cfg.ocv_data_input = cfg.ocv_data_input;
  run_cfg.data_prefix = cfg.data_prefix;
  run_cfg.cell_id = cfg.cell_id;
  run_cfg.engine = methods(idx).engine;
  if ~isempty(methods(idx).diag_type)
    run_cfg.diag_type = methods(idx).diag_type;
  end
  run_cfg.reference_ocv_method = cfg.reference_ocv_method;
  run_cfg.temperature_scope = 'selected';
  run_cfg.desired_temperature = selected_temps;
  run_cfg.min_v = cfg.min_v;
  run_cfg.max_v = cfg.max_v;
  run_cfg.save_plots = false;
  run_cfg.debug_plots = false;
  run_cfg.output = struct( ...
    'save_model', false, ...
    'save_results', false, ...
    'include_model_struct', true);

  identification_results = runOcvIdentification(run_cfg);
  if idx == 1
    inspection.reference = identification_results.ocv_validation.reference;
  end
  inspection.methods(idx).display_name = methods(idx).display_name;
  inspection.methods(idx).engine = methods(idx).engine;
  inspection.methods(idx).diag_type = methods(idx).diag_type;
  inspection.methods(idx).plot_enabled = methods(idx).plot_enabled;
  inspection.methods(idx).identification_results = identification_results;
  inspection.methods(idx).model = identification_results.model;
  inspection.methods(idx).metrics = identification_results.metrics;
end
end

function cfg = defaultInspectionConfig()
cfg = struct();
cfg.ocv_data_input = '';
cfg.data_prefix = 'ATL';
cfg.cell_id = 'ATL20';
cfg.min_v = 2.0;
cfg.max_v = 3.75;
cfg.desired_temperatures = [];
cfg.reference_ocv_method = 'middleCurve';
cfg.plot_diag_methods = true;
end

function methods = methodDefinitions(cfg)
methods = repmat(struct('display_name', '', 'engine', '', 'diag_type', '', 'plot_enabled', true), 7, 1);
methods(1) = struct('display_name', 'Resistance blend', 'engine', 'resistanceBlend', 'diag_type', '', 'plot_enabled', true);
methods(2) = struct('display_name', 'Vavg', 'engine', 'voltageAverage', 'diag_type', '', 'plot_enabled', true);
methods(3) = struct('display_name', 'SOCavg', 'engine', 'socAverage', 'diag_type', '', 'plot_enabled', true);
methods(4) = struct('display_name', 'Middle curve', 'engine', 'middleCurve', 'diag_type', '', 'plot_enabled', true);
methods(5) = struct('display_name', 'Diag useDis', 'engine', 'diagAverage', 'diag_type', 'useDis', 'plot_enabled', logical(cfg.plot_diag_methods));
methods(6) = struct('display_name', 'Diag useChg', 'engine', 'diagAverage', 'diag_type', 'useChg', 'plot_enabled', logical(cfg.plot_diag_methods));
methods(7) = struct('display_name', 'Diag useAvg', 'engine', 'diagAverage', 'diag_type', 'useAvg', 'plot_enabled', logical(cfg.plot_diag_methods));
end

function data = loadOcvInputData(data_input, data_prefix)
if isstruct(data_input)
  data = data_input(:);
  return;
end

if ischar(data_input) || (isstring(data_input) && isscalar(data_input))
  data_dir = char(data_input);
  if exist(data_dir, 'dir') ~= 7
    error('buildOcvInspectionInput:MissingOcvDir', ...
      'OCV data folder not found: %s', data_dir);
  end
  data = loadOcvDataFromDir(data_dir, data_prefix);
  return;
end

error('buildOcvInspectionInput:UnsupportedOcvInput', ...
  'cfg.ocv_data_input must be a folder or an OCV struct array.');
end

function data = loadOcvDataFromDir(data_dir, data_prefix)
pattern = sprintf('%s_OCV_*.mat', data_prefix);
files = dir(fullfile(data_dir, pattern));
files = files(~[files.isdir]);
if isempty(files)
  error('buildOcvInspectionInput:NoOcvFiles', ...
    'No OCV files matching %s were found in %s.', pattern, data_dir);
end

entries = cell(numel(files), 1);
temps_degC = NaN(numel(files), 1);
for idx = 1:numel(files)
  file_path = fullfile(files(idx).folder, files(idx).name);
  temp_degC = parseTemperatureFromFilename(files(idx).name);
  if isempty(temp_degC)
    error('buildOcvInspectionInput:BadFilename', ...
      'Unexpected OCV filename format: %s', files(idx).name);
  end

  src = load(file_path, 'OCVData');
  if ~isfield(src, 'OCVData')
    error('buildOcvInspectionInput:MissingOcvData', ...
      'File %s does not contain OCVData.', file_path);
  end

  entry = src.OCVData;
  entry.temp = temp_degC;
  entries{idx} = entry;
  temps_degC(idx) = temp_degC;
end

[~, order] = sort(temps_degC, 'ascend');
data = vertcat(entries{order});
end

function selected_temps = resolveRequestedTemperatures(available_temps, requested_temps)
if isempty(requested_temps)
  selected_temps = available_temps(:).';
  return;
end

selected_temps = unique(requested_temps(:).', 'stable');
missing = setdiff(selected_temps, available_temps);
if ~isempty(missing)
  error('buildOcvInspectionInput:UnavailableTemperature', ...
    'Requested OCV temperatures not found: %s.', mat2str(missing));
end
selected_temps = sort(selected_temps, 'ascend');
end

function data = selectOcvDataByTemperature(data, temps_degC)
keep = ismember([data.temp], temps_degC);
data = data(keep);
[~, order] = sort([data.temp], 'ascend');
data = data(order);
end

function out = mergeStructDefaults(in, defaults)
out = defaults;
if isempty(in)
  return;
end
names = fieldnames(in);
for idx = 1:numel(names)
  out.(names{idx}) = in.(names{idx});
end
end

function temp_degC = parseTemperatureFromFilename(filename)
temp_degC = [];
tokens = regexp(filename, '_OCV_(N|P)(\d+)\.mat$', 'tokens', 'once');
if isempty(tokens)
  return;
end
temp_degC = str2double(tokens{2});
if strcmpi(tokens{1}, 'N')
  temp_degC = -temp_degC;
end
end
