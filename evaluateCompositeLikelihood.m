function value = evaluateCompositeLikelihood(data,model,bg,domain,N)
%EVALUATECOMPOSITELIKELIHOOD Fixed prediction score on independent blocks.
validateattributes(N,{'numeric'},{'scalar','finite','nonnegative'});
if ~iscell(data), data={data}; end
[~,F]=evaluateIRF([],model,domain); [~,bi]=unbinnedBackground([],bg,domain);
value=-bi-N*F;
for k=1:numel(data)
    d=unbinnedDataChunk(data{k});
    if any(d<domain(1) | d>domain(2)) || any(~isfinite(d))
        error('CoincidenceSim:InvalidInference','Prediction delays outside domain.');
    end
    f=evaluateIRF(d,model,domain); b=unbinnedBackground(d,bg,domain);
    value=value+sum(log(b+N*f));
end
end
