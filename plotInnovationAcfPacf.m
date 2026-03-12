function plotInnovationAcfPacf(innovationSeries, labels, maxLag, figureTitle)
% plotInnovationAcfPacf Plot ACF/PACF for one or more innovation signals.
%   plotInnovationAcfPacf(nu, name)
%   plotInnovationAcfPacf({nu1,nu2,...}, {'EKF','SPKF',...}, maxLag, title)
%
% Inputs:
%   innovationSeries  Vector or cell array of vectors containing pre-fit
%                     innovations (nu_k = y_k - yhat_{k|k-1}).
%   labels            Name or cell array of names for each series.
%   maxLag            Max lag for ACF/PACF bars (default: min(60, floor(N/4))).
%   figureTitle       Figure name/title.

if nargin < 1 || isempty(innovationSeries)
    error('plotInnovationAcfPacf:MissingInput', 'innovationSeries is required.');
end

if ~iscell(innovationSeries)
    innovationSeries = {innovationSeries};
end
nSeries = numel(innovationSeries);

if nargin < 2 || isempty(labels)
    labels = arrayfun(@(k) sprintf('Series %d', k), 1:nSeries, 'UniformOutput', false);
elseif ~iscell(labels)
    labels = {labels};
end

if numel(labels) ~= nSeries
    error('plotInnovationAcfPacf:BadLabels', 'labels must match number of innovation series.');
end

if nargin < 3 || isempty(maxLag)
    maxLag = [];
end

if nargin < 4 || isempty(figureTitle)
    figureTitle = 'Innovation ACF/PACF';
end

figure('Name', figureTitle, 'NumberTitle', 'off');
tiledlayout(nSeries, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:nSeries
    nu = innovationSeries{i};
    if isempty(nu)
        nu = NaN;
    end
    nu = nu(:);
    nu = nu(isfinite(nu));

    if isempty(nu)
        lagUsed = 1;
    elseif isempty(maxLag)
        lagUsed = max(1, min(60, floor(numel(nu) / 4)));
    else
        lagUsed = max(1, min(maxLag, numel(nu) - 1));
    end
    lagUsed = max(1, lagUsed);

    nexttile;
    if numel(nu) < 3
        text(0.1, 0.5, 'Insufficient data', 'Units', 'normalized');
        axis off;
    else
        [acfVals, acfLags] = computeAcf(nu, lagUsed);
        ci = 1.96 / sqrt(numel(nu));
        stem(acfLags, acfVals, 'filled', 'MarkerSize', 3);
        hold on;
        yline(ci, 'r--');
        yline(-ci, 'r--');
        hold off;
        xlim([0, lagUsed]);
        ylim([-1, 1]);
        grid on;
    end
    title(sprintf('%s - ACF', labels{i}), 'Interpreter', 'none');
    xlabel('Lag');
    ylabel('ACF');

    nexttile;
    if numel(nu) < 3
        text(0.1, 0.5, 'Insufficient data', 'Units', 'normalized');
        axis off;
    else
        pacfVals = computePacfLevinson(nu, lagUsed);
        ci = 1.96 / sqrt(numel(nu));
        stem(1:lagUsed, pacfVals, 'filled', 'MarkerSize', 3);
        hold on;
        yline(ci, 'r--');
        yline(-ci, 'r--');
        hold off;
        xlim([1, lagUsed]);
        ylim([-1, 1]);
        grid on;
    end
    title(sprintf('%s - PACF', labels{i}), 'Interpreter', 'none');
    xlabel('Lag');
    ylabel('PACF');
end

sgtitle(figureTitle, 'Interpreter', 'none');
end

function [acfVals, lags] = computeAcf(x, maxLag)
x = x(:);
x = x - mean(x);
n = numel(x);

lags = (0:maxLag).';
acfVals = NaN(maxLag + 1, 1);
if n < 2
    return;
end

gamma0 = (x' * x) / n;
if gamma0 <= eps
    acfVals(1) = 1;
    acfVals(2:end) = 0;
    return;
end

acfVals(1) = 1;
for lag = 1:maxLag
    acfVals(lag + 1) = (x(1:n-lag)' * x(1+lag:n) / n) / gamma0;
end
end

function pacfVals = computePacfLevinson(x, maxLag)
[acfVals, ~] = computeAcf(x, maxLag);
r = acfVals(:);

pacfVals = NaN(maxLag, 1);
phi = zeros(maxLag, maxLag);

for k = 1:maxLag
    if k == 1
        phi(1, 1) = r(2);
    else
        rhoForward = r(2:k);
        rhoBackward = r(k:-1:2);
        num = r(k + 1) - phi(k - 1, 1:k-1) * rhoBackward;
        den = 1 - phi(k - 1, 1:k-1) * rhoForward;
        if abs(den) < eps
            phi(k, k) = NaN;
        else
            phi(k, k) = num / den;
        end
        for j = 1:k-1
            phi(k, j) = phi(k - 1, j) - phi(k, k) * phi(k - 1, k - j);
        end
    end
    pacfVals(k) = phi(k, k);
end
end
