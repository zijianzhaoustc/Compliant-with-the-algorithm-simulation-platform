function c=matchSharedDetectorEvents(f,s,m,coarse,o)
%MATCHSHAREDDETECTOREVENTS Unique SPD association under a validated SYNC map.
% Fixed channel delay is learned on early events and validated on late events.
c=struct('status',"UNALIGNED",'reason',"No reliable channel delay.", ...
    'offset_s',NaN,'referenceF_s',NaN,'scale',NaN,'clockPpm',NaN, ...
    'indexF',[],'indexS',[],'residual_s',[],'timeF_s',[], ...
    'commonCount',NaN,'uniqueF',NaN,'uniqueS',NaN,'eligibleF',NaN,'eligibleS',NaN, ...
    'relativeCompletenessF',NaN,'relativeCompletenessS',NaN, ...
    'overlapF_s',[NaN NaN],'ambiguousCount',NaN,'chanceExpected',NaN,'excessRatio',NaN, ...
    'residualMean_ps',NaN,'residualSigma_ps',NaN,'residualMedian_ps',NaN, ...
    'validationAnchors',0,'anchorSpanFraction',NaN,'channelDelay_s',NaN);
if m.status=="UNALIGNED" || coarse.status~="SUPPORTED", return; end
ref=mean(m.coverageF_s); modelValue=applyTdcSyncMap(m,ref);
delay=coarse.offset_s+coarse.scale*(ref-coarse.referenceF_s)-modelValue;
sample=unique(round(linspace(1,numel(f),min(numel(f),10000))));
prediction=applyTdcSyncMap(m,f(sample),delay);
nearest=nan(size(prediction));
for k=1:numel(prediction)
    if ~isfinite(prediction(k)) || prediction(k)<s(1) || prediction(k)>s(end), continue; end
    l=1; r=numel(s);
    while l<r, mid=floor((l+r)/2); if s(mid)<prediction(k), l=mid+1; else, r=mid; end, end
    if l>1 && abs(s(l-1)-prediction(k))<abs(s(l)-prediction(k)), l=l-1; end
    nearest(k)=l;
end
good=isfinite(nearest) & isfinite(prediction);
residual=s(nearest(good))-prediction(good); times=f(sample(good));
supported=abs(residual)<o.sync.maxChannelDelay_s;
train=supported & times<ref; test=supported & times>=ref;
if nnz(train)<o.alignment.minAnchors || nnz(test)<o.alignment.minAnchors, return; end
correction=median(residual(train)); delay=delay+correction;
if abs(median(residual(test))-correction)>o.alignment.matchTolerance/2, return; end
predicted=applyTdcSyncMap(m,f,delay); tol=o.alignment.matchTolerance;
lo=max(f(1),m.coverageF_s(1)); hi=min(f(end),m.coverageF_s(2));
% Intersect the device S support using monotone predicted timestamps.
valid=isfinite(predicted) & f>=lo & f<=hi & predicted>=s(1) & predicted<=s(end);
fi=zeros(min(numel(f),numel(s)),1); si=fi; errors=fi; count=0; ambiguous=0; left=1; right=0;
for i=1:numel(f)
    if ~valid(i), continue; end
    t=predicted(i);
    while left<=numel(s) && s(left)<t-tol, left=left+1; end
    right=max(right,left-1);
    while right<numel(s) && s(right+1)<=t+tol, right=right+1; end
    if right<left, continue; end
    if right~=left || (i>1 && abs(s(left)-predicted(i-1))<=tol) || ...
            (i<numel(f) && abs(s(left)-predicted(i+1))<=tol)
        ambiguous=ambiguous+1; continue
    end
    count=count+1; fi(count)=i; si(count)=left; errors(count)=s(left)-t;
end
fi=fi(1:count); si=si(1:count); errors=errors(1:count);
if ~any(valid), return; end
lo=min(f(valid)); hi=max(f(valid)); lowS=min(predicted(valid)); highS=max(predicted(valid));
inside=s(si)>=lowS & s(si)<=highS; fi=fi(inside); si=si(inside); errors=errors(inside); count=numel(fi);
nf=nnz(valid); ns=nnz(s>=lowS & s<=highS); chance=2*tol*nf*ns/max(hi-lo,eps);
if count<o.alignment.minCommon || count/max(1,min(nf,ns))<o.alignment.minMatchFraction || ...
        count/max(1,chance)<o.alignment.minExcessRatio
    c.reason="SYNC-guided SPD association failed the excess-over-chance gate."; return
end
% An integer-P clock jump can look perfect in periodic SYNC. Require SPD
% support throughout the mapped acquisition, not just its first good portion.
boundaries=lo:o.sync.blockDuration_s:hi; if boundaries(end)<hi, boundaries(end+1)=hi; end
for k=1:numel(boundaries)-1
    blockF=valid & f>=boundaries(k) & f<boundaries(k+1);
    nF=nnz(blockF); if nF<o.alignment.minCommon, continue; end
    nS=nnz(s>=min(predicted(blockF)) & s<=max(predicted(blockF)));
    nC=nnz(f(fi)>=boundaries(k) & f(fi)<boundaries(k+1));
    accidental=2*tol*nF*nS/max(diff(boundaries(k:k+1)),eps);
    if nC/max(1,min(nF,nS))<o.alignment.minMatchFraction || nC/max(1,accidental)<o.alignment.minExcessRatio
        c.reason="A time block lacks SPD support; possible integer-period clock jump."; return
    end
end
c.status="ALIGNED"; c.reason="Unique SPD association within SYNC validated coverage.";
c.channelDelay_s=delay; c.offset_s=applyTdcSyncMap(m,ref,delay); c.referenceF_s=ref;
c.scale=median(m.segments.scale); c.clockPpm=(c.scale-1)*1e6;
c.indexF=fi; c.indexS=si; c.residual_s=errors; c.timeF_s=f(fi);
c.commonCount=count; c.eligibleF=nf; c.eligibleS=ns; c.uniqueF=nf-count; c.uniqueS=ns-count;
c.relativeCompletenessF=count/max(ns,1); c.relativeCompletenessS=count/max(nf,1);
c.overlapF_s=[lo hi]; c.ambiguousCount=ambiguous; c.chanceExpected=chance; c.excessRatio=count/max(1,chance);
c.residualMean_ps=mean(errors)*1e12; c.residualSigma_ps=std(errors)*1e12;
c.residualMedian_ps=median(errors)*1e12; c.validationAnchors=nnz(test);
c.anchorSpanFraction=(max(times(supported))-min(times(supported)))/max(hi-lo,eps);
end
