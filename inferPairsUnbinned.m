function res = inferPairsUnbinned(deltaEval,Teff,RA,RB,fit,opts)
%INFERPAIRSUNBINNED Fit full recorded correlation area with fixed response.
o=validateInferenceOptions(opts);
validateattributes(Teff,{'numeric'},{'scalar','finite','positive'});
validateattributes(RA,{'numeric'},{'scalar','finite','nonnegative'});
validateattributes(RB,{'numeric'},{'scalar','finite','nonnegative'});
bg=struct('intercept',Teff*RA*RB,'slope',double(o.edgeCorrection)*RA*RB);
if isfield(opts,'background'), bg=opts.background; end
res=solveUnbinnedAmplitude(deltaEval,fit.model,bg,o.domain);
res.C=res.N/Teff; res.Teff=Teff; res.background=bg;
[~,res.Fwindow]=evaluateIRF([],fit.model,fit.model.mu+[-1 1]*o.referenceWindow/2);
res.Ndomain=res.N*res.Fdomain; res.Nwindow=res.N*res.Fwindow;
res.b=bg.intercept; res.warnings=strings(0,1);
if res.Fdomain<o.fitCaptureWarn, res.warnings(end+1)="tail-extrapolation-risk"; end
end
