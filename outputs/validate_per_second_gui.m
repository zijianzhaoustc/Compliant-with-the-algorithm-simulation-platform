root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(root);
files={'exportTimestampSeconds.m','showExportDialog.m','CoincidenceSimulatorApp.m','tests/TestTimestampSeconds.m'};
for k=1:numel(files)
    issues=checkcode(files{k},'-id');
    fprintf('CODE_ANALYZER %s: %d messages\n',files{k},numel(issues));
    assert(isempty(issues));
end
folder=fullfile(root,'outputs','per_second_gui_validation');
if ~isfolder(folder), mkdir(folder); end
timestamps=[0;.2;1;1.2;2;2.4];
writematrix(timestamps,fullfile(folder,'gui_CH1.txt'));
writematrix(timestamps,fullfile(folder,'gui_CH2.txt'));
p=defaultParams(); p.optimization.mode="manual"; p.uncertainty.resamples=20;
out=importTimestampFiles(fullfile(folder,'gui_CH1.txt'),fullfile(folder,'gui_CH2.txt'),1,p);
current=p; current.algorithm.binWidth=200e-12; current.uncertainty.enabled=false;
current.optimization.mode="recommend";
parent=uifigure('Position',[100 100 1000 800]);
cleanupParent=onCleanup(@()delete(parent));
d=showExportDialog(parent,out,current); cleanupDialog=onCleanup(@()delete(d));
mode=findall(d,'Tag','ExportAnalysisMode');
assert(strcmp(mode.Value,'whole'));
mode.Value='per-second'; mode.ValueChangedFcn(mode,[]);
boxes=findall(d,'Type','uicheckbox');
for k=1:numel(boxes)
    boxes(k).Value=strcmp(boxes(k).Text,'符合直方图 CSV');
    if strcmp(boxes(k).Text,'每秒计数率与拟合时间性能 CSV')
        assert(strcmp(boxes(k).Enable,'off'));
    end
    if strcmp(boxes(k).Text,'自适应优化推荐、候选与验证 CSV')
        assert(strcmp(boxes(k).Enable,'on'));
    end
end
folderField=findall(d,'Tag','ExportFolder'); folderField.Value=folder;
baseField=findall(d,'Tag','ExportBaseName'); baseField.Value='gui';
drawnow;
exportapp(d,fullfile(root,'outputs','per_second_export_dialog.png'));
button=findall(d,'Tag','ExportStart'); button.ButtonPushedFcn(button,[]);
index=readtable(fullfile(folder,'gui_per_second_results','gui_second_index.csv'));
assert(height(index)==3);
assert(all(index.CountA==2) && all(index.Nraw==2));
h=readtable(fullfile(folder,'gui_per_second_results','second_0001','gui_second_0001_histogram.csv'));
assert(all(abs(diff(h.TimeDifference)-200)<1e-7));
assert(strcmp(button.Enable,'on'));
mode.Value='whole'; mode.ValueChangedFcn(mode,[]);
for k=1:numel(boxes)
    if strcmp(boxes(k).Text,'每秒计数率与拟合时间性能 CSV'), assert(strcmp(boxes(k).Enable,'on')); end
end
clear cleanupDialog cleanupParent
fprintf('PER_SECOND_GUI_EXPORT_PASSED\n');
