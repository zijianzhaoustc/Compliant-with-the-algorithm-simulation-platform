function report = validateDetectorTiming(folder)
%VALIDATEDETECTORTIMING 生成方案 S1/S2/S3 的可复核峰形与诊断示例。
%   不评价统计方法优劣。为单独观察生成模型，关闭自动选参与 Bootstrap。
if nargin<1, folder=fullfile(pwd,'outputs','detector_timing_validation'); end
if ~isfolder(folder), mkdir(folder); end
base=defaultParams(); base.source.pairRate=1e5;
base.uncertainty.enabled=false; base.optimization.mode="manual";
names=["S1 Gaussian";"S2 Gaussian + exponential tail";"S3 stronger tail"];
results=cell(3,1); values=zeros(3,9);
for k=1:3
    p=base;
    if k==1
        p.detector.A.timingModel="gaussian"; p.detector.B.timingModel="gaussian";
    else
        p.detector.enableDeadTime=true; p.detector.enableAfterpulse=true;
        if k==3
            p.detector.A.tailFraction=.2; p.detector.B.tailFraction=.3;
            p.detector.A.tailTau=1.2e-9; p.detector.B.tailTau=2e-9;
        end
    end
    o=runSimulation(p); d=o.simulationDiagnostics; results{k}=o;
    values(k,:)=[d.generatedPairCount,d.recordedPairCount,d.mean*1e9,d.sigma*1e12, ...
        d.skewness,d.tailFraction,o.metrics.WindowCaptureRate, ...
        sum(d.channels.afterpulseCandidates),sum(d.channels.recordedAfterpulses)];
    prefix="S"+k; exportSimulationDiagnostics(o,folder,prefix);
    params=o.params; save(fullfile(folder,prefix+"_settings.mat"),'params');
end
summary=[table(names,'VariableNames',{'Scenario'}),array2table(values, ...
    'VariableNames',{'GeneratedPairs','RecordedTruePairs','Mean_ns','Sigma_ps', ...
    'Skewness','TailFraction3CoreSigma','GeometricCaptureRate', ...
    'AfterpulseCandidates','RecordedAfterpulses'})];
writeUtf8BomTable(summary,fullfile(folder,'scenario_comparison.csv'));
fig=figure('Visible','off','Color','w','Position',[100 100 1200 480]);
cleanup=onCleanup(@()close(fig));
layout=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
ax=nexttile(layout); hold(ax,'on'); colors=lines(3);
for k=1:3
    d=results{k}.simulationDiagnostics; h=d.histogram;
    density=h.Counts/max(1,d.recordedPairCount)/(diff(d.histogramEdges(1:2))*1e9);
    semilogy(ax,(h.TimeDifference_s-d.referenceCenter)*1e9,density, ...
        'LineWidth',1.4,'Color',colors(k,:));
end
set(ax,'YScale','log'); xlim(ax,[-6 10]); ylim(ax,[1e-4 3]); grid(ax,'on');
xlabel(ax,'Time difference relative to configured mean (ns)');
ylabel(ax,'True-pair density (1/ns)'); title(ax,'Complete pairID truth, no accidental background');
legend(ax,names,'Location','northeast','Interpreter','none');
ax=nexttile(layout); hold(ax,'on');
for k=1:3
    c=results{k}.simulationDiagnostics.capture;
    plot(ax,c.Window_s*1e9,c.CaptureRate,'-o','Color',colors(k,:),'LineWidth',1.4);
end
grid(ax,'on'); ylim(ax,[0 1.02]); xlabel(ax,'Window full width (ns)');
ylabel(ax,'Geometric true-pair capture'); title(ax,'Windows centered on the analysis peak');
legend(ax,names,'Location','southeast','Interpreter','none');
exportgraphics(fig,fullfile(folder,'scenario_comparison.png'),'Resolution',150);
report=struct('summary',summary,'outputFolder',string(folder));
save(fullfile(folder,'validation_summary.mat'),'report');
disp(summary); clear cleanup
end
