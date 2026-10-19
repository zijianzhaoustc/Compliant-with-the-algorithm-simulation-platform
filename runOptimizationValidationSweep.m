function report = runOptimizationValidationSweep(p,seeds)
%RUNOPTIMIZATIONVALIDATIONSWEEP 多随机种子下的四方法训练/独立评价对照。
% 每个种子只生成一批事件，四方法共享该批匹配；不把随机 TP 当作固定覆盖率目标。
if ~isnumeric(seeds) || ~isvector(seeds) || numel(seeds)<2 || ...
        any(~isfinite(seeds) | seeds<0 | seeds>2^32-1 | mod(seeds,1)~=0) || ...
        numel(unique(seeds))~=numel(seeds)
    error('CoincidenceSim:InvalidSeeds','需要至少两个有效整数随机种子。');
end
p=validateParams(p); samples=table(); statuses=strings(numel(seeds),1);
for k=1:numel(seeds)
    q=p; q.seed=seeds(k); q.optimization.mode="manual";
    q.optimization.validationMode="none";
    % 主测量不另做一轮正式 Bootstrap；独立评价内统一计算各方法统计量。
    q.uncertainty.enabled=false;
    out=runSimulation(q);
    q=p; q.seed=seeds(k);
    validation=validateAdaptiveSelection(out.A,out.B,out.matches,q,"simulation");
    statuses(k)=validation.status;
    if ~validation.valid, continue; end
    rows=validation.summary;
    rows=addvars(rows,repmat(seeds(k),height(rows),1), ...
        repmat(out.params.source.pairRate,height(rows),1), ...
        'Before',1,'NewVariableNames',{'Seed','PairRate_Hz'});
    samples=[samples;rows]; %#ok<AGROW>
end
summary=table();
if ~isempty(samples)
    methods=unique(samples.Method,'stable');
    for method=methods(:)'
        rows=samples(samples.Method==method,:);
        errorAcc=rows.Nacc_side-rows.FP; errorCorr=rows.Ncorr_side-rows.TP;
        errorAccTheory=rows.Nacc_theory-rows.FP; errorCorrTheory=rows.Ncorr_theory-rows.TP;
        empiricalSD=NaN;
        if height(rows)>1, empiricalSD=std(rows.Ncorr_side,0); end
        row=table(method,height(rows),empiricalSD,mean(rows.BootstrapU_side,'omitnan'), ...
            mean(errorAcc),sqrt(mean(errorAcc.^2)),mean(errorCorr),sqrt(mean(errorCorr.^2)), ...
            mean(errorAccTheory),sqrt(mean(errorAccTheory.^2)), ...
            mean(errorCorrTheory),sqrt(mean(errorCorrTheory.^2)),mean(rows.EtaW,'omitnan'), ...
            'VariableNames',{'Method','CompleteTrials','EmpiricalSD_Ncorr_side','Mean_U_Bootstrap_side', ...
            'BiasAcc_side','RMSEAcc_side','BiasCorr_side','RMSECorr_side', ...
            'BiasAcc_theory','RMSEAcc_theory','BiasCorr_theory','RMSECorr_theory','Mean_EtaW'});
        summary=[summary;row]; %#ok<AGROW>
    end
end
report=struct('params',p,'samples',samples,'summary',summary, ...
    'trials',table(seeds(:),statuses,'VariableNames',{'Seed','Status'}), ...
    'scope',"training parameters, independent evaluation blocks; no fixed-target coverage claim");
end
