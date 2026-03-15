% script OMTdynId.m
%   Identifies a 25 degC ESC dynamic model for the OMTLIFE 8 Ah cell using
%   the measured Bus_CoreBattery current and voltage profile directly.
%
%   Unlike processDynamic.m, this script does not require the legacy
%   script1/script2/script3 laboratory protocol. It fits two RC pairs,
%   hysteresis, and R0 on one arbitrary measured profile.

clearvars
close all
clc

script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(script_dir);

addpath(repo_root);
addpath(genpath(fullfile(script_dir,'ModelMgmt')));
addpath(genpath(fullfile(repo_root,'utility')));

fprintf('\n');
fprintf('================================================================\n');
fprintf('  OMTLIFE ESC Dynamic Identification\n');
fprintf('================================================================\n\n');

%% SETTINGS
tc_test = 25;                       % Assumed test temperature [degC]
target_ts = 1;                     % Resample profile to 1 s
numpoles = 2;                      % Two RC pairs
do_hysteresis = true;              % Fit hysteresis
save_plots = false;

profile_file = fullfile(script_dir,'Datasets','OMTLIFE8AHC-HP', ...
    'Bus_CoreBatteryData_Data.mat');
ocv_model_file = fullfile(script_dir,'OMTLIFEmodel-ocv-diag.mat');
output_file = fullfile(script_dir,'OMTLIFEmodel.mat');

cfg = struct();
cfg.current_sign = [];             % Set to +1 or -1 to override auto orientation
cfg.source_capacity_ah = [];       % Optional override if source file does not encode capacity
cfg.original_capacity_ah = [];     % Alternate capacity override

%% LOAD OCV MODEL
fprintf('Step 1: Load OCV model\n');
ocv_src = load(ocv_model_file);
if isfield(ocv_src,'model')
    model = ocv_src.model;
else
    error('OMTdynId:MissingOCVModel', ...
        'Expected variable "model" in %s.', ocv_model_file);
end

if ~isfield(model,'QParam') || isempty(model.QParam)
    error('OMTdynId:MissingCapacity', ...
        'The OCV model must contain QParam.');
end
fprintf('  OCV model: %s\n', ocv_model_file);
fprintf('  Capacity from OCV model: %.3f Ah\n', double(model.QParam));

%% LOAD AND PREPARE MEASURED PROFILE
fprintf('\nStep 2: Load Bus CoreBattery profile\n');
profile = loadBusCoreBatteryProfile(profile_file);
[source_capacity_ah, capacity_source] = resolveSourceCapacity(profile, cfg, model);
[current_a, current_sign, sign_source] = orientCurrentToDischargePositive( ...
    profile.current_a, profile.time_s, profile.soc_ref, cfg);
profile.current_a = current_a(:);
profile = resampleProfile(profile, target_ts);

meas_current_a = profile.current_a(:);
meas_voltage_v = profile.voltage_v(:);
meas_time_s = profile.time_s(:);
meas_soc_ref = profile.soc_ref(:);

valid = isfinite(meas_current_a) & isfinite(meas_voltage_v);
if nnz(valid) < 100
    error('OMTdynId:TooFewSamples', ...
        'Not enough valid current/voltage samples after cleanup.');
end
meas_current_a = meas_current_a(valid);
meas_voltage_v = meas_voltage_v(valid);
meas_time_s = meas_time_s(valid);
if ~isempty(meas_soc_ref)
    meas_soc_ref = meas_soc_ref(valid);
end
meas_time_s = meas_time_s - meas_time_s(1);

z0 = determineInitialSoc(meas_voltage_v, meas_current_a, meas_soc_ref, tc_test, model);
fprintf('  Samples used: %d\n', numel(meas_current_a));
fprintf('  Current orientation: %s (multiplier %.0f)\n', sign_source, current_sign);
fprintf('  Source capacity: %.3f Ah (%s)\n', source_capacity_ah, capacity_source);
fprintf('  Initial SOC for Coulomb counting: %.2f %%\n', 100 * z0);

%% FIT DYNAMIC MODEL
fprintf('\nStep 3: Fit ESC dynamic parameters\n');
fprintf('  Looking for %d RC poles, hysteresis = %d\n', numpoles, do_hysteresis);

model.temps = tc_test;
model.QParam = double(source_capacity_ah);
if ~isfield(model,'etaParam') || isempty(model.etaParam)
    model.etaParam = 1;
end

profile_fit = struct();
profile_fit.current_a = meas_current_a(:);
profile_fit.voltage_v = meas_voltage_v(:);
profile_fit.time_s = meas_time_s(:);
profile_fit.ts = target_ts;
profile_fit.z0 = z0;

[model, fit] = fitDynamicModel(profile_fit, model, tc_test, numpoles, do_hysteresis);
fprintf('  gamma = %.6f\n', model.GParam);
fprintf('  R0 = %.6f ohm\n', model.R0Param);
fprintf('  R = [%s] ohm\n', sprintf('%.6f ', model.RParam));
fprintf('  tau = [%s] s\n', sprintf('%.2f ', model.RCParam));
fprintf('  M0 = %.6f V, M = %.6f V\n', model.M0Param, model.MParam);
fprintf('  RMS error = %.2f mV\n', fit.rmse_v * 1000);

%% VALIDATE WITH SIMCELL
fprintf('\nStep 4: Validate fitted model with simCell\n');
[vk, irk, hk, zk, sik, ocv_trace] = simCell(meas_current_a, tc_test, target_ts, ...
    model, z0, zeros(numpoles,1), 0); %#ok<ASGLU>
vk = vk(:);
zk = zk(:);
ocv_trace = ocv_trace(:);

verr = meas_voltage_v - vk;
valid_rmse = fit.valid_idx(:) & isfinite(verr);
if ~any(valid_rmse)
    valid_rmse = isfinite(verr);
end
rmse_check = sqrt(mean(verr(valid_rmse).^2));
fprintf('  simCell RMS check = %.2f mV\n', rmse_check * 1000);

%% SAVE MODEL
fprintf('\nStep 5: Save model\n');
fit_summary = struct();
fit_summary.profile_file = profile.profile_file;
fit_summary.profile_name = profile.profile_name;
fit_summary.source_capacity_ah = source_capacity_ah;
fit_summary.capacity_source = capacity_source;
fit_summary.current_sign_multiplier = current_sign;
fit_summary.current_sign_source = sign_source;
fit_summary.sample_time_s = target_ts;
fit_summary.initial_soc = z0;
fit_summary.rmse_v = fit.rmse_v;
fit_summary.rmse_v_simcell = rmse_check;
fit_summary.valid_idx = fit.valid_idx;
fit_summary.time_s = meas_time_s;
fit_summary.current_a = meas_current_a;
fit_summary.voltage_v = meas_voltage_v;
fit_summary.voltage_est_v = vk;
fit_summary.ocv_v = ocv_trace;
fit_summary.soc_cc = zk;
fit_summary.soc_ref = meas_soc_ref;

save(output_file,'model','fit_summary');
fprintf('  Saved to: %s\n', output_file);

%% PLOTS
fprintf('\nStep 6: Plot validation\n');
figure('Name','OMTLIFE Dynamic Identification','Color','w');
tiledlayout(3,1,'TileSpacing','compact','Padding','compact');

nexttile
plot(meas_time_s/60, meas_voltage_v, 'k', 'LineWidth', 1.1); hold on
plot(meas_time_s/60, vk, 'LineWidth', 1.1);
ylabel('Voltage (V)');
title(sprintf('Measured vs ESC fit at %d degC', tc_test));
legend('Measured', 'ESC fit', 'Location', 'best');
grid on

nexttile
plot(meas_time_s/60, 100 * zk, 'LineWidth', 1.1); hold on
if ~isempty(meas_soc_ref) && any(~isnan(meas_soc_ref))
    plot(meas_time_s/60, 100 * meas_soc_ref, '--', 'LineWidth', 1.0);
    legend('Coulomb-counted SOC', 'Dataset SOC', 'Location', 'best');
else
    legend('Coulomb-counted SOC', 'Location', 'best');
end
ylabel('SOC (%)');
grid on

nexttile
plot(meas_time_s/60, 1000 * verr, 'LineWidth', 1.0);
xlabel('Time (min)');
ylabel('Error (mV)');
grid on

if save_plots
    print(fullfile(script_dir,'OMTLIFE_dynamic_fit.png'),'-dpng','-r200');
end

fprintf('\n');
fprintf('================================================================\n');
fprintf('  Dynamic Identification Complete\n');
fprintf('================================================================\n\n');

function [model, fit] = fitDynamicModel(profile, model, tc_test, numpoles, do_hysteresis)
if exist('fminbnd.m','file')
    options = optimset('TolX',1e-8,'TolFun',1e-8, ...
        'MaxFunEval',100000,'MaxIter',1e6);
else
    options = [];
end

if do_hysteresis
    objective = @(gamma) dynamicCost(abs(gamma), profile, model, tc_test, numpoles, do_hysteresis);
    if ~isempty(options)
        best_gamma = abs(fminbnd(objective, 1, 250, options));
    else
        best_gamma = abs(gss(objective, 1, 250, 1e-8));
    end
else
    best_gamma = 0;
end

model.GParam = best_gamma;
[~, model, fit] = solveDynamicModel(profile, model, tc_test, numpoles, do_hysteresis);
end

function cost = dynamicCost(gamma, profile, model, tc_test, numpoles, do_hysteresis)
model.GParam = gamma;
try
    [cost, ~] = solveDynamicModel(profile, model, tc_test, numpoles, do_hysteresis);
catch
    cost = Inf;
end
end

function [cost, model, fit] = solveDynamicModel(profile, model, tc_test, numpoles, do_hysteresis)
ik = profile.current_a(:);
vk = profile.voltage_v(:);
ts = profile.ts;

Q = abs(getParamESC('QParam', tc_test, model));
eta = abs(getParamESC('etaParam', tc_test, model));
G = abs(getParamESC('GParam', tc_test, model));

etaik = ik;
etaik(ik < 0) = eta * etaik(ik < 0);
zk = profile.z0 - cumsum([0; etaik(1:end-1)]) * ts / (Q * 3600);
ocv = OCVfromSOCtemp(zk, tc_test, model);

h = zeros(size(ik));
sik = zeros(size(ik));
fac = exp(-abs(G * etaik * ts / (3600 * Q)));
for k = 2:length(ik)
    h(k) = fac(k-1) * h(k-1) - (1 - fac(k-1)) * sign(ik(k-1));
    sik(k) = -sign(ik(k));
    if abs(ik(k)) < Q / 100
        sik(k) = sik(k-1);
    end
end

verr = vk - ocv;
if numel(verr) < 25
    error('OMTdynId:ProfileTooShort', 'Profile is too short for dynamic identification.');
end

np = numpoles;
while true
    A = SISOsubid(-diff(verr), diff(etaik), np);
    eigA = eig(A);
    eigA = eigA(abs(imag(eigA)) < 1e-10);
    eigA = real(eigA);
    eigA = eigA(eigA > 0 & eigA < 1);
    okpoles = length(eigA);
    if okpoles >= numpoles
        break;
    end
    np = np + 1;
    if np > numpoles + 6
        error('OMTdynId:DynamicFitFailed', ...
            'Could not identify %d stable RC poles from the profile.', numpoles);
    end
end

RCfact = sort(eigA);
RCfact = RCfact(end-numpoles+1:end);
RC = -ts ./ log(RCfact);
vrcRaw = simulateRCBranches(RCfact, etaik);

if do_hysteresis
    H = [h, sik, -etaik, -vrcRaw];
    if exist('lsqnonneg.m','file')
        W = lsqnonneg(H, verr);
    else
        W = nnls(H, verr);
    end
    M = W(1);
    M0 = W(2);
    R0 = W(3);
    Rfact = W(4:end).';
else
    H = [-etaik, -vrcRaw];
    W = H \ verr;
    M = 0;
    M0 = 0;
    R0 = W(1);
    Rfact = W(2:end).';
end

model.R0Param = R0;
model.M0Param = M0;
model.MParam = M;
model.RCParam = RC(:).';
model.RParam = Rfact(:).';

vest = ocv + M * h + M0 * sik - R0 * etaik - vrcRaw * Rfact(:);
verr = vk - vest;

valid_idx = isfinite(verr) & zk >= 0.05 & zk <= 0.95;
if nnz(valid_idx) < max(50, ceil(0.1 * numel(verr)))
    valid_idx = isfinite(verr);
end

cost = sqrt(mean(verr(valid_idx).^2));
fit = struct();
fit.rmse_v = cost;
fit.zk = zk;
fit.ocv_v = ocv;
fit.voltage_est_v = vest;
fit.h = h;
fit.sik = sik;
fit.valid_idx = valid_idx;
fit.RCfact = RCfact(:).';
end

function vrc = simulateRCBranches(RCfact, etaik)
if exist('dlsim.m','file')
    vrc = dlsim(diag(RCfact), 1 - RCfact, eye(length(RCfact)), zeros(length(RCfact),1), etaik);
else
    vrc = zeros(length(etaik), length(RCfact));
    for k = 1:length(etaik)-1
        vrc(k+1,:) = RCfact(:)' .* vrc(k,:) + (1 - RCfact(:)') * etaik(k);
    end
end
end

function z0 = determineInitialSoc(voltage_v, current_a, soc_ref, tc_test, model)
if ~isempty(soc_ref)
    first_idx = find(isfinite(soc_ref), 1, 'first');
    if ~isempty(first_idx)
        z0 = clamp01(double(soc_ref(first_idx)));
        return;
    end
end

Q = abs(getParamESC('QParam', tc_test, model));
rest_idx = find(abs(current_a(:)) <= 0.02 * Q, min(60, numel(current_a)));
if isempty(rest_idx)
    v0 = voltage_v(1);
else
    v0 = median(voltage_v(rest_idx), 'omitnan');
end
z0 = clamp01(double(SOCfromOCVtemp(v0, tc_test, model)));
end

function x = clamp01(x)
x = min(max(x,0),1);
end

function profile = loadBusCoreBatteryProfile(profile_file)
if exist(profile_file, 'file') ~= 2
    error('OMTdynId:MissingProfile', ...
        'Profile file not found: %s', profile_file);
end

raw = load(profile_file);
primary = choosePrimaryNode(raw);

profile = struct();
profile.profile_file = profile_file;
[~, name, ext] = fileparts(profile_file);
profile.profile_name = [name, ext];

[current_raw, ~] = extractSignal(primary, {'Total_Current_A', 'Current_Vector_A'});
[voltage_raw, ~] = extractSignal(primary, {'Voltage_Vector_V', 'Total_Voltage_V'});
[soc_raw, ~] = extractSignal(primary, {'SOC_Vector_Percent'});
[capacity_raw, ~] = extractSignal(primary, ...
    {'capacity_ah', 'capacity', 'qparam', 'nominalcapacityah', 'ratedcapacityah'});

profile.current_a = coerceNumericVector(current_raw, false);
profile.voltage_v = normalizeOptionalSignal(voltage_raw, numel(profile.current_a), 'voltage');
profile.soc_ref = normalizeSocSignal(normalizeOptionalSignal(soc_raw, numel(profile.current_a), 'soc'));
profile.detected_capacity_ah = coerceNumericScalar(capacity_raw);

if isempty(profile.current_a)
    error('OMTdynId:MissingCurrent', 'Could not locate current signal in %s.', profile_file);
end
if isempty(profile.voltage_v)
    error('OMTdynId:MissingVoltage', 'Could not locate voltage signal in %s.', profile_file);
end

if isa(current_raw, 'timeseries')
    profile.time_s = normalizeTimeVector(current_raw.Time, numel(profile.current_a), 'current.Time');
else
    profile.time_s = (0:numel(profile.current_a)-1).';
end
end

function primary = choosePrimaryNode(raw)
names = fieldnames(raw);
if numel(names) == 1
    primary = raw.(names{1});
else
    primary = raw;
end
end

function [value, path_used] = extractSignal(node, selectors)
value = [];
path_used = '';
for idx = 1:numel(selectors)
    selector = selectors{idx};
    if isstruct(node) && isfield(node, selector)
        value = node.(selector);
        path_used = selector;
        return;
    end
end
end

function out = normalizeOptionalSignal(raw_value, n_expected, signal_name)
if isempty(raw_value)
    out = [];
    return;
end
out = coerceNumericVector(raw_value, false);
if isempty(out)
    out = [];
    return;
end
if numel(out) ~= n_expected
    error('OMTdynId:SignalLengthMismatch', ...
        'Source %s signal has %d samples, expected %d.', signal_name, numel(out), n_expected);
end
out = out(:);
end

function value = coerceNumericVector(raw_value, allow_scalar)
value = [];
if isempty(raw_value)
    return;
end
if isa(raw_value, 'timeseries')
    value = coerceTimeseriesData(raw_value, allow_scalar);
    return;
end
if isnumeric(raw_value)
    if isscalar(raw_value)
        if allow_scalar
            value = double(raw_value);
        end
    elseif isvector(raw_value)
        value = double(raw_value(:));
    end
end
end

function value = coerceNumericScalar(raw_value)
value = [];
if isempty(raw_value)
    return;
end
if isa(raw_value, 'timeseries')
    data = coerceTimeseriesData(raw_value, true);
    if isnumeric(data) && isscalar(data) && isfinite(data)
        value = double(data);
    end
    return;
end
if isnumeric(raw_value) && isscalar(raw_value) && isfinite(raw_value)
    value = double(raw_value);
end
end

function value = coerceTimeseriesData(ts_obj, allow_scalar)
value = [];
data = ts_obj.Data;
if isempty(data) || ~isnumeric(data)
    return;
end

data = double(data);
if isvector(data)
    value = data(:);
    if isscalar(value) && ~allow_scalar
        value = [];
    end
    return;
end

data = reshape(data, size(data, 1), []);
if size(data, 2) == 1
    value = data(:, 1);
elseif allow_scalar && numel(data) == 1
    value = data(1);
else
    value = mean(data, 2, 'omitnan');
end
end

function time_s = normalizeTimeVector(time_raw, n_expected, signal_name)
if isdatetime(time_raw)
    time_raw = seconds(time_raw(:) - time_raw(1));
elseif isduration(time_raw)
    time_raw = seconds(time_raw(:));
else
    time_raw = double(time_raw(:));
end
if numel(time_raw) ~= n_expected
    error('OMTdynId:TimeLengthMismatch', ...
        'Source %s vector has %d samples, expected %d.', signal_name, numel(time_raw), n_expected);
end
time_s = double(time_raw(:) - time_raw(1));
end

function soc = normalizeSocSignal(soc)
if isempty(soc)
    return;
end
soc = soc(:);
if any(abs(soc) > 1.5)
    soc = soc / 100;
end
soc = clamp01(soc);
end

function profile = resampleProfile(profile, ts)
time_s = profile.time_s(:);
if numel(time_s) < 2
    return;
end

[time_s, unique_idx] = unique(time_s, 'stable');
profile.current_a = profile.current_a(unique_idx);
profile.voltage_v = profile.voltage_v(unique_idx);
if ~isempty(profile.soc_ref)
    profile.soc_ref = profile.soc_ref(unique_idx);
end

dt = diff(time_s);
if all(abs(dt - ts) <= 1e-9)
    profile.time_s = time_s;
    return;
end

new_time = (time_s(1):ts:time_s(end)).';
profile.current_a = interp1(time_s, profile.current_a(:), new_time, 'previous', 'extrap');
profile.voltage_v = interp1(time_s, profile.voltage_v(:), new_time, 'linear', 'extrap');
if ~isempty(profile.soc_ref)
    profile.soc_ref = interp1(time_s, profile.soc_ref(:), new_time, 'linear', 'extrap');
    profile.soc_ref = normalizeSocSignal(profile.soc_ref);
end
profile.time_s = new_time(:);
end

function [source_capacity_ah, capacity_source] = resolveSourceCapacity(profile, cfg, model)
source_capacity_ah = [];
capacity_source = '';

if isfield(cfg,'source_capacity_ah') && ~isempty(cfg.source_capacity_ah)
    source_capacity_ah = double(cfg.source_capacity_ah);
    capacity_source = 'cfg.source_capacity_ah';
    return;
end
if isfield(cfg,'original_capacity_ah') && ~isempty(cfg.original_capacity_ah)
    source_capacity_ah = double(cfg.original_capacity_ah);
    capacity_source = 'cfg.original_capacity_ah';
    return;
end
if ~isempty(profile.detected_capacity_ah)
    source_capacity_ah = double(profile.detected_capacity_ah);
    capacity_source = 'dataset';
    return;
end

path_capacity = detectCapacityFromPath(profile.profile_file);
if ~isempty(path_capacity)
    source_capacity_ah = path_capacity;
    capacity_source = 'profile_path';
    return;
end

source_capacity_ah = double(model.QParam);
capacity_source = 'ocv_model';
end

function capacity_ah = detectCapacityFromPath(profile_file)
capacity_ah = [];
tokens = regexp(upper(profile_file), '(\d+(?:P\d+)?)AH', 'tokens', 'once');
if isempty(tokens)
    return;
end
capacity_ah = str2double(strrep(tokens{1}, 'P', '.'));
if ~isfinite(capacity_ah)
    capacity_ah = [];
end
end

function [current_a, sign_multiplier, sign_source] = orientCurrentToDischargePositive(current_a, time_s, soc_ref, cfg)
current_a = current_a(:);
sign_multiplier = 1;
sign_source = 'assumed_discharge_positive';

if isfield(cfg,'current_sign') && ~isempty(cfg.current_sign)
    sign_multiplier = sign(double(cfg.current_sign));
    if sign_multiplier == 0
        sign_multiplier = 1;
    end
    current_a = sign_multiplier * current_a;
    sign_source = 'cfg.current_sign';
    return;
end

if isempty(soc_ref) || all(isnan(soc_ref)) || numel(current_a) < 3
    return;
end

dt = diff(time_s(:));
dsoc = diff(soc_ref(:));
current_k = current_a(1:end-1);
valid = isfinite(dt) & dt > 0 & isfinite(dsoc) & isfinite(current_k) & abs(current_k) > 1e-9;
if ~any(valid)
    return;
end

alignment_score = sum(current_k(valid) .* (-dsoc(valid) ./ dt(valid)));
if alignment_score < 0
    sign_multiplier = -1;
end
current_a = sign_multiplier * current_a;
sign_source = 'auto_from_soc_trend';
end

function A = SISOsubid(y,u,n)
y = y(:).';
u = u(:).';
ny = length(y);
nu = length(u);
i = 2 * n;
twoi = 4 * n;

if ny ~= nu
    error('OMTdynId:SISOsubidSize', 'y and u must be same size.');
end
if (ny - twoi + 1) < twoi
    error('OMTdynId:SISOsubidLength', 'Not enough data points.');
end

j = ny - twoi + 1;
Y = zeros(twoi, j);
U = zeros(twoi, j);
for k = 1:2*i
    Y(k,:) = y(k:k+j-1);
    U(k,:) = u(k:k+j-1);
end

R = triu(qr([U;Y]'))';
R = R(1:4*i,1:4*i);

Rf = R(3*i+1:4*i,:);
Rp = [R(1:1*i,:); R(2*i+1:3*i,:)];
Ru = R(1*i+1:2*i,1:twoi);

Rfp = [Rf(:,1:twoi) - (Rf(:,1:twoi) / Ru) * Ru, Rf(:,twoi+1:4*i)];
Rpp = [Rp(:,1:twoi) - (Rp(:,1:twoi) / Ru) * Ru, Rp(:,twoi+1:4*i)];

if norm(Rpp(:,3*i-2:3*i), 'fro') < 1e-10
    Ob = (Rfp * pinv(Rpp')') * Rp;
else
    Ob = (Rfp / Rpp) * Rp;
end

WOW = [Ob(:,1:twoi) - (Ob(:,1:twoi) / Ru) * Ru, Ob(:,twoi+1:4*i)];
[Umat,S,~] = svd(WOW);
ss = diag(S);

U1 = Umat(:,1:n);
gam = U1 * diag(sqrt(ss(1:n)));
gamm = gam(1:(i-1),:);
gam_inv = pinv(gam);
gamm_inv = pinv(gamm);

Rhs = [gam_inv * R(3*i+1:4*i,1:3*i), zeros(n,1); R(i+1:twoi,1:3*i+1)];
Lhs = [gamm_inv * R(3*i+2:4*i,1:3*i+1); R(3*i+1:3*i+1,1:3*i+1)];
sol = Lhs / Rhs;
A = sol(1:n,1:n);
end

function X = gss(f,a,b,tol)
gr = (sqrt(5)+1)/2;
c = b - (b - a) / gr;
d = a + (b - a) / gr;
while abs(c - d) > tol
    if f(c) < f(d)
        b = d;
    else
        a = c;
    end
    c = b - (b - a) / gr;
    d = a + (b - a) / gr;
end
X = (b + a) / 2;
end

function [x,w,info] = nnls(C,d,opts)
[~,n] = size(C);
maxiter = 4*n;
P = false(n,1);
x = zeros(n,1);
z = x;
w = C' * d;
wsc0 = sqrt(sum(w.^2));
wsc = zeros(n,1);
tol = 3*eps;
accy = 1;
pn1 = 0;
pn2 = 0;
pn = zeros(1,n);

ind = true;
if nargin > 2
    if isfield(opts,'Tol')
        tol = opts.Tol;
        wsc(:) = wsc0 * tol;
    end
    if isfield(opts,'Accy')
        accy = opts.Accy;
    end
    if isfield(opts,'Iter')
        maxiter = opts.Iter;
    end
end

if accy < 2
    A = C' * C;
    b = C' * d;
    LL = zeros(0,0);
    lowtri = struct('LT',true);
    uptri = struct('UT',true);
end

if nargin > 2
    if isfield(opts,'Order') && ~islogical(opts.Order)
        pn1 = length(opts.Order);
        pn(1:pn1) = opts.Order;
        P(pn(1:pn1)) = true;
        ind = false;
    end
    if ~ind && accy < 2
        UU(1:pn1,1:pn1) = chol(A(pn(1:pn1),pn(1:pn1)));
        LL = UU';
    end
    pn2 = pn1;
end

iter = 0;
while true
    if ind && (all(P == true) || all(w(~P) <= wsc(~P)))
        if accy ~= 1
            break
        end
        accy = 2;
        ind = false;
    end

    if ind
        ind1 = find(~P);
        [~,ind2] = max(w(ind1) - wsc(ind1));
        ind1 = ind1(ind2);
        P(ind1) = true;
        pn2 = pn1 + 1;
        pn(pn2) = ind1;
    end

    while true
        iter = iter + 1;
        if iter >= 2*n
            if iter > maxiter
                error('OMTdynId:NNLSConvergence', ...
                    'nnls failed to converge in %d iterations.', iter);
            elseif mod(iter,n) == 0
                wsc = (wsc + wsc0 * tol) * 2;
            end
        end

        z(:) = 0;
        if accy >= 2
            z(P) = C(:,P) \ d;
        else
            for i = pn1+1:pn2
                i1 = i - 1;
                t = linsolve(LL, A(pn(1:i1),pn(i)), lowtri);
                AA = A(pn(i),pn(i));
                tt = AA - t' * t;
                if tt <= AA * tol
                    tt = 1e300;
                else
                    tt = sqrt(tt);
                end
                LL(i,1:i) = [t', tt];
                UU(1:i,i) = [t; tt];
            end

            t = linsolve(LL, b(pn(1:pn2)), lowtri);
            z(pn(1:pn2)) = linsolve(UU, t, uptri);
        end
        pn1 = pn2;

        if all(z(P) >= 0)
            x = z;
            if accy < 2
                w = b - A * x;
            else
                w = C' * (d - C * x);
            end
            wsc(P) = max(wsc(P), 2 * abs(w(P)));
            ind = true;
            break
        end

        ind1 = find(z < 0);
        [alpha,ind2] = min(x(ind1) ./ (x(ind1) - z(ind1) + realmin));
        ind1 = ind1(ind2);

        if x(ind1) == 0 && ind
            w = C' * (d - C * z);
            wsc(ind1) = (abs(w(ind1)) + wsc(ind1)) * 2;
        end
        P(ind1) = false;
        x = x - alpha * (x - z);

        pn1 = find(pn == ind1);
        pn(pn1:end) = [pn(pn1+1:end), 0];
        pn1 = pn1 - 1;
        pn2 = pn2 - 1;
        if accy < 2
            LL = LL(1:pn1,1:pn1);
            UU = UU(1:pn1,1:pn1);
        end
        ind = true;
    end
end

if nargout > 2
    info.iter = iter;
    info.wsc0 = wsc0 * eps;
    info.wsc = max(wsc);
    if nargin > 2 && isfield(opts,'Order')
        info.Order = pn(1:pn1);
    end
end
end
