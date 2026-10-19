function out = adaptiveCoincidenceAnalysis()
%ADAPTIVECOINCIDENCEANALYSIS 自适应推荐、应用和独立验证的命令行示例。
p=defaultParams();
p.detector.A.backgroundRate=1e5; p.detector.B.backgroundRate=1e5;
p.optimization.mode="recommend";
out=runSimulation(p);
disp(buildOptimizationSummaryTable(out.optimization))
% 复用完全相同的时间戳，应用推荐，并用交替时间块比较四种方法。
p.optimization.mode="apply";
p.optimization.validationMode="held-out";
out=recalculateAnalysis(out,p);
disp(out.optimization.validation.summary)
options=struct('settings',false,'histogram',false,'results',false, ...
    'timestamps',false,'uncertainty',true,'optimization',true,'unitSeconds',1e-12);
exportSelectedResults(out,fullfile(pwd,'outputs','adaptive_example'),"adaptive",options);
% 多种子初步验证（按需要执行）：
% report=runOptimizationValidationSweep(p,1:20);
% writeUtf8BomTable(report.samples,'adaptive_trials.csv');
% writeUtf8BomTable(report.summary,'adaptive_validation_summary.csv');
end
