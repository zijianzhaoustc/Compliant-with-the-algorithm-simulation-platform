function dialogFigure = showExportDialog(parent, out)
%SHOWEXPORTDIALOG 打开选择性导出窗口。
%   用户可独立选择设置参数、直方图、计算结果和两路时间戳；时间戳仍采用
%   每行一个数值、无表头格式，便于再次导入平台。

parentPos=parent.Position;
dialogFigure=uifigure('Name','选择导出内容','WindowStyle','modal', ...
    'Position',[parentPos(1)+parentPos(3)/2-220 parentPos(2)+parentPos(4)/2-190 440 380]);
g=uigridlayout(dialogFigure,[10 2]); g.ColumnWidth={145,'1x'};
g.RowHeight={30,30,30,30,30,30,30,30,36,24}; g.Padding=[12 12 12 12];

settings=uicheckbox(g,'Text','设置参数 MAT','Value',true); settings.Layout.Row=1; settings.Layout.Column=[1 2];
histogram=uicheckbox(g,'Text','符合直方图 CSV','Value',true); histogram.Layout.Row=2; histogram.Layout.Column=[1 2];
results=uicheckbox(g,'Text','符合结果与参数列表 CSV','Value',true); results.Layout.Row=3; results.Layout.Column=[1 2];
timestamps=uicheckbox(g,'Text','Start/Stop 时间戳 TXT','Value',false); timestamps.Layout.Row=4; timestamps.Layout.Column=[1 2];

l=uilabel(g,'Text','时间戳/直方图单位'); l.Layout.Row=5; l.Layout.Column=1;
unit=uidropdown(g,'Items',{'ps','ns','s'},'ItemsData',{1e-12,1e-9,1},'Value',1e-12); unit.Layout.Row=5; unit.Layout.Column=2;
l=uilabel(g,'Text','文件名前缀'); l.Layout.Row=6; l.Layout.Column=1;
base=uieditfield(g,'text','Value','coincidence_result'); base.Layout.Row=6; base.Layout.Column=2;
l=uilabel(g,'Text','导出目录'); l.Layout.Row=7; l.Layout.Column=1;
folder=uieditfield(g,'text','Value',pwd); folder.Layout.Row=7; folder.Layout.Column=2;
browse=uibutton(g,'Text','选择目录…','ButtonPushedFcn',@browseFolder); browse.Layout.Row=8; browse.Layout.Column=[1 2];
exportButton=uibutton(g,'Text','开始导出','FontWeight','bold','BackgroundColor',[.16 .52 .35], ...
    'FontColor','white','ButtonPushedFcn',@doExport); exportButton.Layout.Row=9; exportButton.Layout.Column=[1 2];
status=uilabel(g,'Text','请选择内容和保存位置'); status.Layout.Row=10; status.Layout.Column=[1 2];

    function browseFolder(~,~)
        selected=uigetdir(folder.Value,'选择导出目录');
        if ~isequal(selected,0), folder.Value=selected; end
    end

    function doExport(~,~)
        if strlength(string(base.Value))==0, uialert(dialogFigure,'文件名前缀不能为空。','导出错误'); return; end
        options=struct('settings',settings.Value,'histogram',histogram.Value, ...
            'results',results.Value,'timestamps',timestamps.Value,'unitSeconds',unit.Value);
        if ~any([options.settings options.histogram options.results options.timestamps])
            uialert(dialogFigure,'至少选择一种导出内容。','导出错误'); return
        end
        try
            files=exportSelectedResults(out,folder.Value,string(base.Value),options);
            status.Text=sprintf('导出完成：%d 个文件',numel(files));
            uialert(dialogFigure,strjoin(cellstr(files),newline),'导出完成','Icon','success');
        catch ME
            uialert(dialogFigure,ME.message,'导出失败');
        end
    end
end
