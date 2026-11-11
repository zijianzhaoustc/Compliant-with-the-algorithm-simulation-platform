function res = fitUnbinnedBlocks(blocks,p,indices)
%FITUNBINNEDBLOCKS Cross-fit original guarded block sufficient data.
% INDICES keeps each resampled source block in its original parity fold.
o=validateInferenceOptions(p.inference); K=numel(blocks.items);
if nargin<3, indices=1:K; end
items=blocks.items(indices); res=struct('status',"insufficient-blocks", ...
    'warnings',strings(0,1),'Npair_core',NaN,'Tcore',sum([items.exposure]), ...
    'Cpair',NaN,'Npair_fulltime',NaN,'Fdomain',NaN,'Fwindow',NaN, ...
    'etaB_apparent',NaN,'etaB_given_A',NaN,'truth_Nrec',NaN,'folds',{{}}, ...
    'validation_score',NaN,'T',blocks.T,'options',o,'blockCount',numel(items), ...
    'rateA',sum([items.countA])/sum([items.exposure]), ...
    'rateB',sum([items.countB])/sum([items.stop]-[items.start]));
if numel(items)<o.minBlocks
    res.warnings(end+1)="too-few-time-blocks";
end
if o.crossFit && (nnz(mod(indices,2)==0)<2 || nnz(mod(indices,2)==1)<2), return; end
if ~o.crossFit, res.warnings(end+1)="in-sample-response-no-independent-validation"; end
nfold=1+double(o.crossFit); N=0; weightedF=0; weightedW=0; score=0; boundary=false;
for fold=1:nfold
    if o.crossFit
        train=mod(indices,2)==mod(fold,2); evaluation=~train;
    else
        train=true(size(indices)); evaluation=train;
    end
    t=items(train); v=items(evaluation);
    dt=[t.delta]; dv=[v.delta];
    bg=struct('intercept',sum([t.background]),'slope',0);
    f=fitTimeResponse(dt,sum([t.exposure]),bg,o);
    if ~f.valid, res.status=f.status; return; end
    vo=o; vo.background=struct('intercept',sum([v.background]),'slope',0);
    r=inferPairsUnbinned(dv,sum([v.exposure]),0,0,f,vo);
    if ~isfinite(r.N), res.status=r.status; return; end
    predictedN=f.N/f.exposure*r.Teff;
    predictiveScore=evaluateCompositeLikelihood(dv,f.model,vo.background,o.domain,predictedN);
    res.folds{fold}=struct('fit',f,'evaluation',r,'predictiveLogLik',predictiveScore, ...
        'trainingBlocks',indices(train),'evaluationBlocks',indices(evaluation));
    N=N+r.N; weightedF=weightedF+r.Fdomain*r.Teff;
    weightedW=weightedW+r.Fwindow*r.Teff; score=score+predictiveScore;
    boundary=boundary || r.status=="boundary-fit";
    res.warnings=[res.warnings;r.warnings];
    if ~f.identifiable, res.warnings(end+1)="unidentifiable-response"; end
end
res.Npair_core=N; res.Cpair=N/res.Tcore; res.Npair_fulltime=res.Cpair*blocks.T;
res.Fdomain=weightedF/res.Tcore; res.Fwindow=weightedW/res.Tcore;
res.validation_score=score; res.etaB_apparent=res.Cpair/res.rateA;
if isfinite(o.heraldBackgroundRate)
    denominator=res.rateA-o.heraldBackgroundRate;
    if denominator>0, res.etaB_given_A=res.Cpair/denominator;
    else, res.warnings(end+1)="nonpositive-herald-signal-rate"; end
else
    res.warnings(end+1)="unknown-herald-background-apparent-efficiency-only";
end
rates=[items.rateA];
if numel(rates)>1 && std(rates)>max(.1*mean(rates),3*sqrt(mean(rates)/mean([items.exposure])))
    res.warnings(end+1)="rate-drift-check-block-sensitivity";
end
res.warnings=unique(res.warnings,'stable'); res.status="ok";
if boundary, res.status="boundary-fit"; end
if any(res.warnings=="tail-extrapolation-risk"), res.status="tail-risk"; end
if any(res.warnings=="unidentifiable-response"), res.status="unidentifiable-response"; end
end
