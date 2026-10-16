function f = scanFactor(parameter,values,channel)
%SCANFACTOR Factor values are in the human-facing scanParameterCatalog units.
% channel is always both (lock A=B). Legacy A/B inputs are rejected by validation.
if nargin<3, channel="both"; end
f=struct('parameter',string(parameter),'channel',string(channel),'enabled',true, ...
    'inputMode',"list",'values',values,'start',0,'stop',0,'step',1,'count',10);
end
