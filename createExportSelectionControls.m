function controls = createExportSelectionControls(grid, available)
%CREATEEXPORTSELECTIONCONTROLS 单次导出和种子扫描共用的导出选择。
names=["settings","histogram","results","sweep","timeWindows","countRates", ...
    "uncertainty","timestamps","optimization","evaluation","diagnostics","jointFit"];
labels=["设置参数 MAT","符合直方图 CSV","符合结果与参数列表 CSV", ...
    "窗口扫描结果 CSV","时间戳分窗直方图与汇总 CSV","每秒计数率与拟合时间性能 CSV", ...
    "不确定度汇总、分块与 Bootstrap 样本 CSV","Start/Stop 时间戳（导出为 TXT）", ...
    "自适应优化推荐、候选与验证 CSV","评价函数值 CSV","仿真真实峰形与事件链路诊断 CSV（SI单位）", ...
    "联合无分箱拟合汇总、曲线与完整结果（CSV/MAT）"];
if ~available.sweep, labels(4)="窗口扫描结果 CSV（请先执行扫描）"; end
if ~available.timeWindows, labels(5)="时间戳分窗结果（请启用分窗后导入）"; end
hasTruth=isfield(available,'diagnostics') && available.diagnostics;
hasJointFit=isfield(available,'jointFit') && available.jointFit;
values=[true true true false available.timeWindows false available.uncertainty false available.optimization false hasTruth hasJointFit];
if isfield(available,'defaultTimeWindows'), values(5)=available.defaultTimeWindows; end
enabled=[true true true available.sweep available.timeWindows true available.uncertainty true ...
    available.optimization available.optimization hasTruth hasJointFit];
controls=struct();
for k=1:numel(names)
    state='off'; if enabled(k), state='on'; end
    box=uicheckbox(grid,'Text',labels(k),'Value',values(k),'Enable',state, ...
        'Tag',"ExportChoice_"+names(k));
    box.Layout.Row=k; box.Layout.Column=[1 2]; controls.(names(k))=box;
end
end
