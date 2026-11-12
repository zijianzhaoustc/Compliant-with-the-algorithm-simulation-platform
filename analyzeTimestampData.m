function out = analyzeTimestampData(A, B, p, source, dataMode, includeBootstrap, includeOptimization)
%ANALYZETIMESTAMPDATA 对仿真或实测双通道时间戳执行同一套符合分析。
%   A/B 必须包含按升序排列的 time、pairID、type 字段。实测数据使用
%   pairID=0，因此 ground-truth 指标返回 NaN，但速率、峰值、偶然修正和
%   heralding 效率仍可计算。

if nargin<6, includeBootstrap=true; end
if nargin<7, includeOptimization=true; end
p=validateParams(p);
requestedParams=p;
matches=matchCoincidences(A,B,p);
optimization=[];
if includeOptimization && p.optimization.mode~="manual"
    optimization=optimizeCoincidenceParameters(A,B,matches,p,dataMode);
    if optimization.valid && p.optimization.mode=="apply"
        p.algorithm.binWidth=optimization.binWidth;
        p.algorithm.windowMode="fixed"; p.algorithm.window=optimization.window;
        p.algorithm.sidebandGuard=optimization.sideGuard;
        optimization.applied=true;
    end
    optimization.effectiveAlgorithm=p.algorithm;
end
histResult=buildHistogram(matches,p);
if ~isempty(optimization) && optimization.applied
    histResult=applyCoincidencePeak(histResult,optimization.peakModel);
end
raw=calculateRawCoincidence(matches,histResult,p);
raw.matchesIsTrue=matches.isTrue;
acc=estimateAccidentals(A,B,matches,histResult,p);
metrics=calculateMetrics(A,B,matches,raw,acc,histResult,p,dataMode);
out=struct("params",p,"source",source,"A",A,"B",B,"matches",matches, ...
    "hist",histResult,"raw",raw,"acc",acc,"metrics",metrics,"dataMode",dataMode);
out.optimization=optimization;
out.uncertainty=calculateUncertainty(out,includeBootstrap);
if includeOptimization && p.optimization.validationMode=="held-out" && ...
        p.optimization.mode~="manual"
    out.optimization.validation=validateAdaptiveSelection(A,B,matches,requestedParams,dataMode);
end
end
