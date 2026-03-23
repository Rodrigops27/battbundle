function results = runInjTest(cfg)
% runInjTest Legacy wrapper forwarding to the Injection layer.

if nargin < 1 || isempty(cfg)
    cfg = struct();
end

warning('runInjTest:Deprecated', ...
    ['Evaluation/tests has been superseded by Evaluation/Injection. ', ...
    'Forwarding to runInjectionStudy with compatible defaults where possible.']);

results = runInjectionStudy(mapLegacyConfig(cfg));
end

function cfg_out = mapLegacyConfig(cfg_in)
cfg_out = cfg_in;

if ~isfield(cfg_in, 'scenarios')
    cfg_out = defaultInjectionConfig();
end

if isfield(cfg_in, 'tc')
    cfg_out.scenarios(1).modelSpec.tc = cfg_in.tc;
end
if isfield(cfg_in, 'source_dataset_file') && ~isempty(cfg_in.source_dataset_file)
    cfg_out.scenarios(1).source_dataset.dataset_file = cfg_in.source_dataset_file;
end
if isfield(cfg_in, 'esc_model_file') && ~isempty(cfg_in.esc_model_file)
    cfg_out.scenarios(1).modelSpec.esc_model_file = cfg_in.esc_model_file;
end
if isfield(cfg_in, 'rom_file') && ~isempty(cfg_in.rom_file)
    cfg_out.scenarios(1).modelSpec.rom_model_file = cfg_in.rom_file;
end
if isfield(cfg_in, 'tuning') && ~isempty(cfg_in.tuning)
    cfg_out.scenarios(1).estimatorSetSpec.tuning = cfg_in.tuning;
end
if isfield(cfg_in, 'Summaryfigs')
    cfg_out.scenarios(1).benchmarkFlags.Summaryfigs = cfg_in.Summaryfigs;
end
if isfield(cfg_in, 'SOCfigs')
    cfg_out.scenarios(1).benchmarkFlags.SOCfigs = cfg_in.SOCfigs;
end
if isfield(cfg_in, 'Vfigs')
    cfg_out.scenarios(1).benchmarkFlags.Vfigs = cfg_in.Vfigs;
end
if isfield(cfg_in, 'Biasfigs')
    cfg_out.scenarios(1).benchmarkFlags.Biasfigs = cfg_in.Biasfigs;
end
if isfield(cfg_in, 'R0figs')
    cfg_out.scenarios(1).benchmarkFlags.R0figs = cfg_in.R0figs;
end
if isfield(cfg_in, 'InnovationACFPACFfigs')
    cfg_out.scenarios(1).benchmarkFlags.InnovationACFPACFfigs = cfg_in.InnovationACFPACFfigs;
end
if isfield(cfg_in, 'regenerate_test_data')
    overwrite_value = cfg_in.regenerate_test_data;
else
    overwrite_value = true;
end

if isfield(cfg_in, 'test_case') && ~isempty(cfg_in.test_case)
    case_cfg = struct();
    switch lower(cfg_in.test_case)
        case 'noise'
            case_cfg.name = 'noise';
            case_cfg.mode = 'noise';
            noise_cfg = getFieldOr(cfg_in, 'noise_cfg', struct());
            case_cfg.voltage_std_mv = getFieldOr(noise_cfg, 'voltage_std_mv', 15);
            case_cfg.current_error_percent = getFieldOr(noise_cfg, 'current_error_percent', 5);
            case_cfg.random_seed = getFieldOr(noise_cfg, 'random_seed', []);
            case_cfg.overwrite = overwrite_value;

        case {'fault', 'perturbance'}
            case_cfg.name = 'perturbance';
            case_cfg.mode = 'perturbance';
            fault_cfg = getFieldOr(cfg_in, 'fault_cfg', struct());
            case_cfg.current_gain = getFieldOr(fault_cfg, 'current_gain', 1.1);
            case_cfg.current_offset_a = getFieldOr(fault_cfg, 'current_offset_a', 0.1);
            case_cfg.voltage_gain_fault = mapVoltageGain(fault_cfg);
            case_cfg.voltage_offset_mv = getFieldOr(fault_cfg, 'voltage_offset_mv_range', 1);
            case_cfg.random_seed = getFieldOr(fault_cfg, 'random_seed', []);
            case_cfg.overwrite = overwrite_value;

        otherwise
            error('runInjTest:BadTestCase', ...
                'cfg.test_case must be "noise", "fault", or "perturbance".');
    end

    cfg_out.scenarios(1).injection_cases = case_cfg;
end
end

function voltage_gain = mapVoltageGain(fault_cfg)
if isfield(fault_cfg, 'voltage_gain_fault') && ~isempty(fault_cfg.voltage_gain_fault)
    voltage_gain = fault_cfg.voltage_gain_fault;
elseif isfield(fault_cfg, 'voltage_gain_equiv_mv') && ~isempty(fault_cfg.voltage_gain_equiv_mv)
    voltage_gain = (fault_cfg.voltage_gain_equiv_mv / 1000) / 3.6;
else
    voltage_gain = 6e-4;
end
end

function value = getFieldOr(s, field_name, default_value)
if isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end
