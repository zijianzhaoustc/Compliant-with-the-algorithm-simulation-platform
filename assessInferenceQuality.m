function res = assessInferenceQuality(res)
%ASSESSINFERENCEQUALITY Descriptive validation risks, never a chi-square claim.
% Can audit saved numerical results without changing fitted parameters.
if ~isempty(res.diagnostics)
    d=res.diagnostics; tail=d.is_tail;
    if sum(d.observed_pairs(tail))<20, res.warnings(end+1)="limited-nonpeak-background-information"; end
    expected=sum(d.predicted_pairs(tail)); observed=sum(d.observed_pairs(tail));
    if expected>0 && abs(observed-expected)>3*sqrt(expected)
        res.warnings(end+1)="tail-or-background-prediction-mismatch";
    end
    if nnz(abs(d.standardized_residual)>5)>=3
        res.warnings(end+1)="heldout-shape-mismatch";
        if any(res.status==["ok","tail-risk"]), res.status="model-mismatch"; end
    end
end
if res.options.bootstrapCount>0 && res.bootstrap.status~="ok"
    res.warnings(end+1)="bootstrap-"+res.bootstrap.status;
end
if ismember('Fdomain',res.bootstrap.samples.Properties.VariableNames) && ...
        nnz(res.bootstrap.samples.Fdomain<res.options.fitCaptureWarn)>.1*res.options.bootstrapCount
    res.warnings(end+1)="unstable-tail-extrapolation";
end
res.warnings=unique(res.warnings,'stable');
end
