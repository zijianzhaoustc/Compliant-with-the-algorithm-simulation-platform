function window = resolveJointFitWindow(out,requestedParams)
%RESOLVEJOINTFITWINDOW 最窄有效推荐优先，否则使用原始算法设置的实际边界。
%   recommend 和 apply 均可提供最窄窗；Bootstrap 选窗不用于本分析分支。
window=struct('source',"algorithm-settings",'lowerEdge',NaN,'upperEdge',NaN, ...
    'width',NaN,'center',NaN,'includeUpperEdge',true,'fallbackReason',"manual");
o=out.optimization;
if requestedParams.optimization.mode~="manual" && ...
        requestedParams.optimization.selection=="narrowest" && ~isempty(o) && ...
        o.valid && isfinite(o.window) && o.window>0 && isfinite(o.peak)
    window.source="narrowest-adaptive";
    window.lowerEdge=o.peak-o.window/2; window.upperEdge=o.peak+o.window/2;
    window.fallbackReason="";
else
    % 不能使用可能已被其他自动选窗策略覆盖的 out.params/raw。
    h=buildHistogram(out.matches,requestedParams);
    raw=calculateRawCoincidence(out.matches,h,requestedParams);
    window.lowerEdge=raw.lowerEdge; window.upperEdge=raw.upperEdge;
    window.includeUpperEdge=raw.includeUpperEdge;
    if requestedParams.optimization.selection~="narrowest"
        window.fallbackReason="selection-is-not-narrowest";
    elseif ~isempty(o)
        window.fallbackReason=string(o.status);
    end
end
window.width=window.upperEdge-window.lowerEdge;
window.center=(window.upperEdge+window.lowerEdge)/2;
end
