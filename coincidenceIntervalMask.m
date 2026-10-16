function mask=coincidenceIntervalMask(delta,lower,upper,includeUpper)
%COINCIDENCEINTERVALMASK Shared half-open convention, explicit histogram end.
if nargin<4, includeUpper=false; end
mask=delta>=lower & delta<upper;
if includeUpper, mask=mask | delta==upper; end
end
