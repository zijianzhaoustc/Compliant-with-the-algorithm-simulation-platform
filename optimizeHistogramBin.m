function result = optimizeHistogramBin(matches,p,model)
%OPTIMIZEHISTOGRAMBIN 跨四种 bin 相位的 Shimazaki-Shinomoto 代价及峰形稳定性。
widths=unique(max(1,round(p.optimization.binCandidates/p.tdc.resolution))*p.tdc.resolution);
phases=[0 .25 .5 .75]; n=numel(widths);
cost=nan(n,1); peakSpread=nan(n,1); sigmaSpread=nan(n,1); stable=false(n,1);
phaseCost=nan(n,4); phasePeak=nan(n,4); phaseSigma=nan(n,4);
for k=1:n
    h=widths(k); lo=p.algorithm.histRange(1); hi=p.algorithm.histRange(2);
    if ceil((hi-lo)/h)>200000, continue; end
    for j=1:4
        first=lo-phases(j)*h;
        edges=first+(0:ceil((hi-first)/h))*h;
        counts=histcounts(matches.deltaT,edges);
        phaseCost(k,j)=(2*mean(counts)-var(counts,1))/h^2;
        if model.valid
            centers=(edges(1:end-1)+edges(2:end))/2;
            mask=abs(centers-model.peak)<=3*model.sigma;
            signal=max(0,counts(mask)-model.backgroundDensity*h);
            x=centers(mask);
            if sum(signal)>0
                center=sum(x.*signal)/sum(signal);
                spread=sqrt(max(0,sum(signal.*(x-center).^2)/sum(signal)-h^2/12));
                phasePeak(k,j)=center; phaseSigma(k,j)=spread;
            end
        end
    end
    cost(k)=mean(phaseCost(k,:));
    peakSpread(k)=max(phasePeak(k,:))-min(phasePeak(k,:));
    sigmaSpread(k)=max(phaseSigma(k,:))-min(phaseSigma(k,:));
    stable(k)=model.valid && all(isfinite(phasePeak(k,:))) && ...
        peakSpread(k)<=max(p.tdc.resolution,p.optimization.peakStabilitySigma*model.sigma) && ...
        sigmaSpread(k)<=p.optimization.widthStabilityFraction*model.sigma;
end
eligible=isfinite(cost);
if p.optimization.checkBinStability, eligible=eligible & stable; end
result=struct('valid',any(eligible),'binWidth',NaN,'selectedIndex',NaN, ...
    'phaseCost',phaseCost,'phasePeak',phasePeak,'phaseSigma',phaseSigma);
selected=false(n,1);
if any(eligible)
    ranked=cost; ranked(~eligible)=Inf; [~,k]=min(ranked);
    result.binWidth=widths(k); result.selectedIndex=k; selected(k)=true;
end
result.table=table(widths(:),cost,peakSpread,sigmaSpread,stable,eligible,selected, ...
    'VariableNames',{'BinWidth_s','Cost','PeakPhaseSpread_s','SigmaPhaseSpread_s', ...
    'Stable','ValidCandidate','Selected'});
for j=1:4
    result.table.(sprintf('Phase%d_Cost',j))=phaseCost(:,j);
    result.table.(sprintf('Phase%d_Peak_s',j))=phasePeak(:,j);
    result.table.(sprintf('Phase%d_Sigma_s',j))=phaseSigma(:,j);
end
end
