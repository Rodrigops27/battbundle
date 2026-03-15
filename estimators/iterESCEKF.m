function [zk,v_pred,zkbnd,ekfData,v_predbnd] = iterESCEKF(vk,ik,Tk,deltat,ekfData)
% iterESCEKF Perform one ESC-EKF update.
%
% This ESC-EKF uses the same state/data layout produced by initESCSPKF,
% so it can be swapped into the same evaluation flow and innovation
% diagnostics used by the ACF/PACF plotting helpers.
%
% Inputs:
%   vk: Present measured (noisy) cell voltage
%   ik: Present measured (noisy) cell current
%   Tk: Present temperature
%   deltat: Sampling interval
%   ekfData: Data structure initialized by initESCSPKF
%
% Outputs:
%   zk: SOC estimate for this time sample
%   v_pred: Predicted terminal voltage after the state update
%   zkbnd: 3-sigma SOC estimation bounds
%   ekfData: Updated filter data structure
%   v_predbnd: 3-sigma voltage prediction bound
 
model = ekfData.model;

% Load the cell model parameters.
Q  = getParamESC('QParam',Tk,model);
G  = getParamESC('GParam',Tk,model);
M  = getParamESC('MParam',Tk,model);
M0 = getParamESC('M0Param',Tk,model);
RC = exp(-deltat./abs(getParamESC('RCParam',Tk,model)))';
R  = getParamESC('RParam',Tk,model)';
R0 = getParamESC('R0Param',Tk,model);
eta = getParamESC('etaParam',Tk,model);
if ik < 0
    ik = ik * eta;
end

% Get data stored in ekfData structure.
I = ekfData.priorI;
SigmaX = ekfData.SigmaX;
SigmaV = ekfData.SigmaV;
SigmaW = ekfData.SigmaW;
xhat = ekfData.xhat;
irInd = ekfData.irInd;
hkInd = ekfData.hkInd;
zkInd = ekfData.zkInd;
if abs(ik) > Q / 100
    ekfData.signIk = sign(ik);
end
signIk = ekfData.signIk;

% EKF Step 0: compute Ahat[k-1], Bhat[k-1].
nx = length(xhat);
Ahat = zeros(nx, nx);
Bhat = zeros(nx, 1);
Ahat(zkInd, zkInd) = 1;
Bhat(zkInd) = -deltat / (3600 * Q);
Ahat(irInd, irInd) = diag(RC);
Bhat(irInd) = 1 - RC(:);
Ah = exp(-abs(I * G * deltat / (3600 * Q)));
Ahat(hkInd, hkInd) = Ah;
B = [Bhat, zeros(size(Bhat))];
Bhat(hkInd) = -abs(G * deltat / (3600 * Q)) * Ah * (1 + sign(I) * xhat(hkInd));
B(hkInd, 2) = Ah - 1;

% Step 1a: state estimate time update.
xhat = Ahat * xhat + B * [I; sign(I)];
xhat(hkInd) = min(1, max(-1, xhat(hkInd)));
xhat(zkInd) = min(1.05, max(-0.05, xhat(zkInd)));

% Step 1b: error covariance time update.
SigmaX = Ahat * SigmaX * Ahat' + Bhat * SigmaW * Bhat';

% Step 1c: output estimate before measurement correction.
rc_drop = sum(R(:) .* xhat(irInd));
yhat = OCVfromSOCtemp(xhat(zkInd), Tk, model) + M0 * signIk + ...
    M * xhat(hkInd) - rc_drop - R0 * ik;

% Step 2a: estimator gain matrix.
Chat = zeros(1, nx);
soc0 = xhat(zkInd);
ds = 1e-6;
soc_hi = min(1.05, soc0 + ds);
soc_lo = max(-0.05, soc0 - ds);
ocv_hi = OCVfromSOCtemp(soc_hi, Tk, model);
ocv_lo = OCVfromSOCtemp(soc_lo, Tk, model);
Chat(zkInd) = (ocv_hi - ocv_lo) / max(soc_hi - soc_lo, eps);
Chat(hkInd) = M;
Chat(irInd) = -R(:).';
Dhat = 1;
SigmaY = Chat * SigmaX * Chat' + Dhat * SigmaV * Dhat';
SigmaY = max(real(SigmaY), eps);
L = SigmaX * Chat' / SigmaY;

% Step 2b: state estimate measurement update.
r = vk - yhat;
ekfData.lastInnovationPre = r;
ekfData.lastSk = SigmaY;
if r ^ 2 > 100 * SigmaY
    L(:) = 0;
end
xhat = xhat + L * r;
xhat(hkInd) = min(1, max(-1, xhat(hkInd)));
xhat(zkInd) = min(1.05, max(-0.05, xhat(zkInd)));

% Step 2c: error covariance measurement update.
SigmaX = SigmaX - L * SigmaY * L';
if r ^ 2 > 4 * SigmaY
    fprintf('Bumping SigmaX\n');
    SigmaX(zkInd, zkInd) = SigmaX(zkInd, zkInd) * ekfData.Qbump;
end
[~, S, V] = svd(SigmaX);
HH = V * S * V';
SigmaX = (SigmaX + SigmaX' + HH + HH') / 4;

% Save data in ekfData structure for next time.
ekfData.priorI = ik;
ekfData.SigmaX = SigmaX;
ekfData.xhat = xhat;

zk = xhat(zkInd);
zkbnd = 3 * sqrt(max(SigmaX(zkInd, zkInd), 0));
rc_drop = sum(R(:) .* xhat(irInd));
v_pred = OCVfromSOCtemp(xhat(zkInd), Tk, model) + M0 * signIk + ...
    M * xhat(hkInd) - rc_drop - R0 * ik;
v_predbnd = 3 * sqrt(SigmaY);
end
