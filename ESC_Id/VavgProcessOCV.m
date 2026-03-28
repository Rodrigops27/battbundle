% function model=VavgProcessOCV(data,cellID,minV,maxV,savePlots,debugPlots)
%
% Inputs:
%   data = cell-test data passed in from runProcessOCV
%   cellID = cell identifier (string)
%   minV = minimum cell voltage to use in OCV relationship
%   maxV = maximum cell voltage to use in OCV relationship
%   savePlots = 0 or 1 ... set to "1" to save plots as files
%   debugPlots = 0 or 1 ... set to "1" to show averaging debug plots
% Output:
%   model = data structure with information for recreating OCV
%
% This function follows the same test-processing structure as processOCV.m
% but reconstructs the OCV curve via voltage averaging of charge and
% discharge traces, analogous to the reference OCP_voltageAverage method.
%
% Reference implementation adapted from "estimateOCV.m", developed by:
% Prof. Gregory L. Plett and Prof. M. Scott Trimboli University of Colorado
% Colorado Springs (UCCS) as part of the Physics-Based Reduced-Order Model
% framework for lithium-ion batteries (see: Battery Management Systems,
% Volume III: Physics-Based Methods, Artech House, 2024).
% (Functions mirrored: setupIndsLocs, setupBlend, simStep, shortWarn)
% License:
%   This file is distributed under the Creative Commons Attribution-ShareAlike
%   4.0 International License (CC BY-SA 4.0).

function model=VavgProcessOCV(data,cellID,minV,maxV,savePlots,debugPlots)
  if nargin < 6 || isempty(debugPlots)
    debugPlots = false;
  end

  filetemps = [data.temp]; filetemps = filetemps(:);
  numtemps = length(filetemps);

  ind25 = find(filetemps == 25);
  if isempty(ind25)
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
  config = defaultVavgConfig(minV,maxV,debugPlots);

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
  filedata(k) = buildVavgFiledata(data(k), cellID, Q25, config);

  for k = not25'
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
    filedata(k) = buildVavgFiledata(data(k), cellID, Q25, config);
  end

  Vraw = []; temps = [];
  for k = 1:numtemps
    if filedata(k).temp > 0
      Vraw = [Vraw; filedata(k).rawocv]; %#ok<AGROW>
      temps = [temps; filedata(k).temp]; %#ok<AGROW>
    end
  end
  numtempskept = size(Vraw,1);

  OCV0 = zeros(size(SOC)); OCVrel = OCV0;
  H = [ones([numtempskept,1]), temps];
  for k = 1:length(SOC)
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
  for T = filetemps'
    v1 = OCVfromSOCtemp(z,T,model);
    socs = [socs; interp1(v1,z,v)]; %#ok<AGROW>
  end

  SOC0 = zeros(size(v)); SOCrel = SOC0;
  H = [ones([numtemps,1]), filetemps];
  for k = 1:length(v)
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

  for k = 1:numtemps
    figure;
    plot(100*SOC,OCVfromSOCtemp(SOC,filedata(k).temp,model), ...
         100*SOC,filedata(k).rawocv); hold on
    xlabel('SOC (%)'); ylabel('OCV (V)'); ylim([minV-0.1 maxV+0.1]);
    title(sprintf('%s OCV relationship at temp = %d (Voltage Average)', ...
      cellID,filedata(k).temp)); xlim([0 100]);
    err = filedata(k).rawocv - ...
          OCVfromSOCtemp(SOC,filedata(k).temp,model);
    rmserr = sqrt(mean(err.^2));
    text(2,maxV-0.15,sprintf('RMS error = %4.1f (mV)', ...
      rmserr*1000),'fontsize',14);
    plot(100*filedata(k).disZ,filedata(k).disV,'k--','linewidth',1);
    plot(100*filedata(k).chgZ,filedata(k).chgV,'k--','linewidth',1);
    legend('Model prediction','Approximate OCV from data', ...
           'Raw measured data','location','southeast');

    if savePlots
      if ~exist('OCV_FIGURES','dir'), mkdir('OCV_FIGURES'); end
      if filetemps(k) < 0
        filename = sprintf('OCV_FIGURES/%s_Vavg_N%02d.png', ...
          cellID,abs(filetemps(k)));
      else
        filename = sprintf('OCV_FIGURES/%s_Vavg_P%02d.png', ...
          cellID,filetemps(k));
      end
      print(filename,'-dpng')
    end
  end
end

function filedatum = buildVavgFiledata(testdata, cellID, Q25, config)
  indD  = find(testdata.script1.step == 2);
  indC  = find(testdata.script3.step == 2);

  disZ = 1 - testdata.script1.disAh(indD)/Q25;
  disZ = disZ + (1 - disZ(1));
  chgZ = testdata.script3.chgAh(indC)/Q25;
  chgZ = chgZ - chgZ(1);

  disV = testdata.script1.voltage(indD);
  chgV = testdata.script3.voltage(indC);

  avgData = struct();
  avgData.name = cellID;
  avgData.TdegC = testdata.temp;
  avgData.orig.disZ = disZ(:);
  avgData.orig.disV = disV(:);
  avgData.orig.chgZ = chgZ(:);
  avgData.orig.chgV = chgV(:);
  avgData.interp = makeVavgInterpData(avgData.orig, config);

  [avgZ, avgU] = OCV_voltageAverage(avgData, config);

  filedatum.temp = testdata.temp;
  filedatum.disZ = disZ(:);
  filedatum.disV = disV(:);
  filedatum.chgZ = chgZ(:);
  filedatum.chgV = chgV(:);
  filedatum.rawocv = interp1(avgZ,avgU,0:0.005:1,'linear','extrap');

  if config.debug
    figure;
    plot(100*avgData.interp.stdZ,avgData.interp.disV, ...
         100*avgData.interp.stdZ,avgData.interp.chgV, ...
         100*avgZ,avgU,'LineWidth',1.2);
    xlabel('SOC (%)');
    ylabel('Voltage (V)');
    title(sprintf('%s Cell @ %.2f\\circC Voltage Average', ...
      cellID,testdata.temp));
    legend('Discharge','Charge','Average','location','southeast');
    xlim([0 100]);
    ylim([config.vmin config.vmax]);
    grid on;
    drawnow;
  end
end

function interpData = makeVavgInterpData(orig, config)
  stdZ = (0:config.dz:1).';
  interpData.stdZ = stdZ;
  interpData.disV = linearinterp(orig.disZ,orig.disV,stdZ);
  interpData.chgV = linearinterp(orig.chgZ,orig.chgV,stdZ);
end

function config = defaultVavgConfig(vmin,vmax,debugPlots)
  if nargin < 3 || isempty(debugPlots)
    debugPlots = false;
  end

  config = struct();
  config.vmin = vmin;
  config.vmax = vmax;
  config.dz = 0.002;
  config.debug = logical(debugPlots);
end

function [Z, U] = OCV_voltageAverage(data, ~)
  Z = data.interp.stdZ;
  U = (data.interp.chgV + data.interp.disV)/2;
end
