function r=bootstrapCoincidenceEstimate(a,b,p,r)
%BOOTSTRAPCOINCIDENCEESTIMATE Synchronous non-overlapping block bootstrap.
% Resample whole paired acquisition blocks. Never concatenate timestamps:
% histograms/window counts are summed within blocks, so no artificial pair
% can cross a resampled boundary. Refits centre, shape and geometry each time.
T=p.measurementTime; m=floor(T/p.algorithm.bootstrapBlockDuration);
B=p.algorithm.bootstrapReplicates;
r.bootstrap_blocks=m; r.bootstrap_replicates=B; r.bootstrap_failures=B;
if m<4 || B<10
    r.quality_status="CAUTION";
    r.quality_flags=r.quality_flags+";BOOTSTRAP_REQUIRES_4_BLOCKS_AND_10_REPLICATES"; return
end
edges=linspace(0,T,m+1); duration=T/m;
if duration<20*max(abs(p.algorithm.histRange))
    r.quality_status="INVALID"; r.invalid_reason="BOOTSTRAP_BLOCK_TOO_SHORT"; return
end
old=rng; restore=onCleanup(@()rng(old)); rng(p.algorithm.bootstrapSeed,'twister');
blocks=cell(m,2); histograms=[]; q=p; q.measurementTime=duration;
q.algorithm.uncertaintyMethod="delta";
for k=1:m
    for ch=1:2
        times=a; if ch==2, times=b; end
        keep=times>=edges(k) & times<edges(k+1);
        if k==m, keep=times>=edges(k) & times<=edges(k+1); end
        blocks{k,ch}=times(keep)-edges(k);
    end
    counts=streamCoincidenceHistogram(blocks{k,1},blocks{k,2},q);
    if isempty(histograms), histograms=zeros(m,numel(counts)); end
    histograms(k,:)=counts;
end
methods=["theory","segment-theory","side-window","sideband","time-shift"];
samples=nan(B,6); backgrounds=nan(B,numel(methods));
for j=1:B
    chosen=randi(m,m,1); weights=accumarray(chosen,1,[m 1]);
    [h,fit,g]=researchHistogramAnalysis(weights'*histograms,p);
    if ~g.valid || fit.status~="FIT_OK", continue; end
    main=0; side=zeros(g.sideWindowCountRequested,1);
    estimates=zeros(1,numel(methods)); variances=estimates;
    na=0; nb=0; shiftCounts=zeros(p.algorithm.timeShiftCount,1); shiftExposure=shiftCounts;
    for k=find(weights)'
        w=weights(k); ak=blocks{k,1}; bk=blocks{k,2};
        [ck,~,sk]=countResearchWindows(ak,bk,g); main=main+w*ck; side=side+w*sk;
        na=na+w*numel(ak); nb=nb+w*numel(bk);
        for d=2:numel(methods)
            q.algorithm.accidentalMethod=methods(d);
            acc=estimateResearchAccidentals(ak,bk,h,g,q,sk);
            estimates(d)=estimates(d)+w*acc.countEquivalent;
            variances(d)=variances(d)+w*acc.variance;
            if d==5
                shiftCounts=shiftCounts+w*acc.sampleCounts;
                shiftExposure=shiftExposure+w*acc.effectiveExposures;
            end
        end
    end
    estimates(1)=na*nb*g.WActual/T;
    variances(1)=(g.WActual/T)^2*(na*nb^2+nb*na^2);
    if all(shiftExposure>0), estimates(5)=mean(shiftCounts./shiftExposure)*T;
    else, estimates(5)=NaN; end
    % The same replicate gives all background estimates, retaining their
    % covariance for a paired conflict test. Tail-correct the side estimate.
    [F,~,~]=peakWindowMasses(fit,g); L=g.sideWindowCountRequested;
    D=F(1)-F(2)/L;
    backgrounds(j,:)=estimates;
    if D>p.algorithm.minRecoveryDenominator
        backgrounds(j,3)=(F(1)*sum(side)-F(2)*main)/(L*D);
    end
    method=find(methods==p.algorithm.accidentalMethod,1);
    if isempty(method), continue; end
    acc=estimateResearchAccidentals(a,b,h,g,p,side);
    acc.countEquivalent=estimates(method); acc.rate=estimates(method)/T; acc.variance=variances(method);
    observed=struct('C0',main,'Cs',sum(side),'side',side,'acc',acc);
    estimate=estimateRecordedPairs(a,b,h,g,p,fit,observed);
    samples(j,:)=[estimate.Npair_est,estimate.Nacc_est,main,sum(side),F];
end
valid=all(isfinite(samples(:,1:2)),2); r.bootstrap_failures=nnz(~valid);
if nnz(valid)<max(10,.8*B)
    r.quality_status="CAUTION"; r.quality_flags=r.quality_flags+";BOOTSTRAP_FIT_FAILURES"; return
end
r.u_Npair=std(samples(valid,1)); r.u_Nacc=std(samples(valid,2));
r.uncertainty_method="SYNCHRONOUS_BLOCK_BOOTSTRAP_FULL_REFIT";
r=researchConfidenceIntervals(r);
paired=backgrounds(valid,:); conflict=0;
for k=[1 2 4 5]
    diff=paired(:,k)-paired(:,3); diff=diff(isfinite(diff));
    if numel(diff)>=10
        z=abs(mean(diff))/max(std(diff),eps); conflict=max(conflict,z);
    end
end
r.background_conflict_z=conflict;
if conflict>p.algorithm.backgroundConflictThreshold
    r.quality_status="CAUTION"; r.quality_flags=r.quality_flags+";BACKGROUND_MODEL_CONFLICT";
end
r.bootstrap_covariance_json=string(jsonencode(cov(samples(valid,3:6))));
r.background_covariance_json=string(jsonencode(cov(paired(all(isfinite(paired),2),:))));
r.quality_flags=r.quality_flags+";BLOCK_BOUNDARY_PAIRS_EXCLUDED;BLOCK_BOOTSTRAP_ASSUMES_EXCHANGEABLE_BLOCKS";
if p.algorithm.timeShiftMode=="circular"
    r.quality_status="CAUTION"; r.quality_flags=r.quality_flags+";CIRCULAR_SHIFT_BOUNDARY_ASSUMPTION";
end
clear restore
end
