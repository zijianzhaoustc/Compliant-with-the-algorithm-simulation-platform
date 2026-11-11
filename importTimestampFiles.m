function out = importTimestampFiles(startFile, stopFile, unitSeconds, p, analyzeWhole, acquisition)
%IMPORTTIMESTAMPFILES 导入 Start/Stop TXT 或 SSI DAQ 二进制时间戳。
%   TXT 采用“每行一个整数/数值”，UNITSECONDS 指定原始单位对应的秒数；
%   SSI_DAQ_TDC_TIMESTAMP_V1 的 BIN 文件自带格式标识，时间戳固定按 ps
%   解释，因此 BIN 导入不受界面 TXT 单位设置影响。TXT/BIN 均先剔除非有限值，
%   再按需升序排序；清洗信息保存在 source.startCleanup/stopCleanup。

if nargin<5, analyzeWhole=true; end
if nargin<6, acquisition=struct(); end
validateattributes(unitSeconds,{'numeric'},{'scalar','finite','positive'});
[startRaw,startUnit,startInfo]=readTimestampInput(startFile,unitSeconds);
[stopRaw,stopUnit,stopInfo]=readTimestampInput(stopFile,unitSeconds);
if isempty(startRaw) || isempty(stopRaw)
    error("CoincidenceSim:EmptyTimestampFile","Start/Stop 时间戳文件不能为空。");
end
% 同单位时先在原始数值域减去共同原点，最大限度保留大时间戳的精度；
% 混合 TXT/BIN 或单位不同的情况则先换算为秒。
if startUnit==stopUnit
    t0=min(startRaw(1),stopRaw(1));
    if isfield(acquisition,'rawOrigin'), t0=acquisition.rawOrigin; end
    if t0>min(startRaw(1),stopRaw(1))
        error('CoincidenceSim:InvalidDuration','Acquisition origin follows the first event.');
    end
    % Integer TXT ticks are differenced before conversion to seconds.
    if isa(startRaw,'uint64') || isa(stopRaw,'uint64')
        if any(startRaw~=fix(startRaw)) || any(stopRaw~=fix(stopRaw))
            error('CoincidenceSim:TimestampPrecision','Mixed integer/fractional long ticks are unsupported.');
        end
        startRaw=uint64(startRaw); stopRaw=uint64(stopRaw); t0=uint64(t0);
    end
    startTime=double(startRaw-t0)*startUnit;
    stopTime=double(stopRaw-t0)*stopUnit;
    sourceOrigin=t0; sourceUnit=startUnit;
else
    startSeconds=startRaw*startUnit; stopSeconds=stopRaw*stopUnit;
    t0Seconds=min(startSeconds(1),stopSeconds(1));
    startTime=startSeconds-t0Seconds; stopTime=stopSeconds-t0Seconds;
    sourceOrigin=t0Seconds; sourceUnit=1;
end
duration=max(startTime(end),stopTime(end));
exposureSource="inferred";
if isfield(acquisition,'durationSeconds')
    validateattributes(acquisition.durationSeconds,{'numeric'},{'scalar','finite','positive'});
    if duration>acquisition.durationSeconds
        error('CoincidenceSim:InvalidDuration','Timestamps exceed the declared acquisition gate.');
    end
    duration=acquisition.durationSeconds; exposureSource="declared";
end
if duration<=0, error("CoincidenceSim:InvalidDuration","无法从时间戳推导有效采集时长。"); end
p.measurementTime=duration;
p.analysis.sourceCount=NaN;
A=struct("time",startTime,"pairID",zeros(size(startTime)),"type",repmat("measured",numel(startTime),1));
B=struct("time",stopTime,"pairID",zeros(size(stopTime)),"type",repmat("measured",numel(stopTime),1));
source=struct("time",zeros(0,1),"pairID",zeros(0,1),"type",strings(0,1), ...
    "startFile",string(startFile),"stopFile",string(stopFile),"unitSeconds",sourceUnit, ...
    "rawOrigin",sourceOrigin,"startFormat",startInfo.format,"stopFormat",stopInfo.format, ...
    "startChannelName",startInfo.channelName,"stopChannelName",stopInfo.channelName, ...
    "startCleanup",startInfo.cleanup,"stopCleanup",stopInfo.cleanup);
source.exposureSource=exposureSource;
source.gateOriginSource="first-event";
if isfield(acquisition,'rawOrigin'), source.gateOriginSource="declared"; end
source.precisionWarning="";
if (isa(startRaw,'double') && max(abs(startRaw))>flintmax) || ...
        (isa(stopRaw,'double') && max(abs(stopRaw))>flintmax)
    source.precisionWarning="input-double-ticks-exceed-exact-integer-range";
end
if isfield(acquisition,'tickSeconds'), p.inference.tickSeconds=acquisition.tickSeconds; end
% 批量逐秒模式仅载入清洗后的时间戳，避免先构造整段匹配和重复统计。
if ~analyzeWhole
    out=struct('params',validateParams(p),'source',source,'A',A,'B',B, ...
        'dataMode',"imported",'optimization',[]);
    return
end
out=analyzeTimestampData(A,B,p,source,"imported");
% 分窗模式保留整段分析作为主界面结果，同时附加每个子时间窗的独立结果。
if out.params.algorithm.timestampWindowMode
    out.timeWindows=analyzeTimestampWindows(A,B,out.params,source,"imported");
end
end

function [values,valueUnit,info]=readTimestampInput(filename,textUnitSeconds)
%READTIMESTAMPINPUT 按扩展名选择文本或 SSI DAQ 二进制解析器。
[~,~,extension]=fileparts(filename);
if strcmpi(extension,'.bin')
    [values,metadata]=readSsiDaqTimestampBin(filename);
    valueUnit=1e-12;
    cleanup=struct('originalCount',metadata.originalTimestampCount, ...
        'validCount',metadata.timestampCount,'removedNonfiniteCount',metadata.removedNonfiniteCount, ...
        'wasSorted',metadata.wasSorted);
    info=struct('format',"ssi-daq-bin",'channelName',metadata.channelName,'cleanup',cleanup);
elseif strcmpi(extension,'.txt')
    [values,cleanup]=readTimestampColumn(filename);
    valueUnit=textUnitSeconds;
    info=struct('format',"text",'channelName',"",'cleanup',cleanup);
else
    error("CoincidenceSim:UnsupportedTimestampFile", ...
        "仅支持 .txt 和 SSI DAQ .bin 时间戳文件：%s",filename);
end
end

function [values,cleanup]=readTimestampColumn(filename)
%READTIMESTAMPCOLUMN 剔除非有限值后按需排序，保留重复事件。
values=readmatrix(filename,'FileType','text','OutputType','double');
values=values(:);
% Preserve large nonnegative integer TXT ticks exactly, including uint64 >2^53.
if any(values>flintmax)
    lines=strip(readlines(filename)); lines(lines=="")=[];
    if all(~cellfun('isempty',regexp(cellstr(lines),'^\d{1,20}$','once')))
        exact=zeros(numel(lines),1,'uint64');
        for k=1:numel(lines)
            digits=char(lines(k)); number=uint64(0);
            for j=1:numel(digits)
                digit=uint64(double(digits(j))-double('0'));
                if number>idivide(intmax('uint64')-digit,uint64(10))
                    error('CoincidenceSim:TimestampPrecision','Integer tick exceeds uint64.');
                end
                number=number*uint64(10)+digit;
            end
            exact(k)=number;
        end
        values=exact;
    end
end
originalCount=numel(values);
values=values(isfinite(values));
wasSorted=any(values(2:end)<values(1:end-1));
if wasSorted, values=sort(values); end
cleanup=struct('originalCount',originalCount,'validCount',numel(values), ...
    'removedNonfiniteCount',originalCount-numel(values),'wasSorted',wasSorted);
end
