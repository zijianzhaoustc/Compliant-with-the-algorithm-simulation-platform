function y=applyTdcSyncMap(model,x,channelDelay)
%APPLYTDCSYNCMAP Evaluate supported map; outside coverage is explicitly NaN.
if nargin<3, channelDelay=0; end
y=nan(size(x));
if model.status=="UNALIGNED", return; end
for k=1:height(model.segments)
    r=model.segments(k,:);
    keep=x>=r.startF_s & x<r.endF_s;
    if k==height(model.segments), keep=keep | x==r.endF_s; end
    if r.valid, y(keep)=r.offsetS_s+r.scale*(x(keep)-r.referenceF_s)+channelDelay; end
end
end
