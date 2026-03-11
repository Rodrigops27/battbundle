function metrics = printEstimatorBiasMetrics(estimatorName, socError, voltageInnovation, voltageBound, numBootstrap, blockLength, alpha)
% printEstimatorBiasMetrics Print SOC/voltage bias and innovation diagnostics.
%   metrics = printEstimatorBiasMetrics(name, socError, vInnov, vBound)
%   reports:
%     - Mean SOC Bias Error
%     - Mean Voltage Bias Error
%     - NIS (Normalized Innovation Squared)
%     - Innovation lag-1 autocorrelation with block-bootstrap CI
%
% Inputs:
%   estimatorName      Display label for verbose output.
%   socError           SOC error vector (truth - estimate), in normalized SOC.
%   voltageInnovation  Voltage innovation/error vector (truth - estimate), in V.
%   voltageBound       3-sigma voltage innovation bound vector, in V.
%   numBootstrap       Number of bootstrap resamples (default: 250).
%   blockLength        Bootstrap block length (default: max(5, round(N^(1/3)))).
%   alpha              Two-sided CI significance level (default: 0.05).

if nargin < 5 || isempty(numBootstrap)
    numBootstrap = 250;
end
if nargin < 6
    blockLength = [];
end
if nargin < 7 || isempty(alpha)
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

hasVoltage = nargin >= 3 && ~isempty(voltageInnovation);
if hasVoltage
    voltageInnovation = voltageInnovation(:);
    validVoltage = isfinite(voltageInnovation);
    metrics.nVoltage = sum(validVoltage);
    if metrics.nVoltage > 0
        metrics.meanVoltageBiasError = mean(voltageInnovation(validVoltage));
    end

    if nargin >= 4 && ~isempty(voltageBound)
        voltageBound = voltageBound(:);
        nCommon = min(numel(voltageInnovation), numel(voltageBound));
        innovCommon = voltageInnovation(1:nCommon);
        sigma2 = (voltageBound(1:nCommon) ./ 3) .^ 2;

        validNIS = isfinite(innovCommon) & isfinite(sigma2) & (sigma2 > eps);
        metrics.nNIS = sum(validNIS);
        if metrics.nNIS > 0
            nis = (innovCommon(validNIS) .^ 2) ./ sigma2(validNIS);
            metrics.meanNIS = mean(nis);
        end
    end

    innovForCorr = voltageInnovation(validVoltage);
    if numel(innovForCorr) >= 3
        [rho, rhoCI, usedBlockLength] = lag1AutocorrCI(innovForCorr, numBootstrap, blockLength, alpha);
        metrics.innovationLag1Autocorr = rho;
        metrics.innovationLag1CI = rhoCI;
        metrics.blockLength = usedBlockLength;
        metrics.innovationLag1Significant = all(isfinite(rhoCI)) && (rhoCI(1) > 0 || rhoCI(2) < 0);
    end
end

fprintf('  %s:\n', estimatorName);
if isfinite(metrics.meanSocBiasError)
    fprintf('    Mean SOC Bias Error: %.4f %%\n', 100 * metrics.meanSocBiasError);
else
    fprintf('    Mean SOC Bias Error: n/a\n');
end

if ~hasVoltage
    fprintf('    Mean Voltage Bias Error: n/a (no voltage innovation)\n');
    fprintf('    NIS (Normalized Innovation Squared): n/a\n');
    fprintf('    Innovation autocorrelation (lag-1): n/a\n');
    return;
end

if isfinite(metrics.meanVoltageBiasError)
    fprintf('    Mean Voltage Bias Error: %.3f mV\n', 1000 * metrics.meanVoltageBiasError);
else
    fprintf('    Mean Voltage Bias Error: n/a\n');
end

if isfinite(metrics.meanNIS)
    fprintf('    NIS (Normalized Innovation Squared): %.4f\n', metrics.meanNIS);
else
    fprintf('    NIS (Normalized Innovation Squared): n/a\n');
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
