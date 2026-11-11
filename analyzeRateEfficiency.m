function tbl = analyzeRateEfficiency(datasetManifest,p,outputFolder)
%ANALYZERATEEFFICIENCY Independent IRFs for measured data, grouped by optics.
% Manifest table/CSV requires startFile, stopFile, unitSeconds. Optional fields:
% durationSeconds, rawOrigin, tickSeconds, powerW, opticalGroup,
% heraldBackgroundRate, heraldBackgroundSource. Missing metadata stays unknown.
datasetManifest=readInferenceManifest(datasetManifest);
if nargin<3, outputFolder=""; end
p=validateParams(p); rows=cell(height(datasetManifest),1);
for k=1:height(datasetManifest)
    row=datasetManifest(k,:); [loaded,q]=loadInferenceDataset(row,p);
    tic; result=crossFitUnbinned(loaded.A,loaded.B,q); elapsed=toc;
    result.truth_Nrec=NaN;
    if loaded.source.precisionWarning~="", result.warnings(end+1)=loaded.source.precisionWarning; end
    if loaded.source.gateOriginSource=="first-event" && loaded.source.exposureSource=="declared"
        result.warnings(end+1)="declared-duration-origin-assumed-first-event";
    end
    summary=buildInferenceSummaryTable(result);
    summary.dataset_index=k; summary.startFile=string(row.startFile); summary.stopFile=string(row.stopFile);
    summary.power_W=NaN; summary.optical_group="unknown";
    if ismember('powerW',row.Properties.VariableNames), summary.power_W=row.powerW; end
    if ismember('opticalGroup',row.Properties.VariableNames), summary.optical_group=string(row.opticalGroup); end
    summary.rate_A_cps=result.rateA; summary.rate_B_cps=result.rateB; summary.elapsed_s=elapsed;
    summary.shared_IRF_status="independent-only; sharing requires external validation";
    rows{k}=summary;
    if strlength(outputFolder)>0
        folder=fullfile(outputFolder,sprintf('dataset_%04d',k));
        exportInferenceResults(result,folder,q,table2struct(row));
        plotInferenceDiagnostics(result,q,folder);
    end
end
tbl=vertcat(rows{:});
if strlength(outputFolder)>0
    writeUtf8BomTable(tbl,fullfile(outputFolder,'power_rate_efficiency.csv'));
    plotRateEfficiency(tbl,outputFolder);
end
end
