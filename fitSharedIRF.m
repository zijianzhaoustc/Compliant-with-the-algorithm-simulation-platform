function shared = fitSharedIRF(calibrationManifest,p)
%FITSHAREDIRF Train a pooled response on explicitly separate calibration records.
% Requires one known opticalGroup; never automatically replaces independent IRFs.
m=readInferenceManifest(calibrationManifest); p=validateParams(p);
if ~ismember('opticalGroup',m.Properties.VariableNames) || ...
        numel(unique(string(m.opticalGroup)))~=1 || ...
        any(ismissing(string(m.opticalGroup)) | string(m.opticalGroup)=="unknown" | strlength(string(m.opticalGroup))==0)
    error('CoincidenceSim:InvalidManifest','Shared IRF requires one known opticalGroup.');
end
holders=cell(height(m),1); data={}; exposure=0; background=0;
for k=1:height(m)
    [loaded,q]=loadInferenceDataset(m(k,:),p);
    q.inference.maxPairsInMemory=max(1,floor(q.inference.maxPairsInMemory/height(m)));
    holders{k}=splitTimestampBlocks(loaded.A,loaded.B,q.measurementTime,q.inference.domain,q.inference);
    items=holders{k}.items; data=[data items.delta]; %#ok<AGROW>
    exposure=exposure+sum([items.exposure]); background=background+sum([items.background]);
end
shared=struct('fit',fitTimeResponse(data,exposure,struct('intercept',background,'slope',0),p.inference), ...
    'domain',p.inference.domain,'opticalGroup',string(m.opticalGroup(1)), ...
    'calibrationFiles',canonicalFiles(m),'automaticApplicationAllowed',false);
end
function files=canonicalFiles(m)
files=[string(m.startFile);string(m.stopFile)];
for k=1:numel(files), files(k)=string(char(java.io.File(char(files(k))).getCanonicalPath())); end
files=lower(files);
end
