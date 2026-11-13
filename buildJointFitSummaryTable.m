function summary = buildJointFitSummaryTable(fit,duration)
%BUILDJOINTFITSUMMARYTABLE 两个模型的点估计、实际窗口、诊断和仿真真值。
names=["gaussian";"doublegaussian"]; n=2;
selected=names==fit.primaryModel; valid=false(n,1); converged=false(n,1);
status=repmat(string(fit.status),n,1); data=nan(n,22);
data(:,15)=fit.truth.recordedPairs; data(:,16)=fit.truth.windowPairs;
shapeExitFlag=nan(n,1); shapeMethod=strings(n,1);
for k=1:n
    if ~isfield(fit.models,names(k)), continue; end
    m=fit.models.(names(k)); s=m.displayShape;
    valid(k)=m.valid; converged(k)=m.profileConverged; status(k)=string(m.status);
    if isfield(s,'fitExitFlag'), shapeExitFlag(k)=s.fitExitFlag; end
    if isfield(s,'fitMethod'), shapeMethod(k)=string(s.fitMethod); end
    gt=fit.truth.recordedPairs; tp=fit.truth.windowPairs;
    fp=m.referenceWindowRaw-tp;
    data(k,:)=[m.referenceWindowRaw,m.Npair,m.Npair_crossfit,m.Npair/duration, ...
        m.background,m.referenceWindowAcc,m.referenceWindowNet,m.referenceWindowCapture, ...
        m.referenceWindowCaptureCorrected,s.mu*1e-9,s.sigma1*1e-9,s.sigma2*1e-9, ...
        s.alpha,s.delta*1e-9,gt,tp,fp,relative(m.Npair,gt), ...
        relative(m.referenceWindowNet,tp),relative(m.referenceWindowAcc,fp), ...
        m.shapeSamplePairs,m.lagCaptureMass];
    if ~m.valid
        % 保留实测原始计数/真值；不把紧急初值当作拟合出的响应参数。
        data(k,10:14)=NaN;
    end
end
w=fit.window;
summary=table(names,selected,valid,converged,status,repmat(w.source,n,1), ...
    repmat(w.fallbackReason,n,1),repmat(w.lowerEdge,n,1),repmat(w.upperEdge,n,1), ...
    repmat(w.width,n,1),repmat(w.includeUpperEdge,n,1), ...
    'VariableNames',{'Model','Selected','Valid','Converged','Status','WindowSource', ...
    'WindowFallbackReason','WindowLower_s','WindowUpper_s','WindowWidth_s','IncludeUpperEdge'});
summary=[summary,array2table(data,'VariableNames', ...
    {'NrawWindow_AllPairs','NpairFull','NpairCrossfit','PairRate_Hz','Background_counts_per_ns', ...
    'NaccWindow','NnetWindow','CaptureFraction','NwindowCaptureCorrected', ...
    'PeakCoreCenter_s','CoreSigma_s','TailSigma_s','TailFraction','TailOffset_s', ...
    'NrecTruth','TrueWindowPairs','FalseWindowPairs','RelativeErrorFull', ...
    'RelativeErrorWindow','RelativeErrorAcc','ShapeFitPairs','LagRangeMass'})];
summary.NrawRate_Hz=summary.NrawWindow_AllPairs/duration;
summary.NaccRate_Hz=summary.NaccWindow/duration;
summary.NnetRate_Hz=summary.NnetWindow/duration;
summary.CoreFWHM_s=2*sqrt(2*log(2))*summary.CoreSigma_s;
summary.MixtureMean_s=summary.PeakCoreCenter_s+summary.TailFraction.*summary.TailOffset_s;
tailSigma=summary.TailSigma_s;
tailSigma(summary.TailFraction==0)=summary.CoreSigma_s(summary.TailFraction==0);
summary.MixtureSigma_s=sqrt((1-summary.TailFraction).*summary.CoreSigma_s.^2+ ...
    summary.TailFraction.*tailSigma.^2+ ...
    summary.TailFraction.*(1-summary.TailFraction).*summary.TailOffset_s.^2);
summary.CandidatePairs=repmat(optionalNumber(fit,'candidatePairs'),n,1);
summary.TheoryBackground_counts_per_ns=repmat(optionalNumber(fit,'theoryBackgroundPerNs'),n,1);
summary.BackgroundFitOverTheory=summary.Background_counts_per_ns./summary.TheoryBackground_counts_per_ns;
summary.BackgroundFitOverTheory(summary.TheoryBackground_counts_per_ns<=0)=NaN;
summary.ShapeFitExitFlag=shapeExitFlag; summary.ShapeFitMethod=shapeMethod;
summary.ErrorIdentifier=repmat(fit.errorIdentifier,n,1);
summary.Message=repmat(fit.message,n,1);
end

function value=optionalNumber(s,name)
value=NaN;
if isfield(s,name), value=s.(name); end
end

function value=relative(estimate,truth)
value=NaN;
if isfinite(truth) && truth>0, value=(estimate-truth)/truth; end
end
