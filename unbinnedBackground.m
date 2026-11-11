function [b,integralB] = unbinnedBackground(tau,bg,domain)
%UNBINNEDBACKGROUND Constant or finite-gate triangular delay intensity.
if isnumeric(bg), bg=struct('intercept',bg,'slope',0); end
if ~isscalar(bg.intercept) || ~isfinite(bg.intercept) || bg.intercept<0 || ...
        ~isscalar(bg.slope) || ~isfinite(bg.slope) || bg.slope<0
    error('CoincidenceSim:InvalidBackground','Background density must be finite and nonnegative.');
end
b=max(0,bg.intercept-bg.slope*abs(tau));
if bg.slope==0
    integralB=bg.intercept*diff(domain);
else
    bound=bg.intercept/bg.slope; d=max(-bound,min(bound,domain));
    integralB=bg.intercept*diff(d)-bg.slope/2*diff(d.*abs(d));
end
end
