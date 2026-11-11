function comparison = validateSharedIRF(evaluationManifest,shared,p,outputFolder)
%VALIDATESHAREDIRF Compare shared vs independent fixed predictions externally.
% Rejects calibration-file reuse and optical-group mismatch. No automatic choice.
m=readInferenceManifest(evaluationManifest); p=validateParams(p);
if ~shared.fit.valid || ~isequal(shared.domain,p.inference.domain)
    error('CoincidenceSim:InvalidIRF','Shared calibration failed or uses a different domain.');
end
if ~ismember('opticalGroup',m.Properties.VariableNames) || any(string(m.opticalGroup)~=shared.opticalGroup)
    error('CoincidenceSim:InvalidManifest','External records must share the known opticalGroup.');
end
files=[string(m.startFile);string(m.stopFile)];
for k=1:numel(files), files(k)=string(char(java.io.File(char(files(k))).getCanonicalPath())); end
if any(ismember(lower(files),shared.calibrationFiles))
    error('CoincidenceSim:ValidationLeakage','Calibration and external evaluation files overlap.');
end
rows=cell(height(m),6);
for k=1:height(m)
    [loaded,q]=loadInferenceDataset(m(k,:),p);
    blocks=splitTimestampBlocks(loaded.A,loaded.B,q.measurementTime,q.inference.domain,q.inference);
    independent=fitUnbinnedBlocks(blocks,q); sharedScore=0;
    for fold=1:numel(independent.folds)
        f=independent.folds{fold}; train=blocks.items(f.trainingBlocks); v=blocks.items(f.evaluationBlocks);
        bg=struct('intercept',sum([train.background]),'slope',0);
        area=solveUnbinnedAmplitude([train.delta],shared.fit.model,bg,q.inference.domain);
        N=area.N/sum([train.exposure])*sum([v.exposure]);
        bg=struct('intercept',sum([v.background]),'slope',0);
        sharedScore=sharedScore+evaluateCompositeLikelihood([v.delta],shared.fit.model,bg,q.inference.domain,N);
    end
    if isempty(independent.folds), sharedScore=NaN; end
    rows(k,:)={k,string(m.startFile(k)),shared.opticalGroup,independent.validation_score,sharedScore,independent.status};
end
comparison=cell2table(rows,'VariableNames',{'dataset_index','startFile','optical_group', ...
    'independent_fixed_prediction_logLik','shared_fixed_prediction_logLik','status'});
comparison.shared_minus_independent_logLik=comparison.shared_fixed_prediction_logLik-comparison.independent_fixed_prediction_logLik;
if nargin>=4 && strlength(outputFolder)>0
    if ~isfolder(outputFolder), mkdir(outputFolder); end
    writeUtf8BomTable(comparison,fullfile(outputFolder,'shared_IRF_external_validation.csv'));
end
end
