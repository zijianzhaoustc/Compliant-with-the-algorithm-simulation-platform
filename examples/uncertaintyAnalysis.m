function out = uncertaintyAnalysis()
%UNCERTAINTYANALYSIS 自动双方法统计分析与 CSV 导出示例。
% 从项目根目录调用：out=uncertaintyAnalysis()（先 addpath('examples')）。
p=defaultParams();
% 增加独立背景计数，便于观察两种背景估计及其统计波动。
p.detector.A.backgroundRate=1e5;
p.detector.B.backgroundRate=1e5;
p.uncertainty.resamples=2000;
out=runSimulation(p);
disp(out.uncertainty.summary(:,1:11))
options=struct('settings',false,'histogram',false,'results',false, ...
    'timestamps',false,'uncertainty',true,'unitSeconds',1e-12);
files=exportSelectedResults(out,fullfile(pwd,'outputs','uncertainty_example'), ...
    "example",options);
disp(files)
end
