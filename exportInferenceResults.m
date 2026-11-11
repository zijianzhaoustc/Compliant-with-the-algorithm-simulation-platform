function files = exportInferenceResults(res,folder,p,metadata)
%EXPORTINFERENCERESULTS Dedicated SI/Origin CSVs and reproducibility manifest.
% Uses a separate inference directory and never overwrites legacy result CSVs.
if nargin<4, metadata=struct(); end
if ~isfolder(folder), mkdir(folder); end
files=strings(0,1);
writeTable(buildInferenceSummaryTable(res),'inference_summary.csv');
writeTable(res.diagnostics,'model_diagnostics.csv');
writeTable(res.bootstrap.samples,'bootstrap_samples.csv');
writeTable(res.blockTable,'time_blocks.csv');
rows=cell(0,5); grid=linspace(p.inference.domain(1),p.inference.domain(2),1001)';
for k=1:numel(res.folds)
    [f,~,m]=evaluateIRF(grid,res.folds{k}.fit.model,p.inference.domain);
    rows=[rows; num2cell([repmat(k,numel(grid),1),grid,f,m.corePdf,m.widePdf])]; %#ok<AGROW>
end
writeTable(cell2table(rows,'VariableNames',{'fold','delay_s','model_pdf_per_s','core_pdf_per_s','wide_pdf_per_s'}),'IRF_curve.csv');
[code,sha]=system('git rev-parse HEAD'); if code~=0, sha='unknown'; end
settings=struct('params',p,'repositoryCommit',strtrim(sha),'matlabVersion',version, ...
    'metadata',metadata,'exposureSource',res.exposureSource, ...
    'likelihood',"working-composite; candidate pairs share events; no Hessian CI", ...
    'countTarget',"expected recorded correlated pairs; not generated pairs", ...
    'fulltimeCountDefinition',"stationarity-based exposure extrapolation Cpair*T", ...
    'irfPlotDefinition',"analytic model density grid; not raw histogram", ...
    'coverageValidated',false,'backgroundDefinition',res.backgroundDefinition);
file=fullfile(folder,'settings_used.json'); fid=fopen(file,'w','n','UTF-8');
if fid<0, error('CoincidenceSim:ExportFailed','Cannot write settings.'); end
cleanup=onCleanup(@()fclose(fid)); fwrite(fid,jsonencode(settings,'PrettyPrint',true),'char'); clear cleanup
files(end+1,1)=file;
manifest=table(string(datetime('now','TimeZone','UTC')),string(strtrim(sha)),string(version), ...
    string(res.status),string(res.exposureSource),res.T,res.Tcore,res.totalCandidatePairs, ...
    res.bootstrap.seed,res.bootstrap.failureCount,'VariableNames', ...
    {'created_utc','repository_commit','matlab_version','status','exposure_source','T_s','Tcore_s', ...
    'candidate_pairs','bootstrap_seed','failed_refits'});
writeTable(manifest,'run_manifest.csv');
save(fullfile(folder,'inference_result.mat'),'res','p','metadata');
files(end+1,1)=fullfile(folder,'inference_result.mat');
    function writeTable(t,name)
        path=fullfile(folder,name); writeUtf8BomTable(t,path); files(end+1,1)=path;
    end
end
