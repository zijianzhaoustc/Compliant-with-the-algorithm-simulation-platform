function acc = estimateAccidentals(A, B, matches, histResult, p)
%ESTIMATEACCIDENTALS 估计符合窗口中的偶然符合率。
%   ACC = ESTIMATEACCIDENTALS(A,B,MATCHES,HISTRESULT,P) 支持三种方法：
%     theory    - 独立低计数率近似 R_acc = R_A*R_B*W；
%     sideband  - 用远离真实峰的直方图背景密度外推到窗口宽度 W；
%     time-shift- 循环平移 B 路时间戳，破坏真实 pair 的时间相关性。
%   W 始终指完整符合窗口宽度，返回 rate 的单位为 counts/s。

W = resolveCoincidenceWindow(histResult,p); T = p.measurementTime;
switch p.algorithm.accidentalMethod
    case "theory"
        % 适用于两个近似独立 Poisson 单计数流及较窄符合窗口。
        rate = (numel(A.time)/T)*(numel(B.time)/T)*W;
        details = "R_A R_B W";
    case "sideband"
        lo=p.algorithm.histRange(1); hi=p.algorithm.histRange(2);
        % 保护区至少覆盖符合窗口，避免真实峰尾被当成背景。
        guard = max(p.algorithm.sidebandGuard,W/2);
        % 计算保护区左右两侧实际落在直方图范围内的总宽度。
        leftWidth = max(0,min(hi,histResult.peak-guard)-lo);
        rightWidth = max(0,hi-max(lo,histResult.peak+guard));
        sideWidth = leftWidth+rightWidth;
        side = abs(matches.deltaT-histResult.peak) >= guard;
        % 背景计数/边带宽度给出时间差谱密度，再乘目标窗口宽度。
        if sideWidth==0, rate=NaN; else, rate=nnz(side)*W/(sideWidth*T); end
        details = "sideband density";
    case "time-shift"
        shifted = B;
        % mod 实现循环平移，可维持总采集时长和平均单计数率不变。
        shifted.time = mod(B.time+p.algorithm.timeShift,T);
        [shifted.time,order] = sort(shifted.time);
        % 平移数据只用于背景估计，清除 pairID 防止误当作 ground truth。
        shifted.pairID = zeros(size(shifted.pairID(order)));
        shifted.type = shifted.type(order);
        shiftedMatches = matchCoincidences(A,shifted,p);
        % 仍在原始峰位置和相同窗口内计数，以估计偶然背景。
        count = nnz(abs(shiftedMatches.deltaT-histResult.peak)<=W/2);
        rate = count/T;
        details = "circular time shift";
end
% countEquivalent 是当前采集时长内与 rate 等价的期望计数，可为非整数。
acc.rate = rate;
acc.countEquivalent = rate*T;
acc.method = p.algorithm.accidentalMethod;
acc.details = details;
end
