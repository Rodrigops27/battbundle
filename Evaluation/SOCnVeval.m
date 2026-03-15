function varargout = SOCnVeval(dataset, kfData, iterFcn, varargin)
% SOCnVeval Evaluate SOC/voltage estimation performance on a dataset.
%
% Inputs:
%   dataset Struct with at least:
%       time_s, current_a, voltage_v, temperature_c, soc_true
%   kfData  Initialized filter data (from init function)
%   iterFcn Function handle with ESC-style signature:
%       [soc_k, v_k, soc_bnd_k, kfData, v_bnd_k] =
%           iterFcn(v_meas, i_meas, T_meas, dt, kfData)
%   varargin Optional name/value:
%       'ClipSoc'         (default true)
%       'EstimatorName'   (default from function handle)
%
% Output:
%   Single output:
%       results Struct:
%         rmse_soc, rmse_v, soc_est, v_est, soc_bnd, v_bnd, errors...
%   Multiple outputs:
%       [rmse_soc, rmse_v, soc_bnd, v_bnd, results]

opts = parseOptions(varargin{:});
validateInputs(dataset, iterFcn);
if isempty(opts.EstimatorName)
    opts.EstimatorName = func2str(iterFcn);
end

n = numel(dataset.time_s);
dt = inferDt(dataset);

soc_est = NaN(n, 1);
v_est = NaN(n, 1);
soc_bnd = NaN(n, 1);
v_bnd = NaN(n, 1);

if isfield(dataset, 'soc_cc') && numel(dataset.soc_cc) == n
    soc_est(1) = dataset.soc_cc(1);
elseif isfield(dataset, 'soc_true') && numel(dataset.soc_true) == n
    soc_est(1) = dataset.soc_true(1);
end
if isfield(dataset, 'voltage_v') && numel(dataset.voltage_v) == n
    v_est(1) = dataset.voltage_v(1);
end

for k = 2:n
    [soc_k, v_k, soc_bnd_k, kfData, v_bnd_k] = iterFcn( ...
        dataset.voltage_v(k), dataset.current_a(k), dataset.temperature_c(k), dt, kfData);

    if opts.ClipSoc
        soc_k = max(0, min(1, soc_k));
    end

    soc_est(k) = soc_k;
    v_est(k) = v_k;
    soc_bnd(k) = soc_bnd_k;
    v_bnd(k) = v_bnd_k;
end

soc_error = dataset.soc_true(:) - soc_est;
v_error = dataset.voltage_v(:) - v_est;

results = struct();
results.estimator_name = opts.EstimatorName;
results.dt = dt;
results.kfDataFinal = kfData;
results.soc_est = soc_est;
results.v_est = v_est;
results.soc_bnd = soc_bnd;
results.v_bnd = v_bnd;
results.soc_error = soc_error;
results.v_error = v_error;
results.rmse_soc = sqrt(mean(soc_error(~isnan(soc_error)).^2));
results.rmse_v = sqrt(mean(v_error(~isnan(v_error)).^2));
results.max_abs_soc_error = max(abs(soc_error(~isnan(soc_error))));
results.max_abs_v_error = max(abs(v_error(~isnan(v_error))));

if nargout <= 1
    varargout{1} = results;
else
    varargout{1} = results.rmse_soc;
    varargout{2} = results.rmse_v;
    varargout{3} = results.soc_bnd;
    varargout{4} = results.v_bnd;
    if nargout >= 5
        varargout{5} = results;
    end
end
end

function dt = inferDt(dataset)
if isfield(dataset, 'ts') && isscalar(dataset.ts)
    dt = dataset.ts;
    return;
end
if isfield(dataset, 'time_s') && numel(dataset.time_s) > 1
    dt = median(diff(dataset.time_s(:)));
    return;
end
error('SOCnVeval:MissingDt', 'Could not infer dt from dataset.');
end

function validateInputs(dataset, iterFcn)
requiredFields = {'time_s', 'current_a', 'voltage_v', 'temperature_c', 'soc_true'};
for i = 1:numel(requiredFields)
    f = requiredFields{i};
    if ~isfield(dataset, f)
        error('SOCnVeval:MissingField', 'Dataset missing required field: %s', f);
    end
end

n = numel(dataset.time_s);
if numel(dataset.current_a) ~= n || numel(dataset.voltage_v) ~= n || ...
        numel(dataset.temperature_c) ~= n || numel(dataset.soc_true) ~= n
    error('SOCnVeval:SizeMismatch', ...
        'Dataset vectors must have matching lengths for time/current/voltage/temperature/soc_true.');
end

if ~isa(iterFcn, 'function_handle')
    error('SOCnVeval:BadIterFcn', 'iterFcn must be a function handle.');
end
end

function opts = parseOptions(varargin)
p = inputParser;
p.FunctionName = 'SOCnVeval';
addParameter(p, 'ClipSoc', true, @(x)islogical(x) || isnumeric(x));
addParameter(p, 'EstimatorName', '', @(x)ischar(x) || (isstring(x) && isscalar(x)));
parse(p, varargin{:});

opts = p.Results;
opts.ClipSoc = logical(opts.ClipSoc);
opts.EstimatorName = char(opts.EstimatorName);
end
