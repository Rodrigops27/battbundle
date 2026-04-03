function model=middleOCV(data,cellID,minV,maxV,savePlots,debugPlots)
% function model=middleOCV(data,cellID,minV,maxV,savePlots,debugPlots)
%
% Inputs:
%   data = cell-test data passed in from runOcvIdentification
%   cellID = cell identifier (string)
%   minV = minimum cell voltage to use in OCV relationship
%   maxV = maximum cell voltage to use in OCV relationship
%   savePlots = 0 or 1 ... set to "1" to save plots as files
%   debugPlots = 0 or 1 ... set to "1" to show middle-curve debug plots
% Output:
%   model = data structure with information for recreating OCV
%
% This function follows the same test-processing structure as processOCV.m
% but reconstructs the OCV curve via a DTW-matched middle curve between
% the preprocessed discharge and charge branches.

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
config = defaultMiddleConfig(minV, maxV, debugPlots);

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
filedata(k) = buildMiddleFiledata(data(k), cellID, Q25, config);

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
  filedata(k) = buildMiddleFiledata(data(k), cellID, Q25, config);
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
  [v1uniq, uniqIdx] = unique(v1(:), 'stable');
  zuniq = z(uniqIdx);
  socs = [socs; interp1(v1uniq, zuniq, v, 'linear', 'extrap')]; %#ok<AGROW>
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
  title(sprintf('%s OCV relationship at temp = %d (Middle Curve DTW)', ...
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
      filename = sprintf('OCV_FIGURES/%s_middle_N%02d.png', ...
        cellID,abs(filetemps(k)));
    else
      filename = sprintf('OCV_FIGURES/%s_middle_P%02d.png', ...
        cellID,filetemps(k));
    end
    print(filename,'-dpng')
  end
end
end

function filedatum = buildMiddleFiledata(testdata, cellID, Q25, config)
branches = prepareOcvBranches(testdata, Q25, config.dv);

P = [branches.smoothed.disZ, branches.smoothed.disV];
Q = [branches.smoothed.chgZ, branches.smoothed.chgV];
opts = struct( ...
  'nResample', config.n_resample, ...
  'bandFrac', config.band_frac, ...
  'interpMethod', config.interp_method, ...
  'flipSecond', true, ...
  'preSmooth', false, ...
  'finalResample', true);
[midCurve, match, Puni, Quni, info] = middleCurvePolylineDtw(P, Q, opts); %#ok<ASGLU>

[midZ, midU] = normalizeMiddleCurve(midCurve, config.soc_resolution);

filedatum.temp = testdata.temp;
filedatum.disZ = branches.raw.disZ;
filedatum.disV = branches.raw.disV;
filedatum.chgZ = branches.raw.chgZ;
filedatum.chgV = branches.raw.chgV;
filedatum.rawocv = interp1(midZ, midU, 0:0.005:1, 'linear', 'extrap');

if config.debug
  figure;
  plot(100*branches.raw.disZ, branches.raw.disV, 'k--', 'DisplayName', 'Raw discharge'); hold on
  plot(100*branches.raw.chgZ, branches.raw.chgV, 'k-.', 'DisplayName', 'Raw charge');
  plot(100*branches.smoothed.disZ, branches.smoothed.disV, 'LineWidth', 1.1, ...
    'DisplayName', 'Smoothed discharge');
  plot(100*branches.smoothed.chgZ, branches.smoothed.chgV, 'LineWidth', 1.1, ...
    'DisplayName', 'Smoothed charge');
  plot(100*midZ, midU, 'LineWidth', 1.8, 'DisplayName', 'Middle curve');
  grid on
  xlabel('SOC (%)');
  ylabel('Voltage (V)');
  xlim([0 100]);
  ylim([config.vmin config.vmax]);
  title(sprintf('%s Cell @ %.2f\\circC Middle Curve DTW', ...
    cellID,testdata.temp));
  legend('Location', 'best');
  drawnow;
end
end

function [midZ, midU] = normalizeMiddleCurve(midCurve, soc_resolution)
midCurve = sortrows(midCurve, 1, 'ascend');
[midZ, uniqIdx] = unique(midCurve(:,1), 'stable');
midU = midCurve(uniqIdx,2);

midZ = max(0, min(1, midZ(:)));
keep = isfinite(midZ) & isfinite(midU);
midZ = midZ(keep);
midU = midU(keep);

if numel(midZ) < 2
  error('middleOCV:BadMiddleCurve', ...
    'Middle curve did not retain enough unique SOC points.');
end

soc_grid = (0:soc_resolution:1).';
midU = interp1(midZ, midU, soc_grid, 'linear', 'extrap');
midZ = soc_grid;
end

function config = defaultMiddleConfig(vmin, vmax, debugPlots)
if nargin < 3 || isempty(debugPlots)
  debugPlots = false;
end

config = struct();
config.vmin = vmin;
config.vmax = vmax;
config.dv = 0.002;
config.soc_resolution = 0.002;
config.n_resample = 300;
config.band_frac = 0.15;
config.interp_method = 'pchip';
config.debug = logical(debugPlots);
end
