function fit = fitUnbinnedCoincidence(tA,tB,T,p,window,plotEdges)
%FITUNBINNEDCOINCIDENCE Gaussian/双 Gaussian 联合面积-背景复合似然点估计。
%   改编自用户提供的 analyze_real_spdc_1_mult.m（V4）。接口使用 SI 秒，
%   原求解器内部使用 ns；全部 all-pairs 时间差落盘，形状使用均匀子样本。
%   不读 pairID，不执行 Bootstrap、拟合 Bootstrap 或 Hessian 标准误。
%   原文件 SHA256: 57141378307552259FAE0F321D7320C69D3E394FCCB2565445B3FE2C3E5B8331
j=p.jointFit;
opts=struct('initialSigmaNs',j.initialSigma*1e9,'minIRFSigmaNs',j.minSigma*1e9, ...
    'maxTailSigmaNs',j.maxTailSigma*1e9,'blockSeconds',j.blockSize, ...
    'maxShapeFitPairs',j.maxShapeFitPairs,'streamChunkPairs',j.streamChunkPairs, ...
    'sampleSeed',j.seed,'scratchFolder',tempdir,'verbose',false, ...
    'referenceIncludeUpper',window.includeUpperEdge);
range=p.algorithm.histRange*1e9; win=[window.lowerEdge window.upperEdge]*1e9;
if T<=2*max(abs(range))*1e-9
    error('CoincidenceSim:JointFitRange','采集时长须明显大于时间差搜索范围。');
end
if win(1)<range(1)-64*eps(max(1,abs(range(1)))) || ...
        win(2)>range(2)+64*eps(max(1,abs(range(2))))
    error('CoincidenceSim:JointFitWindow','所选符合窗超出时间谱搜索范围，请扩大时间谱范围。');
end
blocks=localMakeBlocks(tA,tB,T,opts.blockSeconds);
bl=blocks.NA.*blocks.NB./blocks.duration*1e-9;
% 平台为保持 bin 宽可能将最后一条显示边界延至搜索区外；拟合诊断仅积分 Ω。
edges=unique([range(1),max(range(1),min(range(2),plotEdges(:)'*1e9)),range(2)]);
[store,anchor,counts]=localEnumerateToDisk(tA,tB,range,blocks,edges,opts);
cleanup=onCleanup(@()localRemoveLagStore(store));
if store.total<30
    error('CoincidenceSim:JointFitInsufficient','搜索范围内候选事件对不足 30，未执行联合拟合。');
end
centers=(edges(1:end-1)+edges(2:end))/2;
[~,peakIndex]=max(counts-sum(bl)*diff(edges)); peak0=centers(peakIndex);
models=struct(); predicted=nan(numel(counts),2);
names=["gaussian","doublegaussian"];
raw=localCountWindowStore(store,win,opts);
for k=1:2
    name=names(k);
    m=localAnalyzeModelStore(store,bl,blocks,T,range,peak0,opts,char(name));
    m.valid=isfinite(m.Npair) && isfinite(m.background) && m.displayShape.valid;
    m.referenceWindowRaw=raw; m.referenceWindowAcc=NaN;
    m.referenceWindowNet=NaN; m.referenceWindowCapture=NaN;
    m.referenceWindowCaptureCorrected=NaN;
    if m.valid
        m.referenceWindowAcc=m.background*diff(win);
        m.referenceWindowNet=raw-m.referenceWindowAcc; % 不截断负数。
        m.referenceWindowCapture=localMass(m.displayShape,win(1),win(2));
        if m.referenceWindowCapture>0
            m.referenceWindowCaptureCorrected=m.referenceWindowNet/m.referenceWindowCapture;
        end
        predicted(:,k)=(m.background*diff(edges)+m.Npair* ...
            localMass(m.displayShape,edges(1:end-1),edges(2:end)))';
    end
    models.(name)=m;
end
chosen=j.primaryModel;
if chosen=="doublegaussian" && ~models.(chosen).valid && models.gaussian.valid
    chosen="gaussian";
end
selected=models.(chosen); status=string(selected.status);
if chosen~=j.primaryModel, status=status+"|fallback-to-gaussian"; end
fit=struct('valid',selected.valid,'status',status,'primaryModel',chosen,'models',models, ...
    'candidatePairs',store.total,'anchorChannel',string(anchor), ...
    'theoryBackgroundPerNs',sum(bl),'windowRaw',raw);
index=find(names==chosen,1);
fit.histogram=table(centers(:)*1e-9,counts(:),predicted(:,1),predicted(:,2), ...
    counts(:)-predicted(:,index),'VariableNames',{'TimeDifference_s','ObservedCounts', ...
    'GaussianExpectedCounts','DoubleGaussianExpectedCounts','SelectedResidualCounts'});
fit.histogram.BinLower_s=edges(1:end-1)'*1e-9;
fit.histogram.BinUpper_s=edges(2:end)'*1e-9;
end

function blocks=localMakeBlocks(tA,tB,T,blockSeconds)
M=ceil(T/blockSeconds);
if M>1e5, error('SPDC:Blocks','Too many blocks; increase blockSeconds.'); end
starts=(0:M-1)'*blockSeconds;
durations=min(blockSeconds,T-starts);
idsA=min(M,1+floor(tA/blockSeconds));
idsB=min(M,1+floor(tB/blockSeconds));
nA=accumarray(idsA(:),1,[M 1],@sum,0);
nB=accumarray(idsB(:),1,[M 1],@sum,0);
blocks=struct('M',M,'blockSeconds',blockSeconds,'duration',durations, ...
    'NA',nA,'NB',nB);
end

function [store,anchor,hCounts]=localEnumerateToDisk(a,b,rangeNs,blocks,plotEdges,opts)
% Exact all-pairs enumeration. Alternate time-block folds are streamed to
% disk; nothing is sampled/discarded in this enumeration.
lo=rangeNs(1)*1e-9; hi=rangeNs(2)*1e-9;
if numel(a)<=numel(b)
    anchors=a; other=b; anchor='A'; wLo=lo; wHi=hi; orient=1;
else
    anchors=b; other=a; anchor='B'; wLo=-hi; wHi=-lo; orient=-1;
end
root=tempname(opts.scratchFolder);
store=struct('files',{{[root '_odd.bin'],[root '_even.bin']}}, ...
    'counts',[0 0],'total',0);
fids=[-1 -1];
try
    for f=1:2
        fids(f)=fopen(store.files{f},'wb');
        if fids(f)<0, error('SPDC:Scratch','Cannot create scratch file %s',store.files{f}); end
    end
    chunk=max(1000,round(opts.streamChunkPairs));
    buffers={zeros(chunk,1),zeros(chunk,1)};
    filled=[0 0];
    hCounts=zeros(1,numel(plotEdges)-1);
    left=1; right=0; nOther=numel(other);
    step=max(1,floor(numel(anchors)/10));
    for k=1:numel(anchors)
        t=anchors(k);
        while left<=nOther && other(left)<t+wLo, left=left+1; end
        right=max(right,left-1);
        while right<nOther && other(right+1)<=t+wHi, right=right+1; end
        n=max(0,right-left+1);
        if n==0, continue; end
        blockId=min(blocks.M,1+floor(t/blocks.blockSeconds));
        fold=1+double(mod(blockId,2)==0); % 1=odd, 2=even
        if orient==1, deltas=(other(left:right)-t)*1e9;
        else, deltas=(t-other(left:right))*1e9;
        end
        deltas=deltas(:);
        at=1;
        while at<=n
            take=min(n-at+1,chunk-filled(fold));
            idx=filled(fold)+(1:take);
            buffers{fold}(idx)=deltas(at:at+take-1);
            filled(fold)=filled(fold)+take; at=at+take;
            if filled(fold)==chunk
                v=buffers{fold};
                count=fwrite(fids(fold),v,'double');
                if count~=chunk, error('SPDC:DiskFull','Scratch write incomplete: disk full?'); end
                hCounts=hCounts+histcounts(v,plotEdges);
                store.counts(fold)=store.counts(fold)+chunk;
                filled(fold)=0;
            end
        end
        if opts.verbose && mod(k,step)==0
            fprintf('[SPDC] scanned %.0f/%.0f anchor events, stored %.0f lag pairs\n', ...
                k,numel(anchors),sum(store.counts)+sum(filled));
        end
    end
    for f=1:2
        if filled(f)>0
            v=buffers{f}(1:filled(f));
            count=fwrite(fids(f),v,'double');
            if count~=filled(f), error('SPDC:DiskFull','Scratch write incomplete: disk full?'); end
            hCounts=hCounts+histcounts(v,plotEdges);
            store.counts(f)=store.counts(f)+filled(f);
        end
    end
    store.total=sum(store.counts);
    for f=1:2, fclose(fids(f)); fids(f)=-1; end
catch ME
    for f=1:2, if fids(f)>=0, fclose(fids(f)); end, end
    localRemoveLagStore(store);
    rethrow(ME);
end
end

function localRemoveLagStore(store)
for k=1:numel(store.files)
    try
        if exist(store.files{k},'file'), delete(store.files{k}); end
    catch
        warning('SPDC:ScratchCleanup','Could not delete scratch file %s',store.files{k});
    end
end
end

function data=localSampleLagFile(file,nAll,nTake,chunk)
% Uniform random lag selection, drawn WITHOUT using a lag histogram.
nTake=min(nAll,max(0,round(nTake)));
if nTake==0, data=zeros(0,1); return; end
idx=sort(randperm(nAll,nTake));
data=zeros(nTake,1);
fid=fopen(file,'rb');
if fid<0, error('SPDC:ScratchRead','Cannot read %s',file); end
closer=onCleanup(@()fclose(fid));
count=0; seen=0; ptr=1;
while seen<nAll
    vec=fread(fid,min(chunk,nAll-seen),'double=>double');
    n=numel(vec);
    if n==0, error('SPDC:ScratchRead','Unexpected EOF in %s',file); end
    first=ptr;
    while ptr<=nTake && idx(ptr)<=seen+n, ptr=ptr+1; end
    if ptr>first
        positions=idx(first:ptr-1)-seen;
        data(first:ptr-1)=vec(positions);
        count=count+numel(positions);
    end
    seen=seen+n;
end
if count~=nTake, error('SPDC:ScratchRead','Sample count inconsistent'); end
end

function out=localAnalyzeModelStore(store,bl,blocks,T,range,mu0,opts,kind)
% For shape parameters, optimize an unbinned Gaussian+uniform mixture on a
% uniform subset of lag pairs. For each fixed fitted shape, PROFILE the
% likelihood in (N,b) on EVERY original lag pair (streamed from disk).
% The full-data profiled (N,b) pair is the PRIMARY estimate. Alternating
% time-block fits remain a useful independent-shape stability diagnostic.
M=blocks.M; bTheory=sum(bl);
counts=store.counts;
rngState=rng;
rngCleaner=onCleanup(@()rng(rngState));
rng(opts.sampleSeed,'twister');
samples=cell(1,2);
for f=1:2
    nTarget=min(counts(f),ceil(opts.maxShapeFitPairs*counts(f)/max(1,store.total)));
    samples{f}=localSampleLagFile(store.files{f},counts(f),nTarget,opts.streamChunkPairs);
end
out=localNoCrossFit(struct(),'crossfit_unavailable');
if M>=4 && all(counts>=40)
    odd=mod((1:M)',2)==1;
    bOdd=sum(bl(odd)); bEven=sum(bl(~odd));
    sOdd=localFitShape(samples{1},bOdd,range,mu0,opts,kind,counts(1));
    sEven=localFitShape(samples{2},bEven,range,mu0,opts,kind,counts(2));
    if opts.verbose
        fprintf('[SPDC] %s folds: odd(valid=%d exit=%g %s), even(valid=%d exit=%g %s)\n', ...
            kind,sOdd.valid,localFitFlag(sOdd),localFitMethod(sOdd), ...
            sEven.valid,localFitFlag(sEven),localFitMethod(sEven));
    end
    if sOdd.valid && sEven.valid
        % Evaluate amplitudes and baselines on held-out folds, for fixed
        % shapes obtained from opposite folds. Both estimated jointly.
        estEven=localAreaStore(store.files{2},counts(2),bEven,range,sOdd,opts.streamChunkPairs);
        estOdd=localAreaStore(store.files{1},counts(1),bOdd,range,sEven,opts.streamChunkPairs);
        out.Npair_crossfit=estEven.N+estOdd.N;
        out.background_crossfit=estEven.b+estOdd.b;
        out.heldOutScore=estEven.logLikelihoodRatio+estOdd.logLikelihoodRatio;
        out.foldArea=[estOdd.N,estEven.N];
        out.foldBaseline=[estOdd.b,estEven.b];
        out.foldShape=[sOdd,sEven];
        out.crossFitted=all(isfinite([estOdd.N,estEven.N,estOdd.b,estEven.b]));
        if out.crossFitted
            out.status='crossfit_ok';
            if localFitFlag(sOdd)<=0 || localFitFlag(sEven)<=0
                out.status='crossfit_optimizer_limit_or_fallback';
            end
        else
            out.status='crossfit_profile_failed';
        end
    else
        out.status='crossfit_shape_failed';
    end
elseif M<4
    out.status='fewer_than_four_blocks';
else
    out.status='insufficient_events_per_fold';
end
sampleAll=[samples{1};samples{2}];
fullShape=localFitShape(sampleAll,bTheory,range,mu0,opts,kind,store.total);
out.fullShape=fullShape;
if ~fullShape.valid
    if out.crossFitted
        out.displayShape=out.foldShape(1);
        out.status=[out.status '|full_shape_fallback_to_fold'];
    else
        out.displayShape=localEmergencyShape(mu0,opts.initialSigmaNs,kind);
    end
else
    out.displayShape=fullShape;
    if isfield(fullShape,'fitMethod') && contains(fullShape.fitMethod,'fallback')
        out.status=[out.status '|shape_EM_fallback'];
    elseif isfield(fullShape,'fitExitFlag') && fullShape.fitExitFlag==0
        out.status=[out.status '|shape_optimizer_budget_limited'];
    end
end
% Full data: (N, b) BOTH obtained from the same unbinned profile likelihood.
inSample=localAreaTwoFiles(store,bTheory,range,out.displayShape,opts.streamChunkPairs);
out.inSampleArea=inSample.N;
out.inSampleBackground=inSample.b;
out.Npair=inSample.N;
out.background=inSample.b;
out.logLikelihoodRatio=inSample.logLikelihoodRatio;
out.profileSignalFraction=inSample.signalFraction;
out.profileConverged=inSample.converged;
out.profileIterations=inSample.iterations;
out.profileScore=inSample.score;
out.totalCountClosure=inSample.predictedTotal-store.total;
out.shapeSamplePairs=numel(sampleAll);
out.shapeSampleFraction=numel(sampleAll)/store.total;
out.backgroundTheory=bTheory;
if ~isfinite(inSample.N) || ~isfinite(inSample.b)
    out.Npair=NaN; out.background=NaN;
    out.status=[out.status '|joint_profile_failed'];
else
    out.status=[out.status '|joint_N_b_profiled_full_data'];
    if ~inSample.converged
        out.status=[out.status '|joint_profile_not_converged'];
    end
end
out.lagCaptureMass=localMass(out.displayShape,range(1),range(2));
out.model=kind; out.duration=T;
end

function est=localAreaTwoFiles(store,b,range,shape,chunk)
% Combine two folds without introducing any subsampling into area estimate.
files=store.files;
est=localAreaGeneric(files,store.total,b,range,shape,chunk);
end

function est=localAreaStore(file,nAll,b,range,shape,chunk)
est=localAreaGeneric({file},nAll,b,range,shape,chunk);
end

function est=localAreaGeneric(files,nAll,bPrior,range,shape,chunk)
% Exactly optimize both N and b (for FIXED time-response shape), streaming
% ALL original unbinned candidate delays. Conditional mixture parameter:
%    p = N*F/M;  b = (1-p)*M/L,   F=int_range f(t)dt, L=range width.
% Extended Poisson composite log-likelihood:
%    ell = sum log(N*f(x_i)+b) - N*F - b*L.
% At optimum N*F+b*L=M. The profile for p is strictly concave:
%    ell(p)-ell(p=0) = sum log(1+p*(L*f(x_i)/F-1)).
% Sampled lag histograms are NEVER used in this calculation.
L=diff(range);
blank=struct('N',NaN,'b',NaN,'signalFraction',NaN, ...
    'logLikelihoodRatio',NaN,'predictedTotal',NaN,'score',NaN, ...
    'iterations',0,'converged',false);
est=blank;
if ~shape.valid || L<=0 || nAll<1
    return
end
F=localMass(shape,range(1),range(2));
if ~isfinite(F) || F<=0, return; end
pLow=0; pHigh=1-1e-10;
if ~isfinite(bPrior) || bPrior<=0
    p=0.25;
else
    p=max(1e-6,min(0.98,(nAll-bPrior*L)/nAll));
end
[sLow,~]=localJointScoreFiles(files,0,shape,L,F,chunk);
if sLow<=0
    p=0;
    converged=true;
    lastScore=sLow;
    iter=0;
else
    [sHigh,~]=localJointScoreFiles(files,pHigh,shape,L,F,chunk);
    if sHigh>=0
        p=pHigh;
        converged=true;
        lastScore=sHigh;
        iter=0;
    else
        converged=false;
        for iter=1:45
            [score,curv]=localJointScoreFiles(files,p,shape,L,F,chunk);
            lastScore=score;
            if score>0, pLow=p; else, pHigh=p; end
            if abs(score)<max(1e-6,5e-9*nAll)
                converged=true; break;
            end
            next=p-score/curv;
            if ~isfinite(next) || next<=pLow || next>=pHigh
                next=(pLow+pHigh)/2;
            end
            if abs(next-p)<3e-10
                p=next;
                converged=true; break;
            end
            p=next;
        end
    end
end
N=p*nAll/F;
b=(1-p)*nAll/L;
ll=localJointLogRatioFiles(files,p,shape,L,F,chunk);
est=struct('N',N,'b',b,'signalFraction',p, ...
    'logLikelihoodRatio',ll,'predictedTotal',N*F+b*L, ...
    'score',lastScore,'iterations',iter,'converged',converged);
end

function [score,curv]=localJointScoreFiles(files,p,shape,L,F,chunk)
score=0; curv=0;
for k=1:numel(files)
    fid=fopen(files{k},'rb');
    if fid<0, error('SPDC:ScratchRead','Cannot read %s',files{k}); end
    cleaner=onCleanup(@()fclose(fid));
    while true
        x=fread(fid,chunk,'double=>double');
        if isempty(x), break; end
        f=localIRF(x,shape,[-Inf Inf]);
        d=(L/F)*f-1;
        v=d./(1+p*d);
        score=score+sum(v);
        curv=curv-sum(v.^2);
    end
    clear cleaner;
end
end

function ll=localJointLogRatioFiles(files,p,shape,L,F,chunk)
ll=0;
if p==0, return; end
for k=1:numel(files)
    fid=fopen(files{k},'rb');
    if fid<0, error('SPDC:ScratchRead','Cannot read %s',files{k}); end
    cleaner=onCleanup(@()fclose(fid));
    while true
        x=fread(fid,chunk,'double=>double');
        if isempty(x), break; end
        f=localIRF(x,shape,[-Inf Inf]);
        ll=ll+sum(log1p(p*((L/F)*f-1)));
    end
    clear cleaner;
end
end

function n=localCountWindowStore(store,win,opts)
n=0;
for k=1:numel(store.files)
    fid=fopen(store.files{k},'rb');
    if fid<0, error('SPDC:ScratchRead','Cannot read %s',store.files{k}); end
    cleaner=onCleanup(@()fclose(fid));
    while true
        x=fread(fid,opts.streamChunkPairs,'double=>double');
        if isempty(x), break; end
        n=n+nnz(x>=win(1) & (x<win(2) | (opts.referenceIncludeUpper & x==win(2))));
    end
    clear cleaner;
end
end

function out=localNoCrossFit(~,why)
out=struct('Npair',NaN,'Npair_crossfit',NaN, ...
    'background_crossfit',NaN,'heldOutScore',NaN, ...
    'foldArea',[NaN NaN],'foldBaseline',[NaN NaN], ...
    'foldShape',[],'crossFitted',false,'status',why);
end

function sh=localEmergencyShape(mu,sig,kind)
sh=struct('kind',kind,'mu',mu,'sigma1',max(sig,0.02), ...
    'sigma2',max(1.8*sig,0.05),'alpha',0, 'delta',0,'valid',false);
end

function shape=localFitShape(dt,bPrior,range,initMu,opts,kind,nAllOverride)
% Fit shape and signal+background mixture weight JOINTLY on random, UNBINNED
% lag samples. The observed count total determines the likelihood scale.
% The final full-resolution N and b are reprofiled on ALL raw lag pairs.
if nargin<7 || isempty(nAllOverride), nAll=numel(dt); else, nAll=nAllOverride; end
shape=localEmergencyShape(initMu,opts.initialSigmaNs,kind);
shape.fitExitFlag=NaN; shape.fitMethod='none'; shape.fitError='';
shape.fitObjective=NaN; shape.bTrain=NaN; shape.signalFraction=NaN;
if nAll<30, shape.fitError='insufficient lag pairs'; return; end
sample=dt(:);
if isempty(sample), shape.fitError='empty lag sample'; return; end
width=diff(range);
coreMin=opts.minIRFSigmaNs;
coreMax=min(width/3,max(opts.initialSigmaNs*8,0.4));
if coreMax<=coreMin, coreMax=coreMin*1.5; end
tailMax=min(width/2,max(coreMax+0.1,opts.maxTailSigmaNs));
centerRange=min(0.35*width,max(2,6*opts.initialSigmaNs));
shiftRange=min(width/3,max(1.5,5*opts.initialSigmaNs));
coreStart=min(max(opts.initialSigmaNs,coreMin*1.01),coreMax*.95);
logit=@(p)log(p/(1-p));
logsig=logit(min(.98,max(.02,(coreStart-coreMin)/(coreMax-coreMin))));
if ~isfinite(bPrior) || bPrior<=0
    pInit=.25;
else
    pInit=max(.01,min(.98,(nAll-bPrior*width)/nAll));
end
if strcmp(kind,'gaussian')
    z0=[0,logsig,logit(pInit)];
else
    tailStart=min(tailMax*.95,max(coreStart*1.8,coreStart+.08));
    tRatio=(tailStart-coreStart)/(tailMax-coreStart);
    z0=[0,logsig,logit(min(.98,max(.02,tRatio))),logit(.13),0,logit(pInit)];
end
options=optimset('Display','off','MaxIter',1700,'MaxFunEvals',7500, ...
    'TolX',2e-6,'TolFun',1e-5);
try
    [z,val,flag,output]=fminsearch(@obj,z0,options);
    cand=decode(z);
    cand.fitExitFlag=flag;
    cand.fitMethod='fminsearch_joint_mixture';
    cand.fitError='';
    cand.fitObjective=val;
    cand.fitIterations=output.iterations;
    cand.valid=(flag>=0) && all(isfinite(struct2array_local(cand))) && ...
        isfinite(val) && val<0 && cand.Ntrain>0 && cand.bTrain>0 && ...
        cand.sigma1>=coreMin && cand.sigma1<=coreMax && ...
        cand.mu>=range(1) && cand.mu<=range(2);
    if strcmp(kind,'doublegaussian')
        cand.valid=cand.valid && cand.sigma2>=cand.sigma1 && ...
            cand.sigma2<=tailMax && cand.alpha>=0 && cand.alpha<1;
    end
    if cand.valid
        shape=cand;
        if flag<=0, shape.fitMethod='fminsearch_joint_budget_limited'; end
    else
        shape.fitError=sprintf('joint-shape fit invalid/no gain (exit=%g, obj=%g)',flag,val);
        shape.fitExitFlag=flag; shape.fitObjective=val;
    end
catch ME
    shape.fitError=sprintf('%s: %s',ME.identifier,ME.message);
end
if ~shape.valid && strcmp(kind,'gaussian')
    try
        em=localGaussianEMJointFallback(sample,nAll,range,initMu, ...
            coreStart,coreMin,coreMax,centerRange,pInit);
        if em.valid
            shape=em;
        elseif isempty(shape.fitError)
            shape.fitError=em.fitError;
        end
    catch ME
        shape.fitError=[shape.fitError ' | joint EM: ' ME.message];
    end
end
    function loss=obj(z)
        if any(~isfinite(z)) || any(abs(z)>35)
            loss=1e50; return;
        end
        m=decode(z);
        [ff,FF]=localIRF(sample,m,range);
        if ~isfinite(FF) || FF<=0 || any(~isfinite(ff))
            loss=1e50; return;
        end
        q=(1-m.signalFraction)+m.signalFraction*width*(ff/FF);
        if any(q<=0) || any(~isfinite(q)), loss=1e50; return; end
        loss=-sum(log(q));
        if ~isfinite(loss), loss=1e50; end
    end
    function m=decode(z)
        invlogit=@(v)1/(1+exp(-v));
        m=struct(); m.kind=kind;
        m.mu=initMu+centerRange*tanh(z(1));
        m.sigma1=coreMin+(coreMax-coreMin)*invlogit(z(2));
        if strcmp(kind,'gaussian')
            m.sigma2=NaN; m.alpha=0; m.delta=0;
            m.signalFraction=invlogit(z(3));
        else
            m.sigma2=m.sigma1+(tailMax-m.sigma1)*invlogit(z(3));
            m.alpha=0.65*invlogit(z(4));
            m.delta=shiftRange*tanh(z(5));
            m.signalFraction=invlogit(z(6));
        end
        F=localMass(m,range(1),range(2));
        m.Ntrain=m.signalFraction*nAll/max(realmin,F);
        m.bTrain=(1-m.signalFraction)*nAll/width;
    end
end

function em=localGaussianEMJointFallback(sample,nAll,range,initMu, ...
    sigma0,sigmaMin,sigmaMax,centerRange,p0)
% Gaussian+uniform mixture EM using individual continuous event differences.
% Neglect boundary truncation in moment updates only if peak is far from edge.
L=diff(range);
mu=initMu; sig=sigma0; p=max(1e-6,min(.99,p0));
em=localEmergencyShape(mu,sig,'gaussian');
em.fitExitFlag=-2; em.fitMethod='gaussian_EM_joint_fallback';
em.fitError=''; em.fitObjective=NaN;
for iter=1:300
    F=localGaussianCDF(range(2),mu,sig)-localGaussianCDF(range(1),mu,sig);
    g=localGaussian(sample,mu,sig)/max(realmin,F);
    signal=p*g;
    resp=signal./max(signal+(1-p)/L,realmin);
    sr=sum(resp);
    if ~isfinite(sr) || sr<10
        em.fitError='Joint EM insufficient inferred signal'; return;
    end
    pNew=min(.999999,max(1e-8,sr/numel(sample)));
    muNew=sum(resp.*sample)/sr;
    muNew=min(initMu+centerRange,max(initMu-centerRange,muNew));
    sigNew=sqrt(sum(resp.*(sample-muNew).^2)/sr);
    sigNew=min(sigmaMax,max(sigmaMin,sigNew));
    if abs(pNew-p)<1e-9 && abs(muNew-mu)<1e-7 && abs(sigNew-sig)<1e-7
        p=pNew; mu=muNew; sig=sigNew; break;
    end
    p=pNew; mu=muNew; sig=sigNew;
end
if min(mu-range(1),range(2)-mu)<3*sig
    em.fitError='Gaussian joint EM peak too close to lag boundary'; return;
end
em.kind='gaussian'; em.mu=mu; em.sigma1=sig;
em.sigma2=NaN; em.alpha=0; em.delta=0;
em.signalFraction=p;
F=localGaussianCDF(range(2),mu,sig)-localGaussianCDF(range(1),mu,sig);
em.Ntrain=p*nAll/F;
em.bTrain=(1-p)*nAll/L;
em.fitIterations=iter;
f=localGaussian(sample,mu,sig);
q=(1-p)+p*L*f/F;
em.fitObjective=-sum(log(q));
em.valid=isfinite(em.fitObjective) && em.fitObjective<0 && ...
    isfinite(em.Ntrain) && isfinite(em.bTrain) && em.bTrain>0;
if ~em.valid, em.fitError='Joint EM found no positive peak evidence'; end
end

function flag=localFitFlag(shape)
flag=NaN;
if isfield(shape,'fitExitFlag'), flag=shape.fitExitFlag; end
end

function method=localFitMethod(shape)
method='unknown';
if isfield(shape,'fitMethod'), method=shape.fitMethod; end
end

function x=struct2array_local(m)
x=[m.mu,m.sigma1,m.alpha,m.delta,m.Ntrain];
if strcmp(m.kind,'doublegaussian'), x=[x,m.sigma2]; end
end

function [f,F]=localIRF(t,m,range)
f=localGaussian(t,m.mu,m.sigma1);
F=localGaussianCDF(range(2),m.mu,m.sigma1) - ...
  localGaussianCDF(range(1),m.mu,m.sigma1);
if strcmp(m.kind,'doublegaussian')
    f=(1-m.alpha)*f+m.alpha*localGaussian(t,m.mu+m.delta,m.sigma2);
    F=(1-m.alpha)*F+m.alpha*( ...
        localGaussianCDF(range(2),m.mu+m.delta,m.sigma2) - ...
        localGaussianCDF(range(1),m.mu+m.delta,m.sigma2));
end
end

function F=localMass(m,lo,hi)
F=localGaussianCDF(hi,m.mu,m.sigma1) - ...
    localGaussianCDF(lo,m.mu,m.sigma1);
if strcmp(m.kind,'doublegaussian')
    F=(1-m.alpha)*F + m.alpha*( ...
        localGaussianCDF(hi,m.mu+m.delta,m.sigma2) - ...
        localGaussianCDF(lo,m.mu+m.delta,m.sigma2));
end
F=max(0,min(1,F));
end

function f=localGaussian(t,mu,sigma)
f=exp(-0.5*((t-mu)/sigma).^2)/(sqrt(2*pi)*sigma);
end

function F=localGaussianCDF(t,mu,sigma)
F=0.5*erfc(-(t-mu)/(sqrt(2)*sigma));
end

