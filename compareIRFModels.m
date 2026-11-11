function comparison = compareIRFModels(A,B,p)
%COMPAREIRFMODELS Two-fold fixed-prediction G/DG scores, no truth or selection.
% Model comparison is descriptive. Further outer validation is required after
% model selection; these evaluation folds must not be repeatedly tuned against.
p=validateParams(p); p.inference.bootstrapCount=0;
models=["gaussian","doublegaussian"]; rows=cell(2,6);
for k=1:2
    p.inference.model=models(k); r=crossFitUnbinned(A,B,p);
    rows(k,:)={models(k),r.Cpair,r.Fdomain,r.Fwindow,r.validation_score,r.status};
end
comparison=cell2table(rows,'VariableNames',{'model','Cpair_cps','Fdomain','Fwindow', ...
    'heldout_fixed_prediction_logLik','status'});
comparison.delta_logLik_vs_gaussian=comparison.heldout_fixed_prediction_logLik-comparison.heldout_fixed_prediction_logLik(1);
end
