function out=simulateDualTdc(s,o)
%SIMULATEDUALTDC One SPDC/optics/SPD stream, split into two TDC responses.
% eventID identifies an electric pulse, including noise and afterpulses; pairID
% identifies photon pairs. Truth IDs never enter analyzeDualTdc/clock fitting.
if nargin<1, s=defaultDualTdcSimulation(); end
if nargin<2, o=defaultDualTdcOptions(); end
validateDualTdcOptions(o);
previous=rng; cleanup=onCleanup(@()rng(previous)); rng(s.seed,'twister');
p=validateParams(s.physical);
expected=p.source.pairRate*p.measurementTime;
noise=(p.detector.A.backgroundRate+p.detector.B.backgroundRate+ ...
    double(p.detector.enableDark)*(p.detector.A.darkRate+p.detector.B.darkRate))*p.measurementTime;
factor=1;
if p.detector.enableAfterpulse
    factor=1/max(eps,1-max(p.detector.A.afterpulseProbability,p.detector.B.afterpulseProbability));
end
if 128*expected+128*(2*expected+noise)*factor>o.maxResidentBytes
    error('DualTDC:MemoryBudget','Expected physical simulation exceeds the working budget; reduce duration or rate.');
end
src=generatePhotonPairs(p);
e1=simulateDetector(simulateOpticalPath(src,p,"A"),p,"A");
e2=simulateDetector(simulateOpticalPath(src,p,"B"),p,"B");
e1.eventID=(1:numel(e1.time))'; e2.eventID=numel(e1.time)+(1:numel(e2.time))';
F1=tdcBranch(e1,s.F,1); F2=tdcBranch(e2,s.F,2);
S1=tdcBranch(e1,s.S,1); S2=tdcBranch(e2,s.S,2);
data=struct('F1',F1.time,'F2',F2.time,'S1',S1.time,'S2',S2.time);
data.metadata.F=struct('duration_s',p.measurementTime*(1+s.F.clockPpm*1e-6));
data.metadata.S=struct('duration_s',p.measurementTime*(1+s.S.clockPpm*1e-6));
out=analyzeDualTdc(data,o);
out.simulation=struct('settings',s,'sourcePairCount',numel(src.time), ...
    'electricCount1',numel(e1.time),'electricCount2',numel(e2.time), ...
    'truthF1',F1,'truthF2',F2,'truthS1',S1,'truthS2',S2);
out.truth=struct('channel1',score(out.alignment.channel1,F1,S1), ...
    'channel2',score(out.alignment.channel2,F2,S2), ...
    'relativeClockPpm',((1+s.S.clockPpm*1e-6)/(1+s.F.clockPpm*1e-6)-1)*1e6);
clear cleanup
end

function out=tdcBranch(e,c,ch)
validateattributes(c.resolution_ps,{'numeric'},{'scalar','positive','finite'});
validateattributes(c.jitter_ps,{'numeric'},{'numel',2,'nonnegative','finite'});
validateattributes(c.deadTime_ns,{'numeric'},{'numel',2,'nonnegative','finite'});
validateattributes(c.recordProbability,{'numeric'},{'numel',2,'>=',0,'<=',1,'finite'});
validateattributes(c.clockPpm,{'numeric'},{'scalar','finite','>',-1e6});
local=e.time+c.jitter_ps(ch)*1e-12*randn(size(e.time))+c.channelBias_ps(ch)*1e-12;
time=c.offset_s+(1+c.clockPpm*1e-6)*local;
q=c.resolution_ps*1e-12; time=round(time/q)*q;
[time,order]=sort(time); id=e.eventID(order); pair=e.pairID(order);
keep=nonParalyzableKeep(time,c.deadTime_ns(ch)*1e-9);
time=time(keep); id=id(keep); pair=pair(keep);
keep=rand(size(time))<c.recordProbability(ch);
out=struct('time',time(keep),'eventID',id(keep),'pairID',pair(keep));
end

function t=score(c,f,s)
t=struct('trueCommonFull',numel(intersect(f.eventID,s.eventID)), ...
    'trueCommonOverlap',NaN,'correct',NaN,'false',NaN,'precision',NaN,'recall',NaN);
if c.status~="ALIGNED", return; end
fEligible=f.time>=c.overlapF_s(1) & f.time<=c.overlapF_s(2);
mapped=c.referenceF_s+(s.time-c.offset_s)/c.scale;
sEligible=mapped>=c.overlapF_s(1) & mapped<=c.overlapF_s(2);
t.trueCommonOverlap=numel(intersect(f.eventID(fEligible),s.eventID(sEligible)));
correct=nnz(f.eventID(c.indexF)==s.eventID(c.indexS)); t.correct=correct;
t.false=numel(c.indexF)-correct; t.precision=correct/max(1,numel(c.indexF));
t.recall=correct/max(1,t.trueCommonOverlap);
end
