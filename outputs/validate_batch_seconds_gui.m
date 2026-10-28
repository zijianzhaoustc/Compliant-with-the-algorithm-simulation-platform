root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(root);
folder=fullfile(root,'outputs','batch_seconds_gui_validation');
input=fullfile(folder,'input'); output=fullfile(folder,'output');
if ~isfolder(input), mkdir(input); end
timestamps=[0;.2;1;1.2;2;2.4];
writematrix(timestamps,fullfile(input,'gui_CH1.txt'));
writematrix(timestamps,fullfile(input,'gui_CH2.txt'));
app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app));
app.Controls.ImportUnit.Value=1;
app.Controls.OptimizationMode.Value='manual'; app.Controls.BootstrapB.Value=20;
app.Controls.Bin.Value=125;
p=defaultParams(); p.optimization.mode="manual"; p.uncertainty.resamples=20;
out=importTimestampFiles(fullfile(input,'gui_CH1.txt'),fullfile(input,'gui_CH2.txt'),1,p);
single=showExportDialog(app.UIFigure,out);
assert(isempty(findall(single,'Tag','ExportAnalysisMode')));
delete(single);
app.Controls.BatchButton.ButtonPushedFcn(app.Controls.BatchButton,[]);
d=findall(groot,'Type','figure','Name','文件夹批量计算并导出'); assert(numel(d)==1);
field=findall(d,'Tag','BatchInputFolder'); field.Value=input;
field=findall(d,'Tag','BatchOutputFolder'); field.Value=output;
mode=findall(d,'Tag','BatchAnalysisMode'); mode.Value='per-second';
field=findall(d,'Tag','BatchHistogram'); field.Value=true;
for tag=["BatchResults","BatchUncertainty","BatchOptimization"]
    field=findall(d,'Tag',tag); field.Value=false;
end
drawnow; exportapp(d,fullfile(root,'outputs','batch_seconds_export_dialog.png'));
start=findall(d,'Tag','BatchStart'); start.ButtonPushedFcn(start,[]);
assert(~isvalid(d));
assert(contains(app.StatusLabel.Text,'成功 1，失败 0'));
assert(isempty(app.LastResult));
folders=dir(fullfile(output,'batch_*')); [~,latest]=max([folders.datenum]);
batch=fullfile(folders(latest).folder,folders(latest).name);
log=readtable(fullfile(batch,'batch_log.csv'),'TextType','string');
assert(log.Status=="success" && log.AnalysisMode=="per-second");
assert(log.SecondCount==3 && log.CompletedSeconds==3 && log.ExportedFiles==4);
file=fullfile(log.OutputFolder(1),'gui_per_second_results','second_0001','gui_second_0001_histogram.csv');
h=readtable(file); assert(all(abs(diff(h.TimeDifference)-125)<1e-7));
clear cleanup
fprintf('BATCH_SECONDS_GUI_EXPORT_PASSED\n');
