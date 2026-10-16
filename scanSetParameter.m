function p = scanSetParameter(p,key,value,channel)
%SCANSETPARAMETER Validated catalog key to nested SI parameter fields.
if nargin<4, channel="both"; end
catalog=scanParameterCatalog(true); i=find(catalog.parameter==string(key),1);
if isempty(i), error('CoincidenceSim:UnknownScanParameter','Unknown parameter: %s',key); end
parts=split(string(key),'.');
if isnumeric(value) || islogical(value), value=value*catalog.scale(i); else, value=string(value); end
if numel(parts)==2 && ismember(parts(1),["detector","tdc"])
    channels=string(channel); if channels=="both", channels=["A","B"]; end
    for ch=channels, p.(parts(1)).(ch).(parts(2))=value; end
elseif string(key)=="algorithm.histHalfRange"
    p.algorithm.histRange=[-value,value];
elseif string(key)=="algorithm.histLeft"
    p.algorithm.histRange(1)=value;
elseif string(key)=="algorithm.histRight"
    p.algorithm.histRange(2)=value;
elseif numel(parts)==1
    p.(parts(1))=value;
else
    p.(parts(1)).(parts(2))=value;
end
end
