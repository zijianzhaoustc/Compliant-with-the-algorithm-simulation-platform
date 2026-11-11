function summary = runUnbinnedRealValidation(startFile,stopFile,outputFolder,bootstrapCount)
%RUNUNBINNEDREALVALIDATION Measured-record command-line audit; no invented metadata.
if nargin<4, bootstrapCount=31; end
if ~isfolder(outputFolder), mkdir(outputFolder); end
p=defaultParams(); p.inference.enabled=true; p.inference.bootstrapCount=bootstrapCount;
p.inference.blockSeconds=.5; p.inference.maxIterations=300;
manifest=table(string(startFile),string(stopFile),1e-12, ...
    'VariableNames',{'startFile','stopFile','unitSeconds'});
summary=analyzeRateEfficiency(manifest,p,fullfile(outputFolder,'gaussian'));
p.inference.model="doublegaussian"; p.inference.maxIterations=600;
p.inference.bootstrapCount=0;
dg=analyzeRateEfficiency(manifest,p,fullfile(outputFolder,'doublegaussian'));
summary.model="gaussian"; dg.model="doublegaussian"; summary=[summary;dg];
summary.delta_heldout_logLik_vs_gaussian=summary.inference_validation_score-summary.inference_validation_score(1);
writeUtf8BomTable(summary,fullfile(outputFolder,'model_comparison.csv'));
% All block-length trials use the same timestamp record; descriptive sensitivity.
p.inference.model="gaussian";
for width=[.25 1]
    p.inference.blockSeconds=width;
    analyzeRateEfficiency(manifest,p,fullfile(outputFolder,sprintf('block_%g_s',width)));
end
end
