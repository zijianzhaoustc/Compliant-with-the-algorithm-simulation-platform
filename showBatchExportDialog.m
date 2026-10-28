function dialogFigure = showBatchExportDialog(parent, runBatch)
%SHOWBATCHEXPORTDIALOG 在批处理入口选择输入/输出目录、分析范围和四类导出。
position=parent.Position;
dialogFigure=uifigure('Name','文件夹批量计算并导出','WindowStyle','modal', ...
    'Position',[position(1)+(position(3)-640)/2 position(2)+(position(4)-460)/2 640 460]);
g=uigridlayout(dialogFigure,[11 3]); g.ColumnWidth={100,'1x',82};
g.RowHeight={30,30,30,46,28,28,28,28,30,36,22}; g.Padding=[12 12 12 12]; g.RowSpacing=8;
label=uilabel(g,'Text','输入文件夹'); label.Layout.Row=1;
input=uieditfield(g,'text','Value',pwd,'Tag','BatchInputFolder'); input.Layout.Row=1; input.Layout.Column=2;
button=uibutton(g,'Text','选择…','ButtonPushedFcn',@(~,~)browse(input,'选择时间戳文件夹（包含子目录）'));
button.Layout.Row=1; button.Layout.Column=3;
label=uilabel(g,'Text','导出目录'); label.Layout.Row=2; label.Layout.Column=1;
output=uieditfield(g,'text','Value',pwd,'Tag','BatchOutputFolder'); output.Layout.Row=2; output.Layout.Column=2;
button=uibutton(g,'Text','选择…','ButtonPushedFcn',@(~,~)browse(output,'选择批量结果导出目录'));
button.Layout.Row=2; button.Layout.Column=3;
label=uilabel(g,'Text','分析范围'); label.Layout.Row=3; label.Layout.Column=1;
mode=uidropdown(g,'Items',{'整段分析','每秒独立分析（1 s）'}, ...
    'ItemsData',{'whole','per-second'},'Value','whole','Tag','BatchAnalysisMode');
mode.Layout.Row=3; mode.Layout.Column=[2 3];
note=uilabel(g,'Text','使用主界面当前参数。逐秒模式：每秒独立计算，末段不足 1 s 按实际时长计算，跨秒匹配不计入。', ...
    'WordWrap','on'); note.Layout.Row=4; note.Layout.Column=[1 3];
histogram=uicheckbox(g,'Text','符合直方图 CSV','Value',true,'Tag','BatchHistogram');
histogram.Layout.Row=5; histogram.Layout.Column=[1 3];
results=uicheckbox(g,'Text','符合结果与参数列表 CSV','Value',true,'Tag','BatchResults');
results.Layout.Row=6; results.Layout.Column=[1 3];
uncertainty=uicheckbox(g,'Text','不确定度汇总 CSV','Value',true,'Tag','BatchUncertainty');
uncertainty.Layout.Row=7; uncertainty.Layout.Column=[1 3];
optimization=uicheckbox(g,'Text','自适应优化推荐 CSV','Value',true,'Tag','BatchOptimization');
optimization.Layout.Row=8; optimization.Layout.Column=[1 3];
label=uilabel(g,'Text','直方图单位'); label.Layout.Row=9; label.Layout.Column=1;
unit=uidropdown(g,'Items',{'ps','ns','s'},'ItemsData',{1e-12,1e-9,1},'Value',1e-12);
unit.Layout.Row=9; unit.Layout.Column=[2 3];
start=uibutton(g,'Text','开始批量计算并导出','FontWeight','bold', ...
    'BackgroundColor',[.16 .52 .35],'FontColor','white','Tag','BatchStart','ButtonPushedFcn',@beginBatch);
start.Layout.Row=10; start.Layout.Column=[1 3];
status=uilabel(g,'Text','每批创建独立输出目录，失败与跳过文件写入日志。');
status.Layout.Row=11; status.Layout.Column=[1 3];

    function browse(field,title)
        folder=uigetdir(field.Value,title);
        if ~isequal(folder,0), field.Value=folder; end
    end

    function beginBatch(~,~)
        if ~isfolder(input.Value)
            uialert(dialogFigure,'请选择有效的输入文件夹。','输入目录错误'); return
        end
        if strlength(strtrim(string(output.Value)))==0
            uialert(dialogFigure,'请选择导出目录。','导出目录错误'); return
        end
        options=struct('perSecond',strcmp(mode.Value,'per-second'), ...
            'histogram',histogram.Value,'results',results.Value, ...
            'uncertainty',uncertainty.Value,'optimization',optimization.Value,'unitSeconds',unit.Value);
        if ~any([options.histogram options.results options.uncertainty options.optimization])
            uialert(dialogFigure,'至少选择一种导出内容。','未选择导出内容'); return
        end
        dialogFigure.Visible='off';
        try
            runBatch(input.Value,output.Value,options);
            delete(dialogFigure);
        catch ME
            dialogFigure.Visible='on';
            uialert(dialogFigure,ME.message,'批处理失败');
        end
    end
end
