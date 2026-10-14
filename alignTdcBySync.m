function m=alignTdcBySync(qF,qS,coarse,o)
%ALIGNTDCBYSYNC SPD disambiguation first, then cycle-index SYNC refinement.
% Regular SYNC alone only determines frequency, never absolute pulse identity.
if nargin<4, d=defaultDualTdcOptions(); o=d; end
m=struct('status',"UNALIGNED",'reason',"Periodic SYNC has unresolved integer-cycle ambiguity.", ...
    'relativeClockPpm',(qS.period_s/qF.period_s-1)*1e6, ...
    'cycleOffset',NaN,'anchorCount',0,'coverageF_s',[NaN NaN], ...
    'segments',emptySegments(),'drift',table(),'channelDelay_s',[NaN NaN], ...
    'extrapolationWarning',"",'integerAmbiguityResolved',false);
if qF.qaFlag~="OK" || qS.qaFlag~="OK"
    m.reason="SYNC cycle reconstruction is uncertain: "+qF.qaFlag+" / "+qS.qaFlag; return
end
if ~isempty(qF.burstIntervals) || ~isempty(qS.burstIntervals)
    m.reason="Long SYNC gaps have unsupported internal coverage; inspect burst intervals before event association."; return
end
if ~isfield(coarse.channel1,'coarse') || ~isfield(coarse.channel2,'coarse'), return; end
c1=coarse.channel1.coarse; c2=coarse.channel2.coarse;
if c1.status~="SUPPORTED" || c2.status~="SUPPORTED", return; end
P=qS.period_s;
if o.sync.maxChannelDelay_s>=P/4
    m.reason="Configured SYNC/SPD delay bound cannot resolve the integer-cycle ambiguity."; return
end
% Pair sparse audit anchors by recovered pulse index; do not force first tags.
x=qF.anchorTime_s; fs=qF.anchorCycle; sy=qS.anchorTime_s; ss=qS.anchorCycle;
prediction=c1.offset_s+c1.scale*(x-c1.referenceF_s);
approxCycle=interp1(sy,ss,prediction,'linear',NaN);
shifts=round(approxCycle-fs); shifts=shifts(isfinite(shifts));
if numel(shifts)<o.alignment.minAnchors, return; end
cycleShift=median(shifts); if cycleShift~=round(cycleShift), return; end
% Sparse anchors need not share record indices: interpolate only to locate
% target cycles, then recover actual timestamps from their exact pulse cycles.
% Audits retain a bounded evenly spaced anchor set; use matching anchors only.
[~,ia,ib]=intersect(fs+cycleShift,ss);
if isfield(qS,'lookupTime') || numel(ia)<2*o.alignment.minAnchors
    % Anchor grids can be disjoint with dropped tags. The full-cycle reader
    % supplies selected timestamps through cycle lookup when available.
    if isfield(qS,'lookupTime')
        y=qS.lookupTime(fs+cycleShift); good=isfinite(y); x=x(good); y=y(good);
    else
        m.reason="Insufficient exact shared SYNC pulse anchors."; return
    end
else
    x=x(ia); y=sy(ib);
end
% Both SPD channels must pick the same integer cycle, including channel delay.
for c={c1,c2}
    ci=c{1}; residual=y-(ci.offset_s+ci.scale*(x-ci.referenceF_s));
    if abs(median(residual))>o.sync.maxChannelDelay_s || nnz(abs(residual)<P/4)<.9*numel(x)
        m.reason="SYNC cycle candidate is not supported by both independent SPD channels."; return
    end
end
if numel(x)<2*o.alignment.minAnchors, return; end
block=o.sync.blockDuration_s; lo=min(x); hi=max(x);
boundaries=lo:block:hi; if isempty(boundaries) || boundaries(end)<hi, boundaries(end+1)=hi; end
% Merge a tiny final remainder into its predecessor instead of silently
% skipping an unvalidated tail or failing an otherwise complete acquisition.
while numel(boundaries)>2 && nnz(x>=boundaries(end-1))<3*o.alignment.minAnchors
    boundaries(end-1)=[];
end
if numel(boundaries)<2, m.reason="SYNC span too short for independent time-block validation."; return; end
rows=zeros(0,10);
for k=1:numel(boundaries)-1
    select=x>=boundaries(k) & x<=boundaries(k+1); xx=x(select); yy=y(select);
    if numel(xx)<12, continue; end
    % First 60% time of each block trains; final 40% validates independently.
    train=xx<min(xx)+.6*(max(xx)-min(xx)); test=~train;
    if min(nnz(train),nnz(test))<o.alignment.minAnchors, continue; end
    [a,b,r]=fitMap(xx(train),yy(train)); residual=yy(test)-(b+a*(xx(test)-r));
    med=median(residual); sig=std(residual); valid=isfinite(sig) && ...
        max(abs(residual))<=o.sync.residualTolerance_ps*1e-12 && ...
        abs(a-1)*1e6<=o.alignment.maxClockPpm;
    before=yy-(c1.offset_s+c1.scale*(xx-c1.referenceF_s));
    rows(end+1,:)=[boundaries(k),boundaries(k+1),r,b,a,nnz(train),nnz(test),med*1e12,sig*1e12,valid]; %#ok<AGROW>
end
segments=array2table(rows,'VariableNames',m.segments.Properties.VariableNames);
blockSegments=segments;
if isempty(segments) || height(segments)~=numel(boundaries)-1 || ~all(segments.valid)
    m.reason="SYNC hold-out residuals show unsupported drift, a jump, or insufficient anchors."; m.segments=segments; return
end
% Try one global affine map using disjoint training/validation time blocks.
training=mod(floor((x-lo)/block),2)==0; if nnz(~training)<12, training=x<lo+.6*(hi-lo); end
[a,b,r]=fitMap(x(training),y(training)); residual=y(~training)-(b+a*(x(~training)-r));
globalValid=~isempty(residual) && max(abs(residual))<=o.sync.residualTolerance_ps*1e-12;
if string(o.sync.model)=="affine" && ~globalValid
    m.reason="Global affine model failed held-out time-block validation."; m.segments=segments; return
end
if string(o.sync.model)~="segmented" && globalValid
    segments=table(lo,hi,r,b,a,nnz(training),nnz(~training),median(residual)*1e12,std(residual)*1e12,true, ...
        'VariableNames',segments.Properties.VariableNames);
else
    % Continuity is checked; piecewise fits cannot hide pulse-index jumps.
    for k=2:height(segments)
        boundary=segments.startF_s(k); prev=segments(k-1,:); curr=segments(k,:);
        jump=curr.offsetS_s+curr.scale*(boundary-curr.referenceF_s)- ...
            (prev.offsetS_s+prev.scale*(boundary-prev.referenceF_s));
        if abs(jump)>o.sync.residualTolerance_ps*1e-12
            m.reason="Piecewise SYNC model has an unsupported boundary discontinuity."; return
        end
    end
end
m.status="ALIGNED"; m.reason="SPD resolved integer cycles; SYNC passed independent time-block validation.";
m.cycleOffset=cycleShift; m.anchorCount=numel(x); m.coverageF_s=[lo hi];
m.segments=segments; m.relativeClockPpm=(median(segments.scale)-1)*1e6;
m.integerAmbiguityResolved=true;
m.drift=table(blockSegments.startF_s,blockSegments.endF_s,(blockSegments.scale-1)*1e6,blockSegments.training_count, ...
    blockSegments.validation_count,blockSegments.validation_mean_ps,blockSegments.validation_sigma_ps, ...
    'VariableNames',{'startF_s','endF_s','relative_ppm','training_count','validation_count','validation_mean_ps','validation_sigma_ps'});
m.preResidualMedian_ps=median(y-(c1.offset_s+c1.scale*(x-c1.referenceF_s)))*1e12;
end

function [a,b,r]=fitMap(x,y)
r=mean(x); b=mean(y); dx=x-r; a=sum(dx.*(y-b))/sum(dx.^2);
% Robustly trim isolated trigger outliers; held-out data are NEVER trimmed.
for k=1:3
    e=y-(b+a*dx); center=median(e); mad=median(abs(e-center));
    keep=abs(e-center)<=max(6*1.4826*mad,50e-12);
    if nnz(keep)<12 || all(keep), break; end
    r=mean(x(keep)); b=mean(y(keep)); dx=x-r;
    a=sum(dx(keep).*(y(keep)-b))/sum(dx(keep).^2);
end
end
function t=emptySegments()
t=array2table(zeros(0,10),'VariableNames',{'startF_s','endF_s','referenceF_s', ...
    'offsetS_s','scale','training_count','validation_count','validation_mean_ps','validation_sigma_ps','valid'});
end
