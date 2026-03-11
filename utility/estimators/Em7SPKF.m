function [zk,v_pred,zkbnd,esckfData,v_predbnd,bhat_est,bbnd,r0_est,r0_bnd] = Em7SPKF(vk,ik,Tk,deltat,esckfData)
% Em7SPKF Method-7 ESC estimator:
%   - ESC-SPKF state update
%   - external bias tracking update (bhat)
%   - simplified 1-state SPKF branch for R0

model = esckfData.model;
% Load cell model parameters
Q  = getParamESC('QParam',Tk,model);
G  = getParamESC('GParam',Tk,model);
M  = getParamESC('MParam',Tk,model);
M0 = getParamESC('M0Param',Tk,model);
RC = exp(-deltat./abs(getParamESC('RCParam',Tk,model)))';
R  = getParamESC('RParam',Tk,model)';
eta = getParamESC('etaParam',Tk,model);
if ik < 0, ik = ik * eta; end

% Core SPKF fields
Iprev = esckfData.priorI;
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

% Bias-filter fields
requiredBiasFields = {'nb', 'bhat', 'SigmaB', 'Bb', 'Cb', 'V', 'currentBiasInd'};
for idx = 1:numel(requiredBiasFields)
    if ~isfield(esckfData, requiredBiasFields{idx})
        error('Em7SPKF:MissingBiasField', ...
            'Missing esckfData.%s. Initialize with Em7init(..., biasCfg).', requiredBiasFields{idx});
    end
end
requiredR0Fields = {'R0hat', 'SigmaR0', 'SigmaWR0', 'hR0', 'WmR0', 'WcR0'};
for idx = 1:numel(requiredR0Fields)
    if ~isfield(esckfData, requiredR0Fields{idx})
        error('Em7SPKF:MissingR0Field', ...
            'Missing esckfData.%s. Initialize with Em7init.', requiredR0Fields{idx});
    end
end

nb = esckfData.nb;
bhat = esckfData.bhat;
SigmaB = esckfData.SigmaB;
Bb = esckfData.Bb;
Cb = esckfData.Cb;
V = esckfData.V;
currentBiasInd = esckfData.currentBiasInd;
R0hat = esckfData.R0hat;
SigmaR0 = esckfData.SigmaR0;

currentNoiseInd = 1;
if isfield(esckfData, 'currentNoiseInd')
    currentNoiseInd = esckfData.currentNoiseInd;
end
if currentNoiseInd < 1 || currentNoiseInd > Nw
    error('Em7SPKF:BadCurrentNoiseIndex', 'currentNoiseInd must be within process-noise dimension.');
end

% Use bias-corrected current for prediction/sign handling
iEffNow = ik - bhat(currentBiasInd);
if abs(iEffNow) > Q / 100
    esckfData.signIk = sign(iEffNow);
end
signIk = esckfData.signIk;

% Step 1a-1: Create augmented SigmaX and xhat
[sigmaXa, p] = chol(SigmaX, 'lower');
if p > 0
    warning('Em7SPKF:CholeskyRecovery', 'Cholesky error. Recovering with diagonal covariance.');
    sigmaXa = diag(sqrt(max(abs(diag(SigmaX)), eps)));
end
sigmaXa = [real(sigmaXa), zeros(Nx, Nw + Nv); zeros(Nw + Nv, Nx), Snoise];
xhata = [xhat; zeros(Nw + Nv, 1)];

% Step 1a-2: Calculate sigma points
Xa = xhata(:, ones(1, 2 * Na + 1)) + ...
    esckfData.h * [zeros(Na, 1), sigmaXa, -sigmaXa];

% Step 1a-3: Time update with bias-corrected previous current
iEffPrev = Iprev - bhat(currentBiasInd);
Xx = stateEqn(Xa(1:Nx, :), iEffPrev, Xa(Nx + 1:Nx + Nw, :));
xhat = Xx * esckfData.Wm;
xhat(hkInd) = min(1, max(-1, xhat(hkInd)));
xhat(socInd) = min(1.05, max(-0.05, xhat(socInd)));

% Step 1b: Error covariance time update
Xs = Xx - xhat(:, ones(1, 2 * Na + 1));
SigmaX = Xs * diag(Wc) * Xs';

% Step 1c: Output estimate with bias-corrected present current
yk = vk;
Y = outputEqn(Xx, iEffNow + Xa(Nx + currentNoiseInd, :), ...
    Xa(Nx + Nw + 1:end, :), Tk, model, R0hat);
yhat = Y * esckfData.Wm;

% Step 2a: State estimator gain
Ys = Y - yhat(:, ones(1, 2 * Na + 1));
SigmaXY = Xs * diag(Wc) * Ys';
SigmaY = Ys * diag(Wc) * Ys';
L = SigmaXY / SigmaY;

% Bias filter update (two-stage branch)
sigmaV = esckfData.SigmaV(1);
if isfield(esckfData, 'biasModelStatic') && esckfData.biasModelStatic
    Ad = esckfData.AdBias;
    Cd = esckfData.CdBias;
else
    Ad = buildAd(iEffPrev);
    Cd = buildCd(xhat, Tk);
end

U = Ad * V + Bb;
S = Cd * U + Cb;
V = U - L * S;

innovLin = Cd * SigmaX * Cd' + sigmaV + S * SigmaB * S';
innovLin = max(real(innovLin), eps);
SigmaB = SigmaB - (SigmaB * S' / innovLin) * S * SigmaB;
SigmaB = (SigmaB + SigmaB') / 2;

Lb = SigmaB * (V' * Cd' + Cb') / max(real(sigmaV), eps);
r = yk - yhat;
bhat = (eye(nb) - Lb * S) * bhat + Lb * r;

% Step 2b: State update + bias correction
if r^2 > 100 * SigmaY
    L(:, 1) = 0;
    warning('10 std dev outlier');
end
xhat = xhat + L * r;
xhat = xhat + V * bhat;
xhat(hkInd) = min(1, max(-1, xhat(hkInd)));
xhat(socInd) = min(1.05, max(-0.05, xhat(socInd)));

% Step 2c: Error covariance measurement update
SigmaX = SigmaX - L * SigmaY * L';
[~, Sx, Vx] = svd(SigmaX);
HH = Vx * Sx * Vx';
SigmaX = (SigmaX + SigmaX' + HH + HH') / 4;

if r^2 > 4 * SigmaY
    warning('2 std. devs. away, Bumping SigmaX');
    SigmaX(socInd, socInd) = SigmaX(socInd, socInd) * esckfData.Qbump;
end

% Simplified 1-state parameter-estimation SPKF to estimate R0
iEffForR0 = ik - bhat(currentBiasInd);
[R0hat, SigmaR0] = R0SPKF(vk, iEffForR0, xhat, R0hat, SigmaR0);

% Save for next sample
esckfData.priorI = ik;
esckfData.SigmaX = SigmaX;
esckfData.xhat = xhat;
esckfData.bhat = bhat;
esckfData.SigmaB = SigmaB;
esckfData.V = V;
esckfData.R0hat = R0hat;
esckfData.SigmaR0 = SigmaR0;

zk = xhat(socInd);
zkbnd = 3 * sqrt(max(SigmaX(socInd, socInd), 0));
bhat_est = bhat;
bbnd = 3 * sqrt(max(diag(SigmaB), 0));
r0_est = R0hat;
r0_bnd = 3 * sqrt(max(SigmaR0, 0));
v_pred = outputEqn(xhat, iEffForR0, zeros(Nv, 1), Tk, model, R0hat);
v_predbnd = 3 * sqrt(max(SigmaY + S * SigmaB * S' + (iEffForR0 ^ 2) * SigmaR0, 0));

    function xnew = stateEqn(xold, currentEff, xnoise)
        currentEff = currentEff + xnoise(currentNoiseInd, :);
        currentEff = reshape(currentEff, 1, []);
        xnew = 0*xold;
        xnew(irInd,:) = RC .* xold(irInd,:) + (1 - RC) .* currentEff;
        Ah = exp(-abs(currentEff * G * deltat / (3600 * Q)));
        xnew(hkInd, :) = Ah .* xold(hkInd, :) + (Ah - 1) .* sign(currentEff);
        xnew(socInd, :) = xold(socInd, :) - currentEff * deltat / (3600 * Q);
    end

    function yhatLoc = outputEqn(xhatLoc, currentEff, ynoise, T, modelLoc, R0hatLoc)
        yhatLoc = OCVfromSOCtemp(xhatLoc(socInd, :), T, modelLoc);
        sik = - signIk;
        yhatLoc = yhatLoc + M * xhatLoc(hkInd, :) + M0 * sik;
        yhatLoc = yhatLoc - sum(R .* xhatLoc(irInd, :), 1) - R0hatLoc .* currentEff + ynoise(1, :);
    end

    function AdLoc = buildAd(currentEff)
        AdLoc = zeros(Nx, Nx);
        AdLoc(irInd, irInd) = diag(RC);
        Ah = exp(-abs(currentEff * G * deltat / (3600 * Q)));
        AdLoc(hkInd, hkInd) = Ah;
        AdLoc(socInd, socInd) = 1;
    end

    function CdLoc = buildCd(xhatLoc, T)
        CdLoc = zeros(1, Nx);
        CdLoc(irInd) = -R;
        CdLoc(hkInd) = M;
        soc0 = xhatLoc(socInd);
        ds = 1e-6;
        socHi = min(1.05, soc0 + ds);
        socLo = max(-0.05, soc0 - ds);
        ocvHi = OCVfromSOCtemp(socHi, T, model);
        ocvLo = OCVfromSOCtemp(socLo, T, model);
        CdLoc(socInd) = (ocvHi - ocvLo) / max(socHi - socLo, eps);
    end

    function [R0hatLoc, SigmaR0Loc] = R0SPKF(vkLoc, ikEffLoc, xhatLoc, R0hatLoc, SigmaR0Loc)
        SigmaR0Loc = SigmaR0Loc + esckfData.SigmaWR0;

        sigmaR0 = sqrt(max(SigmaR0Loc, eps));
        R0SigmaPts = R0hatLoc + esckfData.hR0 * [0; sigmaR0; -sigmaR0];

        nTheta = numel(R0SigmaPts);
        xk_mat = xhatLoc(:, ones(1, nTheta));
        ik_mat = ikEffLoc * ones(1, nTheta);
        ynoise_mat = zeros(1, nTheta);
        D_R0 = outputEqn(xk_mat, ik_mat, ynoise_mat, Tk, model, R0SigmaPts(:).');
        yR0hat = D_R0 * esckfData.WmR0;

        yR0s = D_R0 - yR0hat;
        r0Centered = R0SigmaPts - R0hatLoc;

        SigmaYR0 = yR0s * diag(esckfData.WcR0) * yR0s' + esckfData.SigmaV(1);
        SigmaR0Y = r0Centered' * diag(esckfData.WcR0) * yR0s';
        LR0 = SigmaR0Y / SigmaYR0;

        R0hatLoc = R0hatLoc + LR0 * (vkLoc - yR0hat);
        SigmaR0Loc = SigmaR0Loc - LR0 * SigmaYR0 * LR0';
        SigmaR0Loc = max(real(SigmaR0Loc), 0);
    end
end
