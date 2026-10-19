classdef DualTdcComparisonPanel < handle
    %DUALTDCCOMPARISONPANEL Independent page inside the established GUI.
    properties
        Parent
        Controls=struct()
        Result=[]
        CachedResult=[]
        PhysicalProvider
        HistogramF
        HistogramS
        ResidualAxes
        SweepAxes
        MetricsTable
        StatusLabel
        OverlayAxes
        SyncAxes
        SyncRateAxes
        PerSecondTable
    end
    methods
        function panel=DualTdcComparisonPanel(parent,physicalProvider)
            panel.Parent=parent;
            if nargin<2, physicalProvider=@defaultParams; end
            panel.PhysicalProvider=physicalProvider;
            main=uigridlayout(parent,[1,2]); main.ColumnWidth={480,'1x'};
            left=uitabgroup(main);
            settings=uitab(left,'Title','四路 / 六路导入');
            simulationTab=uitab(left,'Title','共享 SPD 仿真');
            settingsLayout=uigridlayout(settings,[2,1]); settingsLayout.RowHeight={'1x',220};
            settingsLayout.Padding=[0 0 0 0];
            g=uigridlayout(settingsLayout,[28,3]); g.ColumnWidth={130,'1x',70};
            g.RowSpacing=4; g.Padding=[8 8 8 8]; g.Scrollable='on';
            g.RowHeight=repmat({28},1,28);
            names={'F1','F2','S1','S2','Fsync','Ssync'};
            for k=1:numel(names)
                uilabel(g,'Text',names{k}); panel.Controls.(names{k})=uieditfield(g,'text');
                name=names{k}; uibutton(g,'Text','选择…','ButtonPushedFcn',@(~,~)panel.browse(name));
            end
            panel.Controls.UseSync=uicheckbox(g,'Text','启用 SYNC 辅助对齐（可选）','Value',false);
            panel.Controls.UseSync.Layout.Column=[1,3];
            uilabel(g,'Text','SYNC 标称频率 Hz'); panel.Controls.SyncFrequency=uieditfield(g,'numeric','Value',500000,'Limits',[1 Inf]); uilabel(g,'Text','默认 2 μs');
            uilabel(g,'Text','SYNC 边沿'); panel.Controls.SyncEdge=uidropdown(g,'Items',{'rising','falling'}); uilabel(g,'Text','记录设置');
            uilabel(g,'Text','SYNC 模型'); panel.Controls.SyncModel=uidropdown(g,'Items',{'auto','affine','segmented'}); uilabel(g,'Text','独立验证');
            uilabel(g,'Text','验证块长度 s'); panel.Controls.SyncBlock=uieditfield(g,'numeric','Value',1,'Limits',[.001 Inf]); uilabel(g,'Text','默认 1 s');
            uilabel(g,'Text','声明采集时长 s'); panel.Controls.Acquisition=uieditfield(g,'numeric','Value',30,'Limits',[.001 Inf]); uilabel(g,'Text','非测得门宽');
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
                'Tooltip','默认 10 ps；修改后点击按当前参数重新计算，不重新读取文件。');
            uilabel(g,'Text','ps/bin');
            uilabel(g,'Text','符合窗总 bin 数 n');
            panel.Controls.MainBins=uieditfield(g,'numeric','Value',7,'Limits',[1 Inf],'RoundFractionalValues','on', ...
                'Tooltip','总宽 n×binWidth，默认7；偶数 n 时峰右侧多1 bin。'); uilabel(g,'Text','总 n bin');
            uilabel(g,'Text','偶然符合修正');
            panel.Controls.Acc=uidropdown(g,'Items',{'论文指定旁窗','无修正','理论法','旁带法','旁窗法','时间戳平移法'}, ...
                'ItemsData',{'protocol','none','theory','sideband','side-window','time-shift'}); uilabel(g,'Text','all-pairs');
            uilabel(g,'Text','论文旁窗近端 bin'); panel.Controls.SideNear=uieditfield(g,'numeric','Value',14,'Limits',[1 Inf],'RoundFractionalValues','on'); uilabel(g,'Text','峰前');
            uilabel(g,'Text','论文旁窗远端 bin'); panel.Controls.SideFar=uieditfield(g,'numeric','Value',20,'Limits',[1 Inf],'RoundFractionalValues','on'); uilabel(g,'Text','峰前');
            acc=defaults.accidental;
            uilabel(g,'Text','峰保护距离 ns'); panel.Controls.SideGuard=uieditfield(g,'numeric','Value',acc.sidebandGuard*1e9,'Limits',[0 Inf],'LowerLimitInclusive','off'); uilabel(g,'Text','旁带/旁窗');
            uilabel(g,'Text','旁窗左右对数 K'); panel.Controls.SideWindowPairs=uieditfield(g,'numeric','Value',acc.sideWindowPairs,'Limits',[1 Inf],'RoundFractionalValues','on'); uilabel(g,'Text','等宽窗');
            uilabel(g,'Text','平移起点 μs'); panel.Controls.ShiftStart=uieditfield(g,'numeric','Value',acc.timeShiftStart*1e6,'Limits',[0 Inf],'LowerLimitInclusive','off'); uilabel(g,'Text','循环平移');
            uilabel(g,'Text','平移步进 μs'); panel.Controls.ShiftStep=uieditfield(g,'numeric','Value',acc.timeShiftStep*1e6,'Limits',[0 Inf],'LowerLimitInclusive','off'); uilabel(g,'Text','循环平移');
            uilabel(g,'Text','平移次数 Nshift'); panel.Controls.ShiftCount=uieditfield(g,'numeric','Value',acc.timeShiftCount,'Limits',[1 Inf],'RoundFractionalValues','on', ...
                'Tooltip','平移法耗时随次数及扫描窗口数增加；不生成全量配对矩阵。'); uilabel(g,'Text','取均值');
            uilabel(g,'Text','内存预算 GB'); panel.Controls.Memory=uieditfield(g,'numeric','Value',2,'Limits',[.01,64]); uilabel(g,'Text','超限即报错');
            actions=uigridlayout(settingsLayout,[4,1]); actions.RowHeight={30,30,30,'1x'};
            uibutton(actions,'Text','导入并分析（四路 / 六路）','ButtonPushedFcn',@(~,~)panel.importSelected());
            panel.Controls.Recalculate=uibutton(actions,'Text','按当前参数重新计算（不重读文件）','Enable','off', ...
                'Tooltip','复用上次成功加载的时间戳；更改文件路径/TXT单位需重新导入。修改物理仿真参数不会重新生成事件。', ...
                'ButtonPushedFcn',@(~,~)panel.recalculateSelected());
            uibutton(actions,'Text','导出 CSV + 重叠图 PNG / PDF…','ButtonPushedFcn',@(~,~)panel.exportSelected());
            panel.StatusLabel=uilabel(actions,'Text','SYNC 是输入通道，不代表硬件锁钟。残差不能当作单台绝对抖动。','WordWrap','on');
            simGrid=uigridlayout(simulationTab,[3,1]); simGrid.RowHeight={64,260,40};
            uilabel(simGrid,'Text','仿真共享光源/光路/SPD：沿用原参数页。此处保留原四路仿真；SYNC 六路示例见文档。','WordWrap','on');
            s=defaultDualTdcSimulation();
            values={'jitter_ps',s.F.jitter_ps(1),s.F.jitter_ps(2),s.S.jitter_ps(1),s.S.jitter_ps(2); ...
                'resolution_ps',10,10,5,5;'deadTime_ns',2.33,2.33,1,1; ...
                'clockPpm',12,12,-6,-6;'offset_s',.002,.002,.07,.07; ...
                'channelBias_ps',0,20,10,-15;'recordProbability',.97,.98,.99,.99};
            panel.Controls.TdcTable=uitable(simGrid,'Data',values, ...
                'ColumnName',{'参数 / 单位','F1','F2','S1','S2'},'ColumnEditable',[false,true,true,true,true], ...
                'ColumnWidth',{135,60,60,60,60},'RowName',[]);
            uibutton(simGrid,'Text','共享 SPD 电事件仿真并分析','ButtonPushedFcn',@(~,~)panel.runSharedSimulation());
            tabs=uitabgroup(main);
            nativeTab=uitab(tabs,'Title','原始 / 共同事件'); overlayTab=uitab(tabs,'Title','重叠柱状图');
            syncTab=uitab(tabs,'Title','SYNC 质量 / 逐秒统计');
            plots=uigridlayout(nativeTab,[3,2]); plots.RowHeight={'1x','1x','1x'};
            panel.HistogramF=uiaxes(plots); panel.HistogramS=uiaxes(plots);
            panel.ResidualAxes=uiaxes(plots); panel.SweepAxes=uiaxes(plots);
            panel.MetricsTable=uitable(plots,'ColumnName',{'项目','FPGA','Swabian','范围/单位'},'RowName',[]);
            panel.MetricsTable.Layout.Column=[1,2];
            og=uigridlayout(overlayTab,[2,2]); og.RowHeight={30,'1x'};
            panel.Controls.OverlayGroup=uidropdown(og,'Items',{'full','overlap','common'},'ValueChangedFcn',@(~,~)panel.refreshOverlay());
            panel.Controls.OverlayNormalization=uidropdown(og,'Items',{'probability','count'},'ValueChangedFcn',@(~,~)panel.refreshOverlay());
            panel.OverlayAxes=uiaxes(og); panel.OverlayAxes.Layout.Column=[1,2];
            sg=uigridlayout(syncTab,[2,2]);
            panel.SyncAxes=uiaxes(sg); panel.SyncRateAxes=uiaxes(sg);
            panel.PerSecondTable=uitable(sg); panel.PerSecondTable.Layout.Column=[1,2];
        end

        function o=readOptions(panel)
            o=defaultDualTdcOptions(); o.alignment.maxClockPpm=panel.Controls.MaxPpm.Value;
            o.alignment.matchTolerance=panel.Controls.Tolerance.Value*1e-12;
            o.histRange=[-1,1]*panel.Controls.HistRange.Value*1e-9;
            o.binWidth=panel.Controls.BinWidth.Value*1e-12;
            o.mainBinCount=panel.Controls.MainBins.Value;
            o.sideBeforeBins=[panel.Controls.SideNear.Value,panel.Controls.SideFar.Value];
            o.accidental.method=string(panel.Controls.Acc.Value);
            o.accidental.sidebandGuard=panel.Controls.SideGuard.Value*1e-9;
            o.accidental.sideWindowPairs=panel.Controls.SideWindowPairs.Value;
            o.accidental.timeShiftStart=panel.Controls.ShiftStart.Value*1e-6;
            o.accidental.timeShiftStep=panel.Controls.ShiftStep.Value*1e-6;
            o.accidental.timeShiftCount=panel.Controls.ShiftCount.Value;
            o.maxResidentBytes=panel.Controls.Memory.Value*1e9;
            o.sync.enabled=panel.Controls.UseSync.Value;
            o.sync.nominalFrequency_Hz=panel.Controls.SyncFrequency.Value;
            o.sync.edge=string(panel.Controls.SyncEdge.Value); o.sync.model=string(panel.Controls.SyncModel.Value);
            o.sync.blockDuration_s=panel.Controls.SyncBlock.Value;
            o.sync.declaredAcquisition_s=panel.Controls.Acquisition.Value;
            o.computePerSecond=true;
        end

        function result=recalculateCurrent(panel)
            if isempty(panel.CachedResult)
                error('DualTDC:NoCachedData','请先成功导入时间戳或运行一次共享 SPD 仿真。');
            end
            options=panel.readOptions();
            panel.StatusLabel.Text='正在按当前参数重算缓存时间戳（不读取文件）…'; drawnow nocallbacks;
            result=recalculateDualTdc(panel.CachedResult,options);
            panel.setResult(result);
        end

        function importSelected(panel)
            panel.StatusLabel.Text='正在读取、审计和分析时间戳…'; drawnow;
            try
                c=panel.Controls;
                o=panel.readOptions();
                if o.sync.enabled
                    if isempty(c.Fsync.Value) || isempty(c.Ssync.Value), error('DualTDC:SyncFiles','启用 SYNC 时必须同时选择 Fsync 和 Ssync。'); end
                    result=importDualTdcSixFiles(c.F1.Value,c.F2.Value,c.Fsync.Value,c.S1.Value,c.S2.Value,c.Ssync.Value,[c.UnitF.Value,c.UnitS.Value],o);
                else
                    result=importDualTdcFiles(c.F1.Value,c.F2.Value,c.S1.Value,c.S2.Value,[c.UnitF.Value,c.UnitS.Value],o);
                end
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
                o=panel.readOptions(); o.sync.enabled=false;
                panel.setResult(simulateDualTdc(s,o));
            catch e, panel.fail(e); end
        end

        function setResult(panel,result)
            panel.Result=result;
            panel.CachedResult=result;
            panel.Controls.Recalculate.Enable='on';
            drawHistogram(panel.HistogramF,result.F,'FPGA full',result,'F');
            drawHistogram(panel.HistogramS,result.S,'Swabian full',result,'S');
            cla(panel.ResidualAxes,'reset'); cla(panel.SweepAxes,'reset'); hold(panel.ResidualAxes,'on');
            metrics={'全记录 Ch1 计数率',result.F.metrics.rate1_cps,result.S.metrics.rate1_cps,'cps'; ...
                '全记录 Ch2 计数率',result.F.metrics.rate2_cps,result.S.metrics.rate2_cps,'cps'; ...
                '全记录 Nraw',result.F.metrics.Nraw,result.S.metrics.Nraw,sprintf('count / %d bins',result.F.metrics.mainBinCount); ...
                '全记录 Nacc',result.F.metrics.Nacc,result.S.metrics.Nacc,char(result.F.metrics.accidentalMethod); ...
                '全记录 Nnet',result.F.metrics.NnetSigned,result.S.metrics.NnetSigned,'signed count'; ...
                '实际 bin 宽',result.F.options.binWidth*1e12,result.S.options.binWidth*1e12,'ps/bin'; ...
                '主窗实际全宽',result.F.metrics.actualWindow_ps,result.S.metrics.actualWindow_ps,'ps'; ...
                '全记录峰位置',result.F.metrics.peak_ps,result.S.metrics.peak_ps,'ps'; ...
                '全记录 Gaussian sigma',result.F.metrics.sigma_ps,result.S.metrics.sigma_ps,'ps'; ...
                '全记录 FWHM',result.F.metrics.FWHM_ps,result.S.metrics.FWHM_ps,'ps'};
            if ismember(result.status,["ALIGNED","PARTIAL"])
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
                metrics(end+1,:)={'共同时间段 Nraw',result.overlap.F.metrics.Nraw,result.overlap.S.metrics.Nraw,'count'};
                metrics(end+1,:)={'共同时间段 Nnet',result.overlap.F.metrics.NnetSigned,result.overlap.S.metrics.NnetSigned,'signed count'};
                metrics(end+1,:)={'共同时间段 FWHM',result.overlap.F.metrics.FWHM_ps,result.overlap.S.metrics.FWHM_ps,'ps'};
            end
            hold(panel.ResidualAxes,'off'); grid(panel.ResidualAxes,'on');
            xlabel(panel.ResidualAxes,'FPGA local time (s)'); ylabel(panel.ResidualAxes,'S - mapped F (ps)');
            title(panel.ResidualAxes,'相对时间残差（显示最多 5000 点/通道）');
            plot(panel.SweepAxes,result.F.sweep.actualWidth_ps,result.F.sweep.NnetSigned_count,'-o', ...
                result.S.sweep.actualWidth_ps,result.S.sweep.NnetSigned_count,'-s');
            xlabel(panel.SweepAxes,'实际窗口全宽 (ps)'); ylabel(panel.SweepAxes,'Nnet signed (count)');
            legend(panel.SweepAxes,{'FPGA','Swabian'},'Location','best'); grid(panel.SweepAxes,'on');
            panel.MetricsTable.Data=metrics;
            panel.refreshOverlay();
            cla(panel.SyncAxes,'reset'); cla(panel.SyncRateAxes,'reset');
            panel.PerSecondTable.Data={};
            if isfield(result,'perSecond'), panel.PerSecondTable.Data=result.perSecond; end
            if isfield(result,'sync')
                qf=result.sync.F; qs=result.sync.S; model=result.sync.model;
                syncMetrics={'SYNC 总计数',qf.count,qs.count,'count'; ...
                    'SYNC 观察计数率',qf.count/qf.activeSpan_s,qs.count/qs.activeSpan_s,'cps / observed span'; ...
                    'SYNC 活动跨度',qf.activeSpan_s,qs.activeSpan_s,'s / observed'; ...
                    'SYNC 周期',qf.period_s*1e6,qs.period_s*1e6,'μs'; ...
                    'SYNC 候选漏脉冲',qf.missingCandidateCount,qs.missingCandidateCount,'count / inferred'; ...
                    'SYNC 毛刺',qf.glitchCount,qs.glitchCount,'count'; ...
                    'SYNC QA',char(qf.qaFlag),char(qs.qaFlag),'audit'; ...
                    'SYNC 相对频偏',0,model.relativeClockPpm,'ppm / S relative F'; ...
                    'SYNC 整数周期差',0,model.cycleOffset,'cycles / SPD resolved'};
                panel.MetricsTable.Data=[syncMetrics;metrics];
                if ~isempty(model.drift)
                    plot(panel.SyncAxes,model.drift.startF_s,model.drift.relative_ppm,'-o');
                    center=median(model.drift.relative_ppm);
                    half=max(.001,1.2*max(abs(model.drift.relative_ppm-center)));
                    ylim(panel.SyncAxes,center+[-half half]);
                end
                title(panel.SyncAxes,'分块相对时钟频偏'); xlabel(panel.SyncAxes,'FPGA time (s)'); ylabel(panel.SyncAxes,'S relative F (ppm)');
                rf=qf.rates100ms; rs=qs.rates100ms;
                stairs(panel.SyncRateAxes,[rf.start_s;rf.end_s(end)],[rf.sync_rate_cps;rf.sync_rate_cps(end)]);
                hold(panel.SyncRateAxes,'on');
                stairs(panel.SyncRateAxes,[rs.start_s;rs.end_s(end)],[rs.sync_rate_cps;rs.sync_rate_cps(end)]);
                hold(panel.SyncRateAxes,'off');
                title(panel.SyncRateAxes,'SYNC 输入计数率（设备各自时间轴）'); xlabel(panel.SyncRateAxes,'Local time (s)'); ylabel(panel.SyncRateAxes,'cps');
                legend(panel.SyncRateAxes,{'FPGA','Swabian'});
            end
            panel.StatusLabel.Tooltip=char(result.alignment.reason+" "+result.F.metrics.warnings+" "+result.S.metrics.warnings);
            if result.status=="ALIGNED"
                message="ALIGNED：共同事件关联通过质量检查。";
            elseif result.status=="PARTIAL"
                message="PARTIAL：仅 SYNC 支持区间内关联；外推区间不输出匹配。";
            else
                message="UNALIGNED：对齐不可靠，请检查文件、频偏范围和关联半宽。";
            end
            if strlength(result.F.metrics.warnings)>0 || strlength(result.S.metrics.warnings)>0
                message=message+" 偶然符合估计有提示（见悬停说明）。";
            end
            importQuality=timestampImportQuality(result.data);
            if ~isempty(importQuality) && any(importQuality.was_reordered)
                count=nnz(importQuality.was_reordered);
                note=sprintf(' 已自动升序重排 %d 路时间戳（原文件未修改）。',count);
                message=message+string(note);
                panel.StatusLabel.Tooltip=[panel.StatusLabel.Tooltip note];
            end
            panel.StatusLabel.Text=char(message);
            if isfield(result,'recalculation')
                panel.StatusLabel.Text=['已按当前参数重算并刷新所有图（未重读文件）。' panel.StatusLabel.Text];
            end
            % Flush completed graphics synchronously, including hidden tabs;
            % do not dispatch a queued button callback while committing plots.
            drawnow nocallbacks;
        end

        function refreshOverlay(panel)
            if isempty(panel.Result), return; end
            drawDualTdcOverlay(panel.OverlayAxes,panel.Result,string(panel.Controls.OverlayGroup.Value),string(panel.Controls.OverlayNormalization.Value),true);
            drawnow nocallbacks;
        end

        function folder=exportTo(panel,parent)
            if isempty(panel.Result), error('DualTDC:NoResult','Run or import an analysis first.'); end
            folder=exportDualTdcResults(panel.Result,parent);
        end
    end
    methods(Access=private)
        function recalculateSelected(panel)
            try, panel.recalculateCurrent(); catch e, panel.fail(e); end
        end
        function browse(panel,name)
            [file,path]=uigetfile({'*.txt;*.bin;*.ttbin','TXT / SSI DAQ BIN (.ttbin 需转换)'},['选择 ' name]);
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
            panel.Result=[];
            for ax=[panel.HistogramF,panel.HistogramS,panel.ResidualAxes,panel.SweepAxes,panel.OverlayAxes,panel.SyncAxes,panel.SyncRateAxes]
                cla(ax,'reset');
            end
            panel.MetricsTable.Data={}; panel.StatusLabel.Text=['分析失败：' e.message];
            panel.PerSecondTable.Data={}; drawnow nocallbacks;
            uialert(ancestor(panel.Parent,'figure'),e.message,'双 TDC 分析');
        end
    end
end

function drawHistogram(ax,r,label,result,device)
cla(ax,'reset');
h=r.histogram; plot(ax,h.centers*1e12,h.counts,'DisplayName',label); hold(ax,'on');
plot(ax,h.centers*1e12,h.fitCounts,'--','DisplayName','Gaussian fit');
if ismember(result.status,["ALIGNED","PARTIAL"])
    common=result.common.(device).histogram;
    plot(ax,common.centers*1e12,common.counts,'DisplayName','Common events');
end
if isfinite(r.metrics.windowLeft_ps) && isfinite(r.metrics.windowRight_ps)
    xline(ax,r.metrics.windowLeft_ps,':k','HandleVisibility','off','Tag','main_window_left');
    xline(ax,r.metrics.windowRight_ps,':k','HandleVisibility','off','Tag','main_window_right');
end
hold(ax,'off'); title(ax,sprintf('%s | %d bin | %s',label,r.metrics.mainBinCount,r.metrics.accidentalMethod));
xlabel(ax,'t_2 - t_1 (ps)'); ylabel(ax,'all-pairs count'); grid(ax,'on'); legend(ax,'Location','northwest');
if isfinite(h.peak) && isfinite(h.sigma)
    half=max(5*h.sigma,.5e-9); limits=[max(h.edges(1),h.peak-half),min(h.edges(end),h.peak+half)]*1e12;
    if diff(limits)>0, xlim(ax,limits); end
end
end
