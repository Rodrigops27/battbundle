function [c_rate, step_id, time_s] = buildScript1NormalizedProfile(ts)
% buildScript1NormalizedProfile Legacy 90-to-10 script-1 current profile.
%
% Returns the profile in normalized C-rate form so callers can scale it by
% the tested cell capacity:
%   current_a = capacity_ah * c_rate
%
% Inputs
%   ts       Sample time in seconds. Default: 1
%
% Outputs
%   c_rate   Column vector, positive = discharge
%   step_id  Legacy step identifiers
%   time_s   Column vector time base

if nargin < 1 || isempty(ts)
    ts = 1;
end

c_rate = [];
step_id = [];
target_discharge_fraction = 0.90;

[c_rate, step_id] = appendSegment(c_rate, step_id, 0.00, 10 * 60, 1, ts);
[c_rate, step_id] = appendSegment(c_rate, step_id, 1.00, 0.10 * 3600, 2, ts);

while sum(max(c_rate, 0)) * ts / 3600 < target_discharge_fraction
    [c_rate, step_id] = appendSegment(c_rate, step_id, 0.50, 45, 3, ts);
    [c_rate, step_id] = appendSegment(c_rate, step_id, 0.00, 15, 4, ts);
    [c_rate, step_id] = appendSegment(c_rate, step_id, 1.00, 45, 5, ts);
    [c_rate, step_id] = appendSegment(c_rate, step_id, 0.00, 45, 6, ts);
    [c_rate, step_id] = appendSegment(c_rate, step_id, 1.50, 30, 3, ts);
    [c_rate, step_id] = appendSegment(c_rate, step_id, 0.00, 30, 4, ts);
    [c_rate, step_id] = appendSegment(c_rate, step_id, 0.25, 90, 5, ts);
    [c_rate, step_id] = appendSegment(c_rate, step_id, 0.00, 30, 6, ts);
    [c_rate, step_id] = appendSegment(c_rate, step_id, 0.75, 60, 3, ts);
    [c_rate, step_id] = appendSegment(c_rate, step_id, 0.00, 30, 8, ts);
end

discharge_fraction = cumsum(max(c_rate, 0)) * ts / 3600;
last_idx = find(discharge_fraction >= target_discharge_fraction, 1, 'first');
if isempty(last_idx)
    error('buildScript1NormalizedProfile:NoDischarge', ...
        'The generated script-1 profile did not reach the discharge target.');
end

c_rate = c_rate(1:last_idx);
step_id = step_id(1:last_idx);
[c_rate, step_id] = appendSegment(c_rate, step_id, 0.00, 10 * 60, 8, ts);

c_rate = c_rate(:);
step_id = step_id(:);
time_s = (0:numel(c_rate)-1).' * ts;
end

function [signal, step_id] = appendSegment(signal, step_id, level, duration_s, step_value, ts)
num_samples = max(1, round(duration_s / ts));
signal = [signal; level * ones(num_samples, 1)]; %#ok<AGROW>
step_id = [step_id; step_value * ones(num_samples, 1)]; %#ok<AGROW>
end
