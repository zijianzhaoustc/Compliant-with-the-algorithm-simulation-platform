function p=applyResearchCalibration(p,profile)
%APPLYRESEARCHCALIBRATION Apply an integrity-checked, independently tested scope.
if ischar(profile) || isstring(profile), profile=jsondecode(fileread(profile)); end
if ~isfield(profile,'hash') || ~isfield(profile,'sourceHash') || string(profile.sourceHash)~=scanCodeHash() || ...
        ~strcmp(string(profile.hash),scanHash(rmfield(profile,'hash'))) || ...
        ~profile.validated || string(profile.scopeHash)~=researchCalibrationScope(p) || ...
        ~isempty(intersect(profile.trainingSeeds,profile.validationSeeds))
    error('CoincidenceSim:Calibration','Calibration is unvalidated, damaged, overlapping, or outside this exact configuration scope.');
end
p=researchParams(p);
for name=string(fieldnames(profile.thresholds))', p.algorithm.(name)=profile.thresholds.(name); end
p.algorithm.qualityCalibration=profile;
p.algorithm.qualityCalibrated=true; p.algorithm.qualityCalibrationHash=string(profile.hash);
end
