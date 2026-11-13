function validateDetectorTimingUI(folder)
%VALIDATEDETECTORTIMINGUI 通过实际控件回调检查 IRF、重算及两处导出入口。
if nargin<1, folder=fullfile(pwd,'outputs','detector_timing_validation'); end
if ~isfolder(folder), mkdir(folder); end
app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app));
app.ParameterTabs.SelectedTab=app.DetectorTab;
c=app.Controls; c.PairRate.Value=10000; c.Time.Value=.2;
c.BootstrapEnabled.Value=false; c.OptimizationMode.Value='manual';
c.EnableDead.Value=true; c.EnableAfter.Value=true;
c.TailFractionA.Value=18; c.TailTauB.Value=1.7;
c.TimingModelB.Value='gaussian'; c.TimingModelB.ValueChangedFcn([],[]);
assert(strcmp(c.TailFractionB.Enable,'off'));
button=findall(app.UIFigure,'Type','uibutton','Text','运行新仿真');
button.ButtonPushedFcn([],[]);
assert(~isempty(app.LastResult),'仿真按钮执行失败。');
assert(app.LastResult.params.detector.A.tailFraction==.18);
assert(app.LastResult.params.detector.B.timingModel=="gaussian");
c.TimingModelB.Value='gaussian-exp-tail'; c.TimingModelB.ValueChangedFcn([],[]);
assert(strcmp(c.TailFractionB.Enable,'on'));
button.ButtonPushedFcn([],[]);
assert(abs(app.LastResult.params.detector.B.tailTau-1.7e-9)<1e-20);
assert(height(app.DiagnosticsTable.Data)==2, ...
    '诊断表未刷新，界面状态：%s',app.StatusLabel.Text);
assert(strcmp(app.TruthAxes.XLabel.String,'t_B-t_A (ns)'));
assert(strcmp(app.TruthAxes.YLabel.String,'真实对数'));
assert(size(app.DiagnosticsTable.Data,2)==7);
truthTab=findall(app.UIFigure,'Tag','SimulationDiagnosticsTab');
truthTab.Parent.SelectedTab=truthTab; drawnow;
exportapp(app.UIFigure,fullfile(folder,'platform_diagnostics.png'));
original=app.LastResult;
c.TailFractionA.Value=60; c.Window.Value=1;
c.RecalculateButton.ButtonPushedFcn([],[]);
assert(app.LastResult.params.detector.A.tailFraction==.18);
assert(isequal(app.LastResult.A,original.A));
assert(abs(app.LastResult.params.algorithm.window-1e-9)<1e-20);

dialog=showExportDialog(app.UIFigure,app.LastResult);
exportCleanup=onCleanup(@()delete(dialog));
box=findall(dialog,'Tag','ExportChoice_diagnostics');
assert(strcmp(box.Enable,'on') && box.Value);
boxes=findall(dialog,'Type','uicheckbox'); assert(numel(boxes)==12);
rows=arrayfun(@(box)box.Layout.Row,boxes); assert(numel(unique(rows))==12);
drawnow; exportapp(dialog,fullfile(folder,'diagnostics_export_dialog.png'));
clear exportCleanup
dialog=showSeedSweepDialog(app.UIFigure,app.LastResult.params,@(~,~,~,~)[]);
seedCleanup=onCleanup(@()delete(dialog));
box=findall(dialog,'Tag','ExportChoice_diagnostics');
assert(strcmp(box.Enable,'on') && box.Value); clear seedCleanup

% 切换实测结果必须清除旧真值图，并禁用真值导出。
app.LastResult.dataMode="imported";
app.LastResult.A.pairID(:)=0; app.LastResult.B.pairID(:)=0;
app.LastResult=rmfield(app.LastResult,'simulationDiagnostics');
c.RecalculateButton.ButtonPushedFcn([],[]);
assert(isempty(app.DiagnosticsTable.Data));
assert(contains(app.DiagnosticsLabel.Text,'pairID'));
dialog=showExportDialog(app.UIFigure,app.LastResult);
importCleanup=onCleanup(@()delete(dialog));
box=findall(dialog,'Tag','ExportChoice_diagnostics');
assert(strcmp(box.Enable,'off') && ~box.Value);
clear importCleanup
fprintf('UI_CHECKS_PASSED\n'); clear cleanup
end
