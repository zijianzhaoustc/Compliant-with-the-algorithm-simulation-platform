function a=dualTdcAccidentalOptions(o)
%DUALTDCACCIDENTALOPTIONS Single-TDC parameter names, protocol default retained.
p=defaultParams(); a=struct('method',"protocol",'sidebandGuard',p.algorithm.sidebandGuard, ...
    'sideWindowPairs',p.algorithm.sideWindowPairs,'timeShiftStart',p.algorithm.timeShiftStart, ...
    'timeShiftStep',p.algorithm.timeShiftStep,'timeShiftCount',p.algorithm.timeShiftCount);
if nargin>0 && isfield(o,'accidental')
    for name=string(fieldnames(a))'
        if isfield(o.accidental,name), a.(name)=o.accidental.(name); end
    end
end
a.method=string(a.method);
end
