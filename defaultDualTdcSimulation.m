function s=defaultDualTdcSimulation()
%DEFAULTDUALTDCSIMULATION Illustrative parameters, not calibrated hardware data.
p=defaultParams();
s.physical=p;
s.physical.measurementTime=.1;
s.physical.source.pairRate=2e5;
s.seed=701;
s.F=struct('jitter_ps',[15,15],'resolution_ps',10,'deadTime_ns',[2.33,2.33], ...
    'clockPpm',12,'offset_s',.002,'channelBias_ps',[0,20],'recordProbability',[.97,.98]);
s.S=struct('jitter_ps',[8,8],'resolution_ps',5,'deadTime_ns',[1,1], ...
    'clockPpm',-6,'offset_s',.07,'channelBias_ps',[10,-15],'recordProbability',[.99,.99]);
s.parameterSource="Synthetic demonstration only; neither TDC is absolute truth.";
end
