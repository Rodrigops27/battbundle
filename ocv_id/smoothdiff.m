% SMOOTHDIFF Smooth a voltage-v-soc curve and estimate the differential 
% capacity.
%
% -- Usage --
% [zout,vout,dz] = smoothdiff(z,v)
% [zout,vout,dz] = smoothdiff(z,v,dv)
% [zout,vout,dz] = smoothdiff(z,v,dv,tol)
%
% -- Input --
% z    = soc vector [unitless]
% v    = voltage vector [V]
% dv   = voltage resolution (default 2e-3) [V]
% tol  = edge tolerance (default 5e-3) [V]
%
% -- Output --
% zout = smoothed soc vector [unitless]
% vout = smoothed voltage vector [V]
% dz   = differential capacity vector, dz/dv [1/V]
%
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

function [zout,vout,dz] = smoothdiff(z,v,dv,tol)

  % Initialization.
  if ~exist('dv','var')
    dv = 2e-3;
  end
  if ~exist('tol','var')
    tol = 5e-5;
  end
  nsamp = length(v);
  
  % Define voltage points.
  vmin = min(v)-tol;
  vmax = max(v)+tol;
  vout = (vmin:dv:vmax)';
  
  % Approximate differential capacity dz/dv.
  Nv = histcounts(v,length(vout));
  dz = (max(z)-min(z))/nsamp*Nv/dv;
  
  % Interpolate output soc.
  zout = linearinterp(v,z,vout);
  
  % Force the boundaries to agree with the original data-set.
  [~,ind0] = min(zout); zout(ind0) = min(z); 
  [~,ind1] = max(zout); zout(ind1) = max(z);
  [~,ind0] = min(vout); vout(ind0) = min(v);
  [~,ind1] = max(vout); vout(ind1) = max(v);
  
  % Collect output.
  zout = zout(:); 
  vout = vout(:);
  dz = dz(:);

end