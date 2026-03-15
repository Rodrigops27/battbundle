function [zk,v_pred,zkbnd,esckfData,v_predbnd] = iterEnacrSPKF(vk,ik,Tk,deltat,esckfData)
% iterEnacrSPKF ESC-SPKF with autocorrelated process component.
% Uses initESCSPKF data and internally augments state with one correlated
%
% Augmented state:
%   x_aug = [x_main; x_proc], with size 2*Nx0
% Dynamics:
%   x_main(k) = f(x_main(k-1), i(k-1)) + x_proc(k-1)
%   x_proc(k) = Af * x_proc(k-1) + w(k-1)

model = esckfData.model;

% One-time augmentation, preserving initESCSPKF interface.
if ~isfield(esckfData, 'enacrInitialized') || ~esckfData.enacrInitialized
    esckfData = initializeEnacrState(esckfData);
end

% Load model parameters
Q  = getParamESC('QParam',Tk,model);
G  = getParamESC('GParam',Tk,model);
M  = getParamESC('MParam',Tk,model);
M0 = getParamESC('M0Param',Tk,model);
RC = exp(-deltat./abs(getParamESC('RCParam',Tk,model)))';
R  = getParamESC('RParam',Tk,model)';
R0 = getParamESC('R0Param',Tk,model);
eta = getParamESC('etaParam',Tk,model);
if ik < 0, ik = ik * eta; end

% Unpack filter data
Iprev = esckfData.priorI;
SigmaX = esckfData.SigmaX;
xhat = esckfData.xhat;
Nx = esckfData.Nx;
Nw = esckfData.Nw;
Nv = esckfData.Nv;
Na = esckfData.Na;
Snoise = esckfData.Snoise;
Wc = esckfData.Wc;

mainInd = esckfData.enacrMainInd;
procInd = esckfData.enacrProcInd;
Af = esckfData.enacrAf;

irInd = esckfData.irInd;
hkInd = esckfData.hkInd;
socInd = esckfData.soc_estInd;

if abs(ik) > Q / 100
    esckfData.signIk = sign(ik);
end
signIk = esckfData.signIk;

% Step 1a-1: Build sigma points
[sigmaXa, p] = chol(SigmaX, 'lower');
if p > 0
    warning('iterEnacrSPKF:CholeskyRecovery', ...
        'Cholesky error. Recovering with diagonal covariance.');
    sigmaXa = diag(sqrt(max(abs(diag(SigmaX)), eps)));
end
sigmaXa = [real(sigmaXa), zeros(Nx, Nw + Nv); zeros(Nw + Nv, Nx), Snoise];
xhata = [xhat; zeros(Nw + Nv, 1)];
Xa = xhata(:, ones(1, 2 * Na + 1)) + ...
    esckfData.h * [zeros(Na, 1), sigmaXa, -sigmaXa];

% Step 1a-2: Time update
Xx = stateEqn(Xa(1:Nx, :), Iprev, Xa(Nx + 1:Nx + Nw, :));
xhat = Xx * esckfData.Wm;
xhat(hkInd) = min(1, max(-1, xhat(hkInd)));
xhat(socInd) = min(1.05, max(-0.05, xhat(socInd)));

% Step 1b: Covariance time update
Xs = Xx - xhat(:, ones(1, 2 * Na + 1));
SigmaX = Xs * diag(Wc) * Xs';

% Step 1c: Output estimate
% Process autocorrelation is already represented inside x_proc state.
Y = outputEqn(Xx(mainInd, :), ik, Xa(Nx + Nw + 1:end, :), Tk, model);
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
    L(:, 1) = 0;
    warning('10 std dev outlier');
end
xhat = xhat + L * r;
xhat(hkInd) = min(1, max(-1, xhat(hkInd)));
xhat(socInd) = min(1.05, max(-0.05, xhat(socInd)));

% Step 2c: Covariance measurement update
SigmaX = SigmaX - L * SigmaY * L';
[~, S, V] = svd(SigmaX);
HH = V * S * V';
SigmaX = (SigmaX + SigmaX' + HH + HH') / 4;

if r^2 > 4 * SigmaY
    warning('2 std. devs. away, Bumping SigmaX');
    SigmaX(socInd, socInd) = SigmaX(socInd, socInd) * esckfData.Qbump;
end

% Save data
esckfData.priorI = ik;
esckfData.SigmaX = SigmaX;
esckfData.xhat = xhat;

% Outputs (main state only)
zk = xhat(socInd);
zkbnd = 3 * sqrt(max(SigmaX(socInd, socInd), 0));
v_pred = outputEqn(xhat(mainInd), ik, zeros(Nv, 1), Tk, model);
v_predbnd = 3 * sqrt(max(SigmaY, 0));

    function xnew = stateEqn(xoldAug, current, wproc)
        xmain_old = xoldAug(mainInd, :);
        xproc_old = xoldAug(procInd, :);

        current = reshape(current, 1, []);
        xmain_nom = zeros(size(xmain_old));
        xmain_nom(irInd,:) = RC .* xmain_old(irInd,:) + (1 - RC) .* current;
        Ah = exp(-abs(current * G * deltat / (3600 * Q)));
        xmain_nom(hkInd,:) = Ah .* xmain_old(hkInd,:) + (Ah - 1) .* sign(current);
        xmain_nom(socInd,:) = xmain_old(socInd,:) - current * deltat / (3600 * Q);

        xmain_new = xmain_nom + xproc_old;
        xproc_new = Af * xproc_old + wproc;
        xnew = [xmain_new; xproc_new];
    end

    function yhatLoc = outputEqn(xmain, current, ynoise, T, modelIn)
        yhatLoc = OCVfromSOCtemp(xmain(socInd, :), T, modelIn);
        sik = -signIk;
        yhatLoc = yhatLoc + M * xmain(hkInd, :) + M0 * sik;
        yhatLoc = yhatLoc - sum(R .* xmain(irInd, :), 1) - R0 * current + ynoise(1, :);
    end
end

function esckfData = initializeEnacrState(esckfData)
% Augment x with a process-autocorrelation state of size Nx0.

Nx0 = esckfData.Nx;
Nv = esckfData.Nv;
if Nv ~= 1
    error('iterEnacrSPKF:UnsupportedNy', ...
        'iterEnacrSPKF currently supports scalar-voltage measurement only (Nv=1).');
end

% Af can be user-provided as scalar or Nx0-by-Nx0 matrix.
if isfield(esckfData, 'enacrAf')
    AfIn = esckfData.enacrAf;
    if isscalar(AfIn)
        Af = AfIn * eye(Nx0);
    else
        Af = AfIn;
    end
else
    Af = 0.98 * eye(Nx0);
end
if ~isequal(size(Af), [Nx0, Nx0])
    error('iterEnacrSPKF:BadAf', 'enacrAf must be scalar or Nx0-by-Nx0.');
end

% Process-noise covariance for x_proc dynamics.
SigmaWprocVec = expandProcessNoise(esckfData.SigmaW, Nx0);

% Augment state and covariance.
esckfData.xhat = [esckfData.xhat; zeros(Nx0, 1)];
esckfData.SigmaX = blkdiag(esckfData.SigmaX, diag(SigmaWprocVec));

% New process noise acts on x_proc only.
esckfData.SigmaW = SigmaWprocVec(:);
esckfData.Nw = Nx0;
esckfData.Nx = 2 * Nx0;
esckfData.Na = esckfData.Nx + esckfData.Nw + esckfData.Nv;
esckfData.Snoise = real(chol(diag([esckfData.SigmaW(:); esckfData.SigmaV(:)]), 'lower'));

h = sqrt(3);
esckfData.h = h;
weight1 = (h * h - esckfData.Na) / (h * h);
weight2 = 1 / (2 * h * h);
esckfData.Wm = [weight1; weight2 * ones(2 * esckfData.Na, 1)];
esckfData.Wc = esckfData.Wm;

esckfData.enacrMainInd = 1:Nx0;
esckfData.enacrProcInd = Nx0 + (1:Nx0);
esckfData.enacrAf = Af;
esckfData.enacrInitialized = true;
end

function sigmaVec = expandProcessNoise(sigmaIn, n)
if isscalar(sigmaIn)
    sigmaVec = max(real(sigmaIn), eps) * ones(n, 1);
else
    vec = sigmaIn(:);
    if numel(vec) == n
        sigmaVec = max(real(vec), eps);
    else
        sigmaVec = max(real(vec(1)), eps) * ones(n, 1);
    end
end
end
