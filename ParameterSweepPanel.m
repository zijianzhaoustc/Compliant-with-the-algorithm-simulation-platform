classdef ParameterSweepPanel < handle
    %PARAMETERSWEEPPANEL Independent research workspace; execution stays in CLI functions.
    properties
        Parent
        ParameterProvider
        Controls=struct()
        Config
        Result=[]
        CancelRequested=false
        Running=false
        LastPreview=[]
        ProgressTimer
    end
    methods
        function panel=ParameterSweepPanel(parent,provider)
            panel.Parent=parent; panel.ParameterProvider=provider;
            panel.Config=scanDefaultConfig(provider());
            g=uigridlayout(parent,[7,1]); g.RowHeight={32,32,32,'2x',42,26,'1x'};
            g.Padding=[10 8 10 8]; g.RowSpacing=5;
            top=uigridlayout(g,[1,8]); top.Padding=[0 0 0 0];
            top.ColumnWidth={65,145,65,'1x',85,100,90,90};
            uilabel(top,'Text','扫描模式');
            panel.Controls.Mode=uidropdown(top,'Items',{'单因素 OAT','双因素网格','自定义多因素'}, ...
                'ItemsData',{'oat','two-factor','custom-grid'},'Value','custom-grid');
            uilabel(top,'Text','种子列表'); panel.Controls.Seeds=uieditfield(top,'text','Value','1');
            uilabel(top,'Text','基准参数来源');
            panel.Controls.BaseSource=uidropdown(top,'Items',{'当前主界面','配置文件'},'Value','当前主界面');
            panel.Controls.Save=uibutton(top,'Text','保存配置','ButtonPushedFcn',@(~,~)panel.saveConfig());
            panel.Controls.Load=uibutton(top,'Text','载入配置','ButtonPushedFcn',@(~,~)panel.loadConfig());
            paths=uigridlayout(g,[1,4]); paths.Padding=[0 0 0 0]; paths.ColumnWidth={90,'1x',130,130};
            uilabel(paths,'Text','输出根目录');
            panel.Controls.Output=uieditfield(paths,'text','Value',char(panel.Config.outputRoot));
            panel.Controls.SaveTimes=uicheckbox(paths,'Text','保存时间戳 MAT','Value',false);
            panel.Controls.SideDetails=uicheckbox(paths,'Text','导出旁窗明细','Value',true);
            toolbar=uigridlayout(g,[1,7]); toolbar.Padding=[0 0 0 0]; toolbar.ColumnWidth={100,100,100,120,120,'1x',140};
            panel.Controls.Preview=uibutton(toolbar,'Text','预览任务','ButtonPushedFcn',@(~,~)panel.preview());
            panel.Controls.Start=uibutton(toolbar,'Text','开始扫描','ButtonPushedFcn',@(~,~)panel.run(false));
            panel.Controls.Stop=uibutton(toolbar,'Text','停止','Enable','off', ...
                'ButtonPushedFcn',@(~,~)panel.requestStop());
            panel.Controls.Resume=uibutton(toolbar,'Text','选择批次续跑','ButtonPushedFcn',@(~,~)panel.run(true));
            panel.Controls.Open=uibutton(toolbar,'Text','打开结果目录','ButtonPushedFcn',@(~,~)panel.openOutput());
            uilabel(toolbar,'Text','多对多；主窗 2n+1 bin；W=(2n+1)×binWidth；保护间隔 G=W');
            uibutton(toolbar,'Text','从主界面重置基准','ButtonPushedFcn',@(~,~)panel.resetBase());
            panel.Controls.Factors=uitable(g,'RowName',[],'ColumnName', ...
                {'扫描','参数 / 标签','通道','输入方式','固定值 / 列表','起点','终点','步长','log数量','单位','实际数列 / 数量'}, ...
                'ColumnEditable',[true false true true true true true true true false false], ...
                'ColumnFormat',{'logical','char',{'both','A','B'},{'fixed','list','range','log'},'char','numeric','numeric','numeric','numeric','char','char'}, ...
                'ColumnWidth',{45,300,65,75,210,75,75,75,70,70,260});
            panel.Controls.PreviewText=uilabel(g,'Text', ...
                '勾选因素后预览；通道 both 同步 A/B，分别扫描请分别启用 A、B 行。修正方法列表：theory,side-window,time-shift', ...
                'WordWrap','on');
            panel.Controls.Status=uilabel(g,'Text','就绪；未勾选参数保持基准设置。','Interpreter','none');
            tabs=uitabgroup(g); resultPage=uitab(tabs,'Title','结果 / 错误预览（前500行）');
            resultGrid=uigridlayout(resultPage,[1 1]); resultGrid.Padding=[0 0 0 0];
            panel.Controls.Results=uitable(resultGrid,'RowName',[]);
            plotPage=uitab(tabs,'Title','曲线 / 热力图');
            pg=uigridlayout(plotPage,[3 1]); pg.RowHeight={30,30,'1x'};
            controls=uigridlayout(pg,[1 8]); controls.Padding=[0 0 0 0];
            controls.ColumnWidth={35,'1x',35,'1x',35,'1x',95,65};
            vars={'Rpair_per_s','T_s','seed','bin_width_ps','n_bins_each_side','K_requested', ...
                'hist_half_range_ns','dark_A_cps','dark_B_cps','bg_A_cps','bg_B_cps', ...
                'detectorJitter_A_ps','detectorJitter_B_ps','tdcJitter_A_ps','tdcJitter_B_ps', ...
                'param_algorithm_timeShiftStart','param_algorithm_timeShiftStep','param_algorithm_timeShiftCount'};
            uilabel(controls,'Text','X'); panel.Controls.X=uidropdown(controls,'Items',vars,'Value','bin_width_ps');
            uilabel(controls,'Text','Y'); panel.Controls.Y=uidropdown(controls,'Items',vars,'Value','n_bins_each_side');
            uilabel(controls,'Text','指标'); panel.Controls.Metric=uidropdown(controls,'Items', ...
                {'Rnet_signed_cps','Rraw_cps','Racc_cps','metric_EtaW','epsilon_acc_vs_true','epsilon_pair_window','metric_F1'});
            panel.Controls.PlotKind=uidropdown(controls,'Items',{'曲线','热力图'});
            uibutton(controls,'Text','绘制','ButtonPushedFcn',@(~,~)panel.plotResults());
            filterRow=uigridlayout(pg,[1,2]); filterRow.Padding=[0 0 0 0]; filterRow.ColumnWidth={200,'1x'};
            uilabel(filterRow,'Text','固定其他参数（JSON 精确筛选）');
            panel.Controls.Filter=uieditfield(filterRow,'text','Value','{}', ...
                'Placeholder','例如 {"seed":1,"K_requested":2,"accidental_method":"theory"}');
            panel.Controls.Axes=uiaxes(pg); grid(panel.Controls.Axes,'on');
            panel.populate(panel.Config);
        end

        function c=readConfig(panel)
            c=panel.Config;
            if strcmp(panel.Controls.BaseSource.Value,'当前主界面')
                c.baseParams=panel.ParameterProvider();
            end
            c.mode=string(panel.Controls.Mode.Value); seedInput=scanFactor("seed",panel.Controls.Seeds.Value);
            c.seeds=expandScanValues(seedInput); c.outputRoot=string(panel.Controls.Output.Value);
            c.resumeDirectory=""; c.outputs.saveTimestamps=panel.Controls.SaveTimes.Value;
            c.outputs.exportPerSideWindow=panel.Controls.SideDetails.Value;
            data=panel.Controls.Factors.Data; factors=repmat(scanFactor("",[]),0,1);
            for i=1:size(data,1)
                if ~data{i,1}, continue; end
                key=extractBefore(string(data{i,2})," | ");
                f=scanFactor(key,string(data{i,5}),string(data{i,3}));
                f.inputMode=string(data{i,4}); f.start=data{i,6}; f.stop=data{i,7};
                f.step=data{i,8}; f.count=data{i,9}; factors(end+1,1)=f; %#ok<AGROW>
            end
            c.factors=factors; c=validateScanConfig(c);
        end

        function populate(panel,c)
            panel.Config=c; panel.Controls.Mode.Value=char(c.mode);
            panel.Controls.Seeds.Value=char(strjoin(string(c.seeds),','));
            panel.Controls.Output.Value=char(c.outputRoot);
            panel.Controls.SaveTimes.Value=c.outputs.saveTimestamps;
            panel.Controls.SideDetails.Value=c.outputs.exportPerSideWindow;
            catalog=scanParameterCatalog(); data=cell(0,11);
            for i=1:height(catalog)
                key=catalog.parameter(i); channels="both";
                if startsWith(key,"detector.") || startsWith(key,"tdc."), channels=["both","A","B"]; end
                for channel=channels
                    value=scanGetParameter(c.baseParams,key,channel);
                    data(end+1,:)={false,char(key+" | "+catalog.label(i)),char(channel),'list', ...
                        char(string(value)),0,1,1,10,char(catalog.unit(i)),''}; %#ok<AGROW>
                    for f=c.factors(:)'
                        if string(f.parameter)==key && string(f.channel)==channel
                            row=size(data,1); data{row,1}=f.enabled; data{row,4}=char(f.inputMode);
                            data{row,5}=char(strjoin(string(f.values),','));
                            data{row,6}=f.start; data{row,7}=f.stop; data{row,8}=f.step; data{row,9}=f.count;
                        end
                    end
                end
            end
            panel.Controls.Factors.Data=data;
        end

        function preview(panel)
            try
                c=panel.readConfig(); [~,v,c]=buildScanGrid(c); panel.LastPreview=v;
                panel.Controls.PreviewText.Text=sprintf( ...
                    '物理生成 %d 次；分析 %d 行；单批期望源事件 %.3g，通道上界 %.3g；粗略工作内存 %.1f MB。预计旁窗不足 %d 行（按理论峰位，实际逐行检查）。', ...
                    v.physicalGenerationCount,v.analysisCount,v.maxExpectedSourceEvents,v.maxExpectedChannelEvents,v.estimatedWorkingMemoryMB,v.potentialInvalidSideWindowCount);
                data=panel.Controls.Factors.Data; enabled=find(cell2mat(data(:,1)));
                for j=1:numel(enabled)
                    f=c.factors(j); data{enabled(j),11}=char(strjoin(string(f.values),',')+" / "+numel(f.values));
                end
                panel.Controls.Factors.Data=data; panel.Controls.Status.Text='预览通过，可开始扫描。';
            catch e, panel.showError(e); end
        end

        function saveConfig(panel)
            try
                c=panel.readConfig(); [~,~,c]=buildScanGrid(c);
                [file,path]=uiputfile('*.json','保存扫描配置','scan_config.json');
                if isequal(file,0), return; end
                scanWriteJson(fullfile(path,file),c); panel.Controls.Status.Text='扫描配置已保存（包含全部基准参数和展开数列）。';
            catch e, panel.showError(e); end
        end

        function loadConfig(panel)
            [file,path]=uigetfile('*.json','载入扫描配置'); if isequal(file,0), return; end
            try
                c=validateScanConfig(jsondecode(fileread(fullfile(path,file))));
                panel.populate(c); panel.Controls.BaseSource.Value='配置文件'; panel.preview();
            catch e, panel.showError(e); end
        end

        function resetBase(panel)
            if panel.Running, return; end
            c=panel.Config; c.baseParams=panel.ParameterProvider(); panel.populate(c);
            panel.Controls.BaseSource.Value='当前主界面';
        end

        function run(panel,resume)
            if panel.Running, return; end
            try
                if resume
                    folder=uigetdir(char(panel.Controls.Output.Value),'选择含 checkpoint.mat 的批次目录');
                    if isequal(folder,0), return; end
                    c=validateScanConfig(jsondecode(fileread(fullfile(folder,'scan_config.json'))));
                    panel.populate(c); panel.Controls.BaseSource.Value='配置文件'; c.resumeDirectory=string(folder);
                else
                    c=panel.readConfig();
                end
                [~,v]=buildScanGrid(c); panel.LastPreview=v;
                panel.Running=true; panel.CancelRequested=false; panel.setRunning(true);
                cleanup=onCleanup(@()panel.setRunning(false));
                panel.ProgressTimer=tic;
                panel.Controls.Status.Text=sprintf('开始：物理生成 %d 次 / 分析 %d 行。',v.physicalGenerationCount,v.analysisCount);
                drawnow;
                batch=runParameterSweep(c,struct('CancelFcn',@()panel.shouldCancel(), ...
                    'ProgressFcn',@(done,total,row)panel.progress(done,total,row)));
                panel.Result=batch;
                fields={'seed','Rpair_per_s','bin_width_ps','n_bins_each_side','K_requested','accidental_method', ...
                    'Rraw_cps','Racc_cps','Rnet_signed_cps','status','warning_codes','error_report'};
                panel.Controls.Results.Data=batch.results(1:min(500,height(batch.results)),fields);
                panel.Controls.Status.Text=sprintf('完成 %d/%d 行，已停止=%d；%s',height(batch.results),v.analysisCount,batch.stopped,batch.outputDirectory);
                clear cleanup
            catch e, panel.setRunning(false); panel.showError(e); end
        end

        function requestStop(panel)
            panel.CancelRequested=true; panel.Controls.Status.Text='停止请求已记录；当前安全步骤完成后保存结果。';
        end

        function stop=shouldCancel(panel)
            drawnow limitrate; stop=panel.CancelRequested || ~isvalid(panel.Parent);
        end

        function progress(panel,done,total,row)
            if toc(panel.ProgressTimer)>.25 || done==total
                panel.Controls.Status.Text=sprintf('%d/%d (%.1f%%)；seed=%g；%s',done,total,100*done/total,row.seed,row.status);
                panel.ProgressTimer=tic;
            end
            drawnow limitrate;
        end

        function setRunning(panel,running)
            panel.Running=running;
            for name=["Start","Preview","Load","Save","Resume"]
                if running, panel.Controls.(name).Enable='off'; else, panel.Controls.(name).Enable='on'; end
            end
            if running, panel.Controls.Stop.Enable='on'; else, panel.Controls.Stop.Enable='off'; end
        end

        function openOutput(panel)
            if ~isempty(panel.Result), folder=char(panel.Result.outputDirectory);
            else, folder=panel.Controls.Output.Value;
            end
            if isfolder(folder), winopen(folder); end
        end

        function plotResults(panel)
            try
                if isempty(panel.Result), return; end
                t=panel.Result.results; filter=jsondecode(panel.Controls.Filter.Value);
                fields=fieldnames(filter);
                for i=1:numel(fields)
                    f=fields{i}; value=filter.(f);
                    if ~ismember(f,t.Properties.VariableNames), error('CoincidenceSim:PlotFilter','Unknown column %s',f); end
                    if isnumeric(t.(f)), selected=t.(f)==value; else, selected=string(t.(f))==string(value); end
                    t=t(selected,:);
                end
                t=t(t.status=="OK",:); x=panel.Controls.X.Value; y=panel.Controls.Y.Value; z=panel.Controls.Metric.Value;
                ax=panel.Controls.Axes; cla(ax);
                if isempty(t), title(ax,'筛选后无有效结果'); return; end
                if height(t)>5000, error('CoincidenceSim:PlotLimit','Preview exceeds 5000 points; narrow the filters.'); end
                if strcmp(panel.Controls.PlotKind.Value,'曲线')
                    if numel(unique(t.(x)))~=height(t)
                        error('CoincidenceSim:PlotFilter','X contains multiple cases. Fix other parameters and seed using JSON filters.');
                    end
                    [~,order]=sort(t.(x)); plot(ax,t.(x)(order),t.(z)(order),'-o'); ylabel(ax,z,'Interpreter','none');
                else
                    [xs,~,ix]=unique(t.(x)); [ys,~,iy]=unique(t.(y));
                    linear=sub2ind([numel(ys),numel(xs)],iy,ix);
                    if numel(unique(linear))~=height(t)
                        error('CoincidenceSim:PlotFilter','Duplicate grid cells: fix other parameters and seed using JSON filters.');
                    end
                    values=nan(numel(ys),numel(xs)); values(linear)=t.(z);
                    [X,Y]=meshgrid(plotCellEdges(xs),plotCellEdges(ys));
                    colors=nan(size(X)); colors(1:end-1,1:end-1)=values;
                    surface(ax,X,Y,zeros(size(X)),colors,'FaceColor','flat','EdgeColor','none');
                    view(ax,2); colorbar(ax); ylabel(ax,y,'Interpreter','none');
                end
                xlabel(ax,x,'Interpreter','none'); title(ax,z,'Interpreter','none'); grid(ax,'on');
            catch e, panel.showError(e); end
        end

        function showError(panel,e)
            panel.Controls.Status.Text=string(e.message);
            uialert(ancestor(panel.Parent,'figure'),e.message,'扫描设置或运行错误');
        end
    end
end

function edges=plotCellEdges(values)
values=values(:)';
if numel(values)==1, edges=values+[-.5 .5]; return; end
middle=(values(1:end-1)+values(2:end))/2;
edges=[values(1)-(middle(1)-values(1)),middle,values(end)+(values(end)-middle(end))];
end
