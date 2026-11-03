function result = optimizeCoincidenceWindow(A,B,matches,p,model,widths,bootstrapBudget)
%OPTIMIZECOINCIDENCEWINDOW 捕获率、旁窗和背景约束下比较候选；不读取真值。
% shortlist 使用固定种子和相同分块，因此候选间使用相同抽样索引。
if nargin<6 || isempty(widths)
    minimum=2*sqrt(2)*model.sigma*erfinv(p.optimization.targetCapture);
    automatic=ceil(minimum*(1:.1:1.8)/p.tdc.resolution)*p.tdc.resolution;
    widths=unique([p.optimization.windowCandidates,automatic]);
end
if nargin<7, bootstrapBudget=p.optimization.bootstrapCandidates; end
widths=sort(unique(widths(:))); n=numel(widths); T=p.measurementTime;
delta=sort(matches.deltaT(:));
capture=erf(widths/(2*sqrt(2)*model.sigma));
raw=zeros(n,1); side=nan(n,1); theory=numel(A.time)*numel(B.time)*widths/T;
L=zeros(n,1); total=zeros(n,1); z=nan(n,1); guard=zeros(n,1);
valid=false(n,1); diagnostic=strings(n,1); upSide=nan(n,1); upTheory=nan(n,1);
uSide=nan(n,1); uTheory=nan(n,1); ciSide=nan(n,2); ciTheory=nan(n,2);
score=nan(n,1); bootstrapB=nan(n,1); selected=false(n,1);
for k=1:n
    width=widths(k); q=p; q.algorithm.windowMode="fixed"; q.algorithm.window=width;
    guard(k)=max([p.algorithm.sidebandGuard,p.optimization.peakTailSigma*model.sigma,width/2]);
    q.algorithm.sidebandGuard=guard(k);
    edges=accidentalSideWindows(model,q,width); L(k)=size(edges,1);
    counts=zeros(L(k),1);
    for j=1:L(k), counts(j)=countSortedInterval(delta,edges(j,1),edges(j,2),false); end
    raw(k)=countSortedInterval(delta,model.peak-width/2,model.peak+width/2);
    total(k)=sum(counts);
    if L(k)>0, side(k)=mean(counts); end
    left=mean(edges,2)<model.peak; right=~left;
    if any(left) && any(right) && total(k)>0
        % 左右有效旁窗曝光可能不同；密度均值的 Poisson 传播。
        a=sum(counts(left)); b=sum(counts(right)); nl=nnz(left); nr=nnz(right);
        z(k)=abs(a/nl-b/nr)/sqrt(a/nl^2+b/nr^2);
    end
    reason=strings(0,1);
    if ~model.valid, reason(end+1)="invalid-peak-model"; end
    if capture(k)<p.optimization.targetCapture-1e-12, reason(end+1)="capture-below-target"; end
    if model.peak-width/2<p.algorithm.histRange(1) || model.peak+width/2>p.algorithm.histRange(2)
        reason(end+1)="window-outside-search";
    end
    if L(k)==0 || (p.optimization.requireFullSideWindows && L(k)~=2*p.algorithm.sideWindowPairs)
        reason(end+1)="incomplete-side-windows";
    end
    if p.optimization.checkBackground
        if total(k)<p.optimization.minBackgroundCounts || ~isfinite(z(k))
            reason(end+1)="insufficient-background";
        elseif z(k)>p.optimization.backgroundZ
            reason(end+1)="nonstationary-background";
        end
    end
    if isempty(reason), valid(k)=true; diagnostic(k)="ok"; else, diagnostic(k)=strjoin(reason,";"); end
    if total(k)>0 && L(k)>0, upSide(k)=sqrt(raw(k)+total(k)/L(k)^2); end
    if numel(A.time)>0 && numel(B.time)>0
        upTheory(k)=sqrt(raw(k)+(width/T)^2*(numel(B.time)^2*numel(A.time)+numel(A.time)^2*numel(B.time)));
    end
end
shortlist=find(valid);
if p.optimization.selection=="bootstrap-score"
    [~,order]=sort(upSide(shortlist).^2./capture(shortlist).^2);
    shortlist=shortlist(order);
end
shortlist=shortlist(1:min(numel(shortlist),bootstrapBudget));
samples=cell(n,1);
for index=shortlist(:)'
    if ~p.uncertainty.enabled, break; end
    q=p; q.algorithm.windowMode="fixed"; q.algorithm.window=widths(index);
    q.algorithm.accidentalMethod="side-window";
    q.algorithm.sidebandGuard=guard(index); q.algorithm.binWidth=max(p.tdc.resolution,min(p.optimization.binCandidates));
    % 不构建匹配真值指标；只计算数据统计量。
    h=applyCoincidencePeak(buildHistogram(matches,q),model);
    r=calculateRawCoincidence(matches,h,q);
    acc=estimateAccidentals(A,B,matches,h,q);
    provisional=struct('params',q,'A',A,'B',B,'matches',matches,'hist',h, ...
        'raw',r,'acc',acc,'dataMode',"imported");
    blocks=buildBootstrapBlocks(provisional);
    if blocks.count<2, continue; end
    u=q.uncertainty; u.resamples=q.optimization.candidateResamples;
    bs=runBlockBootstrap(blocks,u);
    bs.blocks=blocks;
    samples{index}=bs;
    uSide(index)=bs.standardUncertainty(4); uTheory(index)=bs.standardUncertainty(5);
    ciSide(index,:)=bs.CI(:,4)'; ciTheory(index,:)=bs.CI(:,5)';
    score(index)=uSide(index)^2/capture(index)^2; bootstrapB(index)=u.resamples;
end
choice=NaN;
if any(valid)
    if p.optimization.selection=="narrowest"
        choice=find(valid,1);
    else
        ranked=score; ranked(~valid | ~isfinite(ranked))=Inf;
        [best,k]=min(ranked); if isfinite(best), choice=k; end
    end
end
if isfinite(choice), selected(choice)=true; end
result=struct('valid',isfinite(choice),'window',NaN,'captureEstimate',NaN, ...
    'sideGuard',NaN,'selectedIndex',choice,'candidateBootstrap',{samples});
if result.valid
    result.window=widths(choice); result.captureEstimate=capture(choice); result.sideGuard=guard(choice);
end
result.table=table(widths,raw,side,theory,raw-side,raw-theory,capture,L,total,z,guard, ...
    upSide,upTheory,uSide,uTheory,ciSide(:,1),ciSide(:,2),ciTheory(:,1),ciTheory(:,2), ...
    bootstrapB,score,valid,selected,diagnostic,'VariableNames', ...
    {'Window_s','Nraw','Nacc_side','Nacc_theory','Ncorr_side','Ncorr_theory', ...
    'CaptureEstimate','ValidSideWindows','Nside_total','BackgroundZ','SideGuard_s', ...
    'AnalyticalU_side','AnalyticalU_theory','BootstrapU_side','BootstrapU_theory', ...
    'CI_side_lower','CI_side_upper','CI_theory_lower','CI_theory_upper','BootstrapB', ...
    'OptimizationScore','ValidCandidate','Selected','BackgroundDiagnostic'});
end
