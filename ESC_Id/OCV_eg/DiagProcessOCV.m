% function model=DiagProcessOCV(data,cellID,minV,maxV,savePlots)
%
% Inputs:
%   data = cell-test data passed in from runProcessOCV
%   cellID = cell identifier (string)
%   minV = minimum cell voltage to use in OCV relationship
%   maxV = maximum cell voltage to use in OCV relationship
%   savePlots = 0 or 1 ... set to "1" to save plots as files
% Output:
%   model = data structure with information for recreating OCV
%
% This function follows the same test-processing structure as processOCV.m
% but reconstructs the OCV curve via diagonal averaging of charge and
% discharge traces rather than via resistance blending.

% Copyright (c) 2015 by Gregory L. Plett of the University of Colorado
% Colorado Springs (UCCS). This work is licensed under a Creative Commons
% Attribution-NonCommercial-ShareAlike 4.0 Intl. License, v. 1.0.
% It is provided "as is", without express or implied warranty, for
% educational and informational purposes only.

function model=DiagProcessOCV(data,cellID,minV,maxV,savePlots)
  filetemps = [data.temp]; filetemps = filetemps(:);
  numtemps = length(filetemps);

  ind25 = find(filetemps == 25);
  if isempty(ind25),
    error('Must have a test at 25degC');
  end
  not25 = find(filetemps ~= 25);

  SOC = 0:0.005:1;
  filedata = repmat(struct( ...
    'temp', [], ...
    'disZ', [], ...
    'disV', [], ...
    'chgZ', [], ...
    'chgV', [], ...
    'rawocv', []), numtemps, 1);
  eta = zeros(size(filetemps));
  Q   = zeros(size(filetemps));
  config = defaultDiagConfig(minV,maxV);

  k = ind25;
  totDisAh = data(k).script1.disAh(end) + ...
             data(k).script2.disAh(end) + ...
             data(k).script3.disAh(end) + ...
             data(k).script4.disAh(end);
  totChgAh = data(k).script1.chgAh(end) + ...
             data(k).script2.chgAh(end) + ...
             data(k).script3.chgAh(end) + ...
             data(k).script4.chgAh(end);
  eta25 = totDisAh/totChgAh; eta(k) = eta25;
  data(k).script1.chgAh = data(k).script1.chgAh*eta25;
  data(k).script2.chgAh = data(k).script2.chgAh*eta25;
  data(k).script3.chgAh = data(k).script3.chgAh*eta25;
  data(k).script4.chgAh = data(k).script4.chgAh*eta25;

  Q25 = data(k).script1.disAh(end) + data(k).script2.disAh(end) - ...
        data(k).script1.chgAh(end) - data(k).script2.chgAh(end);
  Q(k) = Q25;
  filedata(k) = buildDiagFiledata(data(k), cellID, Q25, config);

  for k = not25',
    data(k).script2.chgAh = data(k).script2.chgAh*eta25;
    data(k).script4.chgAh = data(k).script4.chgAh*eta25;
    eta(k) = (data(k).script1.disAh(end) + ...
              data(k).script2.disAh(end) + ...
              data(k).script3.disAh(end) + ...
              data(k).script4.disAh(end) - ...
              data(k).script2.chgAh(end) - ...
              data(k).script4.chgAh(end))/ ...
             (data(k).script1.chgAh(end) + ...
              data(k).script3.chgAh(end));
    data(k).script1.chgAh = eta(k)*data(k).script1.chgAh;
    data(k).script3.chgAh = eta(k)*data(k).script3.chgAh;

    Q(k) = data(k).script1.disAh(end) + data(k).script2.disAh(end) ...
           - data(k).script1.chgAh(end) - data(k).script2.chgAh(end);
    filedata(k) = buildDiagFiledata(data(k), cellID, Q25, config);
  end

  Vraw = []; temps = [];
  for k = 1:numtemps,
    if filedata(k).temp > 0,
      Vraw = [Vraw; filedata(k).rawocv]; %#ok<AGROW>
      temps = [temps; filedata(k).temp]; %#ok<AGROW>
    end
  end
  numtempskept = size(Vraw,1);

  OCV0 = zeros(size(SOC)); OCVrel = OCV0;
  H = [ones([numtempskept,1]), temps];
  for k = 1:length(SOC),
    X = H\Vraw(:,k);
    OCV0(k) = X(1);
    OCVrel(k) = X(2);
  end
  model.OCV0 = OCV0;
  model.OCVrel = OCVrel;
  model.SOC = SOC;

  z = -0.1:0.01:1.1;
  v = minV-0.01:0.01:maxV+0.01;
  socs = [];
  for T = filetemps',
    v1 = OCVfromSOCtemp(z,T,model);
    socs = [socs; interp1(v1,z,v)]; %#ok<AGROW>
  end

  SOC0 = zeros(size(v)); SOCrel = SOC0;
  H = [ones([numtemps,1]), filetemps];
  for k = 1:length(v),
    X = H\socs(:,k);
    SOC0(k) = X(1);
    SOCrel(k) = X(2);
  end
  model.OCV = v;
  model.SOC0 = SOC0;
  model.SOCrel = SOCrel;

  model.OCVeta = eta;
  model.OCVQ = Q;
  model.name = cellID;

  for k = 1:numtemps,
    figure;
    plot(100*SOC,OCVfromSOCtemp(SOC,filedata(k).temp,model),...
         100*SOC,filedata(k).rawocv); hold on
    xlabel('SOC (%)'); ylabel('OCV (V)'); ylim([minV-0.1 maxV+0.1]);
    title(sprintf('%s OCV relationship at temp = %d (Diagonal Average)',...
      cellID,filedata(k).temp)); xlim([0 100]);
    err = filedata(k).rawocv - ...
          OCVfromSOCtemp(SOC,filedata(k).temp,model);
    rmserr = sqrt(mean(err.^2));
    text(2,maxV-0.15,sprintf('RMS error = %4.1f (mV)',...
      rmserr*1000),'fontsize',14);
    plot(100*filedata(k).disZ,filedata(k).disV,'k--','linewidth',1);
    plot(100*filedata(k).chgZ,filedata(k).chgV,'k--','linewidth',1);
    legend('Model prediction','Approximate OCV from data', ...
           'Raw measured data','location','southeast');

    if savePlots,
      if ~exist('OCV_FIGURES','dir'), mkdir('OCV_FIGURES'); end
      if filetemps(k) < 0,
        filename = sprintf('OCV_FIGURES/%s_DiagAvg_N%02d.png', ...
          cellID,abs(filetemps(k)));
      else
        filename = sprintf('OCV_FIGURES/%s_DiagAvg_P%02d.png', ...
          cellID,filetemps(k));
      end
      print(filename,'-dpng')
    end
  end
end

function filedatum = buildDiagFiledata(testdata, cellID, Q25, config)
  indD  = find(testdata.script1.step == 2);
  indC  = find(testdata.script3.step == 2);

  disZ = 1 - testdata.script1.disAh(indD)/Q25;
  disZ = disZ + (1 - disZ(1));
  chgZ = testdata.script3.chgAh(indC)/Q25;
  chgZ = chgZ - chgZ(1);

  disV = testdata.script1.voltage(indD);
  chgV = testdata.script3.voltage(indC);

  diagData = struct();
  diagData.name = cellID;
  diagData.TdegC = testdata.temp;
  diagData.orig.disZ = disZ(:);
  diagData.orig.disV = disV(:);
  diagData.orig.chgZ = chgZ(:);
  diagData.orig.chgV = chgV(:);
  diagData.interp = makeDiagInterpData(diagData.orig, config);

  [diagZ, diagU] = OCV_diagonalAverage(diagData, config);

  filedatum.temp = testdata.temp;
  filedatum.disZ = disZ(:);
  filedatum.disV = disV(:);
  filedatum.chgZ = chgZ(:);
  filedatum.chgV = chgV(:);
  filedatum.rawocv = interp1(diagZ,diagU,0:0.005:1,'linear','extrap');
end

function interpData = makeDiagInterpData(orig, config)
  stdV = (config.vmin:config.du:config.vmax).';
  stdZ = (0:config.dz:1).';

  [disVuniq, disVidx] = unique(orig.disV(:),'stable');
  disZuniqV = orig.disZ(disVidx);
  [chgVuniq, chgVidx] = unique(orig.chgV(:),'stable');
  chgZuniqV = orig.chgZ(chgVidx);

  [disZuniq, disZidx] = unique(orig.disZ(:),'stable');
  disVuniqZ = orig.disV(disZidx);
  [chgZuniq, chgZidx] = unique(orig.chgZ(:),'stable');
  chgVuniqZ = orig.chgV(chgZidx);

  interpData.stdV = stdV;
  interpData.disZ = interp1(disVuniq,disZuniqV,stdV,'linear','extrap');
  interpData.chgZ = interp1(chgVuniq,chgZuniqV,stdV,'linear','extrap');

  interpData.stdZ = stdZ;
  interpData.disV = interp1(disZuniq,disVuniqZ,stdZ,'linear','extrap');
  interpData.chgV = interp1(chgZuniq,chgVuniqZ,stdZ,'linear','extrap');
end

function config = defaultDiagConfig(vmin,vmax)
  config = struct();
  config.vmin = vmin;
  config.vmax = vmax;
  config.du = 0.002;
  config.dz = 0.002;
  config.datype = 'useAvg';
  config.debug = false;
  config.daxcorrfiltv = @(stdV) find(stdV >= vmin & stdV <= vmax);
  config.daxcorrfiltz = @(stdZ) find(stdZ >= 0 & stdZ <= 1);
end

function [Z, U] = OCV_diagonalAverage(data, config)
  stdV = data.interp.stdV;
  disZ = data.interp.disZ;
  chgZ = data.interp.chgZ;

  stdZ = data.interp.stdZ;
  disV = data.interp.disV;
  chgV = data.interp.chgV;

  du = mean(diff(stdV));
  intervals = config.daxcorrfiltv(stdV);
  if ~iscell(intervals), intervals = {intervals}; end
  lagU = zeros(size(intervals));
  for k = 1:length(intervals)
    ind = intervals{k};
    dzdv1 = roughdiff(disZ(ind),stdV(ind));
    dzdv3 = roughdiff(chgZ(ind),stdV(ind));
    [c,lag] = xcorr(dzdv1,dzdv3);
    lagU(k) = abs(lag(c==max(c))*du);
    lagU(k) = lagU(k,1);
  end
  lagU = mean(lagU);

  dz = mean(diff(stdZ));
  intervals = config.daxcorrfiltz(stdZ);
  if ~iscell(intervals), intervals = {intervals}; end
  lagZ = zeros(size(intervals));
  for k = 1:length(intervals)
    ind = intervals{k};
    dzdv1 = roughdiff(stdZ(ind),disV(ind));
    dzdv3 = roughdiff(stdZ(ind),chgV(ind));
    [c,lag] = xcorr(dzdv1,dzdv3);
    lagZ(k) = abs(lag(c==max(c))*dz);
    lagZ(k) = lagZ(k,1);
  end
  lagZ = mean(lagZ);

  uuD = data.orig.disV + lagU/2;
  zzD = data.orig.disZ + lagZ/2;
  U4D = interp1(zzD,uuD,stdZ,'linear','extrap');
  uuC = data.orig.chgV - lagU/2;
  zzC = data.orig.chgZ - lagZ/2;
  U4C = interp1(zzC,uuC,stdZ,'linear','extrap');
  switch config.datype
    case 'useDis'
      U4 = U4D;
    case 'useChg'
      U4 = U4C;
    otherwise
      U4 = (U4C + U4D)/2;
  end

  Z = stdZ;
  U = U4;
end

function dy = roughdiff(y,x)
  y = y(:);
  x = x(:);
  if numel(y) ~= numel(x)
    error('roughdiff requires vectors of equal length.');
  end
  if numel(y) < 2
    dy = zeros(size(y));
    return;
  end

  dy = zeros(size(y));
  dy(1) = (y(2)-y(1))/(x(2)-x(1));
  dy(end) = (y(end)-y(end-1))/(x(end)-x(end-1));
  for k = 2:numel(y)-1
    dy(k) = (y(k+1)-y(k-1))/(x(k+1)-x(k-1));
  end
  dy(~isfinite(dy)) = 0;
end
