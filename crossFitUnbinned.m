function res = crossFitUnbinned(A,B,p)
%CROSSFITUNBINNED Recorded correlation area from raw sorted timestamps.
% pairID is read only AFTER all inference, diagnostics and bootstrap finish.
p=validateParams(p); o=p.inference;
if ~any(p.algorithm.matchMethod==["many-to-many","all-pairs"])
    error('CoincidenceSim:InferenceRequiresAllPairs','Unbinned inference requires many-to-many/all-pairs.');
end
blocks=splitTimestampBlocks(A,B,p.measurementTime,o.domain,o);
res=fitUnbinnedBlocks(blocks,p);
res.bootstrap=bootstrapUnbinned(blocks,p);
res.diagnostics=diagnoseIRFModel(blocks,res);
res.exposureSource=o.exposureSource;
if string(o.exposureSource)=="inferred", res.warnings(end+1)="inferred-exposure-not-device-gate"; end
res.backgroundDefinition="sum of per-block RA_core * RB_block * Tcore; exact guarded overlap";
res.spilledToDisk=blocks.spilled; res.maxResidentPairs=blocks.maxResidentPairs;
res.totalCandidatePairs=sum([blocks.items.pairCount]);
res.blockTable=struct2table(rmfield(blocks.items,{'delta'}));
if o.tickSeconds>0 && ~isempty(res.folds) && o.quantizationDiagnostic
    widths=cellfun(@(f)f.fit.model.sigma1,res.folds);
    if o.tickSeconds>.2*min(widths), res.warnings(end+1)="coarse-tick-continuous-density-risk"; end
end
% Evaluation-only labels. Count unique positive recorded IDs, never candidates.
if isfield(A,'pairID') && isfield(B,'pairID') && any(A.pairID>0) && any(B.pairID>0)
    res.truth_Nrec=numel(intersect(A.pairID(A.pairID>0),B.pairID(B.pairID>0)));
end
end
