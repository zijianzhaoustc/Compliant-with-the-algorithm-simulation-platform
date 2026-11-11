function [pdfVal,mass,meta] = evaluateIRF(tau,model,domain)
%EVALUATEIRF Globally normalized Gaussian/shifted-DG PDF and analytic mass.
% MODEL has type, mu, sigma1; DG also has sigma2, alpha, delta (seconds).
validateattributes(tau,{'numeric'},{'real','finite'});
validateattributes(domain,{'numeric'},{'real','finite','numel',2});
if domain(1)>=domain(2), error('CoincidenceSim:InvalidIRF','Invalid domain.'); end
if ~isfield(model,'type') || ~any(string(model.type)==["gaussian","doublegaussian"])
    error('CoincidenceSim:InvalidIRF','Unknown IRF model.');
end
validateattributes(model.mu,{'numeric'},{'real','finite','scalar'});
validateattributes(model.sigma1,{'numeric'},{'real','finite','scalar','positive'});
core=normalPdf(tau,model.mu,model.sigma1);
mass=normalMass(domain,model.mu,model.sigma1); wide=zeros(size(tau));
if string(model.type)=="doublegaussian"
    if ~isscalar(model.alpha) || ~isfinite(model.alpha) || model.alpha<0 || model.alpha>.5 || ...
            ~isscalar(model.sigma2) || ~isfinite(model.sigma2) || model.sigma2<=model.sigma1 || ...
            ~isscalar(model.delta) || ~isfinite(model.delta)
        error('CoincidenceSim:InvalidIRF','Invalid double-Gaussian parameters.');
    end
    core=(1-model.alpha)*core;
    wide=model.alpha*normalPdf(tau,model.mu+model.delta,model.sigma2);
    mass=(1-model.alpha)*mass+model.alpha*normalMass(domain,model.mu+model.delta,model.sigma2);
end
pdfVal=core+wide;
meta=struct('status',"ok",'corePdf',core,'widePdf',wide,'globallyNormalized',true);
if mass<1e-12, meta.status="unidentifiable-domain"; end
end
function y=normalPdf(x,m,s)
y=exp(-.5*((x-m)/s).^2)/(sqrt(2*pi)*s);
end
function q=normalMass(d,m,s)
z=(d-m)/(sqrt(2)*s);
if z(1)>=0, q=.5*(erfc(z(1))-erfc(z(2)));
elseif z(2)<=0, q=.5*(erfc(-z(2))-erfc(-z(1)));
else, q=.5*(erf(z(2))-erf(z(1))); end
q=min(1,max(0,q));
end
