function branches = prepareOcvBranches(testdata, Q25, dv, disV_input, chgV_input)
% prepareOcvBranches Extract raw OCV branches and apply smoothdiff.
%
% Inputs:
%   testdata    OCV test struct with script1/script3 slow branches
%   Q25         Reference capacity used to normalize SOC
%   dv          Voltage resolution for smoothdiff
%   disV_input  Optional discharge voltage vector to smooth
%   chgV_input  Optional charge voltage vector to smooth
%
% Output:
%   branches    Struct with:
%                 .raw.disZ/.disV/.chgZ/.chgV
%                 .smoothed.disZ/.disV/.dis_dz_dv
%                 .smoothed.chgZ/.chgV/.chg_dz_dv

indD = find(testdata.script1.step == 2);
indC = find(testdata.script3.step == 2);
if isempty(indD) || isempty(indC)
  error('prepareOcvBranches:MissingStep2', ...
    'Could not find slow discharge/charge step 2 in the OCV dataset.');
end

rawDisZ = 1 - testdata.script1.disAh(indD) / Q25;
rawDisZ = rawDisZ + (1 - rawDisZ(1));
rawChgZ = testdata.script3.chgAh(indC) / Q25;
rawChgZ = rawChgZ - rawChgZ(1);

rawDisV = testdata.script1.voltage(indD);
rawChgV = testdata.script3.voltage(indC);

if nargin < 4 || isempty(disV_input)
  disV_input = rawDisV;
end
if nargin < 5 || isempty(chgV_input)
  chgV_input = rawChgV;
end

[smDisZ, smDisV, smDisDZ] = smoothOcvBranch(rawDisZ, disV_input, dv);
[smChgZ, smChgV, smChgDZ] = smoothOcvBranch(rawChgZ, chgV_input, dv);

branches = struct();
branches.raw = struct( ...
  'disZ', rawDisZ(:), ...
  'disV', rawDisV(:), ...
  'chgZ', rawChgZ(:), ...
  'chgV', rawChgV(:));
branches.smoothed = struct( ...
  'disZ', smDisZ(:), ...
  'disV', smDisV(:), ...
  'dis_dz_dv', smDisDZ(:), ...
  'chgZ', smChgZ(:), ...
  'chgV', smChgV(:), ...
  'chg_dz_dv', smChgDZ(:));
end

function [zout, vout, dz] = smoothOcvBranch(zin, vin, dv)
[zout, vout, dz] = smoothdiff(zin(:), vin(:), dv);

% Keep the smoothed branch in monotone ascending order for both the
% voltage-domain and SOC-domain interpolations used by the OCV engines.
if numel(vout) >= 2 && vout(1) > vout(end)
  zout = flip(zout);
  vout = flip(vout);
  dz = flip(dz);
end
if numel(zout) >= 2 && zout(1) > zout(end)
  zout = flip(zout);
  vout = flip(vout);
  dz = flip(dz);
end
end
