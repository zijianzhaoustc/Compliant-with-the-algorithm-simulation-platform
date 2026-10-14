classdef TestPaperSimulations < matlab.unittest.TestCase
    methods(Test)
        function signedNetIdentityAndLegacyCompatibility(testCase)
            p=paperTestParams(); p.measurementTime=1;
            A=events([.1;.2],[1;2]); B=events([.1;.2],[1;9]);
            matches=matchCoincidences(A,B,p); hist=buildHistogram(matches,p);
            raw=calculateRawCoincidence(matches,hist,p); raw.matchesIsTrue=matches.isTrue;
            acc=struct('rate',3,'countEquivalent',3,'method',"test", ...
                'details',"",'sampleOffsets',zeros(0,1),'sampleCounts',zeros(0,1));
            m=calculateMetrics(A,B,matches,raw,acc,hist,p,"simulation");
            testCase.verifyEqual(m.NnetSigned,m.Nraw-m.Nacc,'AbsTol',1e-12);
            testCase.verifyEqual(m.Rnet,max(0,m.RnetSigned),'AbsTol',1e-12);
            if m.TP>0 && m.FP>0
                testCase.verifyEqual(m.EpsilonNetSigned, ...
                    -(m.FP/m.TP)*m.EpsilonAcc,'AbsTol',1e-12);
            end
        end

        function stageCountsAreRecorded(testCase)
            p=paperTestParams(); p.source.pairRate=2e4; p.measurementTime=.05;
            p.detector.enableDeadTime=true; p.tdc.enableDeadTime=true;
            out=runSimulation(p);
            testCase.verifyGreaterThanOrEqual(out.stageStats.detectorA.inputCount, ...
                out.stageStats.detectorA.acceptedCount);
            testCase.verifyGreaterThanOrEqual(out.stageStats.tdcA.inputCount, ...
                out.stageStats.tdcA.acceptedCount);
        end

        function estimatorsReuseTruthCounts(testCase)
            p=paperTestParams(); p.source.pairRate=5e4; p.measurementTime=.1;
            out=runSimulation(p); reference=[];
            for method=["theory","side-window","time-shift"]
                q=out.params; q.algorithm.accidentalMethod=method;
                raw=calculateRawCoincidence(out.matches,out.hist,q); raw.matchesIsTrue=out.matches.isTrue;
                acc=estimateAccidentals(out.A,out.B,out.matches,out.hist,q);
                m=calculateMetrics(out.A,out.B,out.matches,raw,acc,out.hist,q,"simulation");
                current=[m.RA,m.RB,m.Nrec,m.Nraw,m.TP,m.FP];
                if isempty(reference), reference=current; else, testCase.verifyEqual(current,reference); end
            end
        end

        function independentStreamsRespectPoissonCrossBaseline(testCase)
            p=paperTestParams(); p.source.pairRate=0; p.measurementTime=.5;
            p.detector.A.backgroundRate=2e5; p.detector.B.backgroundRate=2e5;
            p.algorithm.window=100e-9; p.algorithm.histRange=[-1,1]*1e-6;
            p.detector.enableDeadTime=true; p.detector.A.deadTime=50e-9; p.detector.B.deadTime=50e-9;
            p.tdc.enableDeadTime=true; p.tdc.A.deadTime=2.33e-9; p.tdc.B.deadTime=2.33e-9;
            out=runSimulation(p);
            testCase.verifyEqual(out.metrics.TP,0);
            testCase.verifyTrue(isnan(out.metrics.EpsilonNetSigned));
            testCase.verifyEqual(out.metrics.Geff,1,'AbsTol',.12);
        end

        function configurationMatrixCoversRequiredExperiments(testCase)
            configs=paperSimulationConfigs("smoke"); ids=unique([configs.experimentID]);
            required=["A-J50","A-J150","A-J300","B-RATE","B-BACKGROUND", ...
                "B-WINDOW","C-OFF","C-D50","C-D100","C-T233","C-T10", ...
                "C-BOTH","C-INDEPENDENT","D-BASE","D-AP05","D-FULL"];
            testCase.verifyTrue(all(ismember(required,ids)));
            testCase.verifyFalse(any(startsWith(ids,"E-")));
        end
    end
end

function p=paperTestParams()
p=defaultParams(); p.seed=81; p.optics.A.transmission=1; p.optics.B.transmission=1;
p.detector.A.efficiency=1; p.detector.B.efficiency=1;
p.detector.A.recordEfficiency=1; p.detector.B.recordEfficiency=1;
p.detector.enableDark=false; p.detector.enableDeadTime=false; p.detector.enableAfterpulse=false;
p.detector.A.backgroundRate=0; p.detector.B.backgroundRate=0;
p.detector.A.jitter=0; p.detector.B.jitter=0;
p.tdc.enableJitter=false; p.tdc.enableDeadTime=false; p.tdc.resolution=1e-12;
p.algorithm.matchMethod="many-to-many"; p.algorithm.peakMethod="maximum";
p.algorithm.windowMode="fixed"; p.algorithm.window=1e-9;
p.algorithm.histRange=[-20,20]*1e-9; p.algorithm.binWidth=20e-12;
p.algorithm.sidebandGuard=3e-9; p.algorithm.sideWindowPairs=3;
p.algorithm.timeShiftStart=1e-6; p.algorithm.timeShiftStep=1e-6; p.algorithm.timeShiftCount=3;
p.algorithm.accidentalMethod="theory";
end

function e=events(time,pairID)
e=struct('time',time(:),'pairID',pairID(:),'type',repmat("signal",numel(time),1));
end
