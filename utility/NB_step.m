function [Vcell, obs, cellState] = NB_step(Iapp, Tc, cellState, ROM, initCfg)
% NB_STEP  One-timestep Non-Blend ROM simulation for MPC loops
%
%   [Vcell, obs, cellState] = NB_step(Iapp, Tc, cellState, ROM, initCfg)
%
% Inputs
%   Iapp      : applied current at this step (A)  (charging < 0)
%   Tc        : cell temperature in degC at this step
%   cellState : persistent state structure from previous call (pass [] on first call)
%   ROM       : xRA ROM structure (same used by nonBlend/outBlend)
%   initCfg   : struct used on first call only with fields:
%                 .SOC0    initial SOC in % (e.g., 10)
%                 .warnOff (optional) if true, suppresses short warnings
%
% Outputs
%   Vcell     : cell voltage at this step (V)
%   obs       : struct with per-step outputs (Ifdl/If/Idl/Phis/Phise/Phie/Thetae,
%               Thetass, SOCn/SOCp/cellSOC, etc.)
%   cellState : updated persistent state to feed next NB_step call
%
% Notes
%   - This is a single-step version of "nonBlend": NO blending. A single
%     (T,SOC) setpoint model is selected on first call (nearest to initCfg)
%     and held fixed thereafter, matching nonBlend.m behavior.
%   - Sampling time is taken from ROM.xraData.Tsamp.
%
% Reference implementation adapted from "nonBlend.m", developed by:
% Prof. Gregory L. Plett and Prof. M. Scott Trimboli University of Colorado
% Colorado Springs (UCCS) as part of the Physics-Based Reduced-Order Model
% framework for lithium-ion batteries (see: Battery Management Systems,
% Volume III: Physics-Based Methods, Artech House, 2024).
% (Functions mirrored: setupIndsLocs, setupBlend, simStep, shortWarn)
% License:
%   This file is distributed under the Creative Commons Attribution-ShareAlike
%   4.0 International License (CC BY-SA 4.0).
% -------------------------------------------------------------------------

% -- One-time setup / first call ----------------------------------------
if nargin < 3 || isempty(cellState) || ~isfield(cellState,'initialized') || ~cellState.initialized
    if nargin < 5 || ~isfield(initCfg,'SOC0')
        error('First call requires initCfg.SOC0 (in %).');
    end

    cellState = struct();
    cellState.initialized = true;
    cellState.warnOff = (nargin>=5) && isfield(initCfg,'warnOff') && logical(initCfg.warnOff);

    % Cache ROM bits
    cellState.ROMmdls  = ROM.ROMmdls;
    cellState.cellData = ROM.cellData;
    cellState.Ts       = ROM.xraData.Tsamp;

    % Build indices/locations once (same indexing checks as outBlend/nonBlend)
    cellState.ROM = ROM; % keep for tfData access
    setupIndsLocs;

    % Initial electrode-average SOC (convert from % to local-electrode SOCs)
    Tk1 = Tc + 273.15;
    SOC0n = cellState.cellData.function.neg.soc(initCfg.SOC0/100, Tk1);
    SOC0p = cellState.cellData.function.pos.soc(initCfg.SOC0/100, Tk1);
    cellState.SOCnAvg = SOC0n;
    cellState.SOCpAvg = SOC0p;

    % Keep initial SOC offsets (used in nonlinear corrections, as in nonBlend)
    cellState.SOC0n = SOC0n;
    cellState.SOC0p = SOC0p;

    % Select (T,SOC) nearest-neighbor ROM ONCE (nonBlend behavior)
    TptsK = ROM.xraData.T + 273.15;   % K
    ZptsP = ROM.xraData.SOC;          % %

    % ---- Model-selection targets (decoupled from initial SOC) ----
    % Defaults: use current temperature and init SOC
    TselK = Tk1;
    ZselP = initCfg.SOC0;

    % Option 1: force "last op point" (highest SOC) at 25C (or initCfg.modelTc)
    if isfield(initCfg,'useLastOpPoint') && logical(initCfg.useLastOpPoint)
        ZselP = ZptsP(end);                          % last / highest SOC breakpoint
        if isfield(initCfg,'modelTc')
            TselK = initCfg.modelTc + 273.15;        % degC -> K
        else
            TselK = 25 + 273.15;                     % default 25C
        end
    else
        % Option 2: explicit model-selection SOC/T (still fixed after first call)
        if isfield(initCfg,'modelSOC')
            ZselP = initCfg.modelSOC;                % in %
        end
        if isfield(initCfg,'modelTc')
            TselK = initCfg.modelTc + 273.15;        % in degC
        end
    end

    % Option 3: explicit indices override (most direct)
    if isfield(initCfg,'iTnear') && isfield(initCfg,'iZnear')
        iTnear = initCfg.iTnear;
        iZnear = initCfg.iZnear;
    else
        [~, iTnear] = min(abs(TptsK - TselK));
        [~, iZnear] = min(abs(ZptsP - ZselP));
    end

    cellState.iTnear = iTnear;
    cellState.iZnear = iZnear;

    % (Optional) store for debugging/logging
    cellState.modelTc = TselK - 273.15;
    cellState.modelSOC = ZselP;


    % Initialize single-model state vector x
    nx = size(cellState.ROMmdls(1,1).A,1);
    cellState.x = zeros(nx,1);
end

% -- Do the single simulation step --------------------------------------
[Vcell, newCellState, obs] = simStep(Iapp, Tc+273.15, cellState);

% -- Export updated persistent state ------------------------------------
cellState.x       = newCellState.x;
cellState.SOCnAvg = newCellState.SOCnAvg;
cellState.SOCpAvg = newCellState.SOCpAvg;

% =========================================================================
% Internal helpers (single-step versions)
% =========================================================================

    function setupIndsLocs
        ROMloc = cellState.ROM;
        tfName = ROMloc.tfData.names;
        tfLocs = ROMloc.tfData.xLoc;
        cellState.tfLocs = tfLocs;

        % Negative electrode
        ind.negIfdl    = find(strcmp(tfName,'negIfdl') == 1);
        ind.negIf      = find(strcmp(tfName,'negIf') == 1);
        ind.negIdl     = find(strcmp(tfName,'negIdl') == 1);
        ind.negPhis    = find(strcmp(tfName,'negPhis') == 1);
        ind.negPhise   = find(strcmp(tfName,'negPhise') == 1);
        ind.negThetass = find(strcmp(tfName,'negThetass') == 1);

        % Positive electrode
        ind.posIfdl    = find(strcmp(tfName,'posIfdl') == 1);
        ind.posIf      = find(strcmp(tfName,'posIf') == 1);
        ind.posIdl     = find(strcmp(tfName,'posIdl') == 1);
        ind.posPhis    = find(strcmp(tfName,'posPhis') == 1);
        ind.posPhise   = find(strcmp(tfName,'posPhise') == 1);
        ind.posThetass = find(strcmp(tfName,'posThetass') == 1);

        % Electrolyte potential across cell width
        ind.negPhie = find(strcmp(tfName,'negPhie') == 1);
        ind.sepPhie = find(strcmp(tfName,'sepPhie') == 1);
        ind.posPhie = find(strcmp(tfName,'posPhie') == 1);
        loc.negPhie = tfLocs(ind.negPhie);
        loc.sepPhie = tfLocs(ind.sepPhie);
        loc.posPhie = tfLocs(ind.posPhie);

        ind.Phie = [ind.negPhie; ind.sepPhie; ind.posPhie];
        loc.Phie = [loc.negPhie; loc.sepPhie; loc.posPhie];

        % Electrolyte normalized concentration across cell width
        ind.negThetae  = find(strcmp(tfName,'negThetae')== 1);
        ind.sepThetae  = find(strcmp(tfName,'sepThetae')== 1);
        ind.posThetae  = find(strcmp(tfName,'posThetae')== 1);
        loc.negThetaes = tfLocs(ind.negThetae);
        loc.sepThetaes = tfLocs(ind.sepThetae);
        loc.posThetaes = tfLocs(ind.posThetae);

        ind.Thetae = [ind.negThetae; ind.sepThetae; ind.posThetae];
        loc.Thetae = [loc.negThetaes; loc.sepThetaes; loc.posThetaes];

        % Current-collector specific indices
        ind.negIfdl0    = find(strcmp(tfName,'negIfdl') == 1 & tfLocs == 0);
        ind.posIfdl3    = find(strcmp(tfName,'posIfdl') == 1 & tfLocs == 3);
        ind.negIf0      = find(strcmp(tfName,'negIf')   == 1 & tfLocs == 0);
        ind.posIf3      = find(strcmp(tfName,'posIf')   == 1 & tfLocs == 3);
        ind.negThetass0 = find(strcmp(tfName,'negThetass') == 1 & tfLocs == 0);
        ind.posThetass3 = find(strcmp(tfName,'posThetass') == 1 & tfLocs == 3);
        ind.negPhise0   = find(strcmp(tfName,'negPhise')   == 1 & tfLocs == 0);

        % Checks
        if isempty(ind.negIfdl0), error('Requires Ifdl at negative collector'); end
        if isempty(ind.posIfdl3), error('Requires Ifdl at positive collector'); end
        if isempty(ind.negIf0),   error('Requires If at negative collector');   end
        if isempty(ind.posIf3),   error('Requires If at positive collector');   end
        if loc.Thetae(1) > 0, error('Requires Thetae at negative collector'); end
        if or(loc.Thetae(end)>3+eps,loc.Thetae(end)<3-eps)
            error('Requires Thetae at positive collector');
        end
        if isempty(ind.negThetass0), error('Requires Thetass at negative collector'); end
        if isempty(ind.posThetass3), error('Requires Thetass at positive collector'); end
        if isempty(ind.negPhise0),   error('Requires Phise at negative collector');   end
        if loc.Phie(1) == 0
            shortWarn('First phie x-location should not be zero. Ignoring');
            ind.Phie = ind.Phie(2:end);
            loc.Phie = loc.Phie(2:end);
        end
        if or(loc.Phie(end)>3+eps,loc.Phie(end)<3-eps)
            error('Requires Phie at positive collector');
        end

        cellState.ind = ind;
        cellState.loc = loc;
    end

    function [Vcell,newCellState,obs] = simStep(Iapp,T,cs)
        ind      = cs.ind;
        Ts       = cs.Ts;
        ROMmdls  = cs.ROMmdls;
        cellData = cs.cellData;

        % Fixed non-blended setpoint model indices
        iTnear = cs.iTnear;
        iZnear = cs.iZnear;

        % Initial SOC offsets (nonBlend uses SOC0n/SOC0p for some terms)
        SOC0n = cs.SOC0n;
        SOC0p = cs.SOC0p;

        % Constants / params
        F         = cellData.const.F;
        R         = cellData.const.R;
        Q         = cellData.function.const.Q();   % Ah
        Rc        = cellData.function.const.Rc();
        theta0n   = cellData.function.neg.theta0();
        theta0p   = cellData.function.pos.theta0();
        theta100n = cellData.function.neg.theta100();
        theta100p = cellData.function.pos.theta100();

        wDLn      = cellData.function.neg.wDL(SOC0n,T);
        wDLp      = cellData.function.pos.wDL(SOC0p,T);
        Cdln      = cellData.function.neg.Cdl(SOC0n,T);
        Cdlp      = cellData.function.pos.Cdl(SOC0p,T);
        nDLn      = cellData.function.neg.nDL();
        nDLp      = cellData.function.pos.nDL();
        Cdleffn   = (Cdln^(2-nDLn))*(wDLn^(nDLn-1));
        Cdleffp   = (Cdlp^(2-nDLp))*(wDLp^(nDLp-1));

        % Load present state
        x      = cs.x;
        SOCnAvg = cs.SOCnAvg;
        SOCpAvg = cs.SOCpAvg;

        % ---- Step 1: electrode-average SOC and cell SOC
        obs.negSOC  = SOCnAvg;
        obs.posSOC  = SOCpAvg;
        obs.cellSOC = (SOCnAvg - theta0n)/(theta100n - theta0n);

        % Integrator input gains
        dUocpnAvg = cellData.function.neg.dUocp(SOCnAvg,T);
        dUocppAvg = cellData.function.pos.dUocp(SOCpAvg,T);
        dQn       = abs(theta100n-theta0n);
        dQp       = abs(theta100p-theta0p);
        res0n     = -dQn/(3600*Q - Cdleffn*dQn*dUocpnAvg);
        res0p     =  dQp/(3600*Q - Cdleffp*dQp*dUocppAvg);

        SOCnAvg = SOCnAvg + res0n*Iapp*Ts;
        SOCpAvg = SOCpAvg + res0p*Iapp*Ts;
        if SOCnAvg < 0, shortWarn('Average SOCn < 0'); SOCnAvg = 0; end
        if SOCnAvg > 1, shortWarn('Average SOCn > 1'); SOCnAvg = 1; end
        if SOCpAvg < 0, shortWarn('Average SOCp < 0'); SOCpAvg = 0; end
        if SOCpAvg > 1, shortWarn('Average SOCp > 1'); SOCpAvg = 1; end

        % ---- Step 2: A,C,D at fixed setpoint (remove integrator residue on Phise rows)
        A = ROMmdls(iTnear,iZnear).A;
        C = ROMmdls(iTnear,iZnear).C;
        D = ROMmdls(iTnear,iZnear).D;
        C(ind.negPhise,end) = 0;
        if any(ind.posPhise)
            C(ind.posPhise,end) = 0;
        end

        % ---- Step 3: y[k] and x[k+1] (B assumed ones like ROM design)
        yk = C*x + D*Iapp;
        x  = A*x + Iapp;

        % ---- Step 4: Nonlinear corrections and assemble outputs
        % Ifdl / If / Idl
        obs.negIfdl   = yk(ind.negIfdl);
        obs.posIfdl   = yk(ind.posIfdl);
        obs.negIfdl0  = yk(ind.negIfdl0);
        obs.posIfdl3  = yk(ind.posIfdl3);

        obs.negIf     = yk(ind.negIf);
        obs.posIf     = yk(ind.posIf);
        obs.negIf0    = yk(ind.negIf0);
        obs.posIf3    = yk(ind.posIf3);

        obs.negIdl    = yk(ind.negIdl);
        obs.posIdl    = yk(ind.posIdl);

        % ---------------------------------------------------------
        % Solid surface stoichiometries (thetass)
        % ---------------------------------------------------------
        tmp = yk(ind.negThetass) + SOC0n;
        if any(tmp < 0), shortWarn('negThetass < 0'); end
        if any(tmp > 1), shortWarn('negThetass > 1'); end
        obs.negThetass = min(max(tmp,1e-6),1-1e-6);

        tmp = yk(ind.posThetass) + SOC0p;
        if any(tmp < 0), shortWarn('posThetass < 0'); end
        if any(tmp > 1), shortWarn('posThetass > 1'); end
        obs.posThetass = min(max(tmp,1e-6),1-1e-6);

        tmp = yk(ind.negThetass0) + SOC0n;
        if tmp < 0, shortWarn('negThetass0 < 0'); end
        if tmp > 1, shortWarn('negThetass0 > 1'); end
        obs.negThetass0 = min(max(tmp,1e-6),1-1e-6);

        tmp = yk(ind.posThetass3) + SOC0p;
        if tmp < 0, shortWarn('posThetass3 < 0'); end
        if tmp > 1, shortWarn('posThetass3 > 1'); end
        obs.posThetass3 = min(max(tmp,1e-6),1-1e-6);

        % ---------------------------------------------------------
        % Solid-electrolyte potential difference (phise)
        % The linear output from yk is integrator-removed version
        % ---------------------------------------------------------
        UocpnAvg = cellData.function.neg.Uocp(obs.negSOC,T);
        UocppAvg = cellData.function.pos.Uocp(obs.posSOC,T);

        obs.negPhise  = yk(ind.negPhise)  + UocpnAvg;
        obs.posPhise  = yk(ind.posPhise)  + UocppAvg;
        obs.negPhise0 = yk(ind.negPhise0) + UocpnAvg;

        % ---------------------------------------------------------
        % Compute electrolyte potential: first phie(0,t) then phie(1:3,t)
        % ---------------------------------------------------------
        obs.Phie = zeros(numel(ind.Phie)+1,1);
        obs.Phie(1)     = -obs.negPhise0;
        obs.Phie(2:end) = yk(ind.Phie) - obs.negPhise0;

        % ---------------------------------------------------------
        % Compute electrolyte stoichiometries (thetae)
        % ---------------------------------------------------------
        tmp = yk(ind.Thetae) + 1;
        if any(tmp < 0), shortWarn('Thetae < 0'); end
        obs.Thetae = max(tmp,1e-6);

        % Overpotentials
        k0n = cellData.function.neg.k0(obs.negSOC,T);
        k0p = cellData.function.pos.k0(obs.posSOC,T);
        i0n = k0n*sqrt(obs.Thetae(1)*(1-obs.negThetass0)*obs.negThetass0);
        i0p = k0p*sqrt(obs.Thetae(end)*(1-obs.posThetass3)*obs.posThetass3);
        negEta0 = 2*R*T/F*asinh(obs.negIf0/(2*i0n));
        posEta3 = 2*R*T/F*asinh(obs.posIf3/(2*i0p));

        % Cell voltage
        Uocpn0 = cellData.function.neg.Uocp(obs.negThetass0,T);
        Uocpp3 = cellData.function.pos.Uocp(obs.posThetass3,T);
        Rfn    = cellData.function.neg.Rf(obs.negSOC,T);
        Rfp    = cellData.function.pos.Rf(obs.posSOC,T);

        Vcell = posEta3 - negEta0 + yk(ind.Phie(end)) + Uocpp3 - Uocpn0 ...
            + (Rfp*obs.posIfdl3 - Rfn*obs.negIfdl0);
        Vcell = Vcell - Rc*Iapp;

        % Phis
        obs.negPhis = yk(ind.negPhis);
        obs.posPhis = yk(ind.posPhis) + Vcell;

        obs.Vcell = Vcell;

        % Updated state
        newCellState.x       = x;
        newCellState.SOCnAvg = SOCnAvg;
        newCellState.SOCpAvg = SOCpAvg;
    end

    function shortWarn(msg)
        if cellState.warnOff, return; end
        persistent warnState
        if strcmpi(msg,'on')
            warnState = [];
        elseif strcmpi(msg,'off')
            warnState = 1;
        elseif isempty(warnState)
            fprintf(2,' - Warning: %s\n', msg);
        end
    end
end
