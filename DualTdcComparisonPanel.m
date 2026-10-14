classdef DualTdcComparisonPanel < handle
    %DUALTDCCOMPARISONPANEL Independent page inside the established GUI.
    properties
        Parent
        Controls=struct()
        Result=[]
        PhysicalProvider
        HistogramF
        HistogramS
        ResidualAxes
        SweepAxes
        MetricsTable
        StatusLabel
    end
    methods
        function panel=DualTdcComparisonPanel(parent,physicalProvider)
            panel.Parent=parent;
            if nargin<2, physicalProvider=@defaultParams; end
            panel.PhysicalProvider=physicalProvider;
            main=uigridlayout(parent,[1,2]); main.ColumnWidth={460,'1x'};
            settings=uipanel(main,'Title','四路导入 / 独立双 TDC 设置','Scrollable','on');
            g=uigridlayout(settings,[17,3]); g.ColumnWidth={110,'1x',70};
            g.RowSpacing=4; g.Padding=[8 8 8 8]; g.Scrollable='on';
            g.RowHeight=[repmat({28},1,13),{240,28,44,44}];
            names={'F1','F2','S1','S2'};
            for k=1:4
                uilabel(g,'Text',names{k}); panel.Controls.(names{k})=uieditfield(g,'text');
                name=names{k}; uibutton(g,'Text','选择…','ButtonPushedFcn',@(~,~)panel.browse(name));
            end
            uilabel(g,'Text','FPGA TXT 单位');
            panel.Controls.UnitF=uidropdown(g,'Items',{'ps','ns','s'},'ItemsData',[1e-12,1e-9,1]); uilabel(g,'Text','BIN 固定 ps');
            uilabel(g,'Text','Swabian TXT 单位');
            panel.Controls.UnitS=uidropdown(g,'Items',{'ps','ns','s'},'ItemsData',[1e-12,1e-9,1]); uilabel(g,'Text','同现有格式');
            uilabel(g,'Text','频偏搜索上限 ppm'); panel.Controls.MaxPpm=uieditfield(g,'numeric','Value',1000,'Limits',[1,100000]); uilabel(g,'Text','相对值');
            uilabel(g,'Text','关联半宽 ps'); panel.Controls.Tolerance=uieditfield(g,'numeric','Value',300,'Limits',[1,1e6]); uilabel(g,'Text','唯一关联');
            uilabel(g,'Text','时间谱半范围 ns'); panel.Controls.HistRange=uieditfield(g,'numeric','Value',20,'Limits',[1,1000]); uilabel(g,'Text','正负范围');
            defaults=defaultDualTdcOptions();
            uilabel(g,'Text','直方图 bin 宽 ps');
            panel.Controls.BinWidth=uieditfield(g,'numeric','Value',defaults.binWidth*1e12, ...
                'Limits',[0 Inf],'LowerLimitInclusive','off', ...
                'Tooltip','默认 10 ps；主窗为 7 bin，旁窗为峰前第 14–20 bin。修改后重新分析生效。');
            uilabel(g,'Text','ps/bin');
            uilabel(g,'Text','内存预算 GB'); panel.Controls.Memory=uieditfield(g,'numeric','Value',2,'Limits',[.01,64]); uilabel(g,'Text','超限即报错');
            button=uibutton(g,'Text','导入四路并分析','ButtonPushedFcn',@(~,~)panel.importSelected()); button.Layout.Column=[1,3];
            note=uilabel(g,'Text','仿真共享光源/光路/SPD：沿用原参数页；下表独立设置两台 TDC。'); note.Layout.Column=[1,3];
            s=defaultDualTdcSimulation();
            values={'jitter_ps',s.F.jitter_ps(1),s.F.jitter_ps(2),s.S.jitter_ps(1),s.S.jitter_ps(2); ...
                'resolution_ps',10,10,5,5;'deadTime_ns',2.33,2.33,1,1; ...
                'clockPpm',12,12,-6,-6;'offset_s',.002,.002,.07,.07; ...
                'channelBias_ps',0,20,10,-15;'recordProbability',.97,.98,.99,.99};
            panel.Controls.TdcTable=uitable(g,'Data',values, ...
                'ColumnName',{'参数 / 单位','F1','F2','S1','S2'},'ColumnEditable',[false,true,true,true,true], ...
                'ColumnWidth',{135,60,60,60,60},'RowName',[]);
            panel.Controls.TdcTable.Layout.Column=[1,3];
            button=uibutton(g,'Text','共享 SPD 电事件仿真并分析','ButtonPushedFcn',@(~,~)panel.runSharedSimulation()); button.Layout.Column=[1,3];
            button=uibutton(g,'Text','导出 Origin CSV…','ButtonPushedFcn',@(~,~)panel.exportSelected()); button.Layout.Column=[1,3];
            panel.StatusLabel=uilabel(g,'Text','就绪；残差包含两台仪器及分路响应，不能当作单台绝对抖动。','WordWrap','on');
            panel.StatusLabel.Layout.Column=[1,3];
            plots=uigridlayout(main,[3,2]); plots.RowHeight={'1x','1x','1x'};
            panel.HistogramF=uiaxes(plots); panel.HistogramS=uiaxes(plots);
            panel.ResidualAxes=uiaxes(plots); panel.SweepAxes=uiaxes(plots);
            panel.MetricsTable=uitable(plots,'ColumnName',{'项目','FPGA','Swabian','范围/单位'},'RowName',[]);
            panel.MetricsTable.Layout.Column=[1,2];
        end

        function o=readOptions(panel)
            o=defaultDualTdcOptions(); o.alignment.maxClockPpm=panel.Controls.MaxPpm.Value;
            o.alignment.matchTolerance=panel.Controls.Tolerance.Value*1e-12;
            o.histRange=[-1,1]*panel.Controls.HistRange.Value*1e-9;
            o.binWidth=panel.Controls.BinWidth.Value*1e-12;
            o.maxResidentBytes=panel.Controls.Memory.Value*1e9;
        end

        function importSelected(panel)
            panel.StatusLabel.Text='正在读取和分析四路文件…'; drawnow;
            try
                c=panel.Controls;
                result=importDualTdcFiles(c.F1.Value,c.F2.Value,c.S1.Value,c.S2.Value, ...
                    [c.UnitF.Value,c.UnitS.Value],panel.readOptions());
                panel.setResult(result);
            catch e, panel.fail(e); end
        end

        function runSharedSimulation(panel)
            panel.StatusLabel.Text='正在生成一次共享 SPD 电事件并分析…'; drawnow;
            try
                s=defaultDualTdcSimulation(); s.physical=panel.PhysicalProvider(); s.seed=s.physical.seed;
                values=panel.Controls.TdcTable.Data;
                for device={'F','S'}
                    name=device{1}; columns=2:3; if name=='S', columns=4:5; end
                    for row=1:size(values,1)
                        field=values{row,1}; v=cell2mat(values(row,columns));
                        if ismember(string(field),["resolution_ps","clockPpm","offset_s"])
                            if v(1)~=v(2), error('DualTDC:DeviceClock','%s must be common to both %s channels.',field,name); end
                            v=v(1);
                        end
                        s.(name).(field)=v;
                    end
                end
                panel.setResult(simulateDualTdc(s,panel.readOptions()));
            catch e, panel.fail(e); end
        end

        function setResult(panel,result)
            panel.Result=result;
            drawHistogram(panel.HistogramF,result.F,'FPGA full',result,'F');
            drawHistogram(panel.HistogramS,result.S,'Swabian full',result,'S');
            cla(panel.ResidualAxes); cla(panel.SweepAxes); hold(panel.ResidualAxes,'on');
            metrics={'全记录 Ch1 计数率',result.F.metrics.rate1_cps,result.S.metrics.rate1_cps,'cps'; ...
                '全记录 Ch2 计数率',result.F.metrics.rate2_cps,result.S.metrics.rate2_cps,'cps'; ...
                '全记录 Nraw',result.F.metrics.Nraw,result.S.metrics.Nraw,'count / 7 bins'; ...
                '全记录 Nacc',result.F.metrics.Nacc,result.S.metrics.Nacc,'count / -20:-14 bins'; ...
                '全记录 Nnet',result.F.metrics.NnetSigned,result.S.metrics.NnetSigned,'signed count'; ...
                '实际 bin 宽',result.F.options.binWidth*1e12,result.S.options.binWidth*1e12,'ps/bin'; ...
                '主窗实际全宽',result.F.metrics.actualWindow_ps,result.S.metrics.actualWindow_ps,'ps / 7 bins'; ...
                '全记录峰位置',result.F.metrics.peak_ps,result.S.metrics.peak_ps,'ps'; ...
                '全记录 Gaussian sigma',result.F.metrics.sigma_ps,result.S.metrics.sigma_ps,'ps'; ...
                '全记录 FWHM',result.F.metrics.FWHM_ps,result.S.metrics.FWHM_ps,'ps'};
            if result.status=="ALIGNED"
                for ch=1:2
                    c=result.alignment.(sprintf('channel%d',ch));
                    sample=unique(round(linspace(1,numel(c.residual_s),min(5000,numel(c.residual_s)))));
                    scatter(panel.ResidualAxes,c.timeF_s(sample),c.residual_s(sample)*1e12,4,'.','DisplayName',sprintf('SPD%d',ch));
                    metrics(end+1,:)={sprintf('SPD%d 共同 / 未关联',ch),sprintf('%d / %d',c.commonCount,c.uniqueF),sprintf('%d / %d',c.commonCount,c.uniqueS),'同通道 overlap'};
                    metrics(end+1,:)={sprintf('SPD%d 相对完整率',ch),c.relativeCompletenessF,c.relativeCompletenessS,'相对于另一设备'};
                    metrics(end+1,:)={sprintf('SPD%d 相对时钟频偏',ch),0,c.clockPpm,'ppm / S relative F'};
                end
                metrics(end+1,:)={'共同子集 Nraw',result.common.F.metrics.Nraw,result.common.S.metrics.Nraw,'count'};
                metrics(end+1,:)={'共同子集 Nnet',result.common.F.metrics.NnetSigned,result.common.S.metrics.NnetSigned,'signed count'};
                metrics(end+1,:)={'共同子集 FWHM',result.common.F.metrics.FWHM_ps,result.common.S.metrics.FWHM_ps,'ps'};
            end
            hold(panel.ResidualAxes,'off'); grid(panel.ResidualAxes,'on');
            xlabel(panel.ResidualAxes,'FPGA local time (s)'); ylabel(panel.ResidualAxes,'S - mapped F (ps)');
            title(panel.ResidualAxes,'相对时间残差（显示最多 5000 点/通道）');
            plot(panel.SweepAxes,result.F.sweep.actualWidth_ps,result.F.sweep.NnetSigned_count,'-o', ...
                result.S.sweep.actualWidth_ps,result.S.sweep.NnetSigned_count,'-s');
            xlabel(panel.SweepAxes,'实际窗口全宽 (ps)'); ylabel(panel.SweepAxes,'Nnet signed (count)');
            legend(panel.SweepAxes,{'FPGA','Swabian'},'Location','best'); grid(panel.SweepAxes,'on');
            panel.MetricsTable.Data=metrics;
            panel.StatusLabel.Tooltip=char(result.alignment.reason+" "+result.F.metrics.warnings+" "+result.S.metrics.warnings);
            if result.status=="ALIGNED"
                message="ALIGNED：共同事件关联通过质量检查。";
            else
                message="UNALIGNED：对齐不可靠，请检查文件、频偏范围和关联半宽。";
            end
            if strlength(result.F.metrics.warnings)>0 || strlength(result.S.metrics.warnings)>0
                message=message+" 指定旁窗可能包含真实峰尾。";
            end
            panel.StatusLabel.Text=char(message);
        end

        function folder=exportTo(panel,parent)
            if isempty(panel.Result), error('DualTDC:NoResult','Run or import an analysis first.'); end
            folder=exportDualTdcResults(panel.Result,parent);
        end
    end
    methods(Access=private)
        function browse(panel,name)
            [file,path]=uigetfile({'*.txt;*.bin','TXT / SSI DAQ BIN'},['选择 ' name]);
            if isequal(file,0), return; end
            panel.Controls.(name).Value=fullfile(path,file);
        end
        function exportSelected(panel)
            parent=uigetdir(pwd,'选择双 TDC 结果输出目录'); if isequal(parent,0), return; end
            try
                folder=panel.exportTo(parent); panel.StatusLabel.Text=['已导出：' folder];
            catch e, panel.fail(e); end
        end
        function fail(panel,e)
            panel.Result=[]; cla(panel.HistogramF); cla(panel.HistogramS); cla(panel.ResidualAxes); cla(panel.SweepAxes);
            panel.MetricsTable.Data={}; panel.StatusLabel.Text=['分析失败：' e.message];
            uialert(ancestor(panel.Parent,'figure'),e.message,'双 TDC 分析');
        end
    end
end

function drawHistogram(ax,r,label,result,device)
h=r.histogram; plot(ax,h.centers*1e12,h.counts,'DisplayName',label); hold(ax,'on');
plot(ax,h.centers*1e12,h.fitCounts,'--','DisplayName','Gaussian fit');
if result.status=="ALIGNED"
    common=result.common.(device).histogram;
    plot(ax,common.centers*1e12,common.counts,'DisplayName','Common events');
end
hold(ax,'off'); title(ax,label); xlabel(ax,'t_2 - t_1 (ps)'); ylabel(ax,'all-pairs count'); grid(ax,'on'); legend(ax,'Location','northwest');
if isfinite(h.peak) && isfinite(h.sigma)
    half=max(5*h.sigma,.5e-9); limits=[max(h.edges(1),h.peak-half),min(h.edges(end),h.peak+half)]*1e12;
    if diff(limits)>0, xlim(ax,limits); end
end
end
