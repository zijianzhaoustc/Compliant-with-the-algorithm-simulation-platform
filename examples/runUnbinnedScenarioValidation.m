function [summary,trials] = runUnbinnedScenarioValidation(folder,repeats,bootstrapCount)
%RUNUNBINNEDSCENARIOVALIDATION Independent raw-event controls, no legacy generator.
% Reports signed bias, RMSE and empirical coverage with explicit trial count.
if nargin<2, repeats=5; end
if nargin<3, bootstrapCount=31; end
validateattributes(repeats,{'numeric'},{'scalar','positive','integer'});
if ~isfolder(folder), mkdir(folder); end
scenarios=["independent","gaussian","doublegaussian","skew-misspecified", ...
    "high-rate","deadtime","afterpulse","deadtime-afterpulse"];
rows=cell(0,13); p=defaultParams(); p.measurementTime=4;
p.inference.blockSeconds=.2; p.inference.bootstrapCount=bootstrapCount;
p.inference.initialSigma=.3e-9; p.inference.maxIterations=600;
p.inference.exposureSource="known-control-gate";
for k=1:numel(scenarios)
    scenario=scenarios(k); p.inference.model="gaussian";
    if scenario=="doublegaussian", p.inference.model="doublegaussian"; end
    for r=1:repeats
        [A,B]=controlEvents(scenario,1000*k+r,p.measurementTime);
        tic; result=crossFitUnbinned(A,B,p); elapsed=toc;
        truth=result.truth_Nrec;
        if scenario=="independent", truth=0; end
        estimate=result.Npair_fulltime;
        ci=result.bootstrap.CI95(:,1)*p.measurementTime;
        bias=NaN; if truth>0, bias=(estimate-truth)/truth; end
        covered=NaN; if all(isfinite(ci)), covered=double(truth>=ci(1) && truth<=ci(2)); end
        rows(end+1,:)={scenario,r,p.inference.model,truth,estimate,bias, ...
            ci(1),ci(2),covered,result.Fwindow,result.status,result.bootstrap.failureCount,elapsed}; %#ok<AGROW>
        fprintf('%s trial %d: %s, truth=%g, estimate=%g\n',scenario,r,result.status,truth,estimate);
    end
end
trials=cell2table(rows,'VariableNames',{'scenario','trial','fitted_model','truth_Nrec', ...
    'estimated_Npair_fulltime','signed_relative_bias','CI95_low','CI95_high','covered', ...
    'Fwindow','status','failed_bootstrap_refits','elapsed_s'});
writeUtf8BomTable(trials,fullfile(folder,'scenario_trials.csv'));
summary=table();
for scenario=scenarios
    t=trials(trials.scenario==scenario,:); errorValue=t.estimated_Npair_fulltime-t.truth_Nrec;
    valid=isfinite(t.covered); finite=isfinite(t.estimated_Npair_fulltime);
    falsePeak=mean(t.estimated_Npair_fulltime(finite)>0);
    row=table(scenario,height(t),nnz(isfinite(errorValue)),mean(t.signed_relative_bias,'omitnan'), ...
        sqrt(mean(errorValue.^2,'omitnan')),nnz(valid),mean(t.covered(valid)),falsePeak, ...
        'VariableNames',{'scenario','trial_count','finite_estimates','mean_signed_relative_bias', ...
        'RMSE_counts','coverage_evaluable_trials','empirical_coverage','positive_area_fraction'});
    summary=[summary;row]; %#ok<AGROW>
end
writeUtf8BomTable(summary,fullfile(folder,'scenario_summary.csv'));
end
function [A,B]=controlEvents(scenario,seed,T)
s=RandStream('mt19937ar','Seed',seed); rate=400;
if scenario=="high-rate", rate=1600; end
if scenario=="independent"
    a=poissonEvents(s,5e4,T); b=poissonEvents(s,5e4,T);
    A=events(a,zeros(size(a))); B=events(b,zeros(size(b))); return
end
a=poissonEvents(s,rate,T); n=numel(a); u=rand(s,n,1);
d=.3e-9*sqrt(2)*erfinv(2*u-1);
if scenario=="doublegaussian"
    wide=rand(s,n,1)<.2;
    d(wide)=.7e-9+1.2e-9*sqrt(2)*erfinv(2*rand(s,nnz(wide),1)-1);
elseif scenario=="skew-misspecified"
    d=d-log(rand(s,n,1))*.8e-9;
end
b=a+d; ids=(1:n)';
noise=poissonEvents(s,100,T); A=events([a;noise],[ids;zeros(size(noise))]); A=sortEvents(A);
noise=poissonEvents(s,100,T); B=events([b;noise],[ids;zeros(size(noise))]); B=sortEvents(B);
if any(scenario==["afterpulse","deadtime-afterpulse"])
    mask=rand(s,numel(B.time),1)<.15;
    ap=B.time(mask)-log(rand(s,nnz(mask),1))*50e-9;
    B.time=[B.time;ap]; B.pairID=[B.pairID;zeros(size(ap))]; B=sortEvents(B);
end
if any(scenario==["deadtime","deadtime-afterpulse"])
    A=deadFilter(A,2e-4); B=deadFilter(B,2e-4);
end
A=trim(A,T); B=trim(B,T);
end
function t=poissonEvents(s,rate,T)
t=zeros(0,1); last=0;
while last<T
    batch=last+cumsum(-log(rand(s,max(100,ceil(rate*T)),1))/rate);
    t=[t;batch(batch<T)]; last=batch(end); %#ok<AGROW>
end
end
function e=events(t,id)
e=struct('time',t(:),'pairID',id(:));
end
function e=sortEvents(e)
[e.time,ix]=sort(e.time); e.pairID=e.pairID(ix);
end
function e=deadFilter(e,dead)
keep=false(size(e.time)); last=-Inf;
for i=1:numel(keep)
    if e.time(i)-last>=dead, keep(i)=true; last=e.time(i); end
end
e.time=e.time(keep); e.pairID=e.pairID(keep);
end
function e=trim(e,T)
keep=e.time>=0 & e.time<=T; e.time=e.time(keep); e.pairID=e.pairID(keep);
end
