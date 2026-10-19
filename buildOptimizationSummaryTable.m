function summary = buildOptimizationSummaryTable(o)
%BUILDOPTIMIZATIONSUMMARYTABLE 推荐、约束、候选参数和不确定度口径的可追溯导出。
summary=table(string(o.mode),o.valid,o.applied,string(o.status),o.binWidth,o.window, ...
    o.peak,o.sigma,o.captureEstimate,o.sideGuard,o.settings.targetCapture, ...
    string(o.settings.selection),string(o.uncertaintyScope),strjoin(o.diagnostics,";"), ...
    'VariableNames',{'Mode','Valid','Applied','Status','BinWidth_s','Window_s', ...
    'Peak_s','Sigma_s','CaptureEstimate','SideGuard_s','TargetCapture', ...
    'Selection','UncertaintyScope','Diagnostics'});
summary.OriginalBinWidth_s=o.requestedAlgorithm.binWidth;
summary.OriginalWindow_s=o.requestedAlgorithm.window;
summary.OriginalWindowMode=string(o.requestedAlgorithm.windowMode);
summary.EffectiveBinWidth_s=o.effectiveAlgorithm.binWidth;
summary.EffectiveWindow_s=o.effectiveAlgorithm.window;
summary.EffectiveWindowMode=string(o.effectiveAlgorithm.windowMode);
summary.BootstrapSeed=o.uncertaintySettings.seed;
summary.ConfidenceLevel=o.uncertaintySettings.confidenceLevel;
summary.BlockMode=string(o.uncertaintySettings.blockMode);
summary.RequestedBlockSize_s=o.uncertaintySettings.blockSize;
summary.FormalBootstrapB=o.uncertaintySettings.resamples;
% 每项阈值完整导出，便于检查实验中是否改动过统计约束。
fields=fieldnames(o.settings);
for k=1:numel(fields)
    name=fields{k}; value=o.settings.(name);
    if isnumeric(value) && ~isscalar(value), value=string(mat2str(value,16)); end
    summary.(['Config_' name])=value;
end
end
