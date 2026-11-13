function fit = analyzeJointCoincidence(out,requestedParams)
%ANALYZEJOINTCOINCIDENCE 在同一时间戳上执行独立 all-pairs 联合点估计。
%   窗口来自最窄有效自适应推荐或原算法设置；不使用真值拟合/选参。
window=resolveJointFitWindow(out,requestedParams);
fit=struct('enabled',true,'valid',false,'status',"not-run", ...
    'primaryModel',requestedParams.jointFit.primaryModel,'models',struct(), ...
    'window',window,'histogram',table(),'candidatePairs',NaN, ...
    'errorIdentifier',"",'message',"",'settings',requestedParams.jointFit, ...
    'truth',struct('recordedPairs',NaN,'windowPairs',NaN), ...
    'uncertaintyScope',"point-estimates-only; no Bootstrap or fit Bootstrap");
try
    a=out.A.time(:); b=out.B.time(:); T=requestedParams.measurementTime;
    if any(~isfinite(a)) || any(~isfinite(b)) || any(diff(a)<0) || any(diff(b)<0) || ...
            any(a<0 | a>T) || any(b<0 | b>T)
        error('CoincidenceSim:JointFitTimestamps','联合拟合需要采集区间内升序且有限的时间戳。');
    end
    result=fitUnbinnedCoincidence(a,b,T,requestedParams,window,out.hist.edges);
    for name=string(fieldnames(result))', fit.(name)=result.(name); end
catch ME
    fit.status="unavailable"; fit.errorIdentifier=string(ME.identifier);
    fit.message=string(ME.message);
end
% 真值只在求解结束后评价；完整面积以共有不同非零 pairID 数为目标。
if string(out.dataMode)=="simulation"
    posA=find(out.A.pairID>0); posB=find(out.B.pairID>0);
    [ids,ia,ib]=intersect(out.A.pairID(posA),out.B.pairID(posB));
    delta=out.B.time(posB(ib))-out.A.time(posA(ia));
    fit.truth.recordedPairs=numel(ids);
    fit.truth.windowPairs=nnz(delta>=window.lowerEdge & ...
        (delta<window.upperEdge | (window.includeUpperEdge & delta==window.upperEdge)));
end
fit.summary=buildJointFitSummaryTable(fit,requestedParams.measurementTime);
end
