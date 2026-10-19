function summary = buildBootstrapSummaryTable(out, result)
%BUILDBOOTSTRAPSUMMARYTABLE 可直接导入 Origin 的数值型统计汇总及追溯参数。
m=out.metrics; T=out.params.measurementTime; u=out.params.uncertainty;
names=["Nraw","Nacc_side","Nacc_theory","Ncorr_side","Ncorr_theory","NA","NB"];
point=[m.Nraw,m.Nacc_side,m.Nacc_theory,m.Ncorr_side,m.Ncorr_theory, ...
    numel(out.A.time),numel(out.B.time)];
truth=[m.TP+m.FP,m.FP,m.FP,m.TP,m.TP,NaN,NaN];
error=[NaN,m.epsilon_acc_side,m.epsilon_acc_theory,m.epsilon_corr_side,m.epsilon_corr_theory,NaN,NaN];
method=["main","side-window","theory","side-window","theory","channel-A","channel-B"];
ub=nan(1,7); ci=nan(2,7); rel=nan(1,7);
if ~isempty(result.bootstrap)
    bs=result.bootstrap;
    ub=bs.standardUncertainty(1:7); ci=bs.CI(:,1:7); rel=bs.relativeUncertainty(1:7);
end
up=result.analytical.standardUncertainty;
summary=makeRows(names,method,point,up,ub,ci,rel,truth,error);
% 速率直接除以固定采集时间，无需第二轮 Bootstrap。
rateNames=["Rraw","Racc_side","Racc_theory","Rcorr_side","Rcorr_theory","RA","RB"];
summary=[summary;makeRows(rateNames,method,point/T,up/T,ub/T,ci/T,rel,truth/T,error)];
extraNames=["Delta_acc_methods","epsilon_acc_side","epsilon_acc_theory", ...
    "epsilon_corr_side","epsilon_corr_theory"];
extraPoint=[m.Delta_acc_methods,m.epsilon_acc_side,m.epsilon_acc_theory, ...
    m.epsilon_corr_side,m.epsilon_corr_theory];
extraU=nan(1,5); extraCI=nan(2,5);
if ~isempty(result.bootstrap)
    [~,idx]=ismember(extraNames,result.bootstrap.names);
    extraU=result.bootstrap.standardUncertainty(idx); extraCI=result.bootstrap.CI(:,idx);
end
summary=[summary;makeRows(extraNames,repmat("comparison",1,5),extraPoint, ...
    nan(1,5),extraU,extraCI,nan(1,5),nan(1,5),nan(1,5))];
auxNames=["Cov_raw_acc_side","Cov_raw_acc_theory","Corr_raw_acc_side", ...
    "Corr_raw_acc_theory","Cov_acc_methods","Corr_acc_methods"];
aux=nan(1,6);
if ~isempty(result.bootstrap)
    c=result.bootstrap.covariance; r=result.bootstrap.correlation;
    aux=[c(1,2),c(1,3),r(1,2),r(1,3),c(2,3),r(2,3)];
end
summary=[summary;makeRows(auxNames,repmat("bootstrap",1,6),aux,nan(1,6), ...
    nan(1,6),nan(2,6),nan(1,6),nan(1,6),nan(1,6))];
auxRows=ismember(summary.Metric,auxNames) & isfinite(summary.Estimate);
summary.ValidityFlag(auxRows)="estimate-only";
n=height(summary); L=numel(out.acc.sideWindowCounts);
blockCount=NaN; blockSize=NaN;
if ~isempty(result.blocks), blockCount=result.blocks.count; blockSize=result.blocks.blockSize; end
summary.T_s=repmat(T,n,1);
summary.NA=repmat(numel(out.A.time),n,1); summary.NB=repmat(numel(out.B.time),n,1);
summary.PeakPosition_s=repmat(out.hist.peak,n,1);
summary.W_effective_s=repmat(out.raw.window,n,1);
summary.W_nominal_s=repmat(resolveCoincidenceWindow(out.hist,out.params),n,1);
summary.SideWindowPairs=repmat(out.params.algorithm.sideWindowPairs,n,1);
summary.ValidSideWindows=repmat(L,n,1);
summary.SideGuard_s=repmat(max(out.params.algorithm.sidebandGuard,out.raw.window/2),n,1);
summary.Nside_total=repmat(sum(out.acc.sideWindowCounts),n,1);
summary.BlockSize_s=repmat(blockSize,n,1); summary.BlockCount=repmat(blockCount,n,1);
summary.BootstrapB=repmat(u.resamples,n,1); summary.BootstrapSeed=repmat(u.seed,n,1);
summary.ConfidenceLevel=repmat(u.confidenceLevel,n,1);
summary.MatchMethod=repmat(string(out.params.algorithm.matchMethod),n,1);
summary.AnalyticalAssumption=repmat(result.analytical.assumption,n,1);
summary.Diagnostics=repmat(strjoin(result.messages,"；"),n,1);
end

function t=makeRows(names,method,point,up,ub,ci,rel,truth,err)
flag=repmat("ok",numel(point),1);
flag(~isfinite(ub(:)))="bootstrap-unavailable";
flag(~isfinite(point(:)))="unavailable";
t=table(names(:),method(:),point(:),up(:),ub(:),ci(1,:)',ci(2,:)', ...
    rel(:),truth(:),err(:),flag,'VariableNames',{'Metric','Method','Estimate', ...
    'U_Poisson','U_Bootstrap','CI_Lower','CI_Upper','Relative_U', ...
    'GroundTruth','RelativeError','ValidityFlag'});
end
