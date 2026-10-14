function folder=runDualTdcRecalculationValidation()
%RUNDUALTDCRECALCULATIONVALIDATION Full regression plus cached-GUI/export demo.
folder=runDualTdcSyncValidation(false);
before=simulateDualTdc();
app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app));
app.WorkspaceTabs.SelectedTab=app.DualTdcPanel.Parent;
panel=app.DualTdcPanel; panel.setResult(before);
panel.Controls.BinWidth.Value=25; panel.Controls.MainBins.Value=8;
panel.Controls.Acc.Value='theory';
after=panel.recalculateCurrent();
assert(isequaln(before.data,after.data),'Cached timestamps changed during recalculation.');
assert(abs(after.F.metrics.actualWindow_ps-200)<1e-9);
drawnow; scroll(panel.Controls.MainBins.Parent,'bottom'); drawnow;
exportapp(app.UIFigure,fullfile(folder,'cached_recalculation_gui.png'));
assert(numel(findall(panel.OverlayAxes,'Type','bar'))==2,'Old hidden bars remained after recalculation.');
tab=ancestor(panel.OverlayAxes,'uitab'); tab.Parent.SelectedTab=tab; drawnow nocallbacks;
exportapp(app.UIFigure,fullfile(folder,'cached_overlay_refreshed_gui.png'));
exportDualTdcResults(after,folder);
fprintf('Cached recalculation validation output: %s\n',folder);
clear cleanup
end
