function metrics = printEstimatorBiasMetrics(estimatorName, socError, voltageBiasError, innovationPre, innovationCov, numBootstrap, blockLength, alpha)
% printEstimatorBiasMetrics Print SOC/voltage bias and innovation diagnostics.
%   metrics = printEstimatorBiasMetrics(name, socError, vBiasErr, nuPre, Sk)
%   reports:
%     - Mean SOC Bias Error
%     - Mean Voltage Bias Error
%     - NIS (Normalized Innovation Squared), using pre-fit innovation
%     - Innovation lag-1 autocorrelation with block-bootstrap CI
%
% Inputs:
%   estimatorName      Display label for verbose output.
%   socError           SOC error vector (truth - estimate), in normalized SOC.
%   voltageBiasError   Voltage estimation error vector (truth - estimate), in V.
%   innovationPre      Pre-fit innovation vector nu_k = y_k - yhat_k|k-1, in V.
%   innovationCov      Predicted innovation covariance S_k, in V^2.
%   numBootstrap       Number of bootstrap resamples (default: 250).
%   blockLength        Bootstrap block length (default: max(5, round(N^(1/3)))).
%   alpha              Two-sided CI significance level (default: 0.05).

if nargin < 6 || isempty(numBootstrap)
    numBootstrap = 250;
end
if nargin < 7
    blockLength = [];
end
if nargin < 8 || isempty(alpha)
    alpha = 0.05;
end

if isstring(estimatorName)
    estimatorName = char(estimatorName);
end

metrics = struct( ...
    'meanSocBiasError', NaN, ...
    'meanVoltageBiasError', NaN, ...
    'meanNIS', NaN, ...
    'innovationLag1Autocorr', NaN, ...
    'innovationLag1CI', [NaN, NaN], ...
    'innovationLag1Significant', false, ...
    'innovationLag1Method', 'block-bootstrap-ci', ...
    'numBootstrap', numBootstrap, ...
    'blockLength', NaN, ...
    'alpha', alpha, ...
    'nSoc', 0, ...
    'nVoltage', 0, ...
    'nNIS', 0);

socError = socError(:);
validSoc = isfinite(socError);
metrics.nSoc = sum(validSoc);
if metrics.nSoc > 0
    metrics.meanSocBiasError = mean(socError(validSoc));
end

hasVoltageBias = nargin >= 3 && ~isempty(voltageBiasError);
if hasVoltageBias
    voltageBiasError = voltageBiasError(:);
    validVoltageBias = isfinite(voltageBiasError);
    metrics.nVoltage = sum(validVoltageBias);
    if metrics.nVoltage > 0
        metrics.meanVoltageBiasError = mean(voltageBiasError(validVoltageBias));
    end
end

hasInnovation = nargin >= 4 && ~isempty(innovationPre);
if hasInnovation
    innovationPre = innovationPre(:);
    validInnovation = isfinite(innovationPre);
    innovForCorr = innovationPre(validInnovation);
    if numel(innovForCorr) >= 3
        [rho, rhoCI, usedBlockLength] = lag1AutocorrCI(innovForCorr, numBootstrap, blockLength, alpha);
        metrics.innovationLag1Autocorr = rho;
        metrics.innovationLag1CI = rhoCI;
        metrics.blockLength = usedBlockLength;
        metrics.innovationLag1Significant = all(isfinite(rhoCI)) && (rhoCI(1) > 0 || rhoCI(2) < 0);
    end

    if nargin >= 5 && ~isempty(innovationCov)
        innovationCov = innovationCov(:);
        nCommon = min(numel(innovationPre), numel(innovationCov));
        innovCommon = innovationPre(1:nCommon);
        skCommon = innovationCov(1:nCommon);
        validNIS = isfinite(innovCommon) & isfinite(skCommon) & (skCommon > eps);
        metrics.nNIS = sum(validNIS);
        if metrics.nNIS > 0
            nis = (innovCommon(validNIS) .^ 2) ./ skCommon(validNIS);
            metrics.meanNIS = mean(nis);
        end
    end
end

fprintf('  %s:\n', estimatorName);
if isfinite(metrics.meanSocBiasError)
    fprintf('    Mean SOC Bias Error: %.4f %%\n', 100 * metrics.meanSocBiasError);
else
    fprintf('    Mean SOC Bias Error: n/a\n');
end

if ~hasVoltageBias
    fprintf('    Mean Voltage Bias Error: n/a\n');
else
    if isfinite(metrics.meanVoltageBiasError)
        fprintf('    Mean Voltage Bias Error: %.3f mV\n', 1000 * metrics.meanVoltageBiasError);
    else
        fprintf('    Mean Voltage Bias Error: n/a\n');
    end
end

if ~hasInnovation
    fprintf('    NIS (Normalized Innovation Squared): n/a\n');
    fprintf('    Innovation autocorrelation (lag-1): n/a\n');
    return;
end

if isfinite(metrics.meanNIS)
    fprintf('    NIS (pre-fit, nu_k'' * S_k^{-1} * nu_k): %.4f\n', metrics.meanNIS);
else
    fprintf('    NIS (pre-fit, nu_k'' * S_k^{-1} * nu_k): n/a\n');
end

if isfinite(metrics.innovationLag1Autocorr) && all(isfinite(metrics.innovationLag1CI))
    ciLabel = 'CI includes 0';
    if metrics.innovationLag1Significant
        ciLabel = 'CI excludes 0';
    end
    fprintf(['    Innovation autocorrelation (lag-1): %.4f ' ...
        '[95%% block-bootstrap CI: %.4f, %.4f; %s]\n'], ...
        metrics.innovationLag1Autocorr, metrics.innovationLag1CI(1), ...
        metrics.innovationLag1CI(2), ciLabel);
else
    fprintf('    Innovation autocorrelation (lag-1): n/a\n');
end

end

function [rho, rhoCI, blockLength] = lag1AutocorrCI(x, numBootstrap, blockLength, alpha)
x = x(:);
rho = lagAutocorr(x, 1);
rhoCI = [NaN, NaN];

n = numel(x);
if n < 3 || ~isfinite(rho)
    blockLength = NaN;
    return;
end

if isempty(blockLength)
    blockLength = max(5, round(n^(1/3)));
end
blockLength = max(2, min(blockLength, n));

bootRho = NaN(numBootstrap, 1);
for b = 1:numBootstrap
    idx = movingBlockBootstrapIndices(n, blockLength);
    bootRho(b) = lagAutocorr(x(idx), 1);
end

bootRho = bootRho(isfinite(bootRho));
if isempty(bootRho)
    return;
end
bootRho = sort(bootRho);
rhoCI = [sortedQuantile(bootRho, alpha / 2), sortedQuantile(bootRho, 1 - alpha / 2)];
end

function idx = movingBlockBootstrapIndices(n, blockLength)
numBlocks = ceil(n / blockLength);
maxStart = max(1, n - blockLength + 1);

idx = zeros(numBlocks * blockLength, 1);
cursor = 1;
for k = 1:numBlocks
    startIdx = randi(maxStart);
    idx(cursor:cursor + blockLength - 1) = startIdx:(startIdx + blockLength - 1);
    cursor = cursor + blockLength;
end
idx = idx(1:n);
end

function rho = lagAutocorr(x, lag)
if numel(x) <= lag
    rho = NaN;
    return;
end

x = x(:) - mean(x);
x0 = x(1:end-lag);
x1 = x(1+lag:end);
denom = sqrt(sum(x0 .^ 2) * sum(x1 .^ 2));
if denom <= eps
    rho = NaN;
else
    rho = sum(x0 .* x1) / denom;
end
end

function q = sortedQuantile(sortedData, p)
n = numel(sortedData);
if n < 1 || ~isfinite(p)
    q = NaN;
    return;
end

p = min(max(p, 0), 1);
qIdx = 1 + (n - 1) * p;
lo = floor(qIdx);
hi = ceil(qIdx);

if lo == hi
    q = sortedData(lo);
else
    q = sortedData(lo) + (qIdx - lo) * (sortedData(hi) - sortedData(lo));
end
end
