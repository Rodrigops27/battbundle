function em7_data = Em7init(soc0,R0init,T0,SigmaX0,SigmaV,SigmaW,SigmaR0,SigmaWR0,model,varargin)
% Em7init Initialize Method-7 ESC SPKF:
%   - external bias tracking branch (current + output biases)
%   - simplified random-walk SPKF branch for R0

% Reset function-local persistent states (if any are introduced later).
clear Em7SPKF;

if nargin ~= 9 && nargin ~= 10
    error('Em7init:BadInput', ...
        'Use Em7init(soc0,R0init,T0,SigmaX0,SigmaV,SigmaW,SigmaR0,SigmaWR0,model[,biasCfg]).');
end

if nargin == 10
    em7_data = initESCSPKF(soc0, T0, SigmaX0, SigmaV, SigmaW, model, varargin{1});
else
    em7_data = initESCSPKF(soc0, T0, SigmaX0, SigmaV, SigmaW, model);
end

em7_data.estimatorType = 'em7spkf';
em7_data.R0hat = R0init;
em7_data.SigmaR0 = SigmaR0;
em7_data.SigmaWR0 = SigmaWR0;

em7_data.hR0 = sqrt(3);
weight1R0 = (em7_data.hR0 * em7_data.hR0 - 1) / (em7_data.hR0 * em7_data.hR0);
weight2R0 = 1 / (2 * em7_data.hR0 * em7_data.hR0);
em7_data.WmR0 = [weight1R0; weight2R0; weight2R0];
em7_data.WcR0 = em7_data.WmR0;
end
