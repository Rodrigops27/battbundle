function spkf_data = initESCSPKF(soc0,T0,SigmaX0,SigmaV,SigmaW,model,varargin)
% initESCSPKF Initialize ESC-based SPKF data.
%
% Optional:
%   biasCfg struct with fields:
%     nb             (scalar, number of bias states; default = Nx + Ny)
%     bhat0          (nb-by-1 initial bias estimate)
%     SigmaB0        (nb-by-nb initial bias covariance)
%     Bb             (Nx-by-nb bias-to-state coupling)
%     Cb             (Ny-by-nb bias-to-output coupling)
%     V0             (Nx-by-nb initial V matrix)
%     currentBiasInd (scalar index of current-sensor bias in bhat0)
%     biasModelStatic (logical, use Ad/Cd from init instead of recomputing)
%     Ad             (Nx-by-Nx static bias-state model, required if biasModelStatic)
%     Cd             (Ny-by-Nx static bias-output model, required if biasModelStatic)

% Reset function-local persistent states (if any are introduced later).
clear iterESCSPKF;
clear iterEBiSPKF;

if nargin ~= 6 && nargin ~= 7
    error('initESCSPKF:BadInput', ...
        'Use initESCSPKF(soc0,T0,SigmaX0,SigmaV,SigmaW,model[,biasCfg]).');
end

if soc0 > 1
    soc0 = soc0 / 100;
end

nRC = getNumRC(T0, model);
if nRC < 1
    error('initESCSPKF:MissingRCStates', ...
        'Full ESC model required: no RC branch states found.');
end
Nx = nRC + 2;

SigmaX0 = normalizeStateCovariance(SigmaX0, Nx);
SigmaW = normalizeNoiseVariance(SigmaW);
SigmaV = normalizeNoiseVariance(SigmaV);

spkf_data = struct();
spkf_data.irInd = 1:nRC;
spkf_data.hkInd = nRC + 1;
spkf_data.soc_estInd = nRC + 2;
spkf_data.zkInd = spkf_data.soc_estInd;
spkf_data.xhat = [zeros(nRC, 1); 0; soc0];

spkf_data.SigmaX = SigmaX0;
spkf_data.SigmaV = SigmaV;
spkf_data.SigmaW = SigmaW;
spkf_data.Snoise = real(chol(diag([SigmaW(:); SigmaV(:)]), 'lower'));
spkf_data.Qbump = 5;

spkf_data.Nx = Nx;
spkf_data.Ny = 1;
spkf_data.Nu = 1;
spkf_data.Nw = numel(SigmaW);
spkf_data.Nv = numel(SigmaV);
spkf_data.Na = spkf_data.Nx + spkf_data.Nw + spkf_data.Nv;

h = sqrt(3);
spkf_data.h = h;
weight1 = (h * h - spkf_data.Na) / (h * h);
weight2 = 1 / (2 * h * h);
spkf_data.Wm = [weight1; weight2 * ones(2 * spkf_data.Na, 1)];
spkf_data.Wc = spkf_data.Wm;

spkf_data.priorI = 0;
spkf_data.signIk = 0;
spkf_data.model = model;

if nargin == 7
    spkf_data = initializeBiasFilter(spkf_data, varargin{1});
end
end

function spkf_data = initializeBiasFilter(spkf_data, biasCfg)
if ~isstruct(biasCfg)
    error('initESCSPKF:BadBiasConfig', 'Optional biasCfg must be a struct.');
end

Nx = spkf_data.Nx;
Ny = spkf_data.Ny;

nb = parseNumBiasStates(biasCfg, Nx, Ny);
bhat0 = zeros(nb, 1);
if isfield(biasCfg, 'bhat0')
    bhat0 = biasCfg.bhat0(:);
end
if numel(bhat0) ~= nb
    error('initESCSPKF:BadBiasInit', 'biasCfg.bhat0 must be nb-by-1.');
end

if isfield(biasCfg, 'SigmaB0')
    SigmaB0 = biasCfg.SigmaB0;
else
    SigmaB0 = eye(nb) * 1e-6;
end
if isscalar(SigmaB0)
    SigmaB0 = eye(nb) * SigmaB0;
end
if ~ismatrix(SigmaB0) || any(size(SigmaB0) ~= [nb, nb])
    error('initESCSPKF:BadBiasCovariance', 'biasCfg.SigmaB0 must be nb-by-nb.');
end

Bb = zeros(Nx, nb);
if isfield(biasCfg, 'Bb')
    Bb = biasCfg.Bb;
end
if ~ismatrix(Bb) || any(size(Bb) ~= [Nx, nb])
    error('initESCSPKF:BadBb', 'biasCfg.Bb must be Nx-by-nb.');
end

Cb = zeros(Ny, nb);
if isfield(biasCfg, 'Cb')
    Cb = biasCfg.Cb;
end
if ~ismatrix(Cb) || any(size(Cb) ~= [Ny, nb])
    error('initESCSPKF:BadCb', 'biasCfg.Cb must be Ny-by-nb.');
end

V0 = zeros(Nx, nb);
if isfield(biasCfg, 'V0')
    V0 = biasCfg.V0;
end
if ~ismatrix(V0) || any(size(V0) ~= [Nx, nb])
    error('initESCSPKF:BadV0', 'biasCfg.V0 must be Nx-by-nb.');
end

currentBiasInd = 1;
if isfield(biasCfg, 'currentBiasInd')
    currentBiasInd = biasCfg.currentBiasInd;
end
if ~isscalar(currentBiasInd) || currentBiasInd < 1 || currentBiasInd > nb
    error('initESCSPKF:BadCurrentBiasIndex', ...
        'biasCfg.currentBiasInd must be a scalar integer in [1, nb].');
end

spkf_data.nb = nb;
spkf_data.bhat = bhat0;
spkf_data.SigmaB = real((SigmaB0 + SigmaB0') / 2);
spkf_data.Bb = Bb;
spkf_data.Cb = Cb;
spkf_data.V = V0;
spkf_data.currentBiasInd = currentBiasInd;

biasModelStatic = false;
if isfield(biasCfg, 'biasModelStatic')
    biasModelStatic = logical(biasCfg.biasModelStatic);
end
if ~isscalar(biasModelStatic)
    error('initESCSPKF:BadBiasModelStatic', 'biasCfg.biasModelStatic must be scalar logical.');
end
spkf_data.biasModelStatic = biasModelStatic;

if biasModelStatic
    if ~isfield(biasCfg, 'Ad') || ~isfield(biasCfg, 'Cd')
        error('initESCSPKF:MissingStaticBiasModel', ...
            'biasCfg.Ad and biasCfg.Cd are required when biasModelStatic is true.');
    end
    AdBias = biasCfg.Ad;
    CdBias = biasCfg.Cd;
    if ~ismatrix(AdBias) || any(size(AdBias) ~= [Nx, Nx])
        error('initESCSPKF:BadAdBias', 'biasCfg.Ad must be Nx-by-Nx.');
    end
    if ~ismatrix(CdBias) || any(size(CdBias) ~= [Ny, Nx])
        error('initESCSPKF:BadCdBias', 'biasCfg.Cd must be Ny-by-Nx.');
    end
    spkf_data.AdBias = AdBias;
    spkf_data.CdBias = CdBias;
end
end

function nb = parseNumBiasStates(biasCfg, Nx, Ny)
if isfield(biasCfg, 'nb')
    nb = biasCfg.nb;
elseif isfield(biasCfg, 'bhat0')
    nb = numel(biasCfg.bhat0);
elseif isfield(biasCfg, 'SigmaB0')
    nb = size(biasCfg.SigmaB0, 1);
elseif isfield(biasCfg, 'Bb')
    nb = size(biasCfg.Bb, 2);
elseif isfield(biasCfg, 'Cb')
    nb = size(biasCfg.Cb, 2);
else
    nb = Nx + Ny;
end

if ~isscalar(nb) || nb < 1 || round(nb) ~= nb
    error('initESCSPKF:BadNb', 'biasCfg.nb must be a positive integer.');
end
nb = double(nb);
end

function SigmaX = normalizeStateCovariance(SigmaX0, Nx)
if isscalar(SigmaX0)
    SigmaX = eye(Nx) * SigmaX0;
elseif isvector(SigmaX0)
    vec = SigmaX0(:);
    if numel(vec) ~= Nx
        error('initESCSPKF:BadSigmaX0', 'SigmaX0 vector length must match the number of states.');
    end
    SigmaX = diag(vec);
else
    [nRows, nCols] = size(SigmaX0);
    if nRows ~= nCols || nRows ~= Nx
        error('initESCSPKF:BadSigmaX0', 'SigmaX0 must be an Nx-by-Nx covariance matrix.');
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
    error('initESCSPKF:BadNoiseVariance', 'SigmaV and SigmaW must be scalars or vectors.');
end
end

function nRC = getNumRC(T0, model)
if isfield(model, 'RCParam')
    nRC = numel(getParamESC('RCParam', T0, model));
else
    nRC = 0;
end
end
