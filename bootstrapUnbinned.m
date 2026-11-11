function bs = bootstrapUnbinned(blocks,p)
%BOOTSTRAPUNBINNED Joint original-block resampling; refit IRF each draw.
% Source odd/even parity is preserved. No independent delay resampling.
o=validateInferenceOptions(p.inference); B=o.bootstrapCount;
names={'Cpair_cps','Npair_core','Fwindow','etaB_apparent','etaB_given_A'};
values=NaN(B,5); statuses=strings(B,1); K=numel(blocks.items);
odd=1:2:K; even=2:2:K;
stream=RandStream('mt19937ar','Seed',o.bootstrapSeed);
for r=1:B
    if o.crossFit
        ix=[odd(randi(stream,numel(odd),size(odd))),even(randi(stream,numel(even),size(even)))];
    else
        ix=randi(stream,K,1,K);
    end
    z=fitUnbinnedBlocks(blocks,p,ix); statuses(r)=z.status;
    values(r,:)=[z.Cpair,z.Npair_core,z.Fwindow,z.etaB_apparent,z.etaB_given_A];
end
bs=struct('samples',array2table(values,'VariableNames',names),'status',"not-run", ...
    'standardUncertainty',NaN(1,5),'CI95',NaN(2,5),'failureCount',nnz(~isfinite(values(:,1))), ...
    'requestedCount',B,'seed',o.bootstrapSeed,'coverageValidated',false);
bs.samples.fit_status=statuses;
if B==0, return; end
if K<o.minBlocks || B<20, bs.status="insufficient-blocks-or-replicates"; return; end
if bs.failureCount>.1*B, bs.status="too-many-failed-refits"; return; end
for c=1:5
    v=sort(values(isfinite(values(:,c)),c));
    if numel(v)<20 || max(v)==min(v), continue; end
    bs.standardUncertainty(c)=std(v);
    bs.CI95(:,c)=quantile(v,[.025 .975]).';
end
bs.status="ok";
if all(isnan(bs.CI95(:,1))), bs.status="degenerate-resamples"; end
end
