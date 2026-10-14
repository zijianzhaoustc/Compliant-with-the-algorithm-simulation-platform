function h=dualTdcHistogram(a,b,o)
%DUALTDCHISTOGRAM Full all-pairs histogram with bounded pair scratch memory.
% No Cartesian product or retained pair list. Each A event owns all its pairs;
% chunk boundaries cannot drop or double-count combinations.
a=a(:); b=b(:); lo=o.histRange(1); bw=o.binWidth;
nBins=ceil((o.histRange(2)-lo)/bw-1e-10); edges=lo+(0:nBins)*bw;
counts=zeros(1,nBins); pending=zeros(o.maxPairChunk,1); filled=0;
left=1; right=0; nB=numel(b); maxUsed=0;
for i=1:numel(a)
    while left<=nB && b(left)-a(i)<lo, left=left+1; end
    right=max(right,left-1);
    while right<nB && b(right+1)-a(i)<=o.histRange(2), right=right+1; end
    first=left;
    while first<=right
        n=min(right-first+1,o.maxPairChunk-filled);
        pending(filled+(1:n))=b(first:first+n-1)-a(i); filled=filled+n; first=first+n;
        maxUsed=max(maxUsed,filled);
        if filled==o.maxPairChunk
            counts=counts+histcounts(pending,edges); filled=0;
        end
    end
end
if filled>0, counts=counts+histcounts(pending(1:filled),edges); end
% Reuse the established Gaussian fitter without expanding histogram counts.
p=defaultParams(); p.algorithm.histRange=o.histRange; p.algorithm.binWidth=bw;
p.algorithm.peakMethod="gaussian";
h=fitDualTdcHistogram(counts,edges,p);
h.maxPairScratchCount=maxUsed; h.totalPairs=sum(counts);
end
