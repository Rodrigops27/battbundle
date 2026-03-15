% script patchLfpOcvInterpTail.m
%   Patches the high-SOC tail of the interpolated LFP OCV curves to remove
%   the non-monotone charge tail and replace the discharge tail with a
%   smoother saturating shape for downstream OCV characterization.

clearvars
close all
clc

base_dir = fileparts(mfilename('fullpath'));
data_file = fullfile(base_dir,'Datasets','OMTLIFE8AHC-HP','LFP_OCV_interp.mat');
backup_file = fullfile(base_dir,'Datasets','OMTLIFE8AHC-HP','LFP_OCV_interp_preTailPatch.mat');
patched_copy_file = fullfile(base_dir,'Datasets','OMTLIFE8AHC-HP','LFP_OCV_interp_tailPatched.mat');

overwrite_source = true;
write_patched_copy = true;

src = load(data_file,'OCV_interp');
OCV_interp = src.OCV_interp;

soc = double(OCV_interp.cha.SOC(:));
cha_orig = double(OCV_interp.cha.volt(:));
dch_orig = double(OCV_interp.dch.volt(:));

assert(isequal(soc,double(OCV_interp.dch.SOC(:))), ...
  'Charge and discharge SOC grids must match.');
assert(isequal(soc(:),(0:100)'), ...
  'Expected LFP OCV interpolation grid to be 0:100 SOC percent.');

cha_new = cha_orig;
dch_new = dch_orig;

% Charge patch: keep 0:79 as-is, then enforce a monotone PCHIP tail to 3.38 V.
cha_tail_eval_soc = (80:100)';
cha_left_anchor_soc = (75:79)';
cha_left_anchor_v = cha_orig(cha_left_anchor_soc+1);
cha_right_anchor_soc = [85; 90; 95; 100];
cha_right_anchor_v = expRamp(cha_right_anchor_soc,79,100,cha_orig(80),3.38,1.55);
cha_anchor_soc = [cha_left_anchor_soc; cha_right_anchor_soc];
cha_anchor_v = [cha_left_anchor_v; cha_right_anchor_v];
cha_new(cha_tail_eval_soc+1) = pchip(cha_anchor_soc,cha_anchor_v,cha_tail_eval_soc);

% Discharge patch: keep 0:84 as-is, set 85%% to the original 90%% voltage,
% then grow with a saturating PCHIP tail up to 3.37 V at 100%% SOC.
dch_tail_eval_soc = (85:100)';
dch_left_anchor_soc = (80:84)';
dch_left_anchor_v = dch_orig(dch_left_anchor_soc+1);
dch_v85 = dch_orig(91); % Original 90%% discharge point, approx. 3.3338 V.
dch_right_anchor_soc = [85; 90; 95; 100];
dch_right_anchor_v = [dch_v85; expRamp([90; 95; 100],85,100,dch_v85,3.37,2.2)];
dch_anchor_soc = [dch_left_anchor_soc; dch_right_anchor_soc];
dch_anchor_v = [dch_left_anchor_v; dch_right_anchor_v];
dch_new(dch_tail_eval_soc+1) = pchip(dch_anchor_soc,dch_anchor_v,dch_tail_eval_soc);

assert(all(diff(cha_new) >= -1e-10), ...
  'Patched charge curve must stay monotone increasing.');
assert(all(diff(dch_new) >= -1e-10), ...
  'Patched discharge curve must stay monotone increasing.');

OCV_interp.cha.volt = reshapeLike(cha_new,OCV_interp.cha.volt);
OCV_interp.dch.volt = reshapeLike(dch_new,OCV_interp.dch.volt);

if ~exist(backup_file,'file')
  save(backup_file,'-struct','src');
end

if write_patched_copy
  save(patched_copy_file,'OCV_interp');
end

if overwrite_source
  save(data_file,'OCV_interp');
end

fprintf('Patched charge tail: %.4f V @ 100%% SOC\n',cha_new(end));
fprintf('Patched discharge tail: %.4f V @ 100%% SOC\n',dch_new(end));
fprintf('Backup file: %s\n',backup_file);

figure('Name','LFP OCV Tail Patch','Color','w');
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

nexttile
plot(soc,cha_orig,'--','LineWidth',1.2); hold on
plot(soc,cha_new,'LineWidth',1.5);
xlabel('SOC (%)');
ylabel('Charge voltage (V)');
title('Charge Full Curve');
legend('Original','Patched','Location','northwest');
grid on

nexttile
plot(soc,dch_orig,'--','LineWidth',1.2); hold on
plot(soc,dch_new,'LineWidth',1.5);
xlabel('SOC (%)');
ylabel('Discharge voltage (V)');
title('Discharge Full Curve');
legend('Original','Patched','Location','northwest');
grid on

nexttile
plot(soc,cha_orig,'--','LineWidth',1.2); hold on
plot(soc,cha_new,'LineWidth',1.5);
xlim([75 100]);
ylim([min(cha_orig(76:end))-0.002, max(cha_new(76:end))+0.002]);
xlabel('SOC (%)');
ylabel('Charge voltage (V)');
title('Charge Tail');
grid on

nexttile
plot(soc,dch_orig,'--','LineWidth',1.2); hold on
plot(soc,dch_new,'LineWidth',1.5);
xlim([75 100]);
ylim([min(dch_orig(76:end))-0.002, max(dch_new(76:end))+0.002]);
xlabel('SOC (%)');
ylabel('Discharge voltage (V)');
title('Discharge Tail');
grid on

function y = expRamp(x,x0,x1,y0,y1,alpha)
tau = (double(x) - x0) / (x1 - x0);
tau = min(max(tau,0),1);
shape = (exp(alpha * tau) - 1) / (exp(alpha) - 1);
y = y0 + (y1 - y0) * shape;
end

function out = reshapeLike(vec,template)
out = reshape(vec,size(template));
end
