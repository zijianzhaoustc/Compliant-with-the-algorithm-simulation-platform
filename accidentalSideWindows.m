function edges = accidentalSideWindows(histResult, p, width)
%ACCIDENTALSIDEWINDOWS 与主窗等宽、完整落入时间谱范围的有效旁窗。
guard=max(p.algorithm.sidebandGuard,width/2);
lo=p.algorithm.histRange(1); hi=p.algorithm.histRange(2);
edges=zeros(0,2);
for k=1:p.algorithm.sideWindowPairs
    candidates=[histResult.peak-guard-[k*width,(k-1)*width]; ...
        histResult.peak+guard+[(k-1)*width,k*width]];
    for j=1:2
        if candidates(j,1)>=lo && candidates(j,2)<=hi
            edges(end+1,:)=candidates(j,:); %#ok<AGROW>
        end
    end
end
end
