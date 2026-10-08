function [rateTable,timingTable] = buildPerSecondCountRateTable(out)
%BUILDPERSECONDCOUNTRATETABLE 按一秒区间计算计数率和拟合时间性能。
%   使用 [0,1)、[1,2)... 的左闭右开区间，最后一区间包含采集终点。
%   即使最后一区间不足一秒，也按 1 s 作为归一化时长。每个区间均使用
%   当前匹配、寻峰、符合窗口和偶然符合修正设置独立执行完整分析。
%   第二个输出固定采用 Gaussian 拟合，给出 t_peak、sigma_fit 和 FWHM_fit；
%   无有效峰或拟合失败的区间返回 NaN，不使用最大值法结果代替拟合量。

duration=out.params.measurementTime;
ratio=duration;
nearestInteger=round(ratio);
ratioTolerance=64*eps(max(1,abs(ratio)));
if abs(ratio-nearestInteger)<=ratioTolerance
    nWindows=max(1,nearestInteger);
else
    nWindows=max(1,ceil(ratio));
end

index=(1:nWindows)';
startSeconds=(0:nWindows-1)';
stopSeconds=min((1:nWindows)',duration);
actualDuration=stopSeconds-startSeconds;
normalizationSeconds=ones(nWindows,1);
rateA=zeros(nWindows,1); rateB=zeros(nWindows,1);
rRaw=zeros(nWindows,1); rAcc=zeros(nWindows,1); rNet=zeros(nWindows,1);
method=strings(nWindows,1);
etaW=nan(nWindows,1); epsilonAcc=nan(nWindows,1);
epsilonNet=nan(nWindows,1); gEff=nan(nWindows,1);
tPeakNs=nan(nWindows,1);
sigmaFitPs=nan(nWindows,1);
fwhmFitPs=nan(nWindows,1);

% A/B 已按时间排序，用单向游标切片，避免对千万级时间戳每秒重复全数组扫描。
nextA=1; nextB=1;
for k=1:nWindows
    isLast=k==nWindows;
    [segmentA,nextA]=takeNextSecond(out.A,nextA,startSeconds(k),stopSeconds(k),isLast);
    [segmentB,nextB]=takeNextSecond(out.B,nextB,startSeconds(k),stopSeconds(k),isLast);

    segmentParams=out.params;
    % 不足一秒也按一秒计算，故分析时长固定为 1 s。
    segmentParams.measurementTime=1;
    segmentParams.analysis.sourceCount=NaN;
    segmentSource=out.source;
    segmentSource.secondIndex=k;
    segmentSource.windowStart=startSeconds(k);
    segmentSource.windowStop=stopSeconds(k);
    result=analyzeTimestampData(segmentA,segmentB,segmentParams,segmentSource,out.dataMode);

    rateA(k)=result.metrics.RA; rateB(k)=result.metrics.RB;
    rRaw(k)=result.metrics.Rraw; rAcc(k)=result.metrics.Racc;
    rNet(k)=result.metrics.Rnet;
    method(k)=accidentalMethodDisplayName(result.metrics.AccidentalMethod);
    etaW(k)=result.metrics.EtaW;
    epsilonAcc(k)=result.metrics.EpsilonAcc;
    epsilonNet(k)=result.metrics.EpsilonNet;
    gEff(k)=result.metrics.Geff;

    % 时间性能明确要求拟合量，因此不受界面“最大值/高斯拟合”选择影响。
    % 匹配结果仍完全遵循当前界面的事件匹配算法和直方图范围、bin 宽设置。
    fitParams=segmentParams;
    fitParams.algorithm.peakMethod="gaussian";
    fitHistogram=buildHistogram(result.matches,fitParams);
    if any(isfinite(fitHistogram.fitCounts))
        tPeakNs(k)=fitHistogram.peak*1e9;
        sigmaFitPs(k)=fitHistogram.sigma*1e12;
        fwhmFitPs(k)=fitHistogram.fwhm*1e12;
    end
end

% 每段固定按 1 s 归一化，因此计数与 cps 数值完全相同；导出只保留计数率，
% 避免同一信息以“计数”和“计数率”重复出现。
rateTable=table(index,startSeconds,stopSeconds,actualDuration,normalizationSeconds, ...
    rateA,rateB,rRaw,rAcc,rNet,method,etaW,epsilonAcc,epsilonNet,gEff, ...
    'VariableNames',{'秒序号','起始时间_s','终止时间_s','实际时长_s', ...
    '计数率归一化时长_s','A通道计数率_cps','B通道计数率_cps', ...
    '原始符合计数率_Rraw_cps','偶然符合计数率_Racc_cps', ...
    '净符合计数率_Rnet_cps','偶然符合修正算法', ...
    'eta_W','epsilon_acc','epsilon_net','g_eff'});

% 拟合时间性能单独成表，导出时与计数率表放入同一个逐秒分析目录。
timingTable=table(index,startSeconds,stopSeconds,actualDuration, ...
    tPeakNs,sigmaFitPs,fwhmFitPs, ...
    'VariableNames',{'秒序号','起始时间_s','终止时间_s','实际时长_s', ...
    't_peak_ns','sigma_fit_ps','FWHM_fit_ps'});
end

function [segment,nextIndex] = takeNextSecond(events,nextIndex,startTime,stopTime,isLast)
%TAKENEXTSECOND 用单向游标提取当前一秒区间，并转换为区间内相对时间。
firstIndex=nextIndex;
if isLast
    while nextIndex<=numel(events.time) && events.time(nextIndex)<=stopTime
        nextIndex=nextIndex+1;
    end
else
    while nextIndex<=numel(events.time) && events.time(nextIndex)<stopTime
        nextIndex=nextIndex+1;
    end
end
indices=firstIndex:(nextIndex-1);
segment=events;
segment.time=events.time(indices)-startTime;
segment.pairID=events.pairID(indices);
segment.type=events.type(indices);
end
