function controls = createExportSelectionControls(grid, available)
%CREATEEXPORTSELECTIONCONTROLS 单次导出和种子扫描共用的九项导出选择。
names=["settings","histogram","results","sweep","timeWindows","countRates", ...
    "uncertainty","timestamps","optimization"];
labels=["设置参数 MAT","符合直方图 CSV","符合结果与参数列表 CSV", ...
    "窗口扫描结果 CSV","时间戳分窗直方图与汇总 CSV","每秒计数率与拟合时间性能 CSV", ...
    "不确定度汇总、分块与 Bootstrap 样本 CSV","Start/Stop 时间戳（导出为 TXT）", ...
    "自适应优化推荐、候选与验证 CSV"];
if ~available.sweep, labels(4)="窗口扫描结果 CSV（请先执行扫描）"; end
if ~available.timeWindows, labels(5)="时间戳分窗结果（请启用分窗后导入）"; end
values=[true true true false available.timeWindows false available.uncertainty false available.optimization];
if isfield(available,'defaultTimeWindows'), values(5)=available.defaultTimeWindows; end
enabled=[true true true available.sweep available.timeWindows true available.uncertainty true available.optimization];
controls=struct();
for k=1:numel(names)
    state='off'; if enabled(k), state='on'; end
    box=uicheckbox(grid,'Text',labels(k),'Value',values(k),'Enable',state, ...
        'Tag',"ExportChoice_"+names(k));
    box.Layout.Row=k; box.Layout.Column=[1 2]; controls.(names(k))=box;
end
end
