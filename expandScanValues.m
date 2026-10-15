function values = expandScanValues(f)
%EXPANDSCANVALUES Expand once without eval or cumulative floating addition.
switch string(f.inputMode)
    case {"fixed","list"}
        values=f.values;
        if ischar(values) || isstring(values)
            tokens=strip(split(string(values),[",",";"," "])); tokens(tokens=="")=[];
            numbers=str2double(tokens);
            if all(isfinite(numbers)), values=numbers'; else, values=tokens'; end
        end
    case "range"
        a=f.start; b=f.stop; d=f.step;
        if ~all(isfinite([a b d])) || ~isscalar(a) || ~isscalar(b) || ~isscalar(d) || ...
                d==0 || (b-a)*d<0
            error('CoincidenceSim:ScanRange','Invalid start/stop/step.');
        end
        ratio=(b-a)/d; n=floor(ratio+64*eps(max(1,abs(ratio))));
        if n>1e6, error('CoincidenceSim:ScanLimit','Factor has too many values.'); end
        values=a+(0:n)*d;
        if abs(values(end)-b)<=64*eps(max(abs([a b d]))), values(end)=b; end
    case "log"
        validateattributes([f.start f.stop],{'numeric'},{'finite','positive'});
        validateattributes(f.count,{'numeric'},{'scalar','integer','positive','<=',1e6});
        values=logspace(log10(f.start),log10(f.stop),f.count);
    otherwise
        error('CoincidenceSim:ScanInput','Unknown factor input mode.');
end
if isempty(values) || (isnumeric(values) && any(~isfinite(values)))
    error('CoincidenceSim:ScanValues','Scan values must be nonempty and finite.');
end
values=unique(values(:)','stable');
if string(f.inputMode)=="fixed" && numel(values)~=1
    error('CoincidenceSim:ScanValues','Fixed input requires exactly one value.');
end
end
