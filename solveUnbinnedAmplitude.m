function r = solveUnbinnedAmplitude(data,model,bg,domain)
%SOLVEUNBINNEDAMPLITUDE Concave working composite likelihood, N >= 0.
% DATA is a numeric vector or a cell of bounded numeric/disk chunks.
if ~iscell(data), data={data}; end
[~,F]=evaluateIRF([],model,domain); [~,bi]=unbinnedBackground([],bg,domain);
r=struct('N',NaN,'Fdomain',F,'score',NaN,'logLik',NaN,'curvature',NaN,'status',"unidentifiable-domain");
if F<1e-12, return; end
n=0; impossible=false; cachedF=cell(size(data)); cachedB=cell(size(data));
% Cache PDF evaluations only for resident chunks. Spilled chunks remain streamed.
for k=1:numel(data)
    d=unbinnedDataChunk(data{k});
    if any(~isfinite(d)) || any(d<domain(1) | d>domain(2))
        error('CoincidenceSim:InvalidInference','Evaluation delays outside domain.');
    end
    f=evaluateIRF(d,model,domain); b=unbinnedBackground(d,bg,domain);
    if isnumeric(data{k}), cachedF{k}=f; cachedB{k}=b; end
    impossible=impossible || any(f==0 & b==0); n=n+numel(d);
end
if impossible, r.status="zero-intensity-events"; return; end
if n==0
    r.N=0; r.score=-F; r.logLik=-bi; r.curvature=0; r.status="no-events"; return
end
[s,~,~]=objective(0);
if s<=0
    N=0; r.status="boundary-fit";
else
    low=0; high=max(1,n/F);
    mid=(low+high)/2;
    for j=1:60
        [sm,~,h]=objective(mid);
        if sm>0, low=mid; else, high=mid; end
        if abs(sm)<1e-10*F || high-low<1e-10*max(1,mid), break; end
        proposal=mid-sm/h;
        if ~isfinite(proposal) || proposal<=low || proposal>=high, proposal=(low+high)/2; end
        mid=proposal;
    end
    N=mid; r.status="ok";
end
r.N=N; [r.score,r.logLik,r.curvature]=objective(N);
    function [score,ll,curvature]=objective(N)
        score=-F; ll=-bi-N*F; curvature=0;
        for c=1:numel(data)
            if isnumeric(data{c})
                f=cachedF{c}; b=cachedB{c};
            else
                x=unbinnedDataChunk(data{c}); f=evaluateIRF(x,model,domain);
                b=unbinnedBackground(x,bg,domain);
            end
            intensity=b+N*f;
            if any(intensity==0 & f>0)
                score=Inf; ll=-Inf; curvature=-Inf; return
            end
            ratio=f./intensity; score=score+sum(ratio);
            ll=ll+sum(log(intensity)); curvature=curvature-sum(ratio.^2);
        end
    end
end
