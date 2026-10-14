function out=analyzeDualTdcSync(data,o,base)
%ANALYZEDUALTDCSYNC QA -> cycle disambiguation -> SYNC map -> unique SPD events.
if nargin<3
    % Public two-argument calls must pass through the same timeline audit as
    % GUI imports/recalculation; the three-argument branch is the core helper.
    o.sync.enabled=true; out=analyzeDualTdc(data,o); return
else, out=base; end
qF=auditSyncTimestamps(data.Fsync,o.sync); qS=auditSyncTimestamps(data.Ssync,o.sync);
model=alignTdcBySync(qF,qS,out.alignment,o);
out.options=o; out.sync=struct('F',qF,'S',qS,'model',model);
out.sync.sourceNote="SYNC is an input timestamp channel, not a hardware reference-clock lock.";
out.common=struct('status',"UNALIGNED",'F',[],'S',[]);
out.overlap=struct('status',"UNALIGNED",'F',[],'S',[]);
if model.status=="UNALIGNED"
    out.status="UNALIGNED"; out.alignment.status=out.status; out.alignment.reason=model.reason;
    out.alignment.channel1=eraseMatches(out.alignment.channel1);
    out.alignment.channel2=eraseMatches(out.alignment.channel2);
else
    c1=matchSharedDetectorEvents(data.F1,data.S1,model,out.alignment.channel1.coarse,o);
    c2=matchSharedDetectorEvents(data.F2,data.S2,model,out.alignment.channel2.coarse,o);
    if c1.status~="ALIGNED" || c2.status~="ALIGNED"
        out.status="UNALIGNED"; out.alignment.status=out.status;
        out.alignment.reason="SYNC map cannot validate both SPD channel delays/associations.";
        out.sync.model.status="UNALIGNED"; out.sync.model.reason=out.alignment.reason;
        out.alignment.channel1=eraseMatches(c1); out.alignment.channel2=eraseMatches(c2);
    else
        out.alignment.channel1=c1; out.alignment.channel2=c2;
        out.alignment.relativeClockPpm=model.relativeClockPpm;
        lo=max(c1.overlapF_s(1),c2.overlapF_s(1)); hi=min(c1.overlapF_s(2),c2.overlapF_s(2));
        scale=median(model.segments.scale);
        i1=data.F1(c1.indexF)>=lo & data.F1(c1.indexF)<=hi;
        i2=data.F2(c2.indexF)>=lo & data.F2(c2.indexF)<=hi;
        out.common=struct('status',"ALIGNED", ...
            'F',analyzeDualTdcDevice(data.F1(c1.indexF(i1)),data.F2(c2.indexF(i2)),o,hi-lo), ...
            'S',analyzeDualTdcDevice(data.S1(c1.indexS(i1)),data.S2(c2.indexS(i2)),o,(hi-lo)*scale));
        f1=data.F1>=lo & data.F1<=hi; f2=data.F2>=lo & data.F2<=hi;
        s1lo=applyTdcSyncMap(model,lo,c1.channelDelay_s); s1hi=applyTdcSyncMap(model,hi,c1.channelDelay_s);
        s2lo=applyTdcSyncMap(model,lo,c2.channelDelay_s); s2hi=applyTdcSyncMap(model,hi,c2.channelDelay_s);
        out.overlap=struct('status',"ALIGNED", ...
            'F',analyzeDualTdcDevice(data.F1(f1),data.F2(f2),o,hi-lo), ...
            'S',analyzeDualTdcDevice(data.S1(data.S1>=s1lo & data.S1<=s1hi), ...
            data.S2(data.S2>=s2lo & data.S2<=s2hi),o,(hi-lo)*scale));
        out.status="ALIGNED"; out.alignment.status=out.status; out.alignment.reason=model.reason;
        out.sync.model.channelDelay_s=[c1.channelDelay_s,c2.channelDelay_s];
        fullLo=min(data.F1(1),data.F2(1)); fullHi=max(data.F1(end),data.F2(end));
        if lo-fullLo>o.sync.blockDuration_s/100 || fullHi-hi>o.sync.blockDuration_s/100
            out.status="PARTIAL"; out.alignment.status="PARTIAL"; out.sync.model.status="PARTIAL";
            out.sync.model.extrapolationWarning="SPD outside SYNC coverage is extrapolation and excluded from event association.";
            out.alignment.reason=out.sync.model.extrapolationWarning;
        end
    end
end
if o.computePerSecond || o.sync.enabled, out.perSecond=buildDualTdcPerSecond(out); end
end

function c=eraseMatches(c)
c.status="UNALIGNED";
for field=["indexF","indexS","timeF_s","residual_s"], c.(field)=zeros(0,1); end
for field=["commonCount","uniqueF","uniqueS","eligibleF","eligibleS", ...
        "relativeCompletenessF","relativeCompletenessS","residualMean_ps","residualSigma_ps","residualMedian_ps"]
    c.(field)=NaN;
end
end
