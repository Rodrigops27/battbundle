function eaekfData = initEaEKF(soc0,T0,SigmaX0,SigmaV,SigmaW,model,varargin)
% initEaEKF Initialize ESC-based adaptive EKF data.
%
% Optional config (struct):
%   alpha    : smoothing factor in (0,1), default 0.99
%   NW       : process-noise buffer length, default 500
%   NV       : sensor-noise buffer length, default 500

clear iterEaEKF;

if nargin ~= 6 && nargin ~= 7
    error('initEaEKF:BadInput', ...
        'Use initEaEKF(soc0,T0,SigmaX0,SigmaV,SigmaW,model[,cfg]).');
end

if soc0 > 1
    soc0 = soc0 / 100;
end

nRC = getNumRC(T0, model);
if nRC < 1
    error('initEaEKF:MissingRCStates', ...
        'Full ESC model required: no RC branch states found.');
end
Nx = nRC + 2;

SigmaX0 = normalizeStateCovariance(SigmaX0, Nx);
SigmaW = normalizeStateCovariance(SigmaW, Nx);
SigmaV = normalizeNoiseVariance(SigmaV);

cfg = struct();
if nargin == 7
    cfg = varargin{1};
    if ~isstruct(cfg)
        error('initEaEKF:BadConfig', 'Optional cfg must be a struct.');
    end
end

alpha = getCfg(cfg, 'alpha', 0.99);
NW = getCfg(cfg, 'NW', 500);
NV = getCfg(cfg, 'NV', 500);

eaekfData = struct();
eaekfData.irInd = 1:nRC;
eaekfData.hkInd = nRC + 1;
eaekfData.soc_estInd = nRC + 2;
eaekfData.zkInd = eaekfData.soc_estInd;
eaekfData.xhat = [zeros(nRC, 1); 0; soc0];

eaekfData.SigmaX = SigmaX0;
eaekfData.SigmaV = SigmaV;
eaekfData.SigmaW = SigmaW;

eaekfData.Nx = Nx;
eaekfData.Ny = 1;
eaekfData.Nu = 1;
eaekfData.Nw = Nx;
eaekfData.Nv = 1;

eaekfData.priorI = 0;
eaekfData.signIk = 0;
eaekfData.model = model;
eaekfData.Qbump = 5;

eaekfData.alpha = alpha;
eaekfData.Wstore = zeros(Nx * Nx, NW);
eaekfData.Vstore = zeros(1, NV);
eaekfData.iter = 0;
end

function val = getCfg(cfg, name, defaultVal)
if isfield(cfg, name)
    val = cfg.(name);
else
    val = defaultVal;
end
end

function SigmaX = normalizeStateCovariance(SigmaX0, Nx)
if isscalar(SigmaX0)
    SigmaX = eye(Nx) * SigmaX0;
elseif isvector(SigmaX0)
    vec = SigmaX0(:);
    if numel(vec) ~= Nx
        error('initEaEKF:BadSigma', 'Vector covariance length must match number of states.');
    end
    SigmaX = diag(vec);
else
    [nRows, nCols] = size(SigmaX0);
    if nRows ~= nCols || nRows ~= Nx
        error('initEaEKF:BadSigma', 'State covariance must be Nx-by-Nx.');
    end
    SigmaX = SigmaX0;
end
SigmaX = real((SigmaX + SigmaX') / 2);
end

function Sigma = normalizeNoiseVariance(SigmaIn)
if isscalar(SigmaIn)
    Sigma = SigmaIn;
elseif isvector(SigmaIn) && numel(SigmaIn) == 1
    Sigma = SigmaIn(1);
else
    error('initEaEKF:BadSigmaV', 'SigmaV must be scalar.');
end
end

function nRC = getNumRC(T0, model)
if isfield(model, 'RCParam')
    nRC = numel(getParamESC('RCParam', T0, model));
else
    nRC = 0;
end
end
