function finalizeUnbinnedValidation(folder)
%FINALIZEUNBINNEDVALIDATION Re-audit saved numerical fits and refresh reports.
% Changes quality labels/exports only; fitted parameters and samples are retained.
files=dir(fullfile(folder,'**','inference_result.mat'));
for k=1:numel(files)
    path=fullfile(files(k).folder,files(k).name); s=load(path);
    s.res=assessInferenceQuality(s.res);
    exportInferenceResults(s.res,files(k).folder,s.p,s.metadata);
    plotInferenceDiagnostics(s.res,s.p,files(k).folder);
    parent=fileparts(files(k).folder); summaryFile=fullfile(parent,'power_rate_efficiency.csv');
    if isfile(summaryFile)
        t=readtable(summaryFile,'TextType','string','Delimiter',',','NumHeaderLines',0,'ReadVariableNames',true);
        row=buildInferenceSummaryTable(s.res);
        if height(t)==1
            for name=string(row.Properties.VariableNames), t.(name)=row.(name); end
            writeUtf8BomTable(t,summaryFile); plotRateEfficiency(t,parent);
        end
    end
end
g=fullfile(folder,'gaussian','power_rate_efficiency.csv');
d=fullfile(folder,'doublegaussian','power_rate_efficiency.csv');
if isfile(g) && isfile(d)
    gt=readtable(g,'TextType','string','Delimiter',',','NumHeaderLines',0,'ReadVariableNames',true);
    dt=readtable(d,'TextType','string','Delimiter',',','NumHeaderLines',0,'ReadVariableNames',true);
    gt.model="gaussian"; dt.model="doublegaussian"; t=[gt;dt];
    t.delta_heldout_logLik_vs_gaussian=t.inference_validation_score-t.inference_validation_score(1);
    writeUtf8BomTable(t,fullfile(folder,'model_comparison.csv'));
end
end
