function dialogFigure = showExportDialog(parent, out)
%SHOWEXPORTDIALOG 打开选择性导出窗口。
%   用户可独立选择设置、直方图、结果、扫描、分窗、逐秒分析、统计和时间戳；
%   时间戳仍采用
%   每行一个数值、无表头格式，便于再次导入平台。

parentPos=parent.Position;
dialogFigure=uifigure('Name','选择导出内容','WindowStyle','modal', ...
    'Position',[parentPos(1)+parentPos(3)/2-220 parentPos(2)+parentPos(4)/2-280 440 560]);
g=uigridlayout(dialogFigure,[15 2]); g.ColumnWidth={145,'1x'};
g.RowHeight={30,30,30,30,30,30,30,30,30,30,30,30,30,36,24};
g.Padding=[12 12 12 12]; g.RowSpacing=5;

hasSweep=isfield(out,'sweep') && isstruct(out.sweep) && isfield(out.sweep,'window');
hasTimeWindows=isfield(out,'timeWindows') && isstruct(out.timeWindows) && ...
    isfield(out.timeWindows,'results') && ~isempty(out.timeWindows.results);
hasUncertainty=isfield(out,'uncertainty');
hasOptimization=isfield(out,'optimization') && ~isempty(out.optimization);
available=struct('sweep',hasSweep,'timeWindows',hasTimeWindows, ...
    'uncertainty',hasUncertainty,'optimization',hasOptimization);
choices=createExportSelectionControls(g,available);

l=uilabel(g,'Text','时间戳/直方图单位'); l.Layout.Row=10; l.Layout.Column=1;
unit=uidropdown(g,'Items',{'ps','ns','s'},'ItemsData',{1e-12,1e-9,1},'Value',1e-12); unit.Layout.Row=10; unit.Layout.Column=2;
l=uilabel(g,'Text','文件名前缀'); l.Layout.Row=11; l.Layout.Column=1;
base=uieditfield(g,'text','Value','coincidence_result','Tag','ExportBaseName'); base.Layout.Row=11; base.Layout.Column=2;
l=uilabel(g,'Text','导出目录'); l.Layout.Row=12; l.Layout.Column=1;
folder=uieditfield(g,'text','Value',pwd,'Tag','ExportFolder'); folder.Layout.Row=12; folder.Layout.Column=2;
browse=uibutton(g,'Text','选择目录…','ButtonPushedFcn',@browseFolder); browse.Layout.Row=13; browse.Layout.Column=[1 2];
exportButton=uibutton(g,'Text','开始导出','FontWeight','bold','BackgroundColor',[.16 .52 .35], ...
    'FontColor','white','ButtonPushedFcn',@doExport,'Tag','ExportStart'); exportButton.Layout.Row=14; exportButton.Layout.Column=[1 2];
status=uilabel(g,'Text','请选择内容和保存位置'); status.Layout.Row=15; status.Layout.Column=[1 2];

    function browseFolder(~,~)
        selected=uigetdir(folder.Value,'选择导出目录');
        if ~isequal(selected,0), folder.Value=selected; end
    end

    function doExport(~,~)
        if strlength(string(base.Value))==0, uialert(dialogFigure,'文件名前缀不能为空。','导出错误'); return; end
        options=readExportSelection(choices,unit.Value);
        if ~any([options.settings options.histogram options.results options.sweep ...
                options.timeWindows options.countRates options.timestamps options.uncertainty options.optimization])
            uialert(dialogFigure,'至少选择一种导出内容。','导出错误'); return
        end
        try
            status.Text='正在计算并导出…'; exportButton.Enable='off'; drawnow;
            restore=onCleanup(@()set(exportButton,'Enable','on'));
            files=exportSelectedResults(out,folder.Value,string(base.Value),options);
            clear restore
            status.Text=sprintf('导出完成：%d 个文件',numel(files));
            if numel(files)<=12
                message=strjoin(cellstr(files),newline);
            else
                % 分窗较多时不在弹窗中罗列全部文件，避免提示框过长。
                message=sprintf('%s\n……另有 %d 个文件\n输出目录：%s', ...
                    strjoin(cellstr(files(1:10)),newline),numel(files)-10,folder.Value);
            end
            uialert(dialogFigure,message,'导出完成','Icon','success');
        catch ME
            uialert(dialogFigure,ME.message,'导出失败');
        end
    end
end
