function [F,covariance,G]=peakWindowMasses(fit,g)
%PEAKWINDOWMASSES Exact main/total-side mass and fit-parameter covariance.
F=[NaN NaN]; covariance=nan(2); G=nan(2,4);
if fit.status~="FIT_OK" || ~g.mainValid, return; end
F=[mass(g.mainLower,g.mainUpper),0]; gradients=gradient(g.mainLower,g.mainUpper);
sideGradient=[0 0];
for s=g.sideWindows
    if ~s.valid, F(2)=NaN; break; end
    F(2)=F(2)+mass(s.lower,s.upper); sideGradient=sideGradient+gradient(s.lower,s.upper);
end
G=[0,gradients(1)*fit.scale,gradients(2)*fit.sigma,0; ...
    0,sideGradient(1)*fit.scale,sideGradient(2)*fit.sigma,0];
covariance=G*fit.covTheta*G';
    function f=mass(lo,hi), f=gaussianIntervalProbability(lo,hi,fit.mu,fit.sigma); end
    function d=gradient(lo,hi)
        z=[lo hi]-fit.mu; z=z/fit.sigma; pdf=exp(-z.^2/2)/sqrt(2*pi);
        d=[(pdf(1)-pdf(2))/fit.sigma,(z(1)*pdf(1)-z(2)*pdf(2))/fit.sigma];
    end
end
