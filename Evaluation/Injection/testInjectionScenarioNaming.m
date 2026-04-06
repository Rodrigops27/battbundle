function tests = testInjectionScenarioNaming
tests = functiontests(localfunctions);
end

function testDefaultConfigUsesCanonicalScenarioNames(testCase)
cfg = defaultInjectionConfig();
cases = cfg.scenarios(1).injection_cases;

verifyEqual(testCase, {cases.name}, ...
    {'additive_measurement_noise', 'sensor_gain_bias_fault'});
verifyEqual(testCase, {cases.mode}, ...
    {'additive_measurement_noise', 'sensor_gain_bias_fault'});
verifyEqual(testCase, {cases.dataset_family}, ...
    {'additive_measurement_noise', 'sensor_gain_bias_fault'});
verifyEqual(testCase, {cases.augmentation_type}, ...
    {'additive_measurement_noise', 'sensor_gain_bias_fault'});
end

function testCanonicalNoiseScenarioPreservesNoiseBehavior(testCase)
source = buildSourceDataset();

[dataset, metadata] = generateInjectedDataset(source, '', struct( ...
    'name', 'additive_measurement_noise', ...
    'mode', 'additive_measurement_noise', ...
    'dataset_family', 'additive_measurement_noise', ...
    'augmentation_type', 'additive_measurement_noise', ...
    'voltage_std_mv', 15, ...
    'current_error_percent', 5, ...
    'random_seed', 7));

verifyEqual(testCase, dataset.injection_case, 'additive_measurement_noise');
verifyEqual(testCase, dataset.injection_mode, 'additive_measurement_noise');
verifyEqual(testCase, metadata.mode, 'additive_measurement_noise');
verifyTrue(testCase, isfield(dataset, 'injected_voltage_noise_v'));
verifyTrue(testCase, isfield(dataset, 'injected_current_scale'));
verifyEqual(testCase, size(dataset.current_a), size(source.current_a));
verifyEqual(testCase, size(dataset.voltage_v), size(source.voltage_v));
end

function testCanonicalFaultScenarioPreservesFaultBehavior(testCase)
source = buildSourceDataset();

[dataset, metadata] = generateInjectedDataset(source, '', struct( ...
    'name', 'sensor_gain_bias_fault', ...
    'mode', 'sensor_gain_bias_fault', ...
    'dataset_family', 'sensor_gain_bias_fault', ...
    'augmentation_type', 'sensor_gain_bias_fault', ...
    'current_gain', 1.1, ...
    'current_offset_a', 0.1, ...
    'voltage_gain_fault', 6e-4, ...
    'voltage_offset_mv', 2, ...
    'random_seed', 11));

verifyEqual(testCase, dataset.injection_case, 'sensor_gain_bias_fault');
verifyEqual(testCase, dataset.injection_mode, 'sensor_gain_bias_fault');
verifyEqual(testCase, metadata.mode, 'sensor_gain_bias_fault');
verifyEqual(testCase, dataset.current_a, 1.1 * source.current_a(:) + 0.1, 'AbsTol', 1e-12);
verifyEqual(testCase, dataset.voltage_v, (1 + 6e-4) * source.voltage_v(:) + 0.002, 'AbsTol', 1e-12);
end

function testLegacyNoiseNameRejected(testCase)
verifyError(testCase, @() normalizeInjectionCaseConfig(struct('mode', 'noise')), ...
    'normalizeInjectionCaseConfig:InvalidScenarioName');
end

function testLegacyPerturbanceNameRejected(testCase)
verifyError(testCase, @() normalizeInjectionCaseConfig(struct('mode', 'perturbance')), ...
    'normalizeInjectionCaseConfig:InvalidScenarioName');
end

function testLegacyDatasetFamilyRejected(testCase)
verifyError(testCase, @() normalizeInjectionCaseConfig(struct( ...
    'mode', 'sensor_gain_bias_fault', ...
    'dataset_family', 'perturbance')), ...
    'normalizeInjectionCaseConfig:NonCanonicalIdentifier');
end

function source = buildSourceDataset()
source = struct();
source.name = 'unit_test_source';
source.time_s = (0:4).';
source.current_a = [1.0; 2.0; 3.0; 4.0; 5.0];
source.voltage_v = [3.10; 3.15; 3.20; 3.25; 3.30];
source.soc_true = [0.90; 0.80; 0.70; 0.60; 0.50];
end
