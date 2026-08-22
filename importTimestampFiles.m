function out = importTimestampFiles(startFile, stopFile, unitSeconds, p)
%IMPORTTIMESTAMPFILES 导入“每行一个整数/数值时间戳”的 Start/Stop TXT。
%   UNITSECONDS 是一个原始计数单位对应的秒数，例如 ps 为 1e-12；若设备
%   文件单位是 LSB，则传入 LSB(ps)*1e-12。两路共同减去最早时间戳，避免
%   大整数转换为秒后造成不必要的浮点精度损失。

startRaw=readTimestampColumn(startFile);
stopRaw=readTimestampColumn(stopFile);
if isempty(startRaw) || isempty(stopRaw)
    error("CoincidenceSim:EmptyTimestampFile","Start/Stop 时间戳文件不能为空。");
end
t0=min(startRaw(1),stopRaw(1));
startTime=(startRaw-t0)*unitSeconds;
stopTime=(stopRaw-t0)*unitSeconds;
duration=max(startTime(end),stopTime(end));
if duration<=0, error("CoincidenceSim:InvalidDuration","无法从时间戳推导有效采集时长。"); end
p.measurementTime=duration;
p.analysis.sourceCount=NaN;
A=struct("time",startTime,"pairID",zeros(size(startTime)),"type",repmat("measured",numel(startTime),1));
B=struct("time",stopTime,"pairID",zeros(size(stopTime)),"type",repmat("measured",numel(stopTime),1));
source=struct("time",zeros(0,1),"pairID",zeros(0,1),"type",strings(0,1), ...
    "startFile",string(startFile),"stopFile",string(stopFile),"unitSeconds",unitSeconds, ...
    "rawOrigin",t0);
out=analyzeTimestampData(A,B,p,source,"imported");
end

function values=readTimestampColumn(filename)
%READTIMESTAMPCOLUMN 读取无表头单列数值并检查有限性和单调性。
values=readmatrix(filename,'FileType','text','OutputType','double');
values=values(:);
values=values(isfinite(values));
if any(diff(values)<0)
    error("CoincidenceSim:UnsortedTimestamps","时间戳必须按非递减顺序排列：%s",filename);
end
end
