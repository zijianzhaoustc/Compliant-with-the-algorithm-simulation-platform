function windowed = analyzeTimestampWindows(A, B, p, source, dataMode)
%ANALYZETIMESTAMPWINDOWS 按固定时间窗独立分析双通道时间戳。
%   WINDOWED = ANALYZETIMESTAMPWINDOWS(A,B,P,SOURCE,DATAMODE) 将相对时间戳
%   划分为 [0,W)、[W,2W)...；最后一个窗口包含采集终点。每个子窗中的
%   时间戳减去窗起点后，调用与整段数据相同的 analyzeTimestampData，确保
%   匹配、直方图、符合计数和偶然符合估计均使用当前算法设置。

duration=p.measurementTime;
windowSize=p.algorithm.timestampWindowSize;
ratio=duration/windowSize;
nearestInteger=round(ratio);
ratioTolerance=64*eps(max(1,abs(ratio)));
if abs(ratio-nearestInteger)<=ratioTolerance
    nWindows=max(1,nearestInteger);
else
    nWindows=max(1,ceil(ratio));
end

windowed=struct();
windowed.windowSize=windowSize;
windowed.start=zeros(nWindows,1);
windowed.stop=zeros(nWindows,1);
windowed.results=cell(nWindows,1);
windowed.accidentalMethod=string(p.algorithm.accidentalMethod);

for k=1:nWindows
    windowStart=(k-1)*windowSize;
    windowStop=min(k*windowSize,duration);
    % 中间窗口使用右开区间，边界事件只进入后一窗；末窗包含采集终点。
    if k<nWindows
        maskA=A.time>=windowStart & A.time<windowStop;
        maskB=B.time>=windowStart & B.time<windowStop;
    else
        maskA=A.time>=windowStart & A.time<=windowStop;
        maskB=B.time>=windowStart & B.time<=windowStop;
    end

    segmentA=sliceEvents(A,maskA,windowStart);
    segmentB=sliceEvents(B,maskB,windowStart);
    segmentParams=p;
    segmentParams.measurementTime=windowStop-windowStart;
    segmentParams.analysis.sourceCount=NaN;
    segmentSource=source;
    segmentSource.windowIndex=k;
    segmentSource.windowStart=windowStart;
    segmentSource.windowStop=windowStop;

    windowed.start(k)=windowStart;
    windowed.stop(k)=windowStop;
    windowed.results{k}=analyzeTimestampData(segmentA,segmentB,segmentParams, ...
        segmentSource,dataMode);
end
windowed.count=nWindows;
end

function segment = sliceEvents(events, mask, origin)
%SLICEEVENTS 选取一个时间窗并把时间转换为该子窗内的相对时间。
segment=events;
segment.time=events.time(mask)-origin;
segment.pairID=events.pairID(mask);
segment.type=events.type(mask);
end
