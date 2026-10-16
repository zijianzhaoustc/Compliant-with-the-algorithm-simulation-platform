function f=gaussianIntervalProbability(lower,upper,mu,sigma)
%GAUSSIANINTERVALPROBABILITY Exact arbitrary-boundary normalized Gaussian mass.
f=.5*(erf((upper-mu)/(sqrt(2)*sigma))-erf((lower-mu)/(sqrt(2)*sigma)));
f=max(0,min(1,f));
end
