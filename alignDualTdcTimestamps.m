function alignment=alignDualTdcTimestamps(F1,F2,S1,S2,options)
%ALIGNDUALTDCTIMESTAMPS Infer affine clock maps from shared electric events.
% Mapping: S = offset_ch + scale_ch*(F-referenceF_ch). Independent validation
% anchors and excess-over-chance gates precede publication of any matches.
% Each channel has its own intercept (cable delay); clock slopes must agree.
if nargin<5, d=defaultDualTdcOptions(); options=d.alignment; end
inputs={F1(:),F2(:),S1(:),S2(:)};
for k=1:4
    v=inputs{k};
    if any(~isfinite(v)) || any(diff(v)<0), error('DualTDC:Times','Finite sorted times required.'); end
end
c1=alignChannel(inputs{1},inputs{3},options);
c2=alignChannel(inputs{2},inputs{4},options);
alignment=struct('status',"UNALIGNED",'reason',"",'channel1',c1,'channel2',c2, ...
    'relativeClockPpm',NaN,'interpretation', ...
    "Residual is relative timing response of both devices, not absolute jitter of either device.");
jointOverlap=c1.status=="ALIGNED" && c2.status=="ALIGNED" && ...
    max(c1.overlapF_s(1),c2.overlapF_s(1))<min(c1.overlapF_s(2),c2.overlapF_s(2));
if jointOverlap && abs(c1.scale-c2.scale)*1e6<=options.channelClockAgreementPpm
    alignment.status="ALIGNED";
    alignment.reason="Both channels passed held-out anchor, span, uniqueness and chance gates.";
    alignment.relativeClockPpm=mean([c1.clockPpm,c2.clockPpm]);
else
    alignment.reason="Channel 1: "+c1.reason+"; Channel 2: "+c2.reason;
    if c1.status=="ALIGNED" && c2.status=="ALIGNED"
        alignment.reason="Channel clock slopes disagree or no joint channel overlap; comparison rejected.";
    end
    % Never expose plausible-looking associations when global alignment fails.
    alignment.channel1=clearAssociations(c1);
    alignment.channel2=clearAssociations(c2);
    alignment.channel1.reason=alignment.reason;
    alignment.channel2.reason=alignment.reason;
end
end

function c=alignChannel(f,s,o)
c=emptyChannel();
if min(numel(f),numel(s))<o.minCommon, c.reason="Too few events."; return; end
[x,y]=patternAnchors(f,s,o); c.anchorCandidates=numel(x);
if numel(x)<2*o.minAnchors, c.reason="Insufficient distinctive shared interval patterns."; return; end
% Alternate anchors are withheld from estimation to test generalization.
train=1:2:numel(x); validation=2:2:numel(x);
[offset,slope,reference,inliers]=robustMap(x(train),y(train),o);
if nnz(inliers)<o.minAnchors, c.reason="No supported affine clock model."; return; end
testResidual=y(validation)-(offset+slope*(x(validation)-reference));
valid=abs(testResidual)<=o.anchorTolerance;
c.validationAnchors=nnz(valid);
if nnz(valid)<o.minAnchors
    c.reason="Held-out anchor validation failed."; return
end
duration=min(f(end)-f(1),(s(end)-s(1))/slope);
span=max(x(validation(valid)))-min(x(validation(valid)));
c.anchorSpanFraction=span/max(duration,eps);
if c.anchorSpanFraction<o.minSpanFraction
    c.reason="Shared anchors do not span sufficient acquisition time."; return
end
% Refit only supported anchors, with centered arithmetic for long timestamps.
good=abs(y-(offset+slope*(x-reference)))<=o.anchorTolerance;
[offset,slope,reference]=leastSquaresMap(x(good),y(good));
if abs(slope-1)*1e6>o.maxClockPpm, c.reason="Clock frequency exceeds configured bound."; return; end
c.coarse=struct('status',"SUPPORTED",'offset_s',offset,'referenceF_s',reference, ...
    'scale',slope,'validationAnchors',c.validationAnchors,'spanFraction',c.anchorSpanFraction);
[fi,si,residual,ambiguity]=uniqueAssociations(f,s,offset,slope,reference,o.matchTolerance);
lo=max(f(1),reference+(s(1)-offset)/slope);
hi=min(f(end),reference+(s(end)-offset)/slope);
eligibleF=nnz(f>=lo & f<=hi);
mappedS=reference+(s-offset)/slope;
eligibleS=nnz(mappedS>=lo & mappedS<=hi);
% Gate boundary matches as well as denominators. A match within tolerance may
% otherwise straddle the overlap edge and incorrectly give recall > 1.
inside=f(fi)>=lo & f(fi)<=hi & mappedS(si)>=lo & mappedS(si)<=hi;
fi=fi(inside); si=si(inside); residual=residual(inside);
duration=max(0,hi-lo); expected=2*o.matchTolerance*eligibleF*eligibleS/max(duration,eps);
common=numel(fi); c.chanceExpected=expected; c.excessRatio=common/max(expected,1);
if common<o.minCommon || common/max(1,min(eligibleF,eligibleS))<o.minMatchFraction || ...
        c.excessRatio<o.minExcessRatio
    c.reason="Event association not distinguishable from chance or completeness too low."; return
end
% Drift / nonlinearity check in four time blocks; a single affine map must
% describe the entire overlap, not just a short, locally coincident segment.
blockEdges=linspace(lo,hi,5); medians=nan(4,1);
for k=1:4
    v=residual(f(fi)>=blockEdges(k) & f(fi)<=blockEdges(k+1));
    if numel(v)>=5, medians(k)=median(v); end
end
if nnz(isfinite(medians))<3 || max(abs(medians(isfinite(medians))))>o.matchTolerance/2
    c.reason="Residual time trend or insufficient block support."; return
end
c.status="ALIGNED"; c.reason="Reliable affine association.";
c.offset_s=offset; c.referenceF_s=reference; c.scale=slope; c.clockPpm=(slope-1)*1e6;
c.indexF=fi; c.indexS=si; c.residual_s=residual; c.timeF_s=f(fi);
c.commonCount=common; c.eligibleF=eligibleF; c.eligibleS=eligibleS;
c.uniqueF=eligibleF-common; c.uniqueS=eligibleS-common;
c.relativeCompletenessF=common/max(eligibleS,1);
c.relativeCompletenessS=common/max(eligibleF,1);
c.overlapF_s=[lo,hi]; c.ambiguousCount=ambiguity;
c.residualMean_ps=mean(residual)*1e12; c.residualSigma_ps=std(residual)*1e12;
c.residualMedian_ps=median(residual)*1e12;
c.blockResidualMedian_ps=medians*1e12;
end

function [x,y]=patternAnchors(f,s,o)
% Three consecutive intervals are a fingerprint; missing events invalidate a
% fingerprint but cannot be repaired by treating pulse order as event identity.
df=diff(f); ds=diff(s); x=zeros(0,1); y=x;
if numel(df)<3 || numel(ds)<3, return; end
[sorted,order]=sort(ds(1:end-2));
sample=unique(round(linspace(1,numel(df)-2,min(o.maxAnchors,numel(df)-2))));
for i=sample
    if df(i)<=0, continue; end
    tol=o.patternTolerance+df(i)*o.maxClockPpm*1e-6;
    first=lowerBound(sorted,df(i)-tol); last=lowerBound(sorted,df(i)+tol)-1;
    % MHz streams have thousands of first-interval neighbours. Filter all
    % bounded candidates by the other two intervals before testing uniqueness.
    % Truly periodic runs remain ambiguous and are rejected, not arbitrarily
    % limited to the first few candidates.
    if last<first || last-first>=20000, continue; end
    candidates=order(first:last); scales=ds(candidates)/df(i);
    good=abs(scales-1)<=o.maxClockPpm*1e-6 & ...
        abs(ds(candidates+1)-scales*df(i+1))<=o.patternTolerance & ...
        abs(ds(candidates+2)-scales*df(i+2))<=o.patternTolerance;
    if nnz(good)==1
        j=candidates(good); x(end+1,1)=f(i); y(end+1,1)=s(j); %#ok<AGROW>
    end
end
end

function i=lowerBound(v,value)
l=1; r=numel(v)+1;
while l<r
    m=floor((l+r)/2);
    if v(m)<value, l=m+1; else, r=m; end
end
i=l;
end

function [offset,slope,reference,best]=robustMap(x,y,o)
reference=median(x); offset=NaN; slope=NaN; best=false(size(x));
stream=RandStream('mt19937ar','Seed',719); bestCount=0;
for k=1:o.ransacTrials
    ij=randperm(stream,numel(x),2);
    if abs(diff(x(ij)))<(max(x)-min(x))/10, continue; end
    candidateSlope=diff(y(ij))/diff(x(ij));
    if abs(candidateSlope-1)*1e6>o.maxClockPpm, continue; end
    candidateOffset=y(ij(1))-candidateSlope*(x(ij(1))-reference);
    keep=abs(y-(candidateOffset+candidateSlope*(x-reference)))<=o.anchorTolerance;
    if nnz(keep)>bestCount, best=keep; bestCount=nnz(keep); end
end
if bestCount>=2, [offset,slope,reference]=leastSquaresMap(x(best),y(best)); end
end

function [offset,slope,reference]=leastSquaresMap(x,y)
reference=mean(x); y0=mean(y); dx=x-reference;
slope=sum(dx.*(y-y0))/sum(dx.^2); offset=y0;
end

function [fi,si,residual,ambiguous]=uniqueAssociations(f,s,offset,slope,reference,tolerance)
capacity=min(numel(f),numel(s)); fi=zeros(capacity,1); si=fi; residual=fi;
n=0; left=1; right=0; ambiguous=0;
for i=1:numel(f)
    predicted=offset+slope*(f(i)-reference);
    while left<=numel(s) && s(left)<predicted-tolerance, left=left+1; end
    right=max(right,left-1);
    while right<numel(s) && s(right+1)<=predicted+tolerance, right=right+1; end
    if right<left, continue; end
    if right~=left, ambiguous=ambiguous+1; continue; end
    j=left;
    if (i>1 && abs(s(j)-(offset+slope*(f(i-1)-reference)))<=tolerance) || ...
            (i<numel(f) && abs(s(j)-(offset+slope*(f(i+1)-reference)))<=tolerance)
        ambiguous=ambiguous+1; continue
    end
    n=n+1; fi(n)=i; si(n)=j; residual(n)=s(j)-predicted;
end
fi=fi(1:n); si=si(1:n); residual=residual(1:n);
end

function c=emptyChannel()
c=struct('status',"UNALIGNED",'reason',"",'offset_s',NaN,'referenceF_s',NaN, ...
    'scale',NaN,'clockPpm',NaN,'indexF',zeros(0,1),'indexS',zeros(0,1), ...
    'residual_s',zeros(0,1),'timeF_s',zeros(0,1),'commonCount',NaN, ...
    'uniqueF',NaN,'uniqueS',NaN,'eligibleF',NaN,'eligibleS',NaN, ...
    'relativeCompletenessF',NaN,'relativeCompletenessS',NaN, ...
    'overlapF_s',[NaN NaN],'anchorCandidates',0,'validationAnchors',0, ...
    'anchorSpanFraction',NaN,'ambiguousCount',NaN,'chanceExpected',NaN, ...
    'excessRatio',NaN,'residualMean_ps',NaN,'residualSigma_ps',NaN, ...
    'residualMedian_ps',NaN,'blockResidualMedian_ps',nan(4,1), ...
    'coarse',struct('status',"UNSUPPORTED"));
end

function c=clearAssociations(c)
reason=c.reason; coarse=c.coarse; c=emptyChannel(); c.reason=reason; c.coarse=coarse;
end
