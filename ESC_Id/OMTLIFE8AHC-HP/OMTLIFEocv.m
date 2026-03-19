% script OMTLIFEocv.m
%   Builds a 25 degC OCV model for the OMTLIFE 8 Ah dataset by wrapping
%   the interpolated charge/discharge curves into the script structure
%   expected by DiagProcessOCV.m.

clearvars
close all
clc

script_dir = fileparts(mfilename('fullpath'));
omtlife_parent = fileparts(script_dir);  % ESC_Id/OMTLIFE8AHC-HP/ -> ESC_Id/
repo_root = fileparts(omtlife_parent);    % ESC_Id/ -> bnchmrk/
ocv_output_dir = fullfile(omtlife_parent,'OCV_Files','OMTLIFE8AHC-HP');

addpath(repo_root);
addpath(genpath(fullfile(repo_root,'utility')));
addpath(genpath(fullfile(repo_root,'ESC_Id')));

% Look for OCV data in ESC_Id/OCV_Files/OMTLIFE8AHC-HP/ (correct location)
dataset_file = fullfile(omtlife_parent,'OCV_Files','OMTLIFE8AHC-HP','LFP_OCV_interp.mat');
if ~exist(dataset_file,'file')
    error('OMTLIFEocv:MissingData', ...
        'OCV interpolation data not found: %s\nExpected file in ESC_Id/OCV_Files/OMTLIFE8AHC-HP/', ...
        dataset_file);
end

if exist(ocv_output_dir,'dir') ~= 7
    mkdir(ocv_output_dir);
end

output_file = fullfile(ocv_output_dir,'OMTLIFEmodel-ocv-diag.mat');

temp_degC = 25;
capacity_ah = 8;
save_plots = 0;
cell_id = 'OMTLIFE8AHC_HP';

src = load(dataset_file,'OCV_interp');
OCV_interp = src.OCV_interp;

soc_pct = double(OCV_interp.cha.SOC(:));
cha_v = double(OCV_interp.cha.volt(:));
dch_v = double(OCV_interp.dch.volt(:));

assert(isequal(soc_pct,double(OCV_interp.dch.SOC(:))), ...
  'Charge and discharge SOC grids must match.');
assert(isequal(soc_pct(:),(0:100)'), ...
  'Expected OCV interpolation SOC grid to be 0:100 percent.');

data = struct([]);
data(1).temp = temp_degC;
data(1).script1 = makeDischargeScript(soc_pct,dch_v,capacity_ah);
data(1).script2 = makePlaceholderScript(dch_v(1));
data(1).script3 = makeChargeScript(soc_pct,cha_v,capacity_ah);
data(1).script4 = makePlaceholderScript(cha_v(end));

min_v = min([cha_v; dch_v]);
max_v = max([cha_v; dch_v]);
model = DiagProcessOCV(data,cell_id,min_v,max_v,save_plots);

% With only one temperature, the OCV0/OCVrel split is underdetermined.
% Collapse the result to a pure 25 degC OCV curve and zero temperature slope.
soc_grid = model.SOC(:);
ocv_25 = model.OCV0(:) + temp_degC * model.OCVrel(:);
model.temps = temp_degC;
model.OCV0 = ocv_25;
model.OCVrel = zeros(size(ocv_25));
model.QParam = capacity_ah;
model.etaParam = 1;

[ocv_unique, unique_idx] = unique(ocv_25,'stable');
soc_unique = soc_grid(unique_idx);
model.OCV = linspace(min(ocv_25)-0.01,max(ocv_25)+0.01,201).';
model.SOC0 = interp1(ocv_unique,soc_unique,model.OCV,'linear','extrap');
model.SOCrel = zeros(size(model.OCV));

save(output_file,'model','data');

fprintf('Saved diagonal-average OCV model to:\n  %s\n',output_file);
fprintf('Assumptions: T = %.1f degC, Q = %.1f Ah\n',temp_degC,capacity_ah);

figure('Name','OMTLIFE Diagonal OCV','Color','w');
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

nexttile
plot(100*soc_grid,ocv_25,'k','LineWidth',1.8); hold on
plot(soc_pct,cha_v,'--','LineWidth',1.2);
plot(soc_pct,dch_v,'--','LineWidth',1.2);
xlabel('SOC (%)');
ylabel('Voltage (V)');
title('OMTLIFE 25 degC OCV Reconstruction');
legend('DiagProcessOCV OCV','Input charge curve','Input discharge curve', ...
  'Location','northwest');
grid on

nexttile
ocv_on_input_grid = interp1(soc_grid,ocv_25,soc_pct/100,'linear','extrap');
mid_curve = 0.5 * (cha_v + dch_v);
plot(soc_pct,cha_v - ocv_on_input_grid,'LineWidth',1.2); hold on
plot(soc_pct,dch_v - ocv_on_input_grid,'LineWidth',1.2);
plot(soc_pct,mid_curve - ocv_on_input_grid,'k--','LineWidth',1.1);
xlabel('SOC (%)');
ylabel('Voltage error (V)');
title('Deviation from Reconstructed OCV');
legend('Charge - OCV','Discharge - OCV','Midpoint - OCV', ...
  'Location','best');
grid on

function script = makeDischargeScript(soc_pct,voltage_curve,capacity_ah)
soc_frac = soc_pct(:) / 100;
v_step = flipud(voltage_curve(:));
dis_ah_step = capacity_ah * (1 - flipud(soc_frac));

script.time = (0:(numel(v_step)+1)).';
script.step = [1; 2*ones(numel(v_step),1); 3];
script.current = zeros(size(script.time));
script.voltage = [v_step(1); v_step; v_step(end)];
script.chgAh = zeros(size(script.time));
script.disAh = [0; dis_ah_step; capacity_ah];
end

function script = makeChargeScript(soc_pct,voltage_curve,capacity_ah)
soc_frac = soc_pct(:) / 100;
v_step = voltage_curve(:);
chg_ah_step = capacity_ah * soc_frac;

script.time = (0:(numel(v_step)+1)).';
script.step = [1; 2*ones(numel(v_step),1); 3];
script.current = zeros(size(script.time));
script.voltage = [v_step(1); v_step; v_step(end)];
script.chgAh = [0; chg_ah_step; capacity_ah];
script.disAh = zeros(size(script.time));
end

function script = makePlaceholderScript(rest_voltage)
script.time = (0:2).';
script.step = [1; 2; 3];
script.current = zeros(size(script.time));
script.voltage = rest_voltage * ones(size(script.time));
script.chgAh = zeros(size(script.time));
script.disAh = zeros(size(script.time));
end
