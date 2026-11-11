function manifest = readInferenceManifest(input)
%READINFERENCEMANIFEST Validate a measured-data table, resolve CSV-relative paths.
manifest=input;
if ischar(input) || isstring(input)
    filename=char(input); manifest=readtable(filename,'TextType','string','VariableNamingRule','preserve');
    base=fileparts(char(java.io.File(filename).getCanonicalPath()));
    for name=["startFile","stopFile"]
        if ismember(name,manifest.Properties.VariableNames)
            values=string(manifest.(name));
            for k=1:numel(values)
                if ~java.io.File(char(values(k))).isAbsolute(), values(k)=fullfile(base,values(k)); end
            end
            manifest.(name)=values;
        end
    end
end
if ~istable(manifest) || isempty(manifest) || ...
        ~all(ismember({'startFile','stopFile','unitSeconds'},manifest.Properties.VariableNames))
    error('CoincidenceSim:InvalidManifest','Manifest requires rows with startFile, stopFile, unitSeconds.');
end
end
