function case_cfg = normalizeInjectionCaseConfig(case_cfg)
% normalizeInjectionCaseConfig Validate and normalize injection case identifiers.

if nargin < 1 || isempty(case_cfg)
    case_cfg = struct();
end

scenario_name = getOptionalText(case_cfg, 'mode');
case_name = getOptionalText(case_cfg, 'name');

if isempty(scenario_name)
    scenario_name = case_name;
end
if isempty(scenario_name)
    scenario_name = 'additive_measurement_noise';
end

assertCanonicalScenarioName(scenario_name, 'mode');
case_cfg.mode = scenario_name;
case_cfg.name = resolveCaseName(case_name, scenario_name);
case_cfg.dataset_family = resolveCanonicalField(case_cfg, 'dataset_family', scenario_name);
case_cfg.augmentation_type = resolveCanonicalField(case_cfg, 'augmentation_type', scenario_name);
end

function value = resolveCaseName(case_name, scenario_name)
if isempty(case_name)
    value = scenario_name;
else
    value = case_name;
end
end

function value = resolveCanonicalField(case_cfg, field_name, scenario_name)
value = getOptionalText(case_cfg, field_name);
if isempty(value)
    value = scenario_name;
    return;
end
if ~strcmp(value, scenario_name)
    error('normalizeInjectionCaseConfig:NonCanonicalIdentifier', ...
        'cfg.%s must be "%s" for this injection scenario.', field_name, scenario_name);
end
end

function assertCanonicalScenarioName(value, field_name)
allowed_names = {'sensor_gain_bias_fault', 'additive_measurement_noise', 'composite_measurement_error'};
if any(strcmp(value, allowed_names))
    return;
end

error('normalizeInjectionCaseConfig:InvalidScenarioName', ...
    'cfg.%s must be one of: %s.', field_name, strjoin(allowed_names, ', '));
end

function value = getOptionalText(case_cfg, field_name)
value = '';
if ~isfield(case_cfg, field_name) || isempty(case_cfg.(field_name))
    return;
end

raw_value = case_cfg.(field_name);
if isstring(raw_value)
    if ~isscalar(raw_value)
        error('normalizeInjectionCaseConfig:InvalidFieldType', ...
            'cfg.%s must be a scalar string or char vector.', field_name);
    end
    value = char(raw_value);
elseif ischar(raw_value)
    value = raw_value;
else
    error('normalizeInjectionCaseConfig:InvalidFieldType', ...
        'cfg.%s must be a scalar string or char vector.', field_name);
end
end
