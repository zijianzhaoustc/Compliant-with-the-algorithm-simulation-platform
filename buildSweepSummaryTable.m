function sweepTable = buildSweepSummaryTable(sweep)
%BUILDSWEEPSUMMARYTABLE 将符合窗口扫描数据整理为“每行一个窗口”的表。
%   第一列是窗口全宽（ns），后续每列是随窗口变化的一项计数、
%   算法或性能指标，便于 Excel 直接绘图或比较。

required={'window','Rraw','Racc','Rnet','AccidentalFraction','TP','FP','FN', ...
    'Precision','Recall','F1','WindowCaptureRate','Bias','CAR','SNR'};
for k=1:numel(required)
    if ~isfield(sweep,required{k})
        error('CoincidenceSim:IncompleteSweep','窗口扫描结果缺少字段 %s。',required{k});
    end
end

sweepTable=table(sweep.window(:)*1e9,sweep.Rraw(:),sweep.Racc(:),sweep.Rnet(:), ...
    sweep.AccidentalFraction(:),sweep.TP(:),sweep.FP(:),sweep.FN(:), ...
    sweep.Precision(:),sweep.Recall(:),sweep.F1(:),sweep.WindowCaptureRate(:), ...
    sweep.Bias(:),sweep.CAR(:),sweep.SNR(:), ...
    'VariableNames',{'窗口大小_ns','Rraw_cps','Racc_cps','Rnet_cps','facc', ...
    'TP','FP','FN','Precision','Recall','F1','窗口捕获率','Bias','CAR','SNR'});
end
