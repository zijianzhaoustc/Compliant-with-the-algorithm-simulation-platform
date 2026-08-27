classdef CoincidenceSimulatorApp < handle
    %COINCIDENCESIMULATORAPP 文档定义的 CW-SPDC/TDC 符合仿真与实测分析平台。
    %   GUI 只负责参数、数据源和显示；runSimulation、importTimestampFiles
    %   与 analyzeTimestampData 负责计算，因此仿真和实测 TXT 共用同一算法。

    properties
        UIFigure
        Controls struct = struct()
        ParameterTabs
        SourceTab
        DetectorTab
        AlgorithmTab
        HistogramAxes
        TimestampAxes
        SweepRateAxes
        SweepMetricAxes
        ResultTable
        StatusLabel
        LastResult
    end

    methods
        function app=CoincidenceSimulatorApp()
            app.buildUI();
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure), delete(app.UIFigure); end
        end
    end

    methods (Access=private)
        function buildUI(app)
            p=defaultParams();
            screen=get(groot,'ScreenSize');
            % 主界面始终保持 16:9；在小屏幕上按相同比例缩小，并为
            % Windows 任务栏、标题栏和屏幕边缘预留空间。
            scale=min([100,(screen(3)-40)/16,(screen(4)-90)/9]);
            figWidth=16*scale; figHeight=9*scale;
            figLeft=max(1,screen(1)+(screen(3)-figWidth)/2);
            figBottom=max(1,screen(2)+(screen(4)-figHeight)/2);
            app.UIFigure=uifigure('Name','MATLAB 光子符合仿真与时间戳分析平台', ...
                'Position',[figLeft figBottom figWidth figHeight],'Color',[0.965 0.975 0.985]);
            main=uigridlayout(app.UIFigure,[1 3]);
            main.ColumnWidth={520,'1x',430}; main.Padding=[8 8 8 8]; main.ColumnSpacing=8;

            % 左栏：上方三个自适应参数页，下方局部时间戳及时间范围设置。
            left=uigridlayout(main,[2 1]); left.RowHeight={'3x','2x'}; left.RowSpacing=8;
            app.ParameterTabs=uitabgroup(left);
            app.buildSourceTab(p);
            app.buildDetectorTab(p);
            app.buildAlgorithmTab(p);
            app.buildTimestampPanel(left);

            % 中栏：原局部时间戳区域重新分配给符合直方图和 Parameter Sweep。
            center=uigridlayout(main,[2 1]); center.RowHeight={'1.15x','1x'}; center.RowSpacing=8;
            app.HistogramAxes=uiaxes(center); title(app.HistogramAxes,'符合时间差直方图');
            xlabel(app.HistogramAxes,'t_{Stop}-t_{Start} (ns)'); ylabel(app.HistogramAxes,'计数'); grid(app.HistogramAxes,'on');
            % 扫描图直接放在无标题、无边框容器中，减少界面杂项。
            sweepPanel=uipanel(center,'Title','','BorderType','none');
            sweepGrid=uigridlayout(sweepPanel,[1 2]); sweepGrid.Padding=[4 4 4 4];
            app.SweepRateAxes=uiaxes(sweepGrid); title(app.SweepRateAxes,'符合速率'); xlabel(app.SweepRateAxes,'窗口全宽 (ns)'); ylabel(app.SweepRateAxes,'cps'); grid(app.SweepRateAxes,'on');
            app.SweepMetricAxes=uiaxes(sweepGrid); title(app.SweepMetricAxes,'算法指标'); xlabel(app.SweepMetricAxes,'窗口全宽 (ns)'); ylim(app.SweepMetricAxes,[0 1.05]); grid(app.SweepMetricAxes,'on');

            % 右栏：中文结果列表和数据操作。
            right=uigridlayout(main,[8 1]);
            right.RowHeight={'1x',38,38,38,38,38,38,26}; right.RowSpacing=6;
            app.ResultTable=uitable(right,'ColumnName',{'指标','数值','说明'}, ...
                'ColumnWidth',{205,90,'auto'},'RowName',[]);
            app.addActionButton(right,2,'运行新仿真',[0.12 0.45 0.82],@(~,~)app.runNewSimulation());
            app.addActionButton(right,3,'按当前算法重新计算',[0.18 0.58 0.42],@(~,~)app.recalculate());
            app.addActionButton(right,4,'导入 Start/Stop TXT',[0.36 0.50 0.70],@(~,~)app.importTimestamps());
            app.addActionButton(right,5,'导入设置参数 MAT',[0.42 0.50 0.58],@(~,~)app.importSettings());
            app.addActionButton(right,6,'扫描符合窗口',[0.58 0.42 0.68],@(~,~)app.runSweep());
            app.addActionButton(right,7,'选择性导出…',[0.78 0.43 0.18],@(~,~)app.openExport());
            app.StatusLabel=uilabel(right,'Text','就绪：可运行仿真或导入双通道 TXT', ...
                'FontColor',[.18 .25 .34]); app.StatusLabel.Layout.Row=8;
        end

        function buildSourceTab(app,p)
            app.SourceTab=uitab(app.ParameterTabs,'Title','光源光路参数','Scrollable','off');
            g=uigridlayout(app.SourceTab,[13 2]); g.ColumnWidth={'1x',155};
            g.RowHeight=repmat({26},1,13); g.RowSpacing=4; g.Padding=[8 8 8 8];
            app.Controls.SourceMode=app.addDrop(g,1,'仿真模式',{'直接光子对率','泵浦物理模型'}, ...
                {'direct','pump'},p.source.mode);
            app.Controls.PairRate=app.addNum(g,2,'光子对生成率 Rpair (pair/s)',p.source.pairRate);
            app.Controls.Time=app.addNum(g,3,'测量时间 T (s)',p.measurementTime);
            app.Controls.Seed=app.addNum(g,4,'随机种子 seed',p.seed);
            app.Controls.PumpPower=app.addNum(g,5,'泵浦功率 Pp (mW)',p.source.pumpPower*1e3);
            app.Controls.Wavelength=app.addNum(g,6,'泵浦波长 λp (nm)',p.source.pumpWavelength*1e9);
            app.Controls.EtaLaser=app.addNum(g,7,'激光器-BBO效率 η1',p.source.laserToCrystalTransmission);
            app.Controls.EtaSPDC=app.addNum(g,8,'有效转换概率 ηSPDC',p.source.spdcProbability);
            app.Controls.TransA=app.addNum(g,9,'A光路传输效率 ηA1',p.optics.A.transmission);
            app.Controls.TransB=app.addNum(g,10,'B光路传输效率 ηB1',p.optics.B.transmission);
            app.Controls.DelayA=app.addNum(g,11,'A光路固定延迟 (ns)',p.optics.A.delay*1e9);
            app.Controls.DelayB=app.addNum(g,12,'B光路固定延迟 (ns)',p.optics.B.delay*1e9);
            note=uilabel(g,'Text','计算内核统一使用 SI 单位；此页按标签自动换算。','FontColor',[.35 .4 .48]);
            note.Layout.Row=13; note.Layout.Column=[1 2];
        end

        function buildDetectorTab(app,p)
            app.DetectorTab=uitab(app.ParameterTabs,'Title','探测器TDC参数','Scrollable','off');
            g=uigridlayout(app.DetectorTab,[15 4]);
            g.ColumnWidth={120,'1x',120,'1x'}; g.RowHeight=repmat({26},1,15); g.RowSpacing=4; g.ColumnSpacing=4; g.Padding=[6 6 6 6];
            app.addPairHeader(g);
            [app.Controls.PDEA,app.Controls.PDEB]=app.addPair(g,2,'探测效率 ηdet',p.detector.A.efficiency,p.detector.B.efficiency);
            [app.Controls.RecA,app.Controls.RecB]=app.addPair(g,3,'记录效率 ηrec',p.detector.A.recordEfficiency,p.detector.B.recordEfficiency);
            [app.Controls.DarkA,app.Controls.DarkB]=app.addPair(g,4,'暗计数 Rd (cps)',p.detector.A.darkRate,p.detector.B.darkRate);
            [app.Controls.BgA,app.Controls.BgB]=app.addPair(g,5,'背景计数 Rbg (cps)',p.detector.A.backgroundRate,p.detector.B.backgroundRate);
            [app.Controls.JitterA,app.Controls.JitterB]=app.addPair(g,6,'探测抖动 σ (ps)',p.detector.A.jitter*1e12,p.detector.B.jitter*1e12);
            [app.Controls.DeadA,app.Controls.DeadB]=app.addPair(g,7,'死时间 τd (ns)',p.detector.A.deadTime*1e9,p.detector.B.deadTime*1e9);
            [app.Controls.ApA,app.Controls.ApB]=app.addPair(g,8,'后脉冲概率 Pap',p.detector.A.afterpulseProbability,p.detector.B.afterpulseProbability);
            [app.Controls.ApTauA,app.Controls.ApTauB]=app.addPair(g,9,'后脉冲常数 (ns)',p.detector.A.afterpulseLifetime*1e9,p.detector.B.afterpulseLifetime*1e9);
            [app.Controls.TdcJitterA,app.Controls.TdcJitterB]=app.addPair(g,10,'TDC抖动 (ps)',p.tdc.A.jitter*1e12,p.tdc.B.jitter*1e12);
            [app.Controls.BiasA,app.Controls.BiasB]=app.addPair(g,11,'通道偏置 (ps)',p.tdc.A.bias*1e12,p.tdc.B.bias*1e12);
            app.Controls.Resolution=app.addWideNum(g,12,'TDC分辨率 LSB (ps)',p.tdc.resolution*1e12);
            app.Controls.DNL=app.addHalfNum(g,13,1,'DNL (LSB)',p.tdc.dnl);
            app.Controls.INL=app.addHalfNum(g,13,3,'INL (LSB)',p.tdc.inl);
            app.Controls.EnableDark=app.addHalfCheck(g,14,1,'启用暗计数',p.detector.enableDark);
            app.Controls.EnableDead=app.addHalfCheck(g,14,3,'启用死时间',p.detector.enableDeadTime);
            app.Controls.EnableAfter=app.addHalfCheck(g,15,1,'启用后脉冲',p.detector.enableAfterpulse);
            app.Controls.EnableTdcJitter=app.addHalfCheck(g,15,3,'启用TDC抖动',p.tdc.enableJitter);
        end

        function buildAlgorithmTab(app,p)
            app.AlgorithmTab=uitab(app.ParameterTabs,'Title','算法设置','Scrollable','off');
            g=uigridlayout(app.AlgorithmTab,[18 2]); g.ColumnWidth={'1x',210};
            g.RowHeight=repmat({23},1,18); g.RowSpacing=2; g.Padding=[7 6 7 6];
            app.Controls.Range=app.addNum(g,1,'时间谱半范围 Tt (ns)',max(abs(p.algorithm.histRange))*1e9);
            app.Controls.Bin=app.addNum(g,2,'直方图 bin 宽 (ps)',p.algorithm.binWidth*1e12);
            app.Controls.Peak=app.addDrop(g,3,'寻峰方式',{'最大值寻峰','高斯拟合寻峰'}, ...
                {'maximum','gaussian'},p.algorithm.peakMethod);
            app.Controls.Match=app.addDrop(g,4,'时间匹配规则', ...
                {'单对单（后继首个）','多对单（Stop可复用）','单对多','多对多', ...
                '最近邻匹配（不复用）','最近邻匹配（复用）','时间顺序贪婪一对一'}, ...
                {'one-to-one','many-to-one','one-to-many','many-to-many', ...
                'nearest-no-reuse','nearest-reuse','greedy-chronological'},p.algorithm.matchMethod);
            app.Controls.WindowMode=app.addDrop(g,5,'符合窗口方式',{'固定全宽','峰值左右 nσ','峰值左右 n bin','峰值左右 n FWHM'}, ...
                {'fixed','sigma','bins','fwhm'},p.algorithm.windowMode);
            app.Controls.Window=app.addNum(g,6,'固定窗口全宽 (ns)',p.algorithm.window*1e9);
            app.Controls.WindowN=app.addNum(g,7,'自动窗口系数 n',p.algorithm.windowMultiplier);
            app.Controls.Acc=app.addDrop(g,8,'偶然符合修正', ...
                {'无修正','理论估计','旁带法','旁窗法','时间戳平移法'}, ...
                {'none','theory','sideband','side-window','time-shift'},p.algorithm.accidentalMethod);
            app.Controls.SideGuard=app.addNum(g,9,'峰保护距离 (ns)',p.algorithm.sidebandGuard*1e9);
            app.Controls.SideWindowPairs=app.addNum(g,10,'旁窗左右对数 K',p.algorithm.sideWindowPairs);
            app.Controls.ShiftStart=app.addNum(g,11,'平移起点 (μs)',p.algorithm.timeShiftStart*1e6);
            app.Controls.ShiftStep=app.addNum(g,12,'平移步进 (μs)',p.algorithm.timeShiftStep*1e6);
            app.Controls.ShiftCount=app.addNum(g,13,'平移次数 Nshift',p.algorithm.timeShiftCount);
            app.Controls.SweepStart=app.addNum(g,14,'扫描起点 (ns)',0.1);
            app.Controls.SweepStop=app.addNum(g,15,'扫描终点 (ns)',8);
            app.Controls.SweepStep=app.addNum(g,16,'扫描步进 (ns)',0.1);
            app.Controls.ImportUnit=app.addDrop(g,17,'TXT原始时间单位',{'ps','ns','s','LSB'}, ...
                {1e-12,1e-9,1,NaN},1e-12);
            app.Controls.ImportLSB=app.addNum(g,18,'TXT的 LSB (ps)',p.tdc.resolution*1e12);
        end

        function buildTimestampPanel(app,parent)
            panel=uipanel(parent,'Title','局部时间戳与匹配');
            g=uigridlayout(panel,[2 1]); g.RowHeight={'1x',62}; g.Padding=[5 5 5 5];
            app.TimestampAxes=uiaxes(g); title(app.TimestampAxes,'选定时间范围内时间戳与匹配');
            xlabel(app.TimestampAxes,'相对时间 (μs)'); yticks(app.TimestampAxes,[0 1]);
            yticklabels(app.TimestampAxes,{'Stop','Start'}); grid(app.TimestampAxes,'on');

            settings=uigridlayout(g,[2 5]); settings.Layout.Row=2;
            settings.ColumnWidth={88,75,98,75,'1x'}; settings.RowHeight={26,26}; settings.Padding=[2 2 2 2];
            label=uilabel(settings,'Text','时间起点 (μs)'); label.Layout.Row=1; label.Layout.Column=1;
            app.Controls.ViewStart=uieditfield(settings,'numeric','Value',0,'Limits',[0 Inf]);
            app.Controls.ViewStart.Layout.Row=1; app.Controls.ViewStart.Layout.Column=2;
            label=uilabel(settings,'Text','时间长度 (μs)'); label.Layout.Row=1; label.Layout.Column=3;
            app.Controls.ViewLength=uieditfield(settings,'numeric','Value',10,'Limits',[0.001 100]);
            app.Controls.ViewLength.Layout.Row=1; app.Controls.ViewLength.Layout.Column=4;
            app.Controls.ShowTP=uicheckbox(settings,'Text','显示 TP','Value',true, ...
                'ValueChangedFcn',@(~,~)app.updateTimestampPlot());
            app.Controls.ShowTP.Layout.Row=2; app.Controls.ShowTP.Layout.Column=1;
            app.Controls.ShowFP=uicheckbox(settings,'Text','显示 FP','Value',true, ...
                'ValueChangedFcn',@(~,~)app.updateTimestampPlot());
            app.Controls.ShowFP.Layout.Row=2; app.Controls.ShowFP.Layout.Column=2;
            refresh=uibutton(settings,'Text','刷新显示','ButtonPushedFcn',@(~,~)app.updateTimestampPlot());
            refresh.Layout.Row=1; refresh.Layout.Column=5;
            note=uilabel(settings,'Text','橙色：可记录真实对；红色：TP；蓝色：FP（FP 最多绘制 300 条）。', ...
                'FontColor',[.35 .4 .48]); note.Layout.Row=2; note.Layout.Column=[3 5];
        end

        function p=readParameters(app)
            c=app.Controls; p=defaultParams();
            p.source.mode=string(c.SourceMode.Value); p.source.pairRate=c.PairRate.Value;
            p.source.pumpPower=c.PumpPower.Value*1e-3; p.source.pumpWavelength=c.Wavelength.Value*1e-9;
            p.source.laserToCrystalTransmission=c.EtaLaser.Value; p.source.spdcProbability=c.EtaSPDC.Value;
            p.measurementTime=c.Time.Value; p.seed=round(c.Seed.Value);
            p.optics.A.transmission=c.TransA.Value; p.optics.B.transmission=c.TransB.Value;
            p.optics.A.delay=c.DelayA.Value*1e-9; p.optics.B.delay=c.DelayB.Value*1e-9;
            for ch=["A","B"]
                suffix=char(ch);
                p.detector.(ch).efficiency=c.(['PDE' suffix]).Value;
                p.detector.(ch).recordEfficiency=c.(['Rec' suffix]).Value;
                p.detector.(ch).darkRate=c.(['Dark' suffix]).Value;
                p.detector.(ch).backgroundRate=c.(['Bg' suffix]).Value;
                p.detector.(ch).jitter=c.(['Jitter' suffix]).Value*1e-12;
                p.detector.(ch).deadTime=c.(['Dead' suffix]).Value*1e-9;
                p.detector.(ch).afterpulseProbability=c.(['Ap' suffix]).Value;
                p.detector.(ch).afterpulseLifetime=c.(['ApTau' suffix]).Value*1e-9;
                p.tdc.(ch).jitter=c.(['TdcJitter' suffix]).Value*1e-12;
                p.tdc.(ch).bias=c.(['Bias' suffix]).Value*1e-12;
            end
            p.detector.enableDark=c.EnableDark.Value; p.detector.enableDeadTime=c.EnableDead.Value;
            p.detector.enableAfterpulse=c.EnableAfter.Value; p.tdc.enableJitter=c.EnableTdcJitter.Value;
            p.tdc.resolution=c.Resolution.Value*1e-12; p.tdc.dnl=c.DNL.Value; p.tdc.inl=c.INL.Value;
            range=c.Range.Value*1e-9; p.algorithm.histRange=[-range range];
            p.algorithm.binWidth=c.Bin.Value*1e-12; p.algorithm.peakMethod=string(c.Peak.Value);
            p.algorithm.matchMethod=string(c.Match.Value); p.algorithm.windowMode=string(c.WindowMode.Value);
            p.algorithm.window=c.Window.Value*1e-9; p.algorithm.windowMultiplier=c.WindowN.Value;
            p.algorithm.accidentalMethod=string(c.Acc.Value);
            p.algorithm.sidebandGuard=c.SideGuard.Value*1e-9;
            p.algorithm.sideWindowPairs=round(c.SideWindowPairs.Value);
            p.algorithm.timeShiftStart=c.ShiftStart.Value*1e-6;
            p.algorithm.timeShiftStep=c.ShiftStep.Value*1e-6;
            p.algorithm.timeShiftCount=round(c.ShiftCount.Value);
        end

        function populateControls(app,p)
            % 从导入的 params 结构体恢复界面；只接受当前版本已知字段。
            c=app.Controls;
            c.SourceMode.Value=char(p.source.mode); c.PairRate.Value=p.source.pairRate;
            c.PumpPower.Value=p.source.pumpPower*1e3; c.Wavelength.Value=p.source.pumpWavelength*1e9;
            c.EtaLaser.Value=p.source.laserToCrystalTransmission; c.EtaSPDC.Value=p.source.spdcProbability;
            c.Time.Value=p.measurementTime; c.Seed.Value=p.seed;
            c.TransA.Value=p.optics.A.transmission; c.TransB.Value=p.optics.B.transmission;
            c.DelayA.Value=p.optics.A.delay*1e9; c.DelayB.Value=p.optics.B.delay*1e9;
            for ch=["A","B"]
                s=char(ch); c.(['PDE' s]).Value=p.detector.(ch).efficiency;
                c.(['Rec' s]).Value=p.detector.(ch).recordEfficiency;
                c.(['Dark' s]).Value=p.detector.(ch).darkRate; c.(['Bg' s]).Value=p.detector.(ch).backgroundRate;
                c.(['Jitter' s]).Value=p.detector.(ch).jitter*1e12; c.(['Dead' s]).Value=p.detector.(ch).deadTime*1e9;
                c.(['Ap' s]).Value=p.detector.(ch).afterpulseProbability; c.(['ApTau' s]).Value=p.detector.(ch).afterpulseLifetime*1e9;
                c.(['TdcJitter' s]).Value=p.tdc.(ch).jitter*1e12; c.(['Bias' s]).Value=p.tdc.(ch).bias*1e12;
            end
            c.EnableDark.Value=p.detector.enableDark; c.EnableDead.Value=p.detector.enableDeadTime;
            c.EnableAfter.Value=p.detector.enableAfterpulse; c.EnableTdcJitter.Value=p.tdc.enableJitter;
            c.Resolution.Value=p.tdc.resolution*1e12; c.DNL.Value=p.tdc.dnl; c.INL.Value=p.tdc.inl;
            c.Range.Value=max(abs(p.algorithm.histRange))*1e9; c.Bin.Value=p.algorithm.binWidth*1e12;
            c.Peak.Value=char(p.algorithm.peakMethod); c.Match.Value=char(p.algorithm.matchMethod);
            c.WindowMode.Value=char(p.algorithm.windowMode); c.Window.Value=p.algorithm.window*1e9;
            c.WindowN.Value=p.algorithm.windowMultiplier; c.Acc.Value=char(p.algorithm.accidentalMethod);
            c.SideGuard.Value=p.algorithm.sidebandGuard*1e9;
            c.SideWindowPairs.Value=p.algorithm.sideWindowPairs;
            c.ShiftStart.Value=p.algorithm.timeShiftStart*1e6;
            c.ShiftStep.Value=p.algorithm.timeShiftStep*1e6;
            c.ShiftCount.Value=p.algorithm.timeShiftCount;
        end

        function runNewSimulation(app)
            app.setBusy('正在生成新的 Monte Carlo 时间戳并分析…');
            % 新仿真开始时立即删除上一批时间戳和连线，避免计算期间
            % 仍显示旧数据，也防止新旧图元在后续刷新中叠加。
            app.resetTimestampAxes('正在生成新的时间戳…');
            drawnow;
            try
                app.LastResult=runSimulation(app.readParameters());
                app.refreshAll();
                app.StatusLabel.Text=sprintf('仿真完成：Start %d，Stop %d，峰值 %.4f ns', ...
                    numel(app.LastResult.A.time),numel(app.LastResult.B.time),app.LastResult.hist.peak*1e9);
            catch ME
                app.showError(ME,'仿真失败');
            end
        end

        function recalculate(app)
            if isempty(app.LastResult), app.runNewSimulation(); return; end
            app.setBusy('复用当前时间戳，正在按新算法参数重新计算…');
            try
                app.LastResult=recalculateAnalysis(app.LastResult,app.readParameters());
                app.refreshAll(); app.StatusLabel.Text='重新计算完成（未重新生成时间戳）';
            catch ME
                app.showError(ME,'重新计算失败');
            end
        end

        function importTimestamps(app)
            [sf,sp]=uigetfile({'*.txt','TXT 时间戳'},'选择 Start 通道时间戳'); if isequal(sf,0), return; end
            [tf,tp]=uigetfile({'*.txt','TXT 时间戳'},'选择 Stop 通道时间戳',sp); if isequal(tf,0), return; end
            factor=app.Controls.ImportUnit.Value;
            if isnan(factor), factor=app.Controls.ImportLSB.Value*1e-12; end
            app.setBusy('正在读取并分析双通道 TXT（大文件可能需要一些时间）…');
            try
                app.LastResult=importTimestampFiles(fullfile(sp,sf),fullfile(tp,tf),factor,app.readParameters());
                app.Controls.Time.Value=app.LastResult.params.measurementTime;
                app.refreshAll();
                app.StatusLabel.Text=sprintf('实测数据导入完成：时长 %.6g s，Start %d，Stop %d', ...
                    app.LastResult.params.measurementTime,numel(app.LastResult.A.time),numel(app.LastResult.B.time));
            catch ME
                app.showError(ME,'导入时间戳失败');
            end
        end

        function importSettings(app)
            [file,path]=uigetfile({'*.mat','MAT 参数文件'},'导入设置参数'); if isequal(file,0), return; end
            try
                data=load(fullfile(path,file));
                if isfield(data,'params')
                    p=data.params;
                elseif isfield(data,'p')
                    p=data.p;
                elseif isfield(data,'out') && isfield(data.out,'params')
                    p=data.out.params;
                else
                    error('CoincidenceSim:MissingParams','MAT 文件中未找到 params、p 或 out.params。');
                end
                % 旧版 MAT 只有单个 timeShift，导入时将它迁移为新的平移起点。
                if isfield(p,'algorithm') && isfield(p.algorithm,'timeShift') && ...
                        ~isfield(p.algorithm,'timeShiftStart')
                    p.algorithm.timeShiftStart=p.algorithm.timeShift;
                end
                p=mergeParamsWithDefaults(defaultParams(),p);
                if string(p.algorithm.matchMethod)=="all-pairs", p.algorithm.matchMethod="many-to-many"; end
                if string(p.algorithm.matchMethod)=="nearest", p.algorithm.matchMethod="nearest-reuse"; end
                p=validateParams(p); app.populateControls(p); app.StatusLabel.Text='设置参数已导入；点击运行或重新计算生效';
            catch ME
                app.showError(ME,'导入设置失败');
            end
        end

        function runSweep(app)
            if isempty(app.LastResult), app.runNewSimulation(); end
            if isempty(app.LastResult), return; end
            c=app.Controls; start=c.SweepStart.Value; stop=c.SweepStop.Value; step=c.SweepStep.Value;
            if step<=0 || stop<start, uialert(app.UIFigure,'扫描步进必须为正，终点不得小于起点。','扫描参数错误'); return; end
            widths=(start:step:stop)*1e-9;
            if numel(widths)>500, uialert(app.UIFigure,'扫描点数超过 500，请增大步进。','扫描参数错误'); return; end
            app.setBusy('正在扫描符合窗口…');
            try
                s=sweepCoincidenceWindow(app.LastResult,widths);
                % 保存本次扫描数据，供选择性导出直接生成纵向窗口表。
                app.LastResult.sweep=s;
                cla(app.SweepRateAxes); plot(app.SweepRateAxes,widths*1e9,[s.Rraw s.Racc s.Rnet],'LineWidth',1.25);
                legend(app.SweepRateAxes,{'原始符合','偶然符合','净符合'},'Location','best');
                cla(app.SweepMetricAxes); plot(app.SweepMetricAxes,widths*1e9,[s.Precision s.Recall s.F1],'LineWidth',1.25);
                legend(app.SweepMetricAxes,{'查准率','查全率','F1'},'Location','best'); ylim(app.SweepMetricAxes,[0 1.05]);
                app.StatusLabel.Text=sprintf('符合窗口扫描完成：%d 个点',numel(widths));
            catch ME
                app.showError(ME,'窗口扫描失败');
            end
        end

        function refreshAll(app)
            app.updateHistogram(); app.updateTimestampPlot(); app.updateResultTable();
        end

        function updateHistogram(app)
            if isempty(app.LastResult), return; end
            o=app.LastResult; h=o.hist; ax=app.HistogramAxes; cla(ax);
            bar(ax,h.centers*1e9,h.counts,1,'FaceColor',[.28 .57 .82],'EdgeColor','none'); hold(ax,'on');
            if any(isfinite(h.fitCounts)), plot(ax,h.centers*1e9,h.fitCounts,'Color',[.93 .55 .12],'LineWidth',1.5); end
            xline(ax,h.peak*1e9,'--r','峰值','LineWidth',1.3);
            xline(ax,(h.peak-o.raw.window/2)*1e9,'--k','窗口');
            xline(ax,(h.peak+o.raw.window/2)*1e9,'--k'); hold(ax,'off');
            title(ax,sprintf('符合直方图：峰值 %.4f ns，σ %.3f ps，窗口全宽 %.3f ns', ...
                h.peak*1e9,h.sigma*1e12,o.raw.window*1e9));
        end

        function updateTimestampPlot(app)
            if isempty(app.LastResult), return; end
            o=app.LastResult; ax=app.TimestampAxes;
            % cla reset 和显式删除图例确保旧仿真的连线句柄不会残留。
            app.resetTimestampAxes('选定时间范围内时间戳与匹配');
            hold(ax,'on');
            t0=app.Controls.ViewStart.Value*1e-6;
            viewLength=min(100,max(0.001,app.Controls.ViewLength.Value));
            app.Controls.ViewLength.Value=viewLength;
            t1=t0+viewLength*1e-6;
            aMask=o.A.time>=t0 & o.A.time<=t1; bMask=o.B.time>=t0 & o.B.time<=t1;
            aIdx=find(aMask); bIdx=find(bMask);

            % 先画连线再画时间戳，使 Start/Stop 标记始终位于连线上方。
            connections=classifyTimestampConnections(o,t0,t1);
            showTP=app.Controls.ShowTP.Value; showFP=app.Controls.ShowFP.Value;
            orange=[.95 .55 .10]; red=[.90 .10 .10]; blue=[.10 .40 .90]; neutral=[.35 .42 .52];
            plot(ax,nan,nan,'-','Color',orange,'LineWidth',1.0,'DisplayName','可记录真实对');
            if showTP, plot(ax,nan,nan,'-','Color',red,'LineWidth',1.4,'DisplayName','TP'); end
            if showFP, plot(ax,nan,nan,'-','Color',blue,'LineWidth',1.0,'DisplayName','FP'); end

            % 显示 TP 时，相同 pairID 的基础橙线由红线替代；关闭 TP 时仍以橙线展示。
            orangeMask=true(size(connections.truthPairID));
            if showTP && ~isempty(connections.tpMatch)
                tpPairID=unique(o.matches.pairIDA(connections.tpMatch));
                orangeMask=~ismember(connections.truthPairID,tpPairID);
            end
            for k=find(orangeMask).'
                plot(ax,[o.A.time(connections.truthIndexA(k)) o.B.time(connections.truthIndexB(k))]*1e6, ...
                    [1 0],'-','Color',orange,'LineWidth',1.0,'HandleVisibility','off');
            end
            if showTP
                for k=connections.tpMatch(:).'
                    plot(ax,[o.A.time(o.matches.indexA(k)) o.B.time(o.matches.indexB(k))]*1e6, ...
                        [1 0],'-','Color',red,'LineWidth',1.4,'HandleVisibility','off');
                end
            end
            fpDraw=connections.fpMatch(1:min(300,numel(connections.fpMatch)));
            if showFP
                for k=fpDraw(:).'
                    plot(ax,[o.A.time(o.matches.indexA(k)) o.B.time(o.matches.indexB(k))]*1e6, ...
                        [1 0],'-','Color',blue,'LineWidth',1.0,'HandleVisibility','off');
                end
            end
            % 实测 TXT 无 pairID，不能把算法选中的连接判定为 TP 或 FP。
            unknownDraw=connections.unclassifiedMatch(1:min(300,numel(connections.unclassifiedMatch)));
            if o.dataMode=="imported" && (showTP || showFP)
                plot(ax,nan,nan,'-','Color',neutral,'LineWidth',.9,'DisplayName','实测未分类匹配');
                for k=unknownDraw(:).'
                    plot(ax,[o.A.time(o.matches.indexA(k)) o.B.time(o.matches.indexB(k))]*1e6, ...
                        [1 0],'-','Color',neutral,'LineWidth',.9,'HandleVisibility','off');
                end
            end

            scatter(ax,o.A.time(aIdx)*1e6,ones(size(aIdx)),28,[.90 .18 .18],'filled','DisplayName','Start');
            scatter(ax,o.B.time(bIdx)*1e6,zeros(size(bIdx)),28,[.12 .52 .85],'filled','DisplayName','Stop');
            % 暗计数/背景/后脉冲使用空心黑圈标记。
            badA=aIdx(o.A.type(aIdx)~="signal" & o.A.type(aIdx)~="measured");
            badB=bIdx(o.B.type(bIdx)~="signal" & o.B.type(bIdx)~="measured");
            scatter(ax,o.A.time(badA)*1e6,ones(size(badA)),45,'k','o','HandleVisibility','off');
            scatter(ax,o.B.time(badB)*1e6,zeros(size(badB)),45,'k','o','HandleVisibility','off');
            xlim(ax,[t0 t1]*1e6); ylim(ax,[-.35 1.35]); hold(ax,'off');
            legend(ax,'Location','best');
            if o.dataMode=="simulation"
                title(ax,sprintf('局部时间戳：Start %d，Stop %d；真实对 %d，TP %d，FP %d', ...
                    nnz(aMask),nnz(bMask),numel(connections.truthPairID), ...
                    numel(connections.tpMatch),numel(connections.fpMatch)));
            else
                title(ax,sprintf('局部时间戳：Start %d，Stop %d；实测匹配 %d（无 pairID，不能判定 TP/FP）', ...
                    nnz(aMask),nnz(bMask),numel(connections.unclassifiedMatch)));
            end
        end

        function resetTimestampAxes(app,titleText)
            %RESETTIMESTAMPAXES 彻底清空局部时间戳图并恢复固定坐标设置。
            ax=app.TimestampAxes;
            if isempty(ax) || ~isvalid(ax), return; end
            legend(ax,'off');
            cla(ax,'reset');
            title(ax,titleText);
            xlabel(ax,'相对时间 (μs)');
            yticks(ax,[0 1]); yticklabels(ax,{'Stop','Start'});
            grid(ax,'on');
        end

        function updateResultTable(app)
            if isempty(app.LastResult), return; end
            % 界面和 CSV 共用同一张指标定义表，避免名称或公式不一致。
            summary=buildMetricSummaryTable(app.LastResult);
            app.ResultTable.Data=table2cell(summary);

            % 四个分组标题使用不同的强调色，普通指标行保持默认样式。
            % 先清除旧样式，避免重新仿真或导入数据后重复叠加。
            removeStyle(app.ResultTable);
            sectionNames=["【计数性能】","【时间性能】","【算法性能】","【系统效率与性能】"];
            fontColors={[.05 .32 .68],[.82 .36 .04],[.05 .48 .25],[.48 .20 .66]};%改变颜色
            backgroundColors={[.88 .93 1.00],[1.00 .94 .86],[.88 .97 .91],[.95 .89 .99]};%改变背景颜色
            parameters=string(summary.('参数'));
            for k=1:numel(sectionNames)
                row=find(parameters==sectionNames(k),1);
                if ~isempty(row)
                    style=uistyle('FontColor',fontColors{k},'BackgroundColor',backgroundColors{k}, ...
                        'FontWeight','bold');
                    addStyle(app.ResultTable,style,'row',row);
                end
            end
        end

        function openExport(app)
            if isempty(app.LastResult), uialert(app.UIFigure,'请先运行仿真或导入时间戳。','无可导出结果'); return; end
            showExportDialog(app.UIFigure,app.LastResult);
        end

        function showError(app,ME,titleText)
            app.StatusLabel.Text=titleText; uialert(app.UIFigure,ME.message,titleText);
        end

        function setBusy(app,textValue)
            app.StatusLabel.Text=textValue; drawnow;
        end

        function f=addNum(~,g,row,label,value)
            l=uilabel(g,'Text',label); l.Layout.Row=row; l.Layout.Column=1;
            f=uieditfield(g,'numeric','Value',value); f.Layout.Row=row; f.Layout.Column=2;
        end

        function f=addDrop(~,g,row,label,items,data,value)
            l=uilabel(g,'Text',label); l.Layout.Row=row; l.Layout.Column=1;
            if isstring(value), value=char(value); end
            f=uidropdown(g,'Items',items,'ItemsData',data,'Value',value); f.Layout.Row=row; f.Layout.Column=2;
        end

        function addPairHeader(~,g)
            labels={'参数','A通道','参数','B通道'};
            for k=1:4, x=uilabel(g,'Text',labels{k},'FontWeight','bold','HorizontalAlignment','center'); x.Layout.Row=1; x.Layout.Column=k; end
        end

        function [a,b]=addPair(~,g,row,label,va,vb)
            la=uilabel(g,'Text',label); la.Layout.Row=row; la.Layout.Column=1;
            a=uieditfield(g,'numeric','Value',va); a.Layout.Row=row; a.Layout.Column=2;
            lb=uilabel(g,'Text',label); lb.Layout.Row=row; lb.Layout.Column=3;
            b=uieditfield(g,'numeric','Value',vb); b.Layout.Row=row; b.Layout.Column=4;
        end

        function f=addWideNum(~,g,row,label,value)
            l=uilabel(g,'Text',label); l.Layout.Row=row; l.Layout.Column=[1 2];
            f=uieditfield(g,'numeric','Value',value); f.Layout.Row=row; f.Layout.Column=[3 4];
        end

        function f=addHalfNum(~,g,row,col,label,value)
            l=uilabel(g,'Text',label); l.Layout.Row=row; l.Layout.Column=col;
            f=uieditfield(g,'numeric','Value',value); f.Layout.Row=row; f.Layout.Column=col+1;
        end

        function f=addHalfCheck(~,g,row,col,label,value)
            f=uicheckbox(g,'Text',label,'Value',value); f.Layout.Row=row; f.Layout.Column=[col col+1];
        end

        function addActionButton(~,g,row,textValue,color,callback)
            b=uibutton(g,'Text',textValue,'ButtonPushedFcn',callback,'FontWeight','bold', ...
                'BackgroundColor',color,'FontColor','white'); b.Layout.Row=row;
        end

    end
end
