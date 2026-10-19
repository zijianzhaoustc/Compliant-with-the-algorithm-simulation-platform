function validation = validateAdaptiveSelection(A,B,matches,p,dataMode)
%VALIDATEADAPTIVESELECTION 交替时间块选参/评价，不拼接后重新匹配。
% 完整匹配按 A 时间分块，保留跨边界对；两组仅压缩曝光时间坐标。
T=p.measurementTime;
if p.uncertainty.blockMode=="auto", M=max(30,ceil(T));
else, M=max(1,ceil(T/p.uncertainty.blockSize)); end
validation=struct('valid',false,'status',"insufficient-validation-blocks", ...
    'summary',table(),'trainingOptimization',[], ...
    'scope',"alternating A-anchored time blocks; fixed training parameters on held-out data");
if M<4 || M>1e6, return; end
dt=T/M;
block=@(time) min(M,max(1,floor(time(:)/dt)+1));
anchor=block(A.time(matches.indexA));
groups=cell(2,1);
for group=1:2
    selectedBlocks=(group:2:M)'; n=numel(selectedBlocks);
    rank=zeros(M,1); rank(selectedBlocks)=1:n;
    aBlock=block(A.time); bBlock=block(B.time);
    aMask=rank(aBlock)>0; bMask=rank(bBlock)>0;
    a=A; b=B;
    a.time=A.time(aMask)-(aBlock(aMask)-1)*dt+(rank(aBlock(aMask))-1)*dt;
    b.time=B.time(bMask)-(bBlock(bMask)-1)*dt+(rank(bBlock(bMask))-1)*dt;
    a.pairID=A.pairID(aMask); a.type=A.type(aMask);
    b.pairID=B.pairID(bMask); b.type=B.type(bMask);
    map=zeros(numel(A.time),1); map(aMask)=1:nnz(aMask);
    mask=rank(anchor)>0;
    % 后续仅使用 deltaT、A 索引及事后真值；不保留无意义的 B 子数组索引。
    matched=struct('deltaT',matches.deltaT(mask),'indexA',map(matches.indexA(mask)), ...
        'isTrue',matches.isTrue(mask));
    groups{group}=struct('A',a,'B',b,'matches',matched,'duration',n*dt,'blocks',selectedBlocks);
end
train=groups{1}; test=groups{2}; q=p; q.measurementTime=train.duration;
q.uncertainty.blockMode="manual"; q.uncertainty.blockSize=dt;
q.optimization.validationMode="none"; q.algorithm.accidentalMethod="side-window";
o=optimizeCoincidenceParameters(train.A,train.B,train.matches,q,"imported");
validation.trainingOptimization=o;
validation.trainingBlocks=train.blocks; validation.evaluationBlocks=test.blocks;
validation.trainingDuration=train.duration; validation.evaluationDuration=test.duration;
if ~o.valid, validation.status="training-optimization-failed"; return; end
baseline=buildHistogram(train.matches,q);
baselineRaw=calculateRawCoincidence(train.matches,baseline,q);
g=q; g.algorithm.peakMethod="gaussian"; gaussian=buildHistogram(train.matches,g);
if ~any(isfinite(gaussian.fitCounts))
    validation.status="baseline-gaussian-fit-failed"; return
end
captureWidth=2*sqrt(2)*o.sigma*erfinv(q.optimization.targetCapture);
widths=[baselineRaw.window, ...
    2*sqrt(2)*gaussian.sigma*erfinv(q.optimization.targetCapture),captureWidth,o.window];
centers=[baseline.peak,gaussian.peak,o.peak,o.peak];
sigmas=[baseline.sigma,gaussian.sigma,o.sigma,o.sigma];
bins=[q.algorithm.binWidth,q.algorithm.binWidth,o.binWidth,o.binWidth];
methods=["A_fixed","B_peak-width","C_auto-bin-peak-width","D_constrained"];
rows=cell(4,1); validation.results=cell(4,1);
for k=1:4
    v=q; v.measurementTime=test.duration; v.algorithm.windowMode="fixed";
    if k==1, v.algorithm.windowMode=q.algorithm.windowMode; end
    v.algorithm.binWidth=bins(k); v.algorithm.window=widths(k);
    v.optimization.mode="manual"; v.analysis.sourceCount=NaN;
    if k==4, v.algorithm.sidebandGuard=o.sideGuard; end
    h=buildHistogram(test.matches,v); h.peak=centers(k); h.sigma=sigmas(k);
    h.fwhm=2*sqrt(2*log(2))*h.sigma; h.fitCounts(:)=NaN;
    raw=calculateRawCoincidence(test.matches,h,v); raw.matchesIsTrue=test.matches.isTrue;
    acc=estimateAccidentals(test.A,test.B,test.matches,h,v);
    m=calculateMetrics(test.A,test.B,test.matches,raw,acc,h,v,dataMode);
    evaluation=struct('params',v,'source',struct(),'A',test.A,'B',test.B, ...
        'matches',test.matches,'hist',h,'raw',raw,'acc',acc,'metrics',m,'dataMode',dataMode);
    uncertainty=calculateUncertainty(evaluation,true);
    validation.results{k}=struct('metrics',m,'uncertainty',uncertainty);
    us=NaN; ut=NaN; cis=[NaN NaN]; cit=cis;
    if ~isempty(uncertainty.bootstrap)
        bs=uncertainty.bootstrap; us=bs.standardUncertainty(4); ut=bs.standardUncertainty(5);
        cis=bs.CI(:,4)'; cit=bs.CI(:,5)';
    end
    capture=.5*(erf((raw.upperEdge-o.peak)/(sqrt(2)*o.sigma))- ...
        erf((raw.lowerEdge-o.peak)/(sqrt(2)*o.sigma)));
    rows{k}=table(methods(k),test.duration,bins(k),raw.window,centers(k),capture, ...
        m.Nraw,m.Nacc_side,m.Nacc_theory,m.Ncorr_side,m.Ncorr_theory,us,ut, ...
        cis(1),cis(2),cit(1),cit(2),m.TP,m.FP,m.EtaW, ...
        m.epsilon_acc_side,m.epsilon_acc_theory,m.epsilon_corr_side,m.epsilon_corr_theory, ...
        'VariableNames',{'Method','Duration_s','BinWidth_s','Window_s','Peak_s','CaptureEstimate','Nraw', ...
        'Nacc_side','Nacc_theory','Ncorr_side','Ncorr_theory','BootstrapU_side','BootstrapU_theory', ...
        'CI_side_lower','CI_side_upper','CI_theory_lower','CI_theory_upper','TP','FP','EtaW', ...
        'epsilon_acc_side','epsilon_acc_theory','epsilon_corr_side','epsilon_corr_theory'});
end
validation.summary=vertcat(rows{:}); validation.valid=true; validation.status="ok";
end
