function [counts,edges,info]=streamCoincidenceHistogram(a,b,p)
%STREAMCOINCIDENCEHISTOGRAM Exact all-pairs bins, bounded scratch, no indices.
lo=p.algorithm.histRange(1); hi=p.algorithm.histRange(2); bw=p.algorithm.binWidth;
r=(hi-lo)/bw; nearest=round(r);
if abs(r-nearest)<64*eps(max(1,abs(r))), n=nearest; else, n=ceil(r); end
edges=lo+(0:n)*bw; counts=zeros(1,n); chunk=p.algorithm.pairChunkSize;
if isfield(p.algorithm,'scanWorkingMemoryMB')
    src=0; if isfield(p,'analysis') && isfield(p.analysis,'sourceCount'), src=p.analysis.sourceCount; end
    base=estimateScanWorkingMemoryMB(p,src,[numel(a),numel(b)],0);
    chunk=min(chunk,floor((p.algorithm.scanWorkingMemoryMB-base)*2^20/24));
    if chunk<1, error('CoincidenceSim:WorkingMemoryLimit','No memory budget for streaming scratch.'); end
end
pending=zeros(chunk,1); filled=0; left=1; right=0; total=0; maxUsed=0;
for i=1:numel(a)
    while left<=numel(b) && b(left)-a(i)<lo, left=left+1; end
    right=max(right,left-1);
    while right<numel(b) && b(right+1)-a(i)<=hi, right=right+1; end
    total=total+max(0,right-left+1);
    if isfield(p.algorithm,'maxMatchPairs') && total>p.algorithm.maxMatchPairs
        error('CoincidenceSim:PairLimit','Streaming pair-work limit exceeded (%g).',p.algorithm.maxMatchPairs);
    end
    first=left;
    while first<=right
        take=min(right-first+1,chunk-filled);
        pending(filled+(1:take))=b(first:first+take-1)-a(i); filled=filled+take; first=first+take;
        maxUsed=max(maxUsed,filled);
        if filled==chunk, counts=counts+histcounts(pending,edges); filled=0; end
    end
end
if filled>0, counts=counts+histcounts(pending(1:filled),edges); end
info=struct('pairCount',total,'maxScratchPairs',maxUsed,'searchBounds',[lo hi]);
end
