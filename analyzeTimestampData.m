function out = analyzeTimestampData(A, B, p, source, dataMode)
%ANALYZETIMESTAMPDATA 对仿真或实测双通道时间戳执行同一套符合分析。
%   A/B 必须包含按升序排列的 time、pairID、type 字段。实测数据使用
%   pairID=0，因此 ground-truth 指标返回 NaN，但速率、峰值、偶然修正和
%   heralding 效率仍可计算。

p=validateParams(p);
matches=matchCoincidences(A,B,p);
histResult=buildHistogram(matches,p);
raw=calculateRawCoincidence(matches,histResult,p);
raw.matchesIsTrue=matches.isTrue;
acc=estimateAccidentals(A,B,matches,histResult,p);
metrics=calculateMetrics(A,B,matches,raw,acc,histResult,p,dataMode);
out=struct("params",p,"source",source,"A",A,"B",B,"matches",matches, ...
    "hist",histResult,"raw",raw,"acc",acc,"metrics",metrics,"dataMode",dataMode);
end
