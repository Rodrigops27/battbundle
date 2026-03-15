function noisyDataset = perturbInputDS(dataset, voltageStdMv, currentErrorPercent, varargin)
% perturbInputDS Inject artificial sensor error into a dataset.
%
% Inputs:
%   dataset              Struct with at least current_a and voltage_v.
%   voltageStdMv         Target standard deviation of a zero-mean uniform
%                        voltage perturbation, in mV.
%   currentErrorPercent  Uniform multiplicative current error bound, in %.
%                        Example: 5 means samplewise factor in [0.95, 1.05].
%   varargin             Optional name/value:
%                          'RandomSeed' scalar used to seed rng before
%                                       drawing the perturbations.
%
% Output:
%   noisyDataset         Copy of dataset with perturbed current_a and
%                        voltage_v plus metadata fields describing the
%                        injection.

if nargin < 3
    error('perturbInputDS:BadInput', ...
        'Use perturbInputDS(dataset, voltageStdMv, currentErrorPercent).');
end

opts = parseOptions(varargin{:});

required = {'current_a', 'voltage_v'};
for idx = 1:numel(required)
    if ~isfield(dataset, required{idx}) || isempty(dataset.(required{idx}))
        error('perturbInputDS:MissingField', 'Dataset.%s is required.', required{idx});
    end
end

if ~isscalar(voltageStdMv) || ~isfinite(voltageStdMv) || voltageStdMv < 0
    error('perturbInputDS:BadVoltageStd', 'voltageStdMv must be a nonnegative scalar.');
end
if ~isscalar(currentErrorPercent) || ~isfinite(currentErrorPercent) || currentErrorPercent < 0
    error('perturbInputDS:BadCurrentError', 'currentErrorPercent must be a nonnegative scalar.');
end

noisyDataset = dataset;
noisyDataset.voltage_v_true = dataset.voltage_v(:);
noisyDataset.current_a_true = dataset.current_a(:);

if ~isempty(opts.RandomSeed)
    rng(opts.RandomSeed);
end

sigma_v = voltageStdMv / 1000;
voltage_half_range = sqrt(3) * sigma_v;
voltage_noise = voltage_half_range * (2 * rand(size(noisyDataset.voltage_v_true)) - 1);

current_scale = 1 + (currentErrorPercent / 100) * (2 * rand(size(noisyDataset.current_a_true)) - 1);

noisyDataset.voltage_v = noisyDataset.voltage_v_true + voltage_noise;
noisyDataset.current_a = noisyDataset.current_a_true .* current_scale;

noisyDataset.injected_voltage_noise_v = voltage_noise;
noisyDataset.injected_current_scale = current_scale;
noisyDataset.injected_voltage_std_mv = voltageStdMv;
noisyDataset.injected_current_error_percent = currentErrorPercent;
if ~isempty(opts.RandomSeed)
    noisyDataset.injected_random_seed = opts.RandomSeed;
end
noisyDataset.injected_distribution = 'uniform';
noisyDataset.voltage_name = 'Injected';
end

function opts = parseOptions(varargin)
p = inputParser;
p.FunctionName = 'perturbInputDS';
addParameter(p, 'RandomSeed', [], @(x) isempty(x) || (isscalar(x) && isnumeric(x) && isfinite(x)));
parse(p, varargin{:});
opts = p.Results;
end
