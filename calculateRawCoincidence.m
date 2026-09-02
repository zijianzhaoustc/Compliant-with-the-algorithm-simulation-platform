function raw = calculateRawCoincidence(matches, histResult, p)
%CALCULATERAWCOINCIDENCE 统计峰值附近符合窗口中的原始符合。
%   RAW = CALCULATERAWCOINCIDENCE(MATCHES,HISTRESULT,P) 使用完整窗口宽度
%   p.algorithm.window，以直方图峰值为中心选择事件对。RAW.mask 与匹配数组
%   等长，可用于回查每一对事件及其 ground truth。

if p.algorithm.windowMode=="bins"
    % “左右 n bin”是离散直方图选择：峰值所在 bin 必须计入，再向左右
    % 各扩展 n 个 bin。使用真实 edges，避免把连续窗口错误地居中在拟合峰值上。
    n=p.algorithm.windowMultiplier;
    nHistogramBins=numel(histResult.edges)-1;
    peakBin=discretize(histResult.peak,histResult.edges);
    if isnan(peakBin)
        % 数值拟合偶尔可能把峰值推到直方图外，此时退回最近的 bin 中心。
        [~,peakBin]=min(abs(histResult.centers-histResult.peak));
    end
    firstBin=max(1,peakBin-n);
    lastBin=min(nHistogramBins,peakBin+n);
    lowerEdge=histResult.edges(firstBin);
    upperEdge=histResult.edges(lastBin+1);
    mask=matches.deltaT>=lowerEdge & matches.deltaT<upperEdge;
    % histcounts 规定整个直方图的最后一个右边界也属于最后一个 bin。
    includeUpperEdge=lastBin==nHistogramBins;
    if includeUpperEdge, mask=mask | matches.deltaT==upperEdge; end
    window=upperEdge-lowerEdge;
else
    % fixed/sigma/fwhm 继续使用以寻峰位置为中心的连续时间窗口。
    window=resolveCoincidenceWindow(histResult,p);
    lowerEdge=histResult.peak-window/2;
    upperEdge=histResult.peak+window/2;
    includeUpperEdge=true;
    mask=matches.deltaT>=lowerEdge & matches.deltaT<=upperEdge;
end
raw.mask = mask;
raw.count = nnz(mask);
raw.window = window;
% 保存实际计数边界，供捕获率计算和 GUI 窗口线使用。
raw.lowerEdge=lowerEdge;
raw.upperEdge=upperEdge;
raw.includeUpperEdge=includeUpperEdge;
% 计数除以有效采集时间得到 cps。
raw.rate = raw.count/p.measurementTime;
end
