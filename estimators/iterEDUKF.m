function [zk,v_pred,zkbnd,esckfData,v_predbnd, r0_est, R0_bnd] = iterEDUKF(vk,ik,Tk,deltat,esckfData)
% iterEDUKF (R0) Dual ESC SPKF:
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
%   spkfData: Data structure used to store persistent variables

model = esckfData.model;
% Load the cell model parameters
Q  = getParamESC('QParam',Tk,model);
G  = getParamESC('GParam',Tk,model);
M  = getParamESC('MParam',Tk,model);
M0 = getParamESC('M0Param',Tk,model);
RC = exp(-deltat./abs(getParamESC('RCParam',Tk,model)))';
R  = getParamESC('RParam',Tk,model)';
eta = getParamESC('etaParam',Tk,model);
if ik<0, ik=ik*eta; end

% Get data stored in spkfData structure
Iprev = esckfData.priorI;
SigmaX = esckfData.SigmaX;
xhat = esckfData.xhat; % x_{k-1}^+
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

%% PART 1: Time (Prediction) update
% -------------------------------------------------------------------------
% Parameter filter:
% Par S1a: Parameter prediction time update -> R0_minus = R0_plus
R0hat = esckfData.R0hat;
SigmaR0 = esckfData.SigmaR0 + esckfData.SigmaWR0; % Par S1b: Error covariance time
% Par S1c: Output estimate
% Build parameter (R0) sigma points
sigmaR0 = sqrt(max(SigmaR0, eps)); % Par S1c-1: Create augmented SigmaR0 and R0hat
R0SigmaPts = R0hat + esckfData.hR0 * [0; sigmaR0; -sigmaR0];  % Par S1c-2: Calculate SigmaR0 points

% Par S1c-3: Compute output prediction for each parameter sigma point
nTheta = numel(R0SigmaPts);
xk = stateEqn(xhat, Iprev, 0);         % Nx x 1, zero-mean
xk_mat = xk(:, ones(1, nTheta));           % Nx x nTheta
ik_mat = ik * ones(1, nTheta);                       % 1 x nTheta
ynoise_mat = zeros(1, nTheta);                       % 1 x nTheta
D_param = outputEqn(xk_mat, ik_mat, ynoise_mat, Tk, model, R0SigmaPts(:).');  % zero-mean

dhat_param = D_param * esckfData.WmR0; % scalar weighted output prediction

% Par S2a: Estimator gain matrix
Ds = D_param - dhat_param;
R0_centered = R0SigmaPts(:) - R0hat;
SigmaD_param = Ds * diag(esckfData.WcR0) * Ds' + esckfData.SigmaV;  % scalar innovation variance
SigmaThetaD = R0_centered' * diag(esckfData.WcR0) * Ds';
Ltheta = SigmaThetaD / SigmaD_param;

% -------------------------------------------------------------------------
% State filter:
% State S1a-1: Create augmented SigmaX and xhat
[sigmaXa, p] = chol(SigmaX, 'lower');
if p > 0
    warning('iterESPKF:CholeskyRecovery', 'Cholesky error. Recovering with diagonal covariance.');
    sigmaXa = diag(sqrt(max(abs(diag(SigmaX)), eps)));
end
sigmaXa = [real(sigmaXa), zeros(Nx, Nw + Nv); zeros(Nw + Nv, Nx), Snoise];
xhata = [xhat; zeros(Nw + Nv, 1)];
% State S1a-2: Calculate SigmaX points
Xa = xhata(:, ones(1, 2 * Na + 1)) + ...
    esckfData.h * [zeros(Na, 1), sigmaXa, -sigmaXa]; % to avoid "repmat" call

Xx = stateEqn(Xa(1:Nx, :), Iprev, Xa(Nx + 1:Nx + Nw, :)); % State S1a-3: Time update from last iteration until now stateEqn(xold,current,xnoise)
xhat = Xx * esckfData.Wm;
xhat(hkInd) = min(1, max(-1, xhat(hkInd)));
xhat(socInd) = min(1.05, max(-0.05, xhat(socInd)));

% State S1b: Error covariance time update
Xs = Xx - xhat(:, ones(1, 2 * Na + 1)); % to avoid "repmat" call
SigmaX = Xs * diag(Wc) * Xs';

% State S1c: Output estimate
Y_state = outputEqn(Xx, ik + Xa(Nx + 1:Nx + Nw, :), ...
    Xa(Nx + Nw + 1:end, :), Tk, model, R0hat);
zhat_state = Y_state * esckfData.Wm; % weighted output estimate

% State S2a: Estimator gain matrix
Ys = Y_state - zhat_state(:, ones(1, 2 * Na + 1));
SigmaZ_state = Ys * diag(Wc) * Ys';
SigmaXZ = Xs * diag(Wc) * Ys';
Lx = SigmaXZ / SigmaZ_state;

%% PART 2: Measurement (Correction) update
% -------------------------------------------------------------------------
% State filter:
% State S2b: State estimate measurement update
res_state = vk - zhat_state;
esckfData.lastInnovationPre = res_state;
esckfData.lastSk = max(real(SigmaZ_state), eps);
if res_state^2 > 100 * SigmaZ_state
    Lx(:, 1) = 0;
    warning('10 std dev outlier');
end
xhat = xhat + Lx * res_state;
xhat(hkInd) = min(1, max(-1, xhat(hkInd)));
xhat(socInd) = min(1.05, max(-0.05, xhat(socInd)));

% State S2c: Error covariance measurement update
SigmaX = SigmaX - Lx * SigmaZ_state * Lx';
[~, Sx, Vx] = svd(SigmaX);
HH = Vx * Sx * Vx';
SigmaX = (SigmaX + SigmaX' + HH + HH') / 4;
if res_state^2 > 4 * SigmaZ_state  % bad voltage estimate by (2-sigmaY), bump Q
    warning('2 std. devs. away, Bumping SigmaX');
    SigmaX(socInd, socInd) = SigmaX(socInd, socInd) * esckfData.Qbump;
end

% -------------------------------------------------------------------------
% Parameter filter:
% Par S2b: State estimate measurement update
res_param = vk - dhat_param;
if res_param^2 > 100 * SigmaD_param
    Ltheta(:, 1) = 0;
    warning('10 std dev outlier');
end
R0hat = R0hat + Ltheta * res_param;

% Par S2c: Error covariance measurement update
SigmaR0 = SigmaR0 - Ltheta * SigmaD_param * Ltheta';
SigmaR0 = max(real(SigmaR0), 0);
if res_param^2 > 4 * SigmaD_param  % bad voltage estimate by (2-sigmaY), bump Q
    warning('2 std. devs., Bumping SigmaR0');
    SigmaR0 = SigmaR0 * esckfData.Qbump; % TBD
end

% Save data in spkfData structure for next time...
esckfData.priorI = ik;
esckfData.SigmaX = SigmaX;
esckfData.xhat = xhat;
esckfData.R0hat = R0hat;
esckfData.SigmaR0 = SigmaR0;

zk = xhat(socInd);
zkbnd = 3 * sqrt(max(SigmaX(socInd, socInd), 0));
r0_est = R0hat;
R0_bnd = 3 * sqrt(max(SigmaR0, 0));

v_pred = outputEqn(xhat, ik, zeros(Nv, 1), Tk, model, R0hat);
v_predbnd = 3 * sqrt(max(SigmaZ_state + (ik ^ 2) * SigmaR0, 0));

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
end
