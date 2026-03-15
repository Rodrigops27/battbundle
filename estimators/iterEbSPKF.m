function [zk,v_pred,zkbnd,esckfData,v_predbnd,ib,ibbnd] = iterEbSPKF(vk,ik,Tk,deltat,esckfData)
% iterEbSPKF Perform one ESC-SPKF update with augmented current-sensor bias.
% Inputs:
%   vk: Present measured (noisy) cell voltage
%   ik: Present measured (noisy) cell current
%   Tk: Present temperature
%   deltat: Sampling interval
%   esckfData: Data structure initialized by initESCSPKF and augmented with ib
%
% Output:
%   zk: SOC estimate for this time sample
%   zkbnd: 3-sigma SOC estimation bounds
%   ib: Current-bias estimate for this time sample
%   ibbnd: 3-sigma current-bias estimation bounds
%   esckfData: Data structure used to store persistent variables

model = esckfData.model;
% Load the cell model parameters
Q  = getParamESC('QParam',Tk,model);
G  = getParamESC('GParam',Tk,model);
M  = getParamESC('MParam',Tk,model);
M0 = getParamESC('M0Param',Tk,model);
RC = exp(-deltat./abs(getParamESC('RCParam',Tk,model)))';
R  = getParamESC('RParam',Tk,model)';
R0 = getParamESC('R0Param',Tk,model);
eta = getParamESC('etaParam',Tk,model);
if ik<0, ik=ik*eta; end

% Get data stored in spkfData structure
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

if ~isfield(esckfData, 'ibInd')
    error('iterEbSPKF:MissingBiasState', ...
        'esckfData must include ibInd and augmented state/noise dimensions.');
end
ibInd = esckfData.ibInd;

currentNoiseInd = 1;
if isfield(esckfData, 'currentNoiseInd')
    currentNoiseInd = esckfData.currentNoiseInd;
end
biasNoiseInd = Nw;
if isfield(esckfData, 'biasNoiseInd')
    biasNoiseInd = esckfData.biasNoiseInd;
end

if currentNoiseInd < 1 || currentNoiseInd > Nw || biasNoiseInd < 1 || biasNoiseInd > Nw
    error('iterEbSPKF:BadNoiseIndices', ...
        'currentNoiseInd and biasNoiseInd must be valid indices into process noise.');
end

iEffNow = ik - xhat(ibInd);
if abs(iEffNow) > Q / 100
    esckfData.signIk = sign(iEffNow);
end
signIk = esckfData.signIk;

% Step 1a-1: Create augmented SigmaX and xhat
[sigmaXa, p] = chol(SigmaX, 'lower');
if p > 0
    warning('iterEbSPKF:CholeskyRecovery', 'Cholesky error. Recovering with diagonal covariance.');
    sigmaXa = diag(sqrt(max(abs(diag(SigmaX)), eps)));
end
sigmaXa = [real(sigmaXa), zeros(Nx, Nw + Nv); zeros(Nw + Nv, Nx), Snoise];
xhata = [xhat; zeros(Nw + Nv, 1)];
% Step 1a-2: Calculate SigmaX points
Xa = xhata(:, ones(1, 2 * Na + 1)) + ...
    esckfData.h * [zeros(Na, 1), sigmaXa, -sigmaXa]; % to avoid "repmat" call

Xx = stateEqn(Xa(1:Nx, :), I, Xa(Nx + 1:Nx + Nw, :)); % Step 1a-3: Time update
xhat = Xx * esckfData.Wm;
xhat(hkInd) = min(1, max(-1, xhat(hkInd)));
xhat(socInd) = min(1.05, max(-0.05, xhat(socInd)));

% Step 1b: Error covariance time update
Xs = Xx - xhat(:, ones(1, 2 * Na + 1));   % to avoid "repmat" call
SigmaX = Xs * diag(Wc) * Xs';

% Step 1c: Output estimate
I = ik; yk = vk;
currentSigma = I + Xa(Nx + currentNoiseInd, :);
Y = outputEqn(Xx, currentSigma, Xa(Nx + Nw + 1:end, :), Tk, model);
yhat = Y * esckfData.Wm; % weighted output estimate yhat(k)

% Step 2a: Estimator gain matrix
Ys = Y - yhat(:, ones(1, 2 * Na + 1));
SigmaXY = Xs * diag(Wc) * Ys';
SigmaY = Ys * diag(Wc) * Ys';
SigmaY = max(real(SigmaY), eps);
L = SigmaXY / SigmaY;

% Step 2b: State estimate measurement update
r = yk - yhat;
esckfData.lastInnovationPre = r;
esckfData.lastSk = SigmaY;
if r^2 > 100 * SigmaY
    L(:, 1) = 0;
    warning('10 std dev outlier');
end
xhat = xhat + L * r;
xhat(socInd) = min(1.05, max(-0.05, xhat(socInd)));

% Step 2c: Error covariance measurement update
SigmaX = SigmaX - L * SigmaY * L';
[~, S, V] = svd(SigmaX);
HH = V * S * V';
SigmaX = (SigmaX + SigmaX' + HH + HH') / 4;

% Q-bump code
if r^2 > 4 * SigmaY  % bad voltage estimate by (2-sigmaY), bump Q
    warning('2 std. devs. away, Bumping SigmaX');
    SigmaX(socInd, socInd) = SigmaX(socInd, socInd) * esckfData.Qbump;
end

esckfData.priorI = ik;
esckfData.SigmaX = SigmaX;
esckfData.xhat = xhat;

zk = xhat(socInd);
zkbnd = 3 * sqrt(max(SigmaX(socInd, socInd), 0));
ib = xhat(ibInd);
ibbnd = 3 * sqrt(max(SigmaX(ibInd, ibInd), 0));
v_pred = outputEqn(xhat, ik, zeros(Nv, 1), Tk, model);
v_predbnd = 3 * sqrt(max(SigmaY, 0));

    function xnew = stateEqn(xold, current, xnoise)
        currentEff = current - xold(ibInd, :) + xnoise(currentNoiseInd, :);
        currentEff = reshape(currentEff, 1, []);

        xnew = 0*xold;
        xnew(irInd,:) = RC .* xold(irInd,:) + (1 - RC) .* currentEff;
        Ah = exp(-abs(currentEff * G * deltat / (3600 * Q)));  % hysteresis factor
        xnew(hkInd, :) = Ah .* xold(hkInd, :) + (Ah - 1) .* sign(currentEff);
        xnew(socInd, :) = xold(socInd, :) - currentEff * deltat / (3600 * Q);
        xnew(ibInd, :) = xold(ibInd, :) + xnoise(biasNoiseInd, :);
    end

    function yhat = outputEqn(xhat, current, ynoise, T, model)
        currentEff = current - xhat(ibInd, :);
        currentEff = reshape(currentEff, 1, []);
        yhat = OCVfromSOCtemp(xhat(socInd, :), T, model);
        sik = - signIk; % TBD
        % if abs(currentEff)<Q/100, sik(k) = sik(k-1); end % TBD
        yhat = yhat + M * xhat(hkInd, :) + M0 * sik;
        yhat = yhat - sum(R .* xhat(irInd, :), 1) - R0 .* currentEff + ynoise(1, :);
    end
end
