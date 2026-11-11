function fit = fitTimeResponse(data,exposure,bg,opts)
%FITTIMERESPONSE Profile unbinned composite likelihood to train an IRF.
% Never accepts event labels. SI times are scaled to the domain for optimization.
o=validateInferenceOptions(opts);
validateattributes(exposure,{'numeric'},{'finite','scalar','positive'});
unbinnedBackground([],bg,o.domain);
if ~iscell(data), data={data}; end
scale=diff(o.domain); origin=mean(o.domain); n=0; sample=zeros(0,1);
% Bounded deterministic sample is used only for initial peak location.
for k=1:numel(data)
    d=unbinnedDataChunk(data{k}); n=n+numel(d);
    if any(~isfinite(d)) || any(d<o.domain(1) | d>o.domain(2))
        error('CoincidenceSim:InvalidInference','Training delay outside domain.');
    end
    if numel(sample)<20000
        take=min(20000-numel(sample),numel(d));
        if take>0, sample=[sample; d(round(linspace(1,numel(d),take)))]; end %#ok<AGROW>
    end
end
fit=struct('model',[],'status',"insufficient-events",'valid',false,'N',NaN, ...
    'logLik',NaN,'exitflag',NaN,'boundaryHit',false,'identifiable',false,'exposure',exposure);
if n<o.minFitPairs, return; end
edges=linspace(o.domain(1),o.domain(2),201);
counts=histcounts(sample,edges); [~,j]=max(counts); mu=mean(edges(j:j+1));
smin=max(scale*1e-5,o.tickSeconds/10); smax=scale/2;
s0=min(smax*.8,max(smin*2,o.initialSigma));
start=[(mu-origin)/scale,invlogit((s0-smin)/(smax-smin))];
if o.model=="doublegaussian", start=[start,invlogit(.15),invlogit(.15),0]; end
starts=start;
if o.model=="doublegaussian", starts=[start;start+[.01 zeros(1,numel(start)-1)]]; end
best=Inf; bestx=start; bestflag=0;
for k=1:size(starts,1)
    [x,value,flag]=fminsearch(@loss,starts(k,:),optimset('Display','off', ...
        'MaxIter',o.maxIterations,'MaxFunEvals',o.maxIterations*3,'TolX',1e-6,'TolFun',1e-6));
    if value<best, best=value; bestx=x; bestflag=flag; end
end
model=decode(bestx); amplitude=solveUnbinnedAmplitude(data,model,bg,o.domain);
fit.model=model; fit.N=amplitude.N; fit.logLik=amplitude.logLik; fit.exitflag=bestflag;
fit.boundaryHit=abs(model.mu-origin)>.48*scale || model.sigma1<smin*1.1 || model.sigma1>.95*smax;
fit.identifiable=amplitude.status=="ok" && ~fit.boundaryHit;
if o.model=="doublegaussian"
    fit.identifiable=fit.identifiable && model.alpha>.005 && model.alpha<.495 && ...
        model.sigma2/model.sigma1>1.1 && abs(model.delta)<.24*scale;
end
fit.valid=isfinite(fit.N) && isfinite(fit.logLik) && bestflag>0;
fit.status="ok";
if ~fit.valid
    fit.status="model-fail";
elseif amplitude.status~="ok"
    fit.status=amplitude.status;
elseif ~fit.identifiable
    fit.status="unidentifiable-response";
end
    function v=loss(x)
        m=decode(x); r=solveUnbinnedAmplitude(data,m,bg,o.domain);
        v=-r.logLik;
        if ~isfinite(v), v=realmax/100; end
    end
    function m=decode(x)
        m=struct('type',o.model,'mu',origin+.5*scale*tanh(2*x(1)), ...
            'sigma1',smin+(smax-smin)*logistic(x(2)), ...
            'sigma2',NaN,'alpha',0,'delta',0);
        if o.model=="doublegaussian"
            m.sigma2=m.sigma1+(scale-m.sigma1)*max(1e-9,logistic(x(3)));
            m.alpha=.5*logistic(x(4)); m.delta=.25*scale*tanh(x(5));
        end
    end
end
function y=logistic(x)
y=.5*(1+tanh(x/2));
end
function x=invlogit(y)
x=log(y/(1-y));
end
