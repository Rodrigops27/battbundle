function [M, match, Puni, Quni, info] = middleCurvePolylineDtw(P, Q, opts)
% middleCurvePolylineDtw DTW-based midpoint centerline between two polylines.
%
% Inputs:
%   P, Q  [N x 2], [M x 2] sampled 2D polylines
%   opts  Optional struct:
%         .nResample     default 300
%         .bandFrac      default 0.15
%         .interpMethod  default 'pchip'
%         .flipSecond    default true
%         .preSmooth     default false
%         .smoothMethod  default 'movmean'
%         .smoothWindow  default 7
%         .finalResample default true
%
% Outputs:
%   M      Final middle curve
%   match  DTW index pairs into Puni and Quni
%   Puni   Resampled P
%   Quni   Resampled Q
%   info   Diagnostic struct

if nargin < 3
  opts = struct();
end
if ~isfield(opts, 'nResample'),     opts.nResample = 300; end
if ~isfield(opts, 'bandFrac'),      opts.bandFrac = 0.15; end
if ~isfield(opts, 'interpMethod'),  opts.interpMethod = 'pchip'; end
if ~isfield(opts, 'flipSecond'),    opts.flipSecond = true; end
if ~isfield(opts, 'preSmooth'),     opts.preSmooth = false; end
if ~isfield(opts, 'smoothMethod'),  opts.smoothMethod = 'movmean'; end
if ~isfield(opts, 'smoothWindow'),  opts.smoothWindow = 7; end
if ~isfield(opts, 'finalResample'), opts.finalResample = true; end

validateattributes(P, {'double','single'}, {'2d','ncols',2,'nonempty'});
validateattributes(Q, {'double','single'}, {'2d','ncols',2,'nonempty'});

if exist('dtw', 'file') ~= 2
  error('middleCurvePolylineDtw:MissingDtw', ...
    'MATLAB function dtw() is required for middleCurvePolylineDtw.');
end

P = removeConsecutiveDuplicates(P);
Q = removeConsecutiveDuplicates(Q);

if size(P,1) < 2 || size(Q,1) < 2
  error('middleCurvePolylineDtw:TooFewPoints', ...
    'Each polyline must contain at least two distinct points.');
end

flippedCost = inf;
if opts.flipSecond
  directCost = norm(P(1,:) - Q(1,:)) + norm(P(end,:) - Q(end,:));
  flippedCost = norm(P(1,:) - Q(end,:)) + norm(P(end,:) - Q(1,:));
  if flippedCost < directCost
    Q = flipud(Q);
  end
end

u = linspace(0, 1, opts.nResample).';
Puni = resamplePolylineArc(P, u, opts.interpMethod);
Quni = resamplePolylineArc(Q, u, opts.interpMethod);

if opts.preSmooth
  Puni = smoothdata(Puni, 1, opts.smoothMethod, opts.smoothWindow);
  Quni = smoothdata(Quni, 1, opts.smoothMethod, opts.smoothWindow);
end

maxsamp = max(1, round(opts.bandFrac * opts.nResample));
[dist, ix, iy] = dtw(Puni.', Quni.', maxsamp, 'euclidean');
match = [ix(:), iy(:)];

MidRaw = 0.5 * (Puni(ix,:) + Quni(iy,:));
MidRaw = removeConsecutiveDuplicates(MidRaw);

if opts.finalResample
  M = resamplePolylineArc(MidRaw, u, opts.interpMethod);
else
  M = MidRaw;
end

info = struct();
info.dist = dist;
info.avgPairDistance = mean(sqrt(sum((Puni(ix,:) - Quni(iy,:)).^2, 2)));
info.pathLength = numel(ix);
info.nResample = opts.nResample;
info.maxsamp = maxsamp;
info.P_length = polylineLength(P);
info.Q_length = polylineLength(Q);
info.Puni_length = polylineLength(Puni);
info.Quni_length = polylineLength(Quni);
info.M_length = polylineLength(M);
info.flippedQ = opts.flipSecond && (flippedCost < inf) && (flippedCost < directCost);
end

function X = removeConsecutiveDuplicates(X)
if size(X,1) <= 1
  return;
end
d = diff(X,1,1);
keep = [true; any(abs(d) > 0, 2)];
X = X(keep,:);
end

function L = polylineLength(X)
if size(X,1) < 2
  L = 0;
  return;
end
seg = diff(X,1,1);
L = sum(sqrt(sum(seg.^2,2)));
end

function Xq = resamplePolylineArc(X, uQuery, method)
if size(X,1) < 2
  error('middleCurvePolylineDtw:ResampleNeedsTwoPoints', ...
    'Need at least two points to resample a polyline.');
end

ds = sqrt(sum(diff(X,1,1).^2, 2));
s = [0; cumsum(ds)];
if s(end) <= 0
  error('middleCurvePolylineDtw:ZeroLength', ...
    'Polyline has zero total length.');
end
s = s / s(end);

methodLocal = method;
if strcmpi(methodLocal, 'pchip') && numel(s) < 4
  methodLocal = 'linear';
end

xq = interp1(s, X(:,1), uQuery, methodLocal, 'extrap');
yq = interp1(s, X(:,2), uQuery, methodLocal, 'extrap');
Xq = [xq, yq];
end
