function edukf_data = initEDUKF(soc0,R0init,T0,SigmaX0,SigmaV,SigmaW,SigmaR0,SigmaWR0,model)
% initEDUKF Initialize a dual ESC sigma-point Kalman filter.

% Reset function-local persistent states (if any are introduced later).
clear iterEDUKF;
clear iterEsSPKF;

if soc0 > 1, soc0 = soc0 / 100; end

nRC = getNumRC(T0, model);
if nRC < 1
    error('initEDUKF:MissingRCStates', ...
        'Full ESC model required: no RC branch states found.');
end
Nx = nRC + 2;

SigmaX0 = normalizeStateCovariance(SigmaX0, Nx);
SigmaW = normalizeNoiseVariance(SigmaW);
SigmaV = normalizeNoiseVariance(SigmaV);

edukf_data = struct();
edukf_data.irInd = 1:nRC;
edukf_data.hkInd = nRC + 1;
edukf_data.soc_estInd = Nx;
edukf_data.zkInd = edukf_data.soc_estInd;
edukf_data.xhat = [zeros(nRC, 1); 0; soc0];

edukf_data.SigmaX = SigmaX0;
edukf_data.SigmaV = SigmaV;
edukf_data.SigmaW = SigmaW;
edukf_data.Snoise = real(chol(diag([SigmaW(:); SigmaV(:)]), 'lower'));
edukf_data.Qbump = 5;

edukf_data.Nx = Nx;
edukf_data.Ny = 1;
edukf_data.Nu = 1;
edukf_data.Nw = numel(SigmaW);
edukf_data.Nv = numel(SigmaV);
edukf_data.Na = edukf_data.Nx + edukf_data.Nw + edukf_data.Nv;

h = sqrt(3);
edukf_data.h = h;
weight1 = (h * h - edukf_data.Na) / (h * h);
weight2 = 1 / (2 * h * h);
edukf_data.Wm = [weight1; weight2 * ones(2 * edukf_data.Na, 1)];
edukf_data.Wc = edukf_data.Wm;

edukf_data.priorI = 0;
edukf_data.signIk = 0;
edukf_data.model = model;
edukf_data.estimatorType = 'edukf';

edukf_data.R0hat = R0init;
edukf_data.SigmaR0 = SigmaR0;
edukf_data.SigmaWR0 = SigmaWR0;
edukf_data.hR0 = sqrt(3);
weight1R0 = (edukf_data.hR0 * edukf_data.hR0 - 1) / (edukf_data.hR0 * edukf_data.hR0);
weight2R0 = 1 / (2 * edukf_data.hR0 * edukf_data.hR0);
edukf_data.WmR0 = [weight1R0; weight2R0; weight2R0];
edukf_data.WcR0 = edukf_data.WmR0;
end

function SigmaX = normalizeStateCovariance(SigmaX0, Nx)
if isscalar(SigmaX0)
    SigmaX = eye(Nx) * SigmaX0;
elseif isvector(SigmaX0)
    vec = SigmaX0(:);
    if numel(vec) ~= Nx
        error('initEDUKF:BadSigmaX0', 'SigmaX0 vector length must match the number of states.');
    end
    SigmaX = diag(vec);
else
    [nRows, nCols] = size(SigmaX0);
    if nRows ~= nCols || nRows ~= Nx
        error('initEDUKF:BadSigmaX0', 'SigmaX0 must be an Nx-by-Nx covariance matrix.');
    end
    SigmaX = SigmaX0;
end
end

function Sigma = normalizeNoiseVariance(SigmaIn)
if isscalar(SigmaIn)
    Sigma = SigmaIn;
elseif isvector(SigmaIn)
    Sigma = SigmaIn(:);
else
    error('initEDUKF:BadNoiseVariance', 'SigmaV and SigmaW must be scalars or vectors.');
end
end

function nRC = getNumRC(T0, model)
if isfield(model, 'RCParam')
    nRC = numel(getParamESC('RCParam', T0, model));
else
    nRC = 0;
end
end

