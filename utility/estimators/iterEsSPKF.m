function [zk, v_pred, zkbnd, esckfData, v_predbnd, R0hat, R0_bnd] = iterEsSPKF(vk,ik,Tk,deltat,esckfData)
% iterEsSPKF Perform one dual ESC sigma-point Kalman filter update.
%   - state SPKF for ESC states (SOC, ir, h, ...)
%   - parallel random-walk SPKF for R0
% Inputs:
%   vk: Present measured (noisy) cell voltage
%   ik: Present measured (noisy) cell current
%   Tk: Present temperature
%   deltat: Sampling interval
%   esckfData: Data structure initialized by initSPKF, updated by iterSPKF
%
% Output:
%   zk: SOC estimate for this time sample
%   zkbnd: 3-sigma estimation bounds
%   R0hat: R0 estimate for this time sample
%   r0_bnd: 3-sigma estimation bounds
%   esckfData: Data structure used to store persistent variables

model = esckfData.model;
% Load the cell model parameters
Q  = getParamESC('QParam',Tk,model);
G  = getParamESC('GParam',Tk,model);
M  = getParamESC('MParam',Tk,model);
M0 = getParamESC('M0Param',Tk,model);
RC = exp(-deltat./abs(getParamESC('RCParam',Tk,model)))';
R  = getParamESC('RParam',Tk,model)';
% R0 = getParamESC('R0Param',Tk,model);
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
if abs(ik) > Q / 100
    esckfData.signIk = sign(ik);
end
signIk = esckfData.signIk;
R0hat = esckfData.R0hat;


% PART 1: Time (Prediction) update
% State S1a-1: Create augmented SigmaX and xhat
[sigmaXa, p] = chol(SigmaX, 'lower');
if p > 0
    warning('iterEDUKF:CholeskyRecovery', 'Cholesky error. Recovering with diagonal covariance.');
    sigmaXa = diag(sqrt(max(abs(diag(SigmaX)), eps)));
end
sigmaXa = [real(sigmaXa), zeros(Nx, Nw + Nv); zeros(Nw + Nv, Nx), Snoise];
xhata = [xhat; zeros(Nw + Nv, 1)];
% State S1a-2: Calculate SigmaX points
Xa = xhata(:, ones(1, 2 * Na + 1)) + ...
    esckfData.h * [zeros(Na, 1), sigmaXa, -sigmaXa]; % to avoid "repmat" call

Xx = stateEqn(Xa(1:Nx, :), I, Xa(Nx + 1:Nx + Nw, :)); % State S1a-3: Time update from last iteration until now stateEqn(xold,current,xnoise)
xhat = Xx * esckfData.Wm;
xhat(hkInd) = min(1, max(-1, xhat(hkInd)));
xhat(socInd) = min(1.05, max(-0.05, xhat(socInd)));

% State S1b: Error covariance time update
Xs = Xx - xhat(:, ones(1, 2 * Na + 1)); % to avoid "repmat" call
SigmaX = Xs * diag(Wc) * Xs';

% State S1c: Output estimate
Y = outputEqn(Xx, ik + Xa(Nx + 1:Nx + Nw, :), Xa(Nx + Nw + 1:end, :), Tk, model, R0hat);
yhat = Y * esckfData.Wm;

% State S2a: Estimator gain matrix
Ys = Y - yhat(:, ones(1, 2 * Na + 1));
SigmaXY = Xs * diag(Wc) * Ys';
SigmaY = Ys * diag(Wc) * Ys';
L = SigmaXY / SigmaY;

% PART 2: Measurement (Correction) update
% State S2b: State estimate measurement update
r = vk - yhat;
if r^2 > 100 * SigmaY
    L(:, 1) = 0;
    warning('10 std dev outlier');
end
xhat = xhat + L * r;
xhat(hkInd) = min(1, max(-1, xhat(hkInd)));
xhat(socInd) = min(1.05, max(-0.05, xhat(socInd)));

% State S2c: Error covariance measurement update
SigmaX = SigmaX - L * SigmaY * L';
[~, Sx, Vx] = svd(SigmaX);
HH = Vx * Sx * Vx';
SigmaX = (SigmaX + SigmaX' + HH + HH') / 4;
if r^2 > 4 * SigmaY
    warning('2 std. devs. away, Bumping SigmaX');
    SigmaX(socInd, socInd) = SigmaX(socInd, socInd) * esckfData.Qbump;
end

% Simple 1-state parameter-estimation SPKF to estimate R0
[R0hat, SigmaR0] = R0SPKF(vk, ik, xhat, esckfData.R0hat, esckfData.SigmaR0);

% Save data in spkfData structure for next time...
esckfData.priorI = ik;
esckfData.SigmaX = SigmaX;
esckfData.xhat = xhat;
esckfData.R0hat = R0hat;
esckfData.SigmaR0 = SigmaR0;

zk = xhat(socInd);
zkbnd = 3 * sqrt(max(SigmaX(socInd, socInd), 0));
v_pred = outputEqn(xhat, ik, zeros(Nv, 1), Tk, model, R0hat);
v_predbnd = 3 * sqrt(max(SigmaY + (ik ^ 2) * SigmaR0, 0));
R0_bnd = 3 * sqrt(max(SigmaR0, 0));

    function xnew = stateEqn(xold, current, xnoise)
        current = current + xnoise;
        current = reshape(current, 1, []);
        xnew = 0*xold;
        xnew(irInd,:) = RC .* xold(irInd,:) + (1 - RC) .* current;
        Ah = exp(-abs(current * G * deltat / (3600 * Q)));  % hysteresis factor
        xnew(hkInd, :) = Ah .* xold(hkInd, :) + (Ah - 1) .* sign(current);
        xnew(socInd, :) = xold(socInd, :) - current * deltat / (3600 * Q);
    end

    function yhat = outputEqn(xhat, current, ynoise, T, model, R0hat)
        yhat = OCVfromSOCtemp(xhat(socInd, :), T, model);
        sik = - signIk; % TBD
        % if abs(current)<Q/100, sik(k) = sik(k-1); end % TBD
        yhat = yhat + M * xhat(hkInd, :) + M0 * sik;
        yhat = yhat - sum(R .* xhat(irInd, :), 1) - R0hat .* current + ynoise(1, :);
    end

    function [R0hat, SigmaR0] = R0SPKF(vk, ik, xhat, R0hat, SigmaR0)
        SigmaR0 = SigmaR0 + esckfData.SigmaWR0; % Par S1b: Error covariance time

        % Par S1c: Output estimate
        sigmaR0 = sqrt(max(SigmaR0, eps));
        R0SigmaPts = R0hat + esckfData.hR0 * [0; sigmaR0; -sigmaR0]; % Par S1c-2: Calculate SigmaR0 points

        nTheta = numel(R0SigmaPts);
        xk_mat = xhat(:, ones(1, nTheta));           % Nx x nTheta
        ik_mat = ik * ones(1, nTheta);                       % 1 x nTheta
        ynoise_mat = zeros(1, nTheta);
        D_R0 = outputEqn(xk_mat, ik_mat, ynoise_mat, Tk, model, R0SigmaPts(:).'); % Par S1c-2: prediction
        yR0hat = D_R0 * esckfData.WmR0; % Par S1c-2:  weighted output prediction

        % Par S2a: Estimator gain matrix
        yR0s = D_R0 - yR0hat;
        r0Centered = R0SigmaPts - R0hat;

        SigmaYR0 = yR0s * diag(esckfData.WcR0) * yR0s' + esckfData.SigmaV;  % linear sensor noise
        SigmaR0Y = r0Centered' * diag(esckfData.WcR0) * yR0s';
        LR0 = SigmaR0Y / SigmaYR0;

        % Par S2b: State estimate measurement update
        R0hat = R0hat + LR0 * (vk - yR0hat);
        SigmaR0 = SigmaR0 - LR0 * SigmaYR0 * LR0'; % Par S2c: Error covariance measurement update
        SigmaR0 = max(real(SigmaR0), 0);
    end
end
