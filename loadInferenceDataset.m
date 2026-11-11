function [loaded,q] = loadInferenceDataset(row,p)
%LOADINFERENCEDATASET Import one manifest row, preserving unknown metadata.
if ~istable(row) || height(row)~=1, error('CoincidenceSim:InvalidManifest','Expected one manifest row.'); end
q=validateParams(p); acquisition=struct();
for name=["durationSeconds","rawOrigin","tickSeconds"]
    if ismember(name,row.Properties.VariableNames) && isfinite(row.(name))
        acquisition.(name)=row.(name);
    end
end
for name=["heraldBackgroundRate","heraldBackgroundSource"]
    if ismember(name,row.Properties.VariableNames), q.inference.(name)=row.(name); end
end
loaded=importTimestampFiles(row.startFile,row.stopFile,row.unitSeconds,q,false,acquisition);
q=loaded.params; q.inference.exposureSource=loaded.source.exposureSource;
end
