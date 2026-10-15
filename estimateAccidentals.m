function acc = estimateAccidentals(A, B, matches, histResult, p)
%ESTIMATEACCIDENTALS 估计符合窗中的偶然符合率。
%   ACC = ESTIMATEACCIDENTALS(A,B,MATCHES,HISTRESULT,P) 支持五种模式：
%     none       - 不进行偶然符合修正，R_acc = 0；
%     theory     - 独立低计数率近似 R_acc = R_A*R_B*W；
%     sideband   - 旁带法：用连续背景区域密度外推到 W；
%     side-window- 旁窗法：在峰两侧放置多个等宽背景窗并取平均；
%     time-shift - 时间戳平移法：对多个循环平移的符合计数取平均。
%   W 始终指完整符合窗宽度，返回 rate 的单位为 counts/s。

W=resolveCoincidenceWindow(histResult,p); T=p.measurementTime;
sampleOffsets=zeros(0,1); sampleCounts=zeros(0,1);
status="OK"; boundaries=zeros(0,2); validPairs=0; tailCount=NaN; gap=NaN;
guardMode="fixed-center";
if isfield(p.algorithm,'sideWindowGuardMode'), guardMode=string(p.algorithm.sideWindowGuardMode); end
if isfield(p.algorithm,'strictWindows') && p.algorithm.strictWindows
    main=calculateRawCoincidence(matches,histResult,p);
    if main.status~="OK"
        acc=struct('rate',NaN,'countEquivalent',NaN,'method',p.algorithm.accidentalMethod, ...
            'details',"No valid main window",'sampleOffsets',sampleOffsets,'sampleCounts',sampleCounts, ...
            'status',main.status,'boundaries',boundaries,'validPairs',0,'guardGap',NaN, ...
            'guardMode',guardMode,'sideTrueCount',NaN);
        return
    end
end
switch p.algorithm.accidentalMethod
    case "none"
        % 无修正时 Rnet=Rraw，用于与各背景估计方法直接对照。
        rate=0;
        details="no accidental correction";

    case "theory"
        % 适用于两个近似独立 Poisson 单计数流及较窄符合窗。
        rate=(numel(A.time)/T)*(numel(B.time)/T)*W;
        details="R_A R_B W";

    case "sideband"
        lo=p.algorithm.histRange(1); hi=p.algorithm.histRange(2);
        % 保护区至少覆盖主符合窗的半宽，避免真实峰尾混入背景。
        guard=max(p.algorithm.sidebandGuard,W/2);
        leftWidth=max(0,min(hi,histResult.peak-guard)-lo);
        rightWidth=max(0,hi-max(lo,histResult.peak+guard));
        sideWidth=leftWidth+rightWidth;
        side=abs(matches.deltaT-histResult.peak)>=guard;
        % 连续旁带总计数除以总宽度得到背景密度，再乘主窗宽。
        if sideWidth==0, rate=NaN; else, rate=nnz(side)*W/(sideWidth*T); end
        details="sideband density";

    case "side-window"
        if guardMode=="window-width"
            raw=calculateRawCoincidence(matches,histResult,p);
            W=raw.window; gap=W; K=p.algorithm.sideWindowPairs;
            boundaries=nan(2*K,2); windowCounts=nan(2*K,1);
            tailCount=0;
            lo=max(p.algorithm.histRange(1),histResult.edges(1));
            hi=min(p.algorithm.histRange(2),histResult.edges(end));
            if raw.status~="OK"
                status=raw.status;
            else
                for k=1:K
                    rows=[2*k-1,2*k];
                    boundaries(rows,:)=[raw.lowerEdge-W-k*W,raw.lowerEdge-W-(k-1)*W; ...
                        raw.upperEdge+W+(k-1)*W,raw.upperEdge+W+k*W];
                    valid=false(2,1);
                    for j=1:2
                        r=rows(j); e=boundaries(r,:);
                        tolerance=64*eps(max(abs([lo hi e])));
                        valid(j)=e(1)>=lo-tolerance && e(2)<=hi+tolerance;
                        if valid(j)
                            selected=matches.deltaT>=e(1) & matches.deltaT<e(2);
                            if abs(e(2)-histResult.edges(end))<=tolerance
                                selected=selected | matches.deltaT==histResult.edges(end);
                            end
                            windowCounts(r)=nnz(selected);
                            tailCount=tailCount+nnz(selected & matches.isTrue);
                        end
                    end
                    validPairs=validPairs+all(valid);
                end
                if validPairs~=K, status="INVALID_SIDE_WINDOWS"; end
            end
            if status=="OK", rate=mean(windowCounts)/T; else, rate=NaN; end
            sampleOffsets=mean(boundaries,2)-histResult.peak; sampleCounts=windowCounts;
            details="strict equal-width windows, edge gap G=W";
        else
        lo=p.algorithm.histRange(1); hi=p.algorithm.histRange(2);
        guard=max(p.algorithm.sidebandGuard,W/2); K=p.algorithm.sideWindowPairs;
        windowCounts=zeros(0,1); windowCenters=zeros(0,1);
        % 左右各放 K 个与主符合窗等宽的背景窗，只统计完整落在搜索范围内的窗。
        for k=1:K
            leftEdges=histResult.peak-guard-[k*W,(k-1)*W];
            rightEdges=histResult.peak+guard+[(k-1)*W,k*W];
            if leftEdges(1)>=lo && leftEdges(2)<=hi
                windowCounts(end+1,1)=nnz(matches.deltaT>=leftEdges(1) & matches.deltaT<leftEdges(2)); %#ok<AGROW>
                windowCenters(end+1,1)=mean(leftEdges); %#ok<AGROW>
            end
            if rightEdges(1)>=lo && rightEdges(2)<=hi
                windowCounts(end+1,1)=nnz(matches.deltaT>=rightEdges(1) & matches.deltaT<rightEdges(2)); %#ok<AGROW>
                windowCenters(end+1,1)=mean(rightEdges); %#ok<AGROW>
            end
        end
        if isempty(windowCounts), rate=NaN; else, rate=mean(windowCounts)/T; end
        sampleOffsets=windowCenters-histResult.peak; sampleCounts=windowCounts;
        details=sprintf("side-window mean over %d valid windows",numel(windowCounts));
        end

    case "time-shift"
        % 使用 start+(k-1)*step 循环平移 B 路，对每次窗内符合计数取平均。
        sampleOffsets=p.algorithm.timeShiftStart+ ...
            (0:p.algorithm.timeShiftCount-1)'*p.algorithm.timeShiftStep;
        sampleCounts=zeros(p.algorithm.timeShiftCount,1);
        for k=1:p.algorithm.timeShiftCount
            shifted=B;
            shifted.time=mod(B.time+sampleOffsets(k),T);
            [shifted.time,order]=sort(shifted.time);
            % 平移数据只用于背景估计，清除 pairID 防止误当作 ground truth。
            shifted.pairID=zeros(size(shifted.pairID(order)));
            shifted.type=shifted.type(order);
            shiftedMatches=matchCoincidences(A,shifted,p);
            % 与主符合计数共用同一窗口选择；bins 模式下同样取峰值 bin
            % 及左右各 n 个 bin，而不是近似成连续对称窗口。
            shiftedRaw=calculateRawCoincidence(shiftedMatches,histResult,p);
            sampleCounts(k)=shiftedRaw.count;
        end
        rate=mean(sampleCounts)/T;
        details=sprintf("mean of %d circular time shifts",p.algorithm.timeShiftCount);
end

% countEquivalent 是当前采集时长内与 rate 等价的期望计数，可为非整数。
acc.rate=rate;
acc.countEquivalent=rate*T;
acc.method=p.algorithm.accidentalMethod;
acc.details=details;
% 记录旁窗中心或平移量以及各次计数，便于检查估计稳定性。
acc.sampleOffsets=sampleOffsets;
acc.sampleCounts=sampleCounts;
acc.status=status;
acc.boundaries=boundaries;
acc.validPairs=validPairs;
acc.guardGap=gap;
acc.guardMode=guardMode;
acc.sideTrueCount=tailCount;
end
