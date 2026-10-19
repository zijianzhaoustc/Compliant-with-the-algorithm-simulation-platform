function result = calculateUncertainty(out, includeBootstrap)
%CALCULATEUNCERTAINTY 两种背景估计共用匹配、峰、有效窗口和抽样索引。
if nargin<2, includeBootstrap=true; end
result.analytical=calculateAnalyticalUncertainty(out);
result.bootstrap=[]; result.blocks=[];
result.messages=strings(0,1);
u=out.params.uncertainty;
if ~any(string(out.params.algorithm.matchMethod)==["all-pairs","many-to-many"])
    result.messages(end+1)="当前使用非 all-pairs 匹配；两种估计沿用该规则，理论法仅作近似参考";
end
if isempty(out.acc.sideWindowCounts)
    result.messages(end+1)="无有效旁窗：旁窗结果不可用，请扩大时间谱范围或减小窗口/保护距离";
elseif sum(out.acc.sideWindowCounts)==0
    result.messages(end+1)="旁窗背景总计数为零：无法从经验分布确定背景不确定度";
elseif sum(out.acc.sideWindowCounts)<20
    result.messages(end+1)="旁窗背景总计数少于 20，背景统计稀疏";
end
if out.raw.count<20
    result.messages(end+1)="主窗计数少于 20，统计稀疏";
end
if u.enabled && includeBootstrap
    result.blocks=buildBootstrapBlocks(out);
    if result.blocks.count<2
        result.messages(end+1)="分块不足两个：Bootstrap 不可用";
    else
        result.bootstrap=runBlockBootstrap(result.blocks,u);
        if result.blocks.count<u.minBlocks
            result.messages(end+1)="分块数量低于最小建议值，请缩短分块时长并检查稳定性";
        end
    end
elseif ~u.enabled
    result.messages(end+1)="Bootstrap 已关闭";
else
    result.messages(end+1)="子窗分析仅计算解析参考值，未执行 Bootstrap";
end
result.summary=buildBootstrapSummaryTable(out,result);
end
