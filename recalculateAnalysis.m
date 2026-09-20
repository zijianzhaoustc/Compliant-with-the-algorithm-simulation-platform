function out = recalculateAnalysis(previous, p)
%RECALCULATEANALYSIS 复用已有时间戳，仅按当前算法设置重新计算结果。
%   物理参数不会反向改变已经产生或导入的事件。采集时长、数据模式和
%   仿真源计数沿用 previous，以便算法参数修改后快速“重载”。

p.measurementTime=previous.params.measurementTime;
if isfield(previous.params,"analysis"), p.analysis=previous.params.analysis; end
out=analyzeTimestampData(previous.A,previous.B,p,previous.source,previous.dataMode);
% 对导入数据重新计算时，也按当前界面的分窗开关、窗长和算法参数重建逐窗结果。
if string(previous.dataMode)=="imported" && p.algorithm.timestampWindowMode
    out.timeWindows=analyzeTimestampWindows(previous.A,previous.B,p,previous.source,"imported");
end
end
