function folder=runDualTdcSyncValidation(runBenchmark)
%RUNDUALTDCSYNCVALIDATION Reproducible evidence, examples and GUI snapshots.
if nargin<1, runBenchmark=true; end
root=fileparts(mfilename('fullpath')); addpath(root);
parent=fullfile(root,'outputs','dual_tdc_sync_validation'); if ~isfolder(parent), mkdir(parent); end
[~,id]=fileparts(tempname(parent)); folder=fullfile(parent,id); mkdir(folder);
diary(fullfile(folder,'matlab_validation.log')); cleanDiary=onCleanup(@()diary('off'));
results=runtests(fullfile(root,'tests')); t=table(results);
writeUtf8BomTable(t(:,{'Name','Passed','Failed','Incomplete','Duration'}),fullfile(folder,'test_results.csv'));
assertSuccess(results);
[out,files]=makeDualTdcSyncExample(folder); %#ok<ASGLU>
assert(ismember(out.status,["ALIGNED","PARTIAL"]),'Six-file import example failed alignment.');
app=CoincidenceSimulatorApp(); cleanApp=onCleanup(@()delete(app));
app.WorkspaceTabs.SelectedTab=app.DualTdcPanel.Parent;
for name=["F1","F2","Fsync","S1","S2","Ssync"]
    app.DualTdcPanel.Controls.(name).Value=files.(name);
end
app.DualTdcPanel.Controls.UseSync.Value=true;
app.DualTdcPanel.Controls.SyncBlock.Value=out.options.sync.blockDuration_s;
app.DualTdcPanel.Controls.Acquisition.Value=out.options.sync.declaredAcquisition_s;
app.DualTdcPanel.setResult(out); drawnow;
exportapp(app.UIFigure,fullfile(folder,'sync_gui.png'));
tab=ancestor(app.DualTdcPanel.SyncAxes,'uitab'); tab.Parent.SelectedTab=tab; drawnow;
exportapp(app.UIFigure,fullfile(folder,'sync_quality_gui.png'));
tab=ancestor(app.DualTdcPanel.OverlayAxes,'uitab'); tab.Parent.SelectedTab=tab; drawnow;
exportapp(app.UIFigure,fullfile(folder,'overlay_gui.png')); clear cleanApp
if runBenchmark
    b=benchmarkDualTdcSync(); writeUtf8BomTable(b,fullfile(folder,'MHz_SYNC_benchmark.csv'));
    assert(ismember(b.alignment_status,["ALIGNED","PARTIAL"]),'SYNC benchmark failed: %s',b.reason);
end
fprintf('SYNC validation output: %s\n',folder); clear cleanDiary
end
