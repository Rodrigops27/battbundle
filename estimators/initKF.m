% function kfData = initKF(SOC0,T0,SigmaX0,SigmaV,SigmaW,blend,ROMs)
%
% Inputs:
%   SOC0    = The SOC value (%) to use to initialize the xKF
%   T0      = The temperature at which the simulation was conducted (degC)
%   SigmaX0 = The initial covariance of the state estimation error
%   SigmaV  = The covariance of the voltage-sensor noise
%   SigmaW  = The covariance of the process noise
%   blend   = 'MdlB' or 'OutB' ... the method for blending
%   ROMs    = The set of ROMs to use as the model
%
% Output:
%   kfData  = The initialized data structure
%
% This is a utility function that initializes the xKF (either EKF or SPKF).
% It returns a data structure suitable for using with either EKF or SPKF.
%
% Reference implementation adapted from "initKF.m", developed by:
% Copyright (©) 2024 The Regents of the University of Colorado, a body
% corporate. Created by Gregory L. Plett and M. Scott Trimboli of the
% University of Colorado Colorado Springs (UCCS). This work is licensed
% under a Creative Commons "Attribution-ShareAlike 4.0 International" Intl.
% License. https://creativecommons.org/licenses/by-sa/4.0/
% This code is provided as a supplement to: Gregory L. Plett and M. Scott
% Trimboli, "Battery Management Systems, Volume III, Physics-Based
% Methods," Artech House, 2024. It is provided "as is", without express or
% implied warranty. Attribution should be given by citing: Gregory L. Plett
% and M. Scott Trimboli, Battery Management Systems, Volume III:
% Physics-Based Methods, Artech House, 2024.

function kfData = initKF(SOC0,T0,SigmaX0,SigmaV,SigmaW,blend,ROMs)
clear iterEKF; % we need to clear persistent variables in this function
clear iterSPKF; % we need to clear persistent variables in this function

kfData.SOC = SOC0/100;
if T0 > 100
    warning('initKF assumes that T0 is in Celsius. Converting...');
    T0 = T0 - 273.15; % Convert Kelvin to degC
end
kfData.T = T0 + 273.15; % Convert to Kelvin...

% ---- Save initial scalars before overwriting kfData.T with the grid ----
TinitK  = kfData.T;    % scalar Kelvin (from input T0)
% SOC0pct = SOC0;        % percent (input)
isNB = any(strcmpi(strtrim(char(blend)), {'NB','NNB','NONB','NONBLEND'}));

switch upper(char(blend))
    case {'OUTB','OB'}
        kfData.method = 'OB';
    case {'MDLB','MB'}
        kfData.method = 'MB';
    case {'NNB','NB','NONB','NONBLEND'}
        % Treat nonBlend as degenerate model-blend
        kfData.method = 'MB';
    otherwise
        warning(['"blend" input to initKF not recognized. Switching ' ...
            'to output blending (OutB)']);
        kfData.method = 'OB';
end


% Work on the ROMs
% First, copy the (temperature,SOC) setpoint into aux matrices
T = zeros(size(ROMs.ROMmdls)); Z = T;
T(:) = [ROMs.ROMmdls(:).T];      % in K
Z(:) = [ROMs.ROMmdls(:).SOC];    % in 0..1
n = size(ROMs.ROMmdls(1).A,1)-1; % recall that n = transient states only
nz = size(ROMs.ROMmdls(1,1).C,1); % number of outputs from model

if isNB % using 1x1 ROM grid
    % Match NB_step's fixed-setpoint selection logic (nearest once)
    TptsK = ROMs.xraData.T + 273.15;   % degC -> K
    ZptsP = ROMs.xraData.SOC;          % percent
    ZselP = ZptsP(end);                % SOC setpoint

    [~, iTnear] = min(abs(TptsK - TinitK));
    [~, iZnear] = min(abs(ZptsP - ZselP));

    % Shrink to a 1x1 ROM grid (fixed model)
    ROMs.ROMmdls = ROMs.ROMmdls(iTnear, iZnear);

    % Optional trace
    kfData.fixed.iT = iTnear;
    kfData.fixed.iZ = iZnear;

    % Recompute grid arrays now that ROMmdls is 1x1
    T = ROMs.ROMmdls.T;
    Z = ROMs.ROMmdls.SOC;
    nz = size(ROMs.ROMmdls.C,1);
end

% Copy matrices from ROMs to more direct storage; be sure to strip off
% the x0 components as appropriate; also, initialize model states and
% covariances
if ~isequal(size(SigmaX0),[n+1 n+1])
    error(['Input argument SigmaX0 has wrong dimension. Should be '...
        '%d by %d'],n+1,n+1);
end
SigmaX = SigmaX0(1:end-1,1:end-1);
for theT = 1:size(T,1)
    for theZ = 1:size(T,2)
        A = ROMs.ROMmdls(theT,theZ).A;
        if A(end,end) ~= 1
            error(['A for T=%g degC and Z=%g %% does not have integrator '...
                'state'],T(theT,theZ)-273.15,Z(theT,theZ)*100);
        end
        if ~isequal(diag(diag(A)),A)
            error('A for T=%g degC and Z=%g %% is not diagonal',...
                T(theT,theZ)-273.15,Z(theT,theZ)*100);
        end
        kfData.M(theT,theZ).A = diag(A(1:n,1:n)); % strip integrator residue

        B = ROMs.ROMmdls(theT,theZ).B;
        if prod(B) ~= 1
            error('B for T=%g degC and Z=%g %% is not all units values',...
                T(theT,theZ)-273.15,Z(theT,theZ)*100);
        end % no need to store B since we know what it is

        % Strip integrator res0 terms off of C
        kfData.M(theT,theZ).C = ROMs.ROMmdls(theT,theZ).C(:,1:end-1);
        kfData.M(theT,theZ).D = ROMs.ROMmdls(theT,theZ).D;

        kfData.M(theT,theZ).xhat = zeros(n,1); % for output blend
        kfData.M(theT,theZ).SigmaX = SigmaX;   % for output blend
    end
end
kfData.x0 = 0; % initialize integrator state and covariance
kfData.SigmaX0 = SigmaX0(end,end);
kfData.xhat = zeros(n+1,1); % for model blend
kfData.SigmaX = SigmaX0;   % for model blend

% Covariance values
kfData.SigmaV = SigmaV;
kfData.SigmaW = SigmaW;

% SPKF specific parameters for steps 1c and 3a
switch kfData.method
    case 'OB'
        Na = 4*n+1; % four models being blended plus one integrator state
    case 'MB'
        Na = n+1; % one model plus one integrator state
end
h = sqrt(3); kfData.h = h; % SPKF/CDKF tuning factor
alpha1 = (h*h-Na)/(h*h); % weighting factors when computing mean
alpha2 = 1/(2*h*h); % and covariance
kfData.alpham = [alpha1; alpha2*ones(2*Na,1)]; % mean
kfData.alphac = kfData.alpham;

% previous value of current
kfData.priorI = 0;

% store model data structure too
kfData.T = T; % the temperatures of every setpoint ROM in ROMs
kfData.Z = Z; % the SOC of every setpoint ROM in ROMs
kfData.n = n; % the number of transient states in each ROM
kfData.nz = nz; % the number of outputs

% transfer-function ordering (etc.) used when computing nonlinear things
kfData.tfData = ROMs.tfData;
% sample period and capacity
kfData.Ts = ROMs.xraData.Tsamp; % sample period
kfData.SOC0 = SOC0/100;
% everyting else
kfData.cellData = ROMs.cellData;
end
