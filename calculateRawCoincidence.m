function raw = calculateRawCoincidence(matches, histResult, p)
%CALCULATERAWCOINCIDENCE 统计峰值附近符合窗口中的原始符合。
%   RAW = CALCULATERAWCOINCIDENCE(MATCHES,HISTRESULT,P) 使用完整窗口宽度
%   p.algorithm.window，以直方图峰值为中心选择事件对。RAW.mask 与匹配数组
%   等长，可用于回查每一对事件及其 ground truth。

strict=isfield(p.algorithm,'strictWindows') && p.algorithm.strictWindows;
if (strict && ismember(string(p.algorithm.windowMode),["bins","fixed"])) || ...
        ismember(string(p.algorithm.windowMode),["discrete","continuous"])
    g=buildCoincidenceWindowGeometry(histResult,p);
    status="OK"; count=NaN; mask=false(size(matches.deltaT));
    if g.mainValid
        mask=coincidenceIntervalMask(matches.deltaT,g.mainLower,g.mainUpper,g.includeUpperEdge); count=nnz(mask);
    else, status=g.legacyReason;
    end
    bins=NaN; if g.mode=="DISCRETE_BINS", bins=2*p.algorithm.windowMultiplier+1; end
    width=g.WActual; if ~g.mainValid, width=g.WRequested; end
    raw=struct('mask',mask,'count',count,'rate',count/p.measurementTime,'window',width, ...
        'lowerEdge',g.mainLower,'upperEdge',g.mainUpper,'includeUpperEdge',g.includeUpperEdge, ...
        'status',status,'mainBinCount',bins,'geometry',g);
    return
end
status="OK";
if p.algorithm.windowMode=="bins"
    % “左右 n bin”是离散直方图选择：峰值所在 bin 必须计入，再向左右
    % 各扩展 n 个 bin。使用真实 edges，避免把连续窗口错误地居中在拟合峰值上。
    n=p.algorithm.windowMultiplier;
    nHistogramBins=numel(histResult.edges)-1;
    peakBin=discretize(histResult.peak,histResult.edges);
    if strict
        if isnan(peakBin) || (isfield(histResult,'peakValid') && ~histResult.peakValid) || ...
                (isfield(histResult,'fitStatus') && histResult.fitStatus=="FIT_FAILED")
            status="INVALID_PEAK";
        elseif peakBin-n<1 || peakBin+n>nHistogramBins
            status="INVALID_MAIN_WINDOW";
        else
            % buildHistogram may extend its final full bin beyond requested hi.
            % Research matching only covers histRange, so that bin is not complete.
            edges=histResult.edges([peakBin-n,peakBin+n+1]);
            tolerance=64*eps(max(abs([edges(:);p.algorithm.histRange(:)])));
            if edges(1)<p.algorithm.histRange(1)-tolerance || ...
                    edges(2)>p.algorithm.histRange(2)+tolerance
                status="INVALID_MAIN_WINDOW";
            end
        end
        if status~="OK"
            raw=struct('mask',false(size(matches.deltaT)),'count',NaN,'rate',NaN, ...
                'window',(2*n+1)*p.algorithm.binWidth,'lowerEdge',NaN,'upperEdge',NaN, ...
                'includeUpperEdge',false,'status',status,'mainBinCount',2*n+1);
            return
        end
    end
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
raw.status=status;
raw.mainBinCount=NaN;
if p.algorithm.windowMode=="bins", raw.mainBinCount=lastBin-firstBin+1; end
end
