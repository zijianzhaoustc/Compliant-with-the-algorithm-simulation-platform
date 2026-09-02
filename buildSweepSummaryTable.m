function sweepTable = buildSweepSummaryTable(sweep)
%BUILDSWEEPSUMMARYTABLE 将符合窗口扫描数据整理为“每行一个窗口”的表。
%   第一列是窗口全宽（ns），后续每列是随窗口变化的一项计数、
%   算法或性能指标，便于 Excel 直接绘图或比较。

required={'window','Nraw','Nacc','Rraw','Racc','Rnet','AccidentalFraction','TP','FP','FN', ...
    'Precision','Recall','F1','WindowCaptureRate','Bias','CAR','SNR'};
for k=1:numel(required)
    if ~isfield(sweep,required{k})
        error('CoincidenceSim:IncompleteSweep','窗口扫描结果缺少字段 %s。',required{k});
    end
end

% 旧的扫描缓存没有算法元数据时标记为“未知”，避免导出时误报修正方法。
if isfield(sweep,'accidentalMethod')
    methodName=accidentalMethodDisplayName(sweep.accidentalMethod);
else
    methodName="未知";
end
methodColumn=repmat(methodName,numel(sweep.window),1);

sweepTable=table(sweep.window(:)*1e9,methodColumn,sweep.Nraw(:),sweep.Nacc(:), ...
    sweep.Rraw(:),sweep.Racc(:),sweep.Rnet(:), ...
    sweep.AccidentalFraction(:),sweep.TP(:),sweep.FP(:),sweep.FN(:), ...
    sweep.Precision(:),sweep.Recall(:),sweep.F1(:),sweep.WindowCaptureRate(:), ...
    sweep.Bias(:),sweep.CAR(:),sweep.SNR(:), ...
    'VariableNames',{'窗口大小_ns','偶然符合修正算法','Nraw_count','Nacc_count', ...
    'Rraw_cps','Racc_cps','Rnet_cps','facc', ...
    'TP','FP','FN','Precision','Recall','F1','窗口捕获率','Bias','CAR','SNR'});
end
