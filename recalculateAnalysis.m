function out = recalculateAnalysis(previous, p)
%RECALCULATEANALYSIS 复用已有时间戳，仅按当前算法设置重新计算结果。
%   物理参数不会反向改变已经产生或导入的事件。采集时长、数据模式和
%   仿真源计数沿用 previous，以便算法参数修改后快速“重载”。

p.measurementTime=previous.params.measurementTime;
if isfield(previous.params,"analysis"), p.analysis=previous.params.analysis; end
out=analyzeTimestampData(previous.A,previous.B,p,previous.source,previous.dataMode);
end
