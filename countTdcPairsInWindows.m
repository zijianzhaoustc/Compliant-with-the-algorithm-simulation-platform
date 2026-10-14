function counts=countTdcPairsInWindows(a,b,windows,includeRight)
%COUNTTDCPAIRSINWINDOWS Exact all-pairs counts; two pointers, no pair matrix.
% Each lag interval is [left,right), unless its includeRight flag is true.
if nargin<4, includeRight=false(size(windows,1),1); end
counts=zeros(size(windows,1),1);
for k=1:size(windows,1)
    lo=windows(k,1); hi=windows(k,2); left=1; right=0;
    if ~isfinite(lo) || ~isfinite(hi) || hi<=lo, counts(k)=NaN; continue; end
    for i=1:numel(a)
        while left<=numel(b) && b(left)-a(i)<lo, left=left+1; end
        right=max(right,left-1);
        if includeRight(k)
            while right<numel(b) && b(right+1)-a(i)<=hi, right=right+1; end
        else
            while right<numel(b) && b(right+1)-a(i)<hi, right=right+1; end
        end
        counts(k)=counts(k)+max(0,right-left+1);
    end
end
end
