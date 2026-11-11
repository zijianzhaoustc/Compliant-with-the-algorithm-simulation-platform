function o = validateInferenceOptions(o)
%VALIDATEINFERENCEOPTIONS Validate inference options without simulation truth.
o=inferenceOptions(o);
for name=["enabled","crossFit","edgeCorrection","quantizationDiagnostic"]
    v=o.(name);
    if ~isscalar(v) || ~ismember(v,[0 1]), error('CoincidenceSim:InvalidInference','Invalid %s.',name); end
    o.(name)=logical(v);
end
if ~isscalar(string(o.model)) || ~any(string(o.model)==["gaussian","doublegaussian"])
    error('CoincidenceSim:InvalidIRF','Unknown response model.');
end
if ~isnumeric(o.domain) || numel(o.domain)~=2 || any(~isfinite(o.domain)) || o.domain(1)>=o.domain(2)
    error('CoincidenceSim:InvalidInference','domain must contain increasing finite SI times.');
end
o.domain=reshape(o.domain,1,2);
for name=["initialSigma","blockSeconds","referenceWindow","maxPairsInMemory","minBlocks","minFitPairs","maxIterations"]
    v=o.(name);
    if ~isnumeric(v) || ~isscalar(v) || ~isfinite(v) || v<=0
        error('CoincidenceSim:InvalidInference','Invalid positive option %s.',name);
    end
end
for name=["maxPairsInMemory","minBlocks","minFitPairs","maxIterations","bootstrapCount","bootstrapSeed"]
    v=o.(name);
    if ~isscalar(v) || ~isfinite(v) || v<0 || fix(v)~=v
        error('CoincidenceSim:InvalidInference','Invalid integer option %s.',name);
    end
end
if o.minBlocks<4 || o.bootstrapSeed>2^32-1 || o.fitCaptureWarn<=0 || o.fitCaptureWarn>1 || ...
        ~isscalar(o.fitCaptureWarn) || ~isfinite(o.fitCaptureWarn) || ...
        ~isscalar(o.tickSeconds) || ~isfinite(o.tickSeconds) || o.tickSeconds<0
    error('CoincidenceSim:InvalidInference','Invalid capture threshold, tick, seed or block count.');
end
if string(o.backgroundMode)~="rate-product"
    error('CoincidenceSim:InvalidInference','Only explicitly modelled rate-product background is supported.');
end
if ~isscalar(o.heraldBackgroundRate) || (~isnan(o.heraldBackgroundRate) && ...
        (~isfinite(o.heraldBackgroundRate) || o.heraldBackgroundRate<0))
    error('CoincidenceSim:InvalidInference','Herald background must be nonnegative or unknown (NaN).');
end
if isfinite(o.heraldBackgroundRate) && string(o.heraldBackgroundSource)=="unknown"
    error('CoincidenceSim:InvalidInference','A measured herald background requires an explicit source.');
end
end
