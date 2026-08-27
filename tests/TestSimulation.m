classdef TestSimulation < matlab.unittest.TestCase
    %TESTSIMULATION 仿真内核的物理一致性与算法回归测试。
    %   每项测试固定随机种子；随机量只用于检验统计规律，容差按照样本量设置。

    methods (Test)
        function idealChainPreservesPairs(testCase)
            % 理想效率、零背景和零抖动时，两路必须保留全部产生的 pair。
            p=idealParams(); p.source.pairRate=2000; p.measurementTime=0.2;
            out=runSimulation(p);
            n=numel(out.source.time);
            testCase.verifyEqual(numel(out.A.time),n);
            testCase.verifyEqual(numel(out.B.time),n);
            testCase.verifyEqual(out.metrics.Rtrue,n/p.measurementTime);
            testCase.verifyGreaterThan(out.metrics.Recall,0.99);
            testCase.verifyLessThan(abs(out.hist.peak-5e-9),p.algorithm.binWidth*2);
        end

        function efficiencyScaling(testCase)
            % 单计数与双路真实符合应分别服从 etaA、etaB 和 etaA*etaB 缩放。
            p=idealParams(); p.source.pairRate=5e4; p.measurementTime=1;
            p.optics.A.transmission=.8; p.detector.A.efficiency=.5;
            p.optics.B.transmission=.7; p.detector.B.efficiency=.6;
            out=runSimulation(p); r=numel(out.source.time)/p.measurementTime;
            testCase.verifyEqual(out.metrics.RA/r,.4,'RelTol',.025);
            testCase.verifyEqual(out.metrics.RB/r,.42,'RelTol',.025);
            testCase.verifyEqual(out.metrics.Rtrue/r,.168,'RelTol',.04);
        end

        function jitterAddsInQuadrature(testCase)
            % 独立 Gaussian 抖动的时间差标准差应等于各通道方差之和的平方根。
            p=idealParams(); p.source.pairRate=2e4; p.measurementTime=.5;
            p.detector.A.jitter=150e-12; p.detector.B.jitter=150e-12;
            p.tdc.A.jitter=10e-12; p.tdc.B.jitter=10e-12; p.tdc.enableJitter=true;
            out=runSimulation(p);
            measured=std(out.matches.deltaT(out.matches.isTrue));
            expected=sqrt(2*(150e-12)^2+2*(10e-12)^2);
            testCase.verifyEqual(measured,expected,'RelTol',.05);
        end

        function oneToOneDoesNotReuseEvents(testCase)
            % 贪心一对一算法不得重复使用任一 A 或 B 时间戳。
            p=idealParams(); p.algorithm.matchMethod="one-to-one";
            p.algorithm.histRange=[-1 1]*1e-9;
            A=struct('time',[0;10;20]*1e-9,'pairID',[1;2;3],'type',repmat("signal",3,1));
            B=struct('time',[.1;10.1;20.1]*1e-9,'pairID',[1;2;3],'type',repmat("signal",3,1));
            m=matchCoincidences(A,B,p);
            testCase.verifyEqual(numel(unique(m.indexA)),numel(m.indexA));
            testCase.verifyEqual(numel(unique(m.indexB)),numel(m.indexB));
            testCase.verifyTrue(all(m.isTrue));
        end

        function accidentalEstimatorsAreFinite(testCase)
            % 边带和时间平移方法在包含暗计数的数据上应返回有限非负估计。
            p=idealParams(); p.source.pairRate=1e4; p.measurementTime=.2;
            p.detector.enableDark=true; p.detector.A.darkRate=1000; p.detector.B.darkRate=1000;
            for method=["none","sideband","side-window","time-shift"]
                p.algorithm.accidentalMethod=method;
                out=runSimulation(p);
                testCase.verifyTrue(isfinite(out.metrics.Racc));
                testCase.verifyGreaterThanOrEqual(out.metrics.Racc,0);
            end
        end

        function noAccidentalCorrection(testCase)
            % 无修正模式必须令 Racc=0 且 Rnet=Rraw。
            p=idealParams(); p.source.pairRate=3000; p.measurementTime=.1;
            p.algorithm.accidentalMethod="none";
            out=runSimulation(p);
            testCase.verifyEqual(out.metrics.Racc,0,'AbsTol',0);
            testCase.verifyEqual(out.metrics.Rnet,out.metrics.Rraw,'AbsTol',0);
        end

        function sideWindowUsesPairedEqualWidthWindows(testCase)
            % 左右各两个等宽旁窗每窗各有一个事件，平均应为 1 count/s。
            p=idealParams(); p.measurementTime=1; p.algorithm.window=1e-9;
            p.algorithm.histRange=[-10 10]*1e-9; p.algorithm.sidebandGuard=1e-9;
            p.algorithm.sideWindowPairs=2; p.algorithm.accidentalMethod="side-window";
            emptyEvents=struct('time',zeros(0,1),'pairID',zeros(0,1),'type',strings(0,1));
            matches=struct('deltaT',[-2.5;-1.5;1.5;2.5]*1e-9);
            histResult=struct('peak',0,'sigma',1e-10,'fwhm',2.355e-10);
            acc=estimateAccidentals(emptyEvents,emptyEvents,matches,histResult,p);
            testCase.verifyEqual(acc.rate,1,'AbsTol',1e-12);
            testCase.verifyEqual(acc.sampleCounts,ones(4,1));
        end

        function multipleTimeShiftParameters(testCase)
            % 默认平移量必须为 1、2、3、4、5 μs，并保留每次计数供检查。
            p=idealParams(); p.source.pairRate=2000; p.measurementTime=.02;
            p.algorithm.accidentalMethod="time-shift";
            out=runSimulation(p);
            testCase.verifyEqual(out.acc.sampleOffsets,(1:5)'*1e-6,'AbsTol',1e-15);
            testCase.verifySize(out.acc.sampleCounts,[5 1]);
            testCase.verifyEqual(out.acc.rate,mean(out.acc.sampleCounts)/p.measurementTime, ...
                'AbsTol',1e-12);
        end

        function fourDocumentMatchingRules(testCase)
            % 文档四种匹配规则必须表现出不同的事件复用约束。
            p=idealParams(); p.algorithm.histRange=[-3 3]*1e-9;
            A=struct('time',[0;1;2]*1e-9,'pairID',[1;2;3],'type',repmat("signal",3,1));
            B=struct('time',[1.5;2.5]*1e-9,'pairID',[4;5],'type',repmat("signal",2,1));
            methods=["one-to-one","many-to-one","one-to-many","many-to-many"];
            expected=[2 3 2 6];
            for k=1:numel(methods)
                p.algorithm.matchMethod=methods(k); m=matchCoincidences(A,B,p);
                testCase.verifyEqual(numel(m.deltaT),expected(k));
                if methods(k)~="many-to-many", testCase.verifyGreaterThanOrEqual(min(m.deltaT),0); end
            end
        end

        function nearestNeighborReuseRules(testCase)
            % 最近邻必须按绝对时间差选择；复用开关只影响 B 事件能否再次被选。
            p=idealParams(); p.algorithm.histRange=[-3 3]*1e-9;
            A=struct('time',[0;2]*1e-9,'pairID',[1;2],'type',repmat("signal",2,1));
            B=struct('time',1e-9,'pairID',3,'type',"signal");
            p.algorithm.matchMethod="nearest-no-reuse"; withoutReuse=matchCoincidences(A,B,p);
            p.algorithm.matchMethod="nearest-reuse"; withReuse=matchCoincidences(A,B,p);
            testCase.verifyEqual(numel(withoutReuse.indexA),1);
            testCase.verifyEqual(numel(withReuse.indexA),2);
            testCase.verifyEqual(withReuse.indexB,[1;1]);

            % 最近候选可以在 A 之前或之后，不限于“后继首个”。
            A.time=10e-9; A.pairID=1; A.type="signal";
            B.time=[8;10.5]*1e-9; B.pairID=[2;3]; B.type=repmat("signal",2,1);
            nearest=matchCoincidences(A,B,p);
            testCase.verifyEqual(nearest.indexB,2);
        end

        function chronologicalGreedyIsOneToOne(testCase)
            % 双指针贪婪算法允许 B 早于 A，但两路事件都不得复用。
            p=idealParams(); p.algorithm.histRange=[-2 2]*1e-9;
            p.algorithm.matchMethod="greedy-chronological";
            A=struct('time',[1;10]*1e-9,'pairID',[1;2],'type',repmat("signal",2,1));
            B=struct('time',[0;11]*1e-9,'pairID',[3;4],'type',repmat("signal",2,1));
            matches=matchCoincidences(A,B,p);
            testCase.verifyEqual(matches.indexA,[1;2]);
            testCase.verifyEqual(matches.indexB,[1;2]);
            testCase.verifyEqual(numel(unique(matches.indexA)),numel(matches.indexA));
            testCase.verifyEqual(numel(unique(matches.indexB)),numel(matches.indexB));
        end

        function gaussianPeakFit(testCase)
            % Gaussian 寻峰应恢复已知峰中心和标准差。
            rng(9); p=idealParams(); p.algorithm.peakMethod="gaussian";
            p.algorithm.histRange=[-2 2]*1e-9; p.algorithm.binWidth=20e-12;
            expectedPeak=.3e-9; expectedSigma=.12e-9;
            matches=struct('deltaT',expectedPeak+expectedSigma*randn(15000,1));
            h=buildHistogram(matches,p);
            testCase.verifyEqual(h.peak,expectedPeak,'AbsTol',8e-12);
            testCase.verifyEqual(h.sigma,expectedSigma,'RelTol',.08);
        end

        function compactEfficiencyDefinitions(testCase)
            % 非对称双路参数用于验证条件效率的分母方向和 PDE 反推公式。
            p=idealParams(); p.source.pairRate=1e5; p.measurementTime=1;
            p.optics.A.transmission=.5; p.detector.A.efficiency=.4;
            p.optics.B.transmission=.8; p.detector.B.efficiency=.75;
            out=runSimulation(p); m=out.metrics;
            testCase.verifyEqual(m.PDETheoryA,.4,'AbsTol',1e-12);
            testCase.verifyEqual(m.PDETheoryB,.75,'AbsTol',1e-12);
            testCase.verifyEqual(m.EtaConditionalTheoryA,.2,'AbsTol',1e-12);
            testCase.verifyEqual(m.EtaConditionalTheoryB,.6,'AbsTol',1e-12);
            testCase.verifyEqual(m.EtaConditionalEstimateA,.2,'RelTol',.04);
            testCase.verifyEqual(m.EtaConditionalEstimateB,.6,'RelTol',.04);
            testCase.verifyEqual(m.PDEEstimateA,.4,'RelTol',.04);
            testCase.verifyEqual(m.PDEEstimateB,.75,'RelTol',.04);
            testCase.verifyEqual(m.EtaJointEstimate,.12,'RelTol',.05);
            testCase.verifyEqual(m.AccidentalFraction,m.Racc/m.Rraw,'RelTol',1e-12);
            testCase.verifyGreaterThan(m.WindowCaptureRate,.99);
        end

        function resultSummaryMatchesRequestedGroups(testCase)
            % GUI 与 CSV 共用的结果表必须包含截图要求的四个分组和精简效率项。
            p=idealParams(); p.source.pairRate=2000; p.measurementTime=.1;
            summary=buildMetricSummaryTable(runSimulation(p));
            names=string(summary.('参数'));
            testCase.verifyTrue(all(ismember(["【计数性能】","【时间性能】", ...
                "【算法性能】","【系统效率与性能】"],names)));
            testCase.verifyTrue(any(names=="偶然符合占比 facc"));
            testCase.verifyTrue(any(names=="符合估计 PDEA / PDEB"));
            testCase.verifyTrue(any(names=="符合估计双路联合探测效率"));
        end

        function timestampConnectionClasses(testCase)
            % 局部连线分类必须把可记录真实对、TP 和 FP 分开。
            p=idealParams(); p.source.pairRate=3000; p.measurementTime=.1;
            out=runSimulation(p);
            c=classifyTimestampConnections(out,0,p.measurementTime+10e-9);
            testCase.verifyEqual(numel(c.truthPairID),out.metrics.Rtrue*p.measurementTime);
            testCase.verifyEqual(numel(c.tpMatch),out.metrics.TP);
            testCase.verifyEqual(numel(c.fpMatch),out.metrics.FP);
            % 实测数据即使有窗口内匹配，也不得被误标为 FP。
            measured=out; measured.dataMode="imported";
            cm=classifyTimestampConnections(measured,0,p.measurementTime+10e-9);
            testCase.verifyEmpty(cm.tpMatch); testCase.verifyEmpty(cm.fpMatch);
            testCase.verifyEqual(numel(cm.unclassifiedMatch),out.raw.count);
        end

        function exportedCsvUsesUtf8Bom(testCase)
            % Excel 依靠 UTF-8 BOM 自动识别含中文的 CSV 编码。
            filename=[tempname '.csv']; cleanup=onCleanup(@()deleteIfPresent(filename));
            source=table("计数性能",480870,'VariableNames',{'参数','数值'});
            writeUtf8BomTable(source,filename);
            fid=fopen(filename,'r'); bytes=fread(fid,3,'uint8=>uint8').'; fclose(fid);
            testCase.verifyEqual(bytes,uint8([239 187 191]));
            restored=readtable(filename,'TextType','string','Encoding','UTF-8', ...
                'VariableNamingRule','preserve');
            testCase.verifyEqual(string(restored.Properties.VariableNames(1)),"参数");
            testCase.verifyEqual(restored{1,1},"计数性能");
            clear cleanup
        end

        function windowSweepExportLayout(testCase)
            % 导出表纵向对应窗口大小，横向对应各个扫描指标。
            p=idealParams(); p.source.pairRate=5000; p.measurementTime=.1;
            out=runSimulation(p); widths=[.1;.2;.5]*1e-9;
            sweep=sweepCoincidenceWindow(out,widths);
            sweepTable=buildSweepSummaryTable(sweep);
            testCase.verifySize(sweepTable,[3 15]);
            testCase.verifyEqual(sweepTable.('窗口大小_ns'),[.1;.2;.5],'AbsTol',1e-12);
            expected=["Rraw_cps","Racc_cps","Rnet_cps","Precision","Recall", ...
                "F1","窗口捕获率","CAR","SNR"];
            testCase.verifyTrue(all(ismember(expected,string(sweepTable.Properties.VariableNames))));
        end

        function selectiveExportWritesSweepCsv(testCase)
            % 选择性导出应单独产生可由 Excel 读取的窗口扫描 CSV。
            p=idealParams(); p.source.pairRate=3000; p.measurementTime=.05;
            out=runSimulation(p);
            out.sweep=sweepCoincidenceWindow(out,[.1;.2]*1e-9);
            folder=tempname; mkdir(folder); cleanup=onCleanup(@()removeFolderIfPresent(folder));
            options=struct('settings',false,'histogram',false,'results',false, ...
                'sweep',true,'timestamps',false,'unitSeconds',1e-12);
            files=exportSelectedResults(out,folder,"test",options);
            expectedFile=fullfile(folder,'test_window_sweep.csv');
            testCase.verifyEqual(files,string(expectedFile));
            exported=readtable(expectedFile,'Encoding','UTF-8','VariableNamingRule','preserve');
            testCase.verifyEqual(exported.('窗口大小_ns'),[.1;.2],'AbsTol',1e-12);
            clear cleanup
        end
    end
end

function deleteIfPresent(filename)
%DELETEIFPRESENT 清理 CSV 编码测试产生的临时文件。
if isfile(filename), delete(filename); end
end

function removeFolderIfPresent(folder)
%REMOVEFOLDERIFPRESENT 只删除本测试专用的 tempname 临时目录。
if isfolder(folder), rmdir(folder,'s'); end
end

function p=idealParams()
%IDEALPARAMS 构造关闭所有非理想因素的公共测试基线。
p=defaultParams(); p.seed=17;
p.optics.A.transmission=1; p.optics.B.transmission=1;
p.detector.A.efficiency=1; p.detector.B.efficiency=1;
p.detector.A.recordEfficiency=1; p.detector.B.recordEfficiency=1;
p.detector.A.jitter=0; p.detector.B.jitter=0;
p.detector.enableDark=false; p.detector.enableDeadTime=false; p.detector.enableAfterpulse=false;
p.tdc.enableJitter=false; p.tdc.resolution=1e-12;
p.algorithm.histRange=[-20 20]*1e-9; p.algorithm.binWidth=10e-12;
p.algorithm.window=1e-9; p.algorithm.matchMethod="all-pairs";
p.algorithm.accidentalMethod="theory";
end
