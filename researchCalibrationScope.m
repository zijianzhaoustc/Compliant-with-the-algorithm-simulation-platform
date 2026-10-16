function hash=researchCalibrationScope(p)
%RESEARCHCALIBRATIONSCOPE Exact physical/analysis scope, excluding QA metadata.
p=researchParams(p); p=rmfield(p,'seed');
if isfield(p,'analysis'), p=rmfield(p,'analysis'); end
exclude=["qualityCalibrated","qualityCalibrationHash","qualityCalibration", ...
    "residualThreshold","sideTailThreshold","sideAsymmetryThreshold","stationarityAlpha", ...
    "backgroundConflictThreshold","bootstrapSeed","maxMatchPairs","scanWorkingMemoryMB", ...
    "storageMode","pairChunkSize"];
for name=exclude
    if isfield(p.algorithm,name), p.algorithm=rmfield(p.algorithm,name); end
end
hash=scanHash(p);
end
