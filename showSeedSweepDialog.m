function dialogFigure = showSeedSweepDialog(parent, p, runSweep)
%SHOWSEEDSWEEPDIALOG 种子起点/步进/次数及与选择性导出相同的九项内容。
position=parent.Position;
dialogFigure=uifigure('Name','随机种子步进扫描','WindowStyle','modal', ...
    'Position',[position(1)+(position(3)-620)/2 position(2)+(position(4)-660)/2 620 660]);
outer=uigridlayout(dialogFigure,[3 1]); outer.RowHeight={94,310,'1x'};
outer.Padding=[12 12 12 12]; outer.RowSpacing=8;
top=uigridlayout(outer,[3 6]); top.Padding=[0 0 0 0]; top.RowHeight={30,28,24};
top.ColumnWidth={70,110,50,100,50,'1x'}; top.RowSpacing=6;
label=uilabel(top,'Text','起始种子'); label.Layout.Row=1; label.Layout.Column=1;
start=uieditfield(top,'numeric','Value',p.seed,'Limits',[0 2^32-1],'Tag','SeedStart');
start.Layout.Row=1; start.Layout.Column=2;
label=uilabel(top,'Text','步进'); label.Layout.Row=1; label.Layout.Column=3;
step=uieditfield(top,'numeric','Value',1,'Tag','SeedStep'); step.Layout.Row=1; step.Layout.Column=4;
label=uilabel(top,'Text','次数'); label.Layout.Row=1; label.Layout.Column=5;
count=uieditfield(top,'numeric','Value',min(10,2^32-p.seed),'Limits',[1 1e6],'Tag','SeedCount');
count.Layout.Row=1; count.Layout.Column=6;
label=uilabel(top,'Text','每次仅改变主随机种子；其他输入参数及 Bootstrap 种子使用主界面设置。','WordWrap','on');
label.Layout.Row=2; label.Layout.Column=[1 6];
preview=uilabel(top,'Text',''); preview.Layout.Row=3; preview.Layout.Column=[1 6];
start.ValueChangedFcn=@updatePreview; step.ValueChangedFcn=@updatePreview; count.ValueChangedFcn=@updatePreview;
grid=uigridlayout(outer,[9 2]); grid.Padding=[0 0 0 0];
grid.RowHeight=repmat({30},1,9); grid.RowSpacing=5;
available=struct('sweep',true,'timeWindows',true,'uncertainty',true, ...
    'optimization',string(p.optimization.mode)~="manual",'defaultTimeWindows',p.algorithm.timestampWindowMode);
choices=createExportSelectionControls(grid,available);
bottom=uigridlayout(outer,[5 3]); bottom.ColumnWidth={110,'1x',80}; bottom.Padding=[0 0 0 0];
bottom.RowHeight={30,30,30,36,24}; bottom.RowSpacing=5;
label=uilabel(bottom,'Text','时间戳/直方图单位'); label.Layout.Row=1; label.Layout.Column=1;
unit=uidropdown(bottom,'Items',{'ps','ns','s'},'ItemsData',{1e-12,1e-9,1},'Value',1e-12);
unit.Layout.Row=1; unit.Layout.Column=[2 3];
label=uilabel(bottom,'Text','文件名前缀'); label.Layout.Row=2; label.Layout.Column=1;
base=uieditfield(bottom,'text','Value','simulation','Tag','SeedBaseName'); base.Layout.Row=2; base.Layout.Column=[2 3];
label=uilabel(bottom,'Text','导出目录'); label.Layout.Row=3; label.Layout.Column=1;
folder=uieditfield(bottom,'text','Value',pwd,'Tag','SeedOutputFolder'); folder.Layout.Row=3; folder.Layout.Column=2;
button=uibutton(bottom,'Text','选择…','ButtonPushedFcn',@browse); button.Layout.Row=3; button.Layout.Column=3;
button=uibutton(bottom,'Text','开始种子扫描并导出','FontWeight','bold','Tag','SeedSweepStart', ...
    'BackgroundColor',[.16 .52 .35],'FontColor','white','ButtonPushedFcn',@beginSweep);
button.Layout.Row=4; button.Layout.Column=[1 3];
label=uilabel(bottom,'Text','逐次仿真并保存；可在两次仿真之间取消。'); label.Layout.Row=5; label.Layout.Column=[1 3];
updatePreview([],[]);

    function updatePreview(~,~)
        try
            seeds=buildSeedSequence(start.Value,step.Value,count.Value);
            preview.Text=sprintf('种子：%.0f → %.0f，共 %d 次',seeds(1),seeds(end),numel(seeds));
            preview.FontColor=[.2 .3 .4];
        catch
            preview.Text='种子需为 0～4294967295 的整数，步进非零，次数为正整数。';
            preview.FontColor=[.8 .2 .15];
        end
    end

    function browse(~,~)
        selected=uigetdir(folder.Value,'选择种子扫描导出目录');
        if ~isequal(selected,0), folder.Value=selected; end
    end

    function beginSweep(~,~)
        try
            buildSeedSequence(start.Value,step.Value,count.Value);
            options=readExportSelection(choices,unit.Value);
            if ~any(structfun(@(value)logical(value),rmfield(options,'unitSeconds')))
                error('CoincidenceSim:NoSeedSweepExports','至少选择一种导出内容。');
            end
            if strlength(strtrim(string(folder.Value)))==0 || strlength(strtrim(string(base.Value)))==0
                error('CoincidenceSim:EmptyExportPath','请填写导出目录和文件名前缀。');
            end
            spec=struct('start',start.Value,'step',step.Value,'count',count.Value);
            dialogFigure.Visible='off';
            runSweep(spec,folder.Value,base.Value,options);
            delete(dialogFigure);
        catch ME
            dialogFigure.Visible='on';
            uialert(dialogFigure,ME.message,'种子扫描失败');
        end
    end
end
