function [zk,v_pred,zkbnd,eaekfData,v_predbnd] = iterEaEKF(vk,ik,Tk,deltat,eaekfData)
% iterEaEKF Perform one ESC adaptive-EKF update.

model = eaekfData.model;
Q  = getParamESC('QParam',Tk,model);
G  = getParamESC('GParam',Tk,model);
M  = getParamESC('MParam',Tk,model);
M0 = getParamESC('M0Param',Tk,model);
RC = exp(-deltat./abs(getParamESC('RCParam',Tk,model)))';
R  = getParamESC('RParam',Tk,model)';
R0 = getParamESC('R0Param',Tk,model);
eta = getParamESC('etaParam',Tk,model);
if ik < 0, ik = ik * eta; end

Iprev = eaekfData.priorI;
SigmaX = eaekfData.SigmaX;
SigmaV = eaekfData.SigmaV;
SigmaW = eaekfData.SigmaW;
xhat = eaekfData.xhat;

irInd = eaekfData.irInd;
hkInd = eaekfData.hkInd;
socInd = eaekfData.soc_estInd;
Nx = eaekfData.Nx;

if abs(ik) > Q / 100
    eaekfData.signIk = sign(ik);
end
signIk = eaekfData.signIk;

% Step 1a: Time update
xminus = stateEqn(xhat, Iprev);
Ahat = stateJacobian(Iprev);
Sx_prev = SigmaX;
SigmaX = Ahat * SigmaX * Ahat' + SigmaW;

% Step 1c: Output estimate
yk = vk;
yhat = outputEqn(xminus, ik);

% Step 2a: Gain
Chat = outputJacobian(xminus, Tk);
SigmaY = Chat * SigmaX * Chat' + SigmaV;
L = SigmaX * Chat' / SigmaY;

% Step 2b: Measurement update
mu = yk - yhat;
eaekfData.lastInnovationPre = mu;
eaekfData.lastSk = max(real(SigmaY), eps);
xhat = xminus + L * mu;
xhat(hkInd) = min(1, max(-1, xhat(hkInd)));
xhat(socInd) = min(1.05, max(-0.05, xhat(socInd)));

% Residual after correction
yhatPlus = outputEqn(xhat, ik);
r = yk - yhatPlus;

% Step 2c: Covariance update
SigmaX = SigmaX - L * SigmaY * L';
[~, S, V] = svd(SigmaX);
HH = V * S * V';
SigmaX = (SigmaX + SigmaX' + HH + HH') / 4;

if r^2 > 4 * SigmaY
    warning('2 std. devs. away, Bumping SigmaX');
    SigmaX(socInd, socInd) = SigmaX(socInd, socInd) * eaekfData.Qbump;
end

% Adaptive SigmaW/SigmaV update
alpha = eaekfData.alpha;
newW = (L * mu) * (L * mu)' + (SigmaX - Ahat * Sx_prev * Ahat');
[~, Sw, Vw] = svd(newW); % Robustifying AEKF-Update
HHw = Vw * Sw * Vw';
newW = (newW + newW' + HHw + HHw') / 4;

eaekfData.Wstore = [eaekfData.Wstore(:, 2:end), newW(:)];
if eaekfData.iter > size(eaekfData.Wstore, 2)
    avgW = mean(eaekfData.Wstore, 2);
    SigmaW_vec = alpha * SigmaW(:) + (1 - alpha) * avgW;
    SigmaW = reshape(SigmaW_vec, Nx, Nx); % Robustifying AEKF-Update
    SigmaW = real((SigmaW + SigmaW') / 2);
    SigmaW = SigmaW + eye(Nx) * eps;
end

newV = r * r' + Chat * SigmaX * Chat';
eaekfData.Vstore = [eaekfData.Vstore(2:end), newV];
if eaekfData.iter > size(eaekfData.Vstore, 2)
    avgV = mean(eaekfData.Vstore, 2);
    SigmaV = alpha * SigmaV + (1 - alpha) * avgV;
    SigmaV = max(real(SigmaV), eps);
end

eaekfData.priorI = ik;
eaekfData.SigmaX = SigmaX;
eaekfData.SigmaW = SigmaW;
eaekfData.SigmaV = SigmaV;
eaekfData.xhat = xhat;
eaekfData.iter = eaekfData.iter + 1;

zk = xhat(socInd);
zkbnd = 3 * sqrt(max(SigmaX(socInd, socInd), 0));
v_pred = outputEqn(xhat, ik);
v_predbnd = 3 * sqrt(max(SigmaY, 0));

    function xnew = stateEqn(xold, current)
        xnew = zeros(size(xold));
        xnew(irInd,:) = RC .* xold(irInd,:) + (1 - RC) .* current;
        Ah = exp(-abs(current * G * deltat / (3600 * Q)));
        xnew(hkInd,:) = Ah .* xold(hkInd,:) + (Ah - 1) .* sign(current);
        xnew(socInd,:) = xold(socInd,:) - current * deltat / (3600 * Q);
    end

    function A = stateJacobian(current)
        A = zeros(Nx, Nx);
        A(irInd, irInd) = diag(RC);
        Ah = exp(-abs(current * G * deltat / (3600 * Q)));
        A(hkInd, hkInd) = Ah;
        A(socInd, socInd) = 1;
    end

    function y = outputEqn(xstate, current)
        y = OCVfromSOCtemp(xstate(socInd,:), Tk, model);
        sik = -signIk;
        y = y + M * xstate(hkInd,:) + M0 * sik;
        y = y - sum(R .* xstate(irInd,:), 1) - R0 * current;
    end

    function C = outputJacobian(xstate, T)
        C = zeros(1, Nx);
        C(irInd) = -R;
        C(hkInd) = M;
        soc0 = xstate(socInd);
        ds = 1e-6;
        socHi = min(1.05, soc0 + ds);
        socLo = max(-0.05, soc0 - ds);
        ocvHi = OCVfromSOCtemp(socHi, T, model);
        ocvLo = OCVfromSOCtemp(socLo, T, model);
        C(socInd) = (ocvHi - ocvLo) / max(socHi - socLo, eps);
    end
end
