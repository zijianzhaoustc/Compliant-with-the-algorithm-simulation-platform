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
            for method=["sideband","time-shift"]
                p.algorithm.accidentalMethod=method;
                out=runSimulation(p);
                testCase.verifyTrue(isfinite(out.metrics.Racc));
                testCase.verifyGreaterThanOrEqual(out.metrics.Racc,0);
            end
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
    end
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
