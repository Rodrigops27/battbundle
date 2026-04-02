% function model=DiagProcessOCV(data,cellID,minV,maxV,savePlots,debugPlots,diagType)
%
% Inputs:
%   data = cell-test data passed in from runProcessOCV
%   cellID = cell identifier (string)
%   minV = minimum cell voltage to use in OCV relationship
%   maxV = maximum cell voltage to use in OCV relationship
%   savePlots = 0 or 1 ... set to "1" to save plots as files
%   debugPlots = 0 or 1 ... set to "1" to show diagonal-averaging debug plots
%   diagType = 'useAvg', 'useDis', or 'useChg'
% Output:
%   model = data structure with information for recreating OCV
%
% This function follows the same test-processing structure as processOCV.m
% but reconstructs the OCV curve via diagonal averaging of charge and
% discharge traces rather than via resistance blending.
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
% -------------------------------------------------------------------------
% Known failure mode: flat-plateau / low-slope regions can make the
% derivative-based lag estimation unstable or non-representative.
% If the estimated diagonal shifts leave only a narrow mid-SOC overlap
% between the shifted charge and discharge curves, rawocv can become
% dominated by tail extrapolation and stretch unrealistically near
% 0% and 100% SOC.
%
% A more robust approach is to construct rawocv only on the valid overlap
% interval of the shifted branches, then fill the tails from measured
% charge/discharge data (or leave them unsupported) instead of
% extrapolating the diagonal estimate.
%
% TODO: use a masked/smoothed dU/dZ-based lag estimation instead of
% relying on unmasked dZ/dU-like inverse-slope alignment over the full range.
% adding pchip to the interpolation pursuing for monotonicity.

function model=DiagProcessOCV(data,cellID,minV,maxV,savePlots,debugPlots,diagType)
  if nargin < 6 || isempty(debugPlots)
    debugPlots = false;
  end
  if nargin < 7 || isempty(diagType)
    diagType = 'useAvg';
  end

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
  config = defaultDiagConfig(minV,maxV,debugPlots,diagType);

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
    [v1uniq, uniqIdx] = unique(v1(:), 'stable');
    zuniq = z(uniqIdx);
    socs = [socs; interp1(v1uniq, zuniq, v, 'linear', 'extrap')]; %#ok<AGROW>
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

  rawDisZ = 1 - testdata.script1.disAh(indD)/Q25;
  rawDisZ = rawDisZ + (1 - rawDisZ(1));
  rawChgZ = testdata.script3.chgAh(indC)/Q25;
  rawChgZ = rawChgZ - rawChgZ(1);

  rawDisV = testdata.script1.voltage(indD);
  rawChgV = testdata.script3.voltage(indC);

  [disZ,disV] = preprocessOcvBranch(rawDisZ, rawDisV, config.du);
  [chgZ,chgV] = preprocessOcvBranch(rawChgZ, rawChgV, config.du);

  diagData = struct();
  diagData.name = cellID;
  diagData.TdegC = testdata.temp;
  diagData.orig.disZ = disZ(:);
  diagData.orig.disV = disV(:);
  diagData.orig.chgZ = chgZ(:);
  diagData.orig.chgV = chgV(:);
  diagData.interp = makeDiagInterpData(diagData.orig, config);

  [diagZ, diagU, diagInfo] = OCV_diagonalAverage(diagData, config);
  if config.retain_voltage_grid_output
    diagZ = linearinterp(diagU, diagZ, diagData.interp.stdV);
    diagU = diagData.interp.stdV;
  end

  filedatum.temp = testdata.temp;
  filedatum.disZ = rawDisZ(:);
  filedatum.disV = rawDisV(:);
  filedatum.chgZ = rawChgZ(:);
  filedatum.chgV = rawChgV(:);
  filedatum.rawocv = buildOverlapLimitedRawOcv(diagData, diagZ, diagU, diagInfo);
end

function interpData = makeDiagInterpData(orig, config)
  stdV = (config.vmin:config.du:config.vmax).';
  stdZ = (0:config.dz:1).';

  interpData.stdV = stdV;
  interpData.disZ = linearinterp(orig.disV,orig.disZ,stdV);
  interpData.chgZ = linearinterp(orig.chgV,orig.chgZ,stdV);

  interpData.stdZ = stdZ;
  interpData.disV = linearinterp(orig.disZ,orig.disV,stdZ);
  interpData.chgV = linearinterp(orig.chgZ,orig.chgV,stdZ);
end

function [zout,vout] = preprocessOcvBranch(zin, vin, dv)
  zin = zin(:);
  vin = vin(:);

  [zout,vout] = smoothdiff(zin, vin, dv);

  % Keep the smoothed branch in voltage-ascending order for downstream
  % voltage-domain interpolation and cross-correlation.
  if vout(1) > vout(end)
    zout = flip(zout);
    vout = flip(vout);
  end
end

function config = defaultDiagConfig(vmin,vmax,debugPlots,diagType)
  if nargin < 3 || isempty(debugPlots)
    debugPlots = false;
  end
  if nargin < 4 || isempty(diagType)
    diagType = 'useAvg';
  end
  valid_types = {'useAvg', 'useDis', 'useChg'};
  if ~any(strcmp(diagType, valid_types))
    error('DiagProcessOCV:BadDiagType', ...
      'diagType must be one of: %s', strjoin(valid_types, ', '));
  end

  config = struct();
  config.vmin = vmin;
  config.vmax = vmax;
  config.du = 0.002;
  config.dz = 0.002;
  config.datype = diagType;
  config.debug = logical(debugPlots);
  config.retain_voltage_grid_output = false;
  config.daxcorrfiltv = @(stdV) find(stdV >= vmin & stdV <= vmax);
  config.daxcorrfiltz = @(stdZ) find(stdZ >= 0 & stdZ <= 1);
end

function [Z, U, info] = OCV_diagonalAverage(data, config)
  stdV = data.interp.stdV;
  disZ = data.interp.disZ;
  chgZ = data.interp.chgZ;

  stdZ = data.interp.stdZ;
  disV = data.interp.disV;
  chgV = data.interp.chgV;

  % First, find cross-correlations for U vs dZdV
  % That is, differential capacities versus U
  du = mean(diff(stdV));
  intervals = config.daxcorrfiltv(stdV);
  if ~iscell(intervals), intervals = {intervals}; end
  lagU = zeros(size(intervals));
  voltageShiftAxes = cell(size(intervals));
  voltageCorrAxes = cell(size(intervals));
  voltagePeakAxes = cell(size(intervals));
  selectedVoltagePeakLag = zeros(size(intervals));
  for k = 1:length(intervals)
    ind = intervals{k};
    dzdv1 = roughdiff(disZ(ind),stdV(ind));
    dzdv3 = roughdiff(chgZ(ind),stdV(ind));
    [c,lag] = xcorr(dzdv1,dzdv3);
    voltageShiftAxes{k} = lag * du;
    voltageCorrAxes{k} = normalizeCorrelation(c);
    voltagePeakAxes{k} = lag(c==max(c)) * du;
    selectedVoltagePeakLag(k) = voltagePeakAxes{k}(1);
    lagU(k) = abs(lag(c==max(c))*du);
    lagU(k) = lagU(k,1);
  end
  lagU = mean(lagU);
  if config.debug
    figure;
    hold on
    for k = 1:length(intervals)
      plot(voltageShiftAxes{k}, voltageCorrAxes{k}, 'LineWidth', 1.2, ...
        'DisplayName', sprintf('Interval %d', k));
      peakShift = voltagePeakAxes{k};
      peakCorr = interp1(voltageShiftAxes{k}, voltageCorrAxes{k}, peakShift, 'nearest', 'extrap');
      plot(peakShift, peakCorr, 'o', 'MarkerSize', 7, 'LineWidth', 1.2, ...
        'DisplayName', sprintf('Peak %d', k));
    end
    xline(lagU, 'r--', 'LineWidth', 1.2, ...
      'DisplayName', sprintf('Used magnitude = %.5g V', lagU));
    xlabel('Voltage shift');
    ylabel('Normalized cross-correlation');
    title('Determine voltage shift via correlation');
    ylim([0 1.05]);
    grid on
    legend('Location', 'best');
    text(0.02, 0.98, sprintf([ ...
      'Peak lag from xcorr = %.3f V\n' ...
      'Used separation magnitude = %.3f V\n' ...
      'Applied branch shifts = ±%.3f V'], ...
      selectedVoltagePeakLag(1), lagU, lagU/2), ...
      'Units', 'normalized', ...
      'VerticalAlignment', 'top', ...
      'BackgroundColor', 'w', ...
      'Margin', 4);
    drawnow;
  end
  if config.debug
    dzdv1 = roughdiff(disZ,stdV);
    dzdv3 = roughdiff(chgZ,stdV);
    figure;
    plot(stdV,abs(dzdv1),stdV,abs(dzdv3));
    set(gca,'colororderindex',1); hold on
    plot(stdV+lagU/2,abs(dzdv1),'--',...
      stdV-lagU/2,abs(dzdv3),'--');
    xlabel('Voltage'); 
    ylabel('Absolute dZ/dU'); 
    legend('Discharge','Charge','Shift dis','Shift chg'); 
    title( ...
        sprintf('%s Cell @ %.2f\\circC', ...
            data.name,data.TdegC));
    xlim([config.vmin config.vmax]); grid on
    drawnow;
  end

  % Second, find cross-correlations for Z vs dZdV
  dz = mean(diff(stdZ));
  intervals = config.daxcorrfiltz(stdZ);
  if ~iscell(intervals), intervals = {intervals}; end
  lagZ = zeros(size(intervals));
  socShiftAxes = cell(size(intervals));
  socCorrAxes = cell(size(intervals));
  socPeakAxes = cell(size(intervals));
  selectedSocPeakLag = zeros(size(intervals));
  for k = 1:length(intervals)
    ind = intervals{k};
    dzdv1 = roughdiff(stdZ(ind),disV(ind));
    dzdv3 = roughdiff(stdZ(ind),chgV(ind));
    [c,lag] = xcorr(dzdv1,dzdv3);
    socShiftAxes{k} = lag * dz;
    socCorrAxes{k} = normalizeCorrelation(c);
    socPeakAxes{k} = lag(c==max(c)) * dz;
    selectedSocPeakLag(k) = socPeakAxes{k}(1);
    lagZ(k) = abs(lag(c==max(c))*dz);
    lagZ(k) = lagZ(k,1);
  end
  lagZ = mean(lagZ);
  if config.debug
    figure;
    hold on
    for k = 1:length(intervals)
      plot(socShiftAxes{k}, socCorrAxes{k}, 'LineWidth', 1.2, ...
        'DisplayName', sprintf('Interval %d', k));
      peakShift = socPeakAxes{k};
      peakCorr = interp1(socShiftAxes{k}, socCorrAxes{k}, peakShift, 'nearest', 'extrap');
      plot(peakShift, peakCorr, 'o', 'MarkerSize', 7, 'LineWidth', 1.2, ...
        'DisplayName', sprintf('Peak %d', k));
    end
    xline(lagZ, 'r--', 'LineWidth', 1.2, ...
      'DisplayName', sprintf('Used magnitude = %.5g SOC', lagZ));
    xlabel('SOC shift');
    ylabel('Normalized cross-correlation');
    title('Determine SOC shift via correlation');
    ylim([0 1.05]);
    grid on
    legend('Location', 'best');
    text(0.02, 0.98, sprintf([ ...
      'Peak lag from xcorr = %.3f SOC\n' ...
      'Used separation magnitude = %.3f SOC\n' ...
      'Applied branch shifts = ±%.3f SOC'], ...
      selectedSocPeakLag(1), lagZ, lagZ/2), ...
      'Units', 'normalized', ...
      'VerticalAlignment', 'top', ...
      'BackgroundColor', 'w', ...
      'Margin', 4);
    drawnow;
  end
  if config.debug
    dzdv1 = roughdiff(stdZ,disV);
    dzdv3 = roughdiff(stdZ,chgV);
    figure;
    plot(stdZ,abs(dzdv1),stdZ,abs(dzdv3));
    set(gca,'colororderindex',1); hold on
    plot(stdZ+lagZ/2,abs(dzdv1),'--',...
      stdZ-lagZ/2,abs(dzdv3),'--');
    xlabel('Relative composition'); 
    ylabel('Absolute dZ/dU'); 
    legend('Discharge','Charge','Shift dis','Shift chg'); 
    title( ...
        sprintf('%s Cell @ %.2f\\circC', ...
            data.name,data.TdegC));
    xlim([0 1]); grid on
    drawnow;
  end

  % Interpolate shifted charge/discharge curves and keep only the region
  % where both branches have valid support. The tails are filled later from
  % measured branches to avoid diagonal extrapolation blow-up.
  uuD = data.orig.disV + lagU/2;
  zzD = data.orig.disZ + lagZ/2;
  U4D = interp1(zzD,uuD,stdZ,'linear',NaN);
  uuC = data.orig.chgV - lagU/2;
  zzC = data.orig.chgZ - lagZ/2;
  U4C = interp1(zzC,uuC,stdZ,'linear',NaN);
  overlapMask = isfinite(U4D) & isfinite(U4C);
  U4 = NaN(size(stdZ));
  switch config.datype
    case 'useDis' % base off of discharge data
      U4(overlapMask) = U4D(overlapMask);
    case 'useChg' % base off of charge data
      U4(overlapMask) = U4C(overlapMask);
    otherwise  % 'useAvg' average the basis
      U4(overlapMask) = (U4C(overlapMask) + U4D(overlapMask))/2;
  end

  Z = stdZ;
  U = U4;
  info = struct();
  info.overlapMask = overlapMask;
  info.U4D = U4D;
  info.U4C = U4C;
  info.lagU = lagU;
  info.lagZ = lagZ;
end

function rawocv = buildOverlapLimitedRawOcv(diagData, diagZ, diagU, diagInfo)
  stdZ = diagZ(:);
  lowTail = diagData.interp.chgV(:);
  highTail = diagData.interp.disV(:);
  rawStd = NaN(size(stdZ));

  overlapIdx = find(diagInfo.overlapMask(:));
  if isempty(overlapIdx)
    warning('DiagProcessOCV:NoDiagonalOverlap', ...
      ['No valid diagonal overlap remained after shifting; falling back ' ...
       'to simple voltage averaging on the standard SOC grid.']);
    rawStd = (lowTail + highTail)/2;
  else
    firstIdx = overlapIdx(1);
    lastIdx = overlapIdx(end);

    rawStd(overlapIdx) = diagU(overlapIdx);

    lowOffset = rawStd(firstIdx) - lowTail(firstIdx);
    highOffset = rawStd(lastIdx) - highTail(lastIdx);

    if firstIdx > 1
      rawStd(1:firstIdx-1) = lowTail(1:firstIdx-1) + lowOffset;
    end
    if lastIdx < numel(stdZ)
      rawStd(lastIdx+1:end) = highTail(lastIdx+1:end) + highOffset;
    end

    missingIdx = find(~isfinite(rawStd));
    if ~isempty(missingIdx)
      validIdx = find(isfinite(rawStd));
      rawStd(missingIdx) = interp1(stdZ(validIdx), rawStd(validIdx), ...
        stdZ(missingIdx), 'linear', 'extrap');
    end
  end

  rawocv = interp1(stdZ, rawStd, 0:0.005:1, 'linear');
end

function dZ = roughdiff(Z,U)
  Z = Z(:);
  U = U(:);
  if numel(Z) ~= numel(U)
    error('roughdiff requires vectors of equal length.');
  end
  if numel(Z) < 2
    dZ = zeros(size(Z));
    return;
  end

  % Collapse adjacent repeated denominator points before differentiating.
  run_start = [true; diff(U) ~= 0];
  run_id = cumsum(run_start);
  n_runs = run_id(end);
  Uc = accumarray(run_id, U, [n_runs 1], @mean);
  Zc = accumarray(run_id, Z, [n_runs 1], @mean);

  if numel(Uc) < 2
    dZ = zeros(size(Z));
    return;
  end

  dUc = diff(Uc);
  dZc = diff(Zc)./dUc;
  dZc(~isfinite(dZc)) = 0;
  dZc = ([dZc(1);dZc]+[dZc;dZc(end)])/2; % Avg of fwd/bkwd diffs

  dZ = dZc(run_id);
end

function cnorm = normalizeCorrelation(c)
  c = double(c(:));
  cmin = min(c);
  cmax = max(c);
  if ~isfinite(cmin) || ~isfinite(cmax)
    cnorm = zeros(size(c));
  elseif abs(cmax - cmin) <= eps(max(abs([cmin; cmax; 1])))
    cnorm = ones(size(c));
  else
    cnorm = (c - cmin) ./ (cmax - cmin);
  end
end
