function value = scanGetParameter(p,key,channel)
%SCANGETPARAMETER Retrieve display-unit values for the editable scan table.
if nargin<3 || channel=="both", channel="A"; end
catalog=scanParameterCatalog(); i=find(catalog.parameter==key,1); parts=split(key,'.');
if key=="algorithm.histHalfRange", value=max(abs(p.algorithm.histRange));
elseif numel(parts)==1, value=p.(parts(1));
elseif ismember(parts(1),["detector","tdc"]), value=p.(parts(1)).(channel).(parts(2));
else, value=p.(parts(1)).(parts(2));
end
if isnumeric(value), value=value/catalog.scale(i); else, value=string(value); end
end
