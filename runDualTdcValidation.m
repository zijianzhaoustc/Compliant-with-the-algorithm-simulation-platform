function folder=runDualTdcValidation(runBenchmark)
%RUNDUALTDCVALIDATION Tests, synthetic example, GUI preview, and optional MHz run.
if nargin<1, runBenchmark=true; end
root=fileparts(mfilename('fullpath')); addpath(root);
parent=fullfile(root,'outputs','dual_tdc_validation'); if ~isfolder(parent), mkdir(parent); end
[~,uniqueID]=fileparts(tempname(parent)); folder=fullfile(parent,uniqueID); mkdir(folder);
r=runtests(fullfile(root,'tests')); t=table(r);
writeUtf8BomTable(t(:,{'Name','Passed','Failed','Incomplete','Duration'}),fullfile(folder,'test_results.csv'));
assertSuccess(r);
example=simulateDualTdc(); exportFolder=exportDualTdcResults(example,folder);
fid=fopen(fullfile(folder,'example_path.txt'),'w','n','UTF-8'); fprintf(fid,'%s',exportFolder); fclose(fid);
app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app));
app.WorkspaceTabs.SelectedTab=app.DualTdcPanel.Parent;
app.DualTdcPanel.setResult(example); drawnow;
exportapp(app.UIFigure,fullfile(folder,'dual_tdc_gui.png')); clear cleanup
if runBenchmark
    benchmark=benchmarkDualTdc(); writeUtf8BomTable(benchmark,fullfile(folder,'MHz_benchmark.csv'));
end
fprintf('Dual TDC validation output: %s\n',folder);
end
