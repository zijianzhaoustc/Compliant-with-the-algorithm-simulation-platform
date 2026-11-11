function f = showInferenceResult(res,p)
%SHOWINFERENCERESULT Live, separate inference viewer using computed results.
f=uifigure('Name','无分箱相关峰推断与验证','Position',[100 100 1050 780]);
g=uigridlayout(f,[3 2]); g.RowHeight={230,'1x',80};
labels=["完整相关峰计数率";"核心曝光内完整峰面积";"核心有效曝光"; ...
    "全采集等效数量（平稳曝光外推）";"分析区间捕获率";"参考窗口捕获率"; ...
    "表观条件效率（未扣预告背景）";"有效条件效率（已扣预告背景）";"计数率 95% 百分位区间";"质量状态"];
values=[string(res.Cpair);string(res.Npair_core);string(res.Tcore);string(res.Npair_fulltime); ...
    string(res.Fdomain);string(res.Fwindow);string(res.etaB_apparent);string(res.etaB_given_A); ...
    sprintf('[%.6g, %.6g]',res.bootstrap.CI95(1,1),res.bootstrap.CI95(2,1));res.status];
if isnan(res.etaB_given_A), values(8)="背景未知或分母无效"; end
if any(isnan(res.bootstrap.CI95(:,1))), values(9)="未形成有效区间："+res.bootstrap.status; end
units=["cps";"counts";"s";"counts";"1";"1";"1";"1";"cps";""];
t=uitable(g,'Data',table(labels,values,units,'VariableNames',{'指标','数值','单位'}), ...
    'ColumnWidth',{360,'auto',80}); t.Layout.Row=1; t.Layout.Column=[1 2];
ax=uiaxes(g); ax.Layout.Row=2; ax.Layout.Column=1; hold(ax,'on');
x=linspace(p.inference.domain(1),p.inference.domain(2),1001);
for k=1:numel(res.folds)
    pdf=evaluateIRF(x,res.folds{k}.fit.model,p.inference.domain);
    plot(ax,x*1e9,pdf*1e-9,'DisplayName',sprintf('训练折 %d',k));
end
title(ax,'归一化系统响应模型'); xlabel(ax,'延迟 (ns)'); ylabel(ax,'PDF (1/ns)'); grid(ax,'on');
if ~isempty(res.folds), legend(ax,'show'); end
ax=uiaxes(g); ax.Layout.Row=2; ax.Layout.Column=2; hold(ax,'on'); d=res.diagnostics;
for k=1:numel(res.folds)
    mask=d.fold==k;
    plot(ax,.5e9*(d.delay_low_s(mask)+d.delay_high_s(mask)),d.standardized_residual(mask),'.-');
end
yline(ax,0); title(ax,'独立评价块分区残差'); xlabel(ax,'延迟 (ns)'); ylabel(ax,'标准化残差'); grid(ax,'on');
label=uilabel(g,'Text',"状态："+res.status+"；"+strjoin(res.warnings,'；')+ ...
    "。区间覆盖率尚未验证；完整峰面积依赖响应模型；全时段数量包含平稳曝光外推。",'WordWrap','on');
label.Layout.Row=3; label.Layout.Column=[1 2];
end
