function d = buildSimulationDiagnostics(out,detector,tdc)
%BUILDSIMULATIONDIAGNOSTICS 从最终时间戳按相同非零 pairID 构造真实 IRF。
%   不使用 matches、寻峰筛选或时间谱范围截断来选择真实事件。
%   detector/tdc 是生成链路的计数诊断，重算时应沿用原始生成链路记录。
if nargin<2, detector=struct(); end
if nargin<3, tdc=struct(); end
if string(out.dataMode)~="simulation"
    error('CoincidenceSim:NoSimulationTruth','实测时间戳没有可用的 pairID 真值。');
end
p=out.params;
posA=find(out.A.pairID>0); posB=find(out.B.pairID>0);
[ids,ia,ib]=intersect(out.A.pairID(posA),out.B.pairID(posB));
timeA=out.A.time(posA(ia)); timeB=out.B.time(posB(ib)); delta=timeB-timeA;
n=numel(ids); generated=NaN;
if isfield(p,'analysis') && isfield(p.analysis,'sourceCount')
    generated=p.analysis.sourceCount;
elseif isfield(out.source,'time')
    generated=numel(out.source.time);
end
center=(p.optics.B.delay+p.tdc.B.bias)-(p.optics.A.delay+p.tdc.A.bias);
coreVariance=p.detector.A.jitter^2+p.detector.B.jitter^2;
if p.tdc.enableJitter
    coreVariance=coreVariance+p.tdc.A.jitter^2+p.tdc.B.jitter^2;
end
% 两路均匀量化误差的独立近似，仅用于三 sigma 尾部诊断参考。
referenceSigma=sqrt(coreVariance+p.tdc.resolution^2/6);
sampleMean=NaN; sampleSigma=NaN; skew=NaN; excess=NaN;
tailFraction=NaN; leftTail=NaN; rightTail=NaN;
if n>0
    sampleMean=mean(delta); sampleSigma=std(delta,0);
    centered=delta-sampleMean; variance=mean(centered.^2);
    if variance>0
        skew=mean(centered.^3)/variance^1.5;
        excess=mean(centered.^4)/variance^2-3;
    end
    leftTail=nnz(delta<center-3*referenceSigma)/n;
    rightTail=nnz(delta>center+3*referenceSigma)/n;
    tailFraction=leftTail+rightTail;
end
d=struct('generatedPairCount',generated,'recordedPairCount',n, ...
    'referenceCenter',center,'referenceSigma',referenceSigma, ...
    'mean',sampleMean,'sigma',sampleSigma,'skewness',skew, ...
    'excessKurtosis',excess,'tailFraction',tailFraction, ...
    'leftTailFraction',leftTail,'rightTailFraction',rightTail, ...
    'detector',detector,'tdc',tdc);
d.pairs=table(ids,timeA,timeB,delta,'VariableNames', ...
    {'PairID','TimeA_s','TimeB_s','DeltaT_s'});
% 显示整个真值分布；极端参数时最多 20000 bin，避免无限扩大图表。
lo=p.algorithm.histRange(1); hi=p.algorithm.histRange(2);
if n>0
    lo=min(delta)-p.algorithm.binWidth;
    hi=max(delta)+p.algorithm.binWidth;
end
binWidth=max(p.algorithm.binWidth,(hi-lo)/20000);
lower=floor(lo/binWidth)*binWidth; upper=ceil(hi/binWidth)*binWidth;
count=min(20000,max(1,ceil((upper-lower)/binWidth)));
edges=linspace(lower,upper,count+1);
counts=histcounts(delta,edges);
d.histogram=table((edges(1:end-1)'+edges(2:end)')/2,counts(:), ...
    'VariableNames',{'TimeDifference_s','Counts'});
d.histogramEdges=edges;
d.outsideAnalysisRange=nnz(delta<out.hist.edges(1) | delta>out.hist.edges(end));

% 全部真实对在当前寻峰中心的几何捕获率；完全独立于匹配竞争。
widths=unique([p.optimization.windowCandidates(:);out.raw.window]);
left=out.hist.peak-widths/2; right=out.hist.peak+widths/2;
current=widths==out.raw.window; includeUpper=true(size(widths));
if isfield(out.raw,'lowerEdge')
    left(current)=out.raw.lowerEdge; right(current)=out.raw.upperEdge;
    includeUpper(current)=out.raw.includeUpperEdge;
end
captured=zeros(size(widths)); captureRate=nan(size(widths));
for k=1:numel(widths)
    captured(k)=nnz(delta>=left(k) & ...
        (delta<right(k) | (includeUpper(k) & delta==right(k))));
end
if n>0, captureRate=captured/n; end
d.capture=table(widths,left,right,captured,captureRate,current, ...
    'VariableNames',{'Window_s','LowerEdge_s','UpperEdge_s', ...
    'TrueCapturedCount','CaptureRate','IsCurrentWindow'});

% 按等时长块统计完整时间戳；以 A 路时刻给真实对归块。
blocks=max(1,min(1000,ceil(p.measurementTime)));
blockEdges=linspace(0,p.measurementTime,blocks+1)';
start=blockEdges(1:end-1); stop=blockEdges(2:end); duration=stop-start;
countA=histcounts(out.A.time,blockEdges)'; countB=histcounts(out.B.time,blockEdges)';
trueCount=histcounts(timeA,blockEdges)';
d.timeBlocks=table(start,stop,duration,countA,countB,trueCount, ...
    countA./duration,countB./duration,trueCount./duration, ...
    'VariableNames',{'Start_s','Stop_s','Duration_s','CountA','CountB', ...
    'RecordedTruePairs','RateA_Hz','RateB_Hz','TruePairRate_Hz'});
keys=["GeneratedPairs";"RecordedTruePairs";"ReferenceCenter_s"; ...
    "Mean_s";"Std_s";"Skewness";"ExcessKurtosis";"CoreReferenceSigma_s"; ...
    "TailFractionBeyond3CoreSigma";"LeftTailFraction";"RightTailFraction"; ...
    "TruePairsOutsideAnalysisRange"];
values=[generated;n;center;sampleMean;sampleSigma;skew;excess;referenceSigma; ...
    tailFraction;leftTail;rightTail;d.outsideAnalysisRange];
d.summary=table(keys,values,'VariableNames',{'Metric','Value'});

channels=["A";"B"]; model=strings(2,1);
fields=["primaryCandidates","primaryRejectedDeadTime","afterpulseCandidates", ...
    "afterpulseOutsideAcquisition","afterpulseRejectedDeadTime","afterpulseAccepted", ...
    "acceptedAvalanches","generationProbability","isolatedObservedProbability","observedProbability"];
data=nan(2,numel(fields)+3);
for k=1:2
    ch=channels(k); model(k)=p.detector.(ch).timingModel;
    if isfield(detector,ch)
        for j=1:numel(fields), data(k,j)=detector.(ch).(fields(j)); end
    end
    if isfield(tdc,ch)
        data(k,end-2:end)=[tdc.(ch).outsideAcquisition, ...
            tdc.(ch).rejectedDeadTime,tdc.(ch).recordedAfterpulses];
    end
end
d.channels=[table(channels,model,'VariableNames',{'Channel','TimingModel'}), ...
    array2table(data,'VariableNames',cellstr([fields, ...
    "tdcOutsideAcquisition","tdcRejectedDeadTime","recordedAfterpulses"]))];
end
