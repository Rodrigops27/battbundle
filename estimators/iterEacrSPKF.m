function [zk,v_pred,zkbnd,esckfData,v_predbnd] = iterEacrSPKF(vk,ik,Tk,deltat,esckfData)
% iterEacrSPKF ESC-SPKF with sensor autocorrelation treatment.
% Uses initESCSPKF data and internally augments state with one correlated
% sensor-noise state:
%   x_corr(k) = Af * x_corr(k-1) + w_corr(k-1)
% magnitude of the random-walk driving noise to be comparable to the measurement noise variance
% Output equation includes x_corr additively.

model = esckfData.model;

% One-time augmentation so initESCSPKF can be reused unchanged.
if ~isfield(esckfData, 'eacrInitialized') || ~esckfData.eacrInitialized
    esckfData = initializeEacrState(esckfData);
end

% Load cell model parameters
Q  = getParamESC('QParam',Tk,model);
G  = getParamESC('GParam',Tk,model);
M  = getParamESC('MParam',Tk,model);
M0 = getParamESC('M0Param',Tk,model);
RC = exp(-deltat./abs(getParamESC('RCParam',Tk,model)))';
R  = getParamESC('RParam',Tk,model)';
R0 = getParamESC('R0Param',Tk,model);
eta = getParamESC('etaParam',Tk,model);
if ik < 0, ik = ik * eta; end

% Data from initialization / previous step
I = esckfData.priorI;
SigmaX = esckfData.SigmaX;
xhat = esckfData.xhat;
Nx = esckfData.Nx;
Nw = esckfData.Nw;
Nv = esckfData.Nv;
Na = esckfData.Na;
Snoise = esckfData.Snoise;
Wc = esckfData.Wc;
irInd = esckfData.irInd;
hkInd = esckfData.hkInd;
socInd = esckfData.soc_estInd;
corrInd = esckfData.eacrCorrInd;
NwOrig = esckfData.eacrNwOrig;
Af = esckfData.eacrAf;

if abs(ik) > Q / 100
    esckfData.signIk = sign(ik);
end
signIk = esckfData.signIk;

% Step 1a-1: Create augmented covariance and sigma points
[sigmaXa, p] = chol(SigmaX, 'lower');
if p > 0
    warning('iterEacrSPKF:CholeskyRecovery', ...
        'Cholesky error. Recovering with diagonal covariance.');
    sigmaXa = diag(sqrt(max(abs(diag(SigmaX)), eps)));
end
sigmaXa = [real(sigmaXa), zeros(Nx, Nw + Nv); zeros(Nw + Nv, Nx), Snoise];
xhata = [xhat; zeros(Nw + Nv, 1)];
Xa = xhata(:, ones(1, 2 * Na + 1)) + ...
    esckfData.h * [zeros(Na, 1), sigmaXa, -sigmaXa];

% Step 1a-2: Time update
wk = Xa(Nx + 1:Nx + Nw, :);
Xx = stateEqn(Xa(1:Nx, :), I, wk);
xhat = Xx * esckfData.Wm;
xhat(hkInd) = min(1, max(-1, xhat(hkInd)));
xhat(socInd) = min(1.05, max(-0.05, xhat(socInd)));

% Step 1b: Error covariance time update
Xs = Xx - xhat(:, ones(1, 2 * Na + 1));
SigmaX = Xs * diag(Wc) * Xs';

% Step 1c: Output estimate
wk_state = wk(1:NwOrig, :);
Y = outputEqn(Xx, I + wk_state, Xa(Nx + Nw + 1:end, :), Tk, model);
yhat = Y * esckfData.Wm;

% Step 2a: Gain
Ys = Y - yhat(:, ones(1, 2 * Na + 1));
SigmaXY = Xs * diag(Wc) * Ys';
SigmaY = Ys * diag(Wc) * Ys';
L = SigmaXY / SigmaY;

% Step 2b: Measurement update
r = vk - yhat;
esckfData.lastInnovationPre = r;
esckfData.lastSk = max(real(SigmaY), eps);
if r^2 > 100 * SigmaY
    L(:,1) = 0;
    warning('10 std dev outlier');
end
xhat = xhat + L * r;
xhat(hkInd) = min(1, max(-1, xhat(hkInd)));
xhat(socInd) = min(1.05, max(-0.05, xhat(socInd)));

% Step 2c: Error covariance measurement update
SigmaX = SigmaX - L * SigmaY * L';
[~, S, V] = svd(SigmaX);
HH = V * S * V';
SigmaX = (SigmaX + SigmaX' + HH + HH') / 4;

if r^2 > 4 * SigmaY
    warning('2 std. devs. away, Bumping SigmaX');
    SigmaX(socInd, socInd) = SigmaX(socInd, socInd) * esckfData.Qbump;
end

% Save for next call
esckfData.priorI = ik;
esckfData.SigmaX = SigmaX;
esckfData.xhat = xhat;

% Outputs
zk = xhat(socInd);
zkbnd = 3 * sqrt(max(SigmaX(socInd, socInd), 0));
v_pred = outputEqn(xhat, ik, zeros(Nv, 1), Tk, model);
v_predbnd = 3 * sqrt(max(SigmaY, 0));

    function xnew = stateEqn(xold, current, xnoise)
        % xnoise = [process/current-noise; correlated-sensor-state-noise]
        w_state = xnoise(1:NwOrig, :);
        w_corr = xnoise(NwOrig + 1:end, :);

        current = current + w_state;
        current = reshape(current, 1, []);

        xnew = 0 * xold;
        xnew(irInd,:) = RC .* xold(irInd,:) + (1 - RC) .* current;
        Ah = exp(-abs(current * G * deltat / (3600 * Q)));
        xnew(hkInd,:) = Ah .* xold(hkInd,:) + (Ah - 1) .* sign(current);
        xnew(socInd,:) = xold(socInd,:) - current * deltat / (3600 * Q);
        xnew(corrInd,:) = Af .* xold(corrInd,:) + w_corr;
    end

    function yhat = outputEqn(xk, current, ynoise, T, modelIn)
        yhat = OCVfromSOCtemp(xk(socInd, :), T, modelIn);
        sik = -signIk;
        yhat = yhat + M * xk(hkInd, :) + M0 * sik;
        yhat = yhat - sum(R .* xk(irInd, :), 1) - R0 * current;
        yhat = yhat + xk(corrInd, :) + ynoise(1, :);
    end
end

function esckfData = initializeEacrState(esckfData)
% Extend ESC-SPKF state: x_aug = [x; x_corr]

Nx0 = esckfData.Nx;
Nw0 = esckfData.Nw;
Nv = esckfData.Nv;

if Nv ~= 1
    error('iterEacrSPKF:UnsupportedNy', ...
        'iterEacrSPKF currently supports scalar-voltage measurement only (Nv=1).');
end

if isfield(esckfData, 'eacrAf') && isscalar(esckfData.eacrAf)
    Af = esckfData.eacrAf;
else
    Af = 1; % random-walk default for correlated sensor-noise state
end

sigmaVproc = extractNoiseScalar(esckfData.SigmaV);

% Augment state and covariance
esckfData.xhat = [esckfData.xhat; 0];
esckfData.SigmaX = blkdiag(esckfData.SigmaX, sigmaVproc);

% Augment process noise: [existing SigmaW; SigmaV]
SigmaWvec = esckfData.SigmaW(:);
SigmaWaug = [SigmaWvec; sigmaVproc];
esckfData.SigmaW = SigmaWaug;
esckfData.Nw = numel(SigmaWaug);
esckfData.Nx = Nx0 + 1;
esckfData.Na = esckfData.Nx + esckfData.Nw + esckfData.Nv;

esckfData.Snoise = real(chol(diag([SigmaWaug(:); esckfData.SigmaV(:)]), 'lower'));

h = sqrt(3);
esckfData.h = h;
weight1 = (h * h - esckfData.Na) / (h * h);
weight2 = 1 / (2 * h * h);
esckfData.Wm = [weight1; weight2 * ones(2 * esckfData.Na, 1)];
esckfData.Wc = esckfData.Wm;

esckfData.eacrNwOrig = Nw0;
esckfData.eacrCorrInd = Nx0 + 1;
esckfData.eacrAf = Af;
esckfData.eacrInitialized = true;
end

function s = extractNoiseScalar(sigmaLike)
if isscalar(sigmaLike)
    s = sigmaLike;
else
    vec = sigmaLike(:);
    s = vec(1);
end
s = max(real(s), eps);
end
