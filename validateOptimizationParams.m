function o = validateOptimizationParams(o)
%VALIDATEOPTIMIZATIONPARAMS 验证自适应参数及约束，旧设置由 validateParams 补齐。
for field=["mode","selection","validationMode"]
    if ~isscalar(string(o.(field)))
        error('CoincidenceSim:InvalidOptimization','优化选项 %s 必须为标量。',field);
    end
    o.(field)=string(o.(field));
end
if ~any(o.mode==["manual","recommend","apply"]) || ...
        ~any(o.selection==["narrowest","bootstrap-score"]) || ...
        ~any(o.validationMode==["none","held-out"])
    error('CoincidenceSim:InvalidOptimization','未知的优化模式、选择策略或验证模式。');
end
for field=["binCandidates","windowCandidates"]
    x=o.(field);
    if ~isnumeric(x) || isempty(x) || ~isvector(x) || any(~isfinite(x) | x<=0) || numel(x)>200
        error('CoincidenceSim:InvalidOptimization','%s 需要 1~200 个有限正数。',field);
    end
    o.(field)=unique(x(:)');
end
for field=["requireFullSideWindows","checkBackground","checkBinStability"]
    x=o.(field);
    if ~isscalar(x) || ~(islogical(x) || isnumeric(x)) || ~ismember(x,[0 1])
        error('CoincidenceSim:InvalidOptimization','%s 必须为逻辑标量。',field);
    end
    o.(field)=logical(x);
end
for field=["targetCapture","minPeakCounts","minBackgroundCounts","backgroundZ", ...
        "peakTailSigma","peakStabilitySigma","widthStabilityFraction", ...
        "maxModelDeviation","bootstrapCandidates","candidateResamples"]
    x=o.(field);
    if ~isnumeric(x) || ~isscalar(x) || ~isfinite(x) || x<=0
        error('CoincidenceSim:InvalidOptimization','%s 必须为有限正标量。',field);
    end
end
if o.targetCapture>=1 || o.maxModelDeviation>=1 || ...
        o.bootstrapCandidates>200 || o.candidateResamples<2 || o.candidateResamples>1e5 || ...
        any(mod([o.minPeakCounts,o.minBackgroundCounts,o.bootstrapCandidates,o.candidateResamples],1)~=0)
    error('CoincidenceSim:InvalidOptimization','捕获率、模型容差或抽样参数无效。');
end
end
