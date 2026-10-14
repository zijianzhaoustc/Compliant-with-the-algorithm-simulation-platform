function acc=estimateDualTdcAccidentals(a,b,h,o,T,windows,context)
%ESTIMATEDUALTDCACCIDENTALS All-pairs backgrounds without retained pair lists.
% windows: main window first, followed by all requested sweep windows.
if nargin<7, context=struct(); end
cfg=dualTdcAccidentalOptions(o); widths=diff(windows,1,2);
acc=struct('method',cfg.method,'counts',nan(size(widths)),'warnings',"", ...
    'sampleOffsets_s',zeros(0,1),'sampleCounts',zeros(0,1),'timeOrigin_s',NaN);
rateCounts=[numel(a),numel(b)];
if isfield(context,'rateCounts'), rateCounts=context.rateCounts; end
switch cfg.method
    case "protocol"
        side=h.peakBin-(o.sideBeforeBins(1):o.sideBeforeBins(2));
        main=dualTdcMainBins(o,h.peakBin);
        if any(side<1 | side>numel(h.counts)) || ~isempty(intersect(main,side))
            acc.warnings="Protocol side window is unavailable or overlaps the main window."; return
        end
        % Use integer bin counts, retaining the original protocol arithmetic.
        acc.counts=sum(h.counts(side))*round(widths/o.binWidth)/numel(side);
        if isfinite(h.sigma) && o.sideBeforeBins(1)*o.binWidth<5*h.sigma
            acc.warnings="Specified side bins may contain the true peak tail; accidental estimate is a protocol value, not ground truth.";
        end
    case "none"
        acc.counts=zeros(size(widths));
    case "theory"
        acc.counts=prod(rateCounts)/T*widths;
        acc.warnings="Theory assumes independent stationary singles; it is not a measured accidental truth.";
    case "sideband"
        lo=o.histRange(1); hi=o.histRange(2);
        for j=1:numel(widths)
            guard=max(cfg.sidebandGuard,widths(j)/2);
            intervals=[lo,min(hi,h.peak-guard);max(lo,h.peak+guard),hi];
            intervals=intervals(diff(intervals,1,2)>0,:);
            if isempty(intervals), continue; end
            counts=countTdcPairsInWindows(a,b,intervals,true(size(intervals,1),1));
            acc.counts(j)=sum(counts)/sum(diff(intervals,1,2))*widths(j);
            if isfinite(h.sigma) && guard<5*h.sigma
                acc.warnings="Background guard is closer than 5 sigma; real peak tails may bias accidentals.";
            end
        end
    case "side-window"
        for j=1:numel(widths)
            W=widths(j); guard=max(cfg.sidebandGuard,W/2); intervals=zeros(0,2);
            for k=1:cfg.sideWindowPairs
                candidates=[h.peak-guard-[k*W,(k-1)*W];h.peak+guard+[(k-1)*W,k*W]];
                keep=candidates(:,1)>=o.histRange(1) & candidates(:,2)<=o.histRange(2);
                intervals=[intervals;candidates(keep,:)]; %#ok<AGROW>
            end
            if isempty(intervals), continue; end
            counts=countTdcPairsInWindows(a,b,intervals);
            acc.counts(j)=mean(counts);
            if j==1, acc.sampleOffsets_s=mean(intervals,2)-h.peak; acc.sampleCounts=counts; end
            if isfinite(h.sigma) && guard<5*h.sigma
                acc.warnings="Background guard is closer than 5 sigma; real peak tails may bias accidentals.";
            end
        end
    case "time-shift"
        if isempty(a) || isempty(b) || T<=0, return; end
        origin=min(a(1),b(1)); shiftB=b;
        if isfield(context,'origin_s'), origin=context.origin_s; end
        if isfield(context,'shiftB'), shiftB=context.shiftB; end
        acc.timeOrigin_s=origin;
        acc.sampleOffsets_s=cfg.timeShiftStart+(0:cfg.timeShiftCount-1)'*cfg.timeShiftStep;
        if any(abs(mod(acc.sampleOffsets_s,T))<16*eps(T))
            acc.warnings="A circular shift is zero modulo acquisition span and may retain the real coincidence peak.";
        end
        counts=zeros(cfg.timeShiftCount,numel(widths));
        includeRight=windows(:,2)==h.edges(end);
        for k=1:cfg.timeShiftCount
            shifted=sort(origin+mod(shiftB-origin+acc.sampleOffsets_s(k),T));
            counts(k,:)=countTdcPairsInWindows(a,shifted,windows,includeRight)';
        end
        acc.counts=mean(counts,1)'; acc.sampleCounts=counts(:,1);
end
acc.counts(~isfinite(widths) | widths<=0)=NaN;
end
