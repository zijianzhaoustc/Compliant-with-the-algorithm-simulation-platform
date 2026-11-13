classdef TestDetectorTiming < matlab.unittest.TestCase
    %TESTDETECTORTIMING 非高斯 IRF、雪崩计数、完整 pairID 真值的物理验证。
    methods (Test)
        function gaussianAndZeroTailPreserveRandomSequence(t)
            p=defaultParams(); cfg=p.detector.A; cfg.timingModel="gaussian";
            rng(123); expected=cfg.jitter*randn(71,1); next=rand;
            rng(123); actual=sampleDetectorTiming(71,cfg);
            t.verifyEqual(actual,expected); t.verifyEqual(rand,next);
            cfg.timingModel="gaussian-exp-tail"; cfg.tailFraction=0;
            rng(123); actual=sampleDetectorTiming(71,cfg);
            t.verifyEqual(actual,expected); t.verifyEqual(rand,next);
        end

        function exponentialTailHasCorrectMoments(t)
            p=defaultParams(); cfg=p.detector.B; rng(823);
            x=sampleDetectorTiming(300000,cfg); q=cfg.tailFraction; tau=cfg.tailTau;
            variance=cfg.jitter^2+q*(2-q)*tau^2;
            thirdMoment=2*q*(3-3*q+q^2)*tau^3;
            centered=x-mean(x);
            t.verifyEqual(mean(x),0,'AbsTol',8e-12);
            t.verifyEqual(var(x,1),variance,'RelTol',.04);
            t.verifyEqual(mean(centered.^3),thirdMoment,'RelTol',.08);
            t.verifyGreaterThan(nnz(x>3*cfg.jitter)/numel(x),.05);
        end

        function invalidParametersAndLegacyGaussian(t)
            p=defaultParams(); legacy=p;
            for ch=["A","B"]
                legacy.detector.(ch)=rmfield(legacy.detector.(ch), ...
                    {'timingModel','tailFraction','tailTau'});
            end
            restored=validateParams(legacy);
            t.verifyEqual(restored.detector.A.timingModel,"gaussian");
            t.verifyEqual(restored.detector.B.timingModel,"gaussian");
            p.detector.A.tailFraction=1.1;
            t.verifyError(@()validateParams(p),'CoincidenceSim:InvalidProbability');
            p=defaultParams(); p.detector.A.tailTau=NaN;
            t.verifyError(@()validateParams(p),'CoincidenceSim:InvalidTailTau');
            p.detector.A.tailTau=0;
            t.verifyError(@()validateParams(p),'CoincidenceSim:InvalidTailTau');
            p=defaultParams(); p.detector.B.timingModel="other";
            t.verifyError(@()validateParams(p),'CoincidenceSim:InvalidTimingModel');
        end

        function afterpulseDiagnosticsConserveEveryCandidate(t)
            primary=events((1:5000)'*5);
            rng(17); [output,d]=processDetectorAvalanches(primary,.1,.3,.1,25005);
            t.verifyEqual(d.afterpulseCandidates,d.afterpulseAccepted+ ...
                d.afterpulseRejectedDeadTime+d.afterpulseOutsideAcquisition);
            t.verifyEqual(d.primaryAccepted+d.primaryRejectedDeadTime,5000);
            t.verifyEqual(d.afterpulseAccepted,nnz(output.type=="afterpulse"));
            t.verifyEqual(numel(output.time),d.primaryAccepted+d.afterpulseAccepted);
            t.verifyEqual(d.afterpulseAccepted/numel(output.time),.3*exp(-1),'AbsTol',.015);
            t.verifyTrue(all(output.pairID(output.type=="afterpulse")==0));
        end

        function longHoldoffRejectsShortLifetimeAfterpulses(t)
            p=parameters(); p.measurementTime=.01;
            p.detector.enableDeadTime=true; p.detector.enableAfterpulse=true;
            p.detector.A.deadTime=1e-6; p.detector.A.afterpulseLifetime=50e-9;
            p.detector.A.afterpulseProbability=.5;
            input=events((1:500)'*10e-6);
            rng(91); [output,d]=simulateDetector(input,p,"A");
            t.verifyGreaterThan(d.afterpulseCandidates,200);
            t.verifyEqual(d.afterpulseAccepted,0);
            t.verifyEqual(d.afterpulseRejectedDeadTime,d.afterpulseCandidates);
            t.verifyEqual(d.isolatedObservedProbability,.5*exp(-20),'RelTol',1e-12);
            t.verifyEqual(output.pairID,input.pairID);
        end

        function tdcLossesAndAfterpulseRecordsAreCounted(t)
            p=parameters(); p.measurementTime=1e-6;
            p.tdc.enableDeadTime=true; p.tdc.A.deadTime=50e-9;
            input=events([0;10;60]*1e-9);
            input.pairID(2:3)=0; input.type(2:3)="afterpulse";
            [output,d]=simulateTDC(input,p,"A");
            t.verifyEqual(d.rejectedDeadTime,1); t.verifyEqual(d.recordedAfterpulses,1);
            t.verifyEqual(numel(output.time)+d.rejectedDeadTime+d.outsideAcquisition,d.inputEvents);
        end

        function completeTruthIsIndependentOfMatchingAndHistogramRange(t)
            p=parameters(); p.algorithm.histRange=[-1 1]*1e-9;
            A=events([.1;.2;.3]); B=A; B.time=A.time+[5;20;50]*1e-9;
            out=analyzeTimestampData(A,B,p,struct(),'simulation');
            d=buildSimulationDiagnostics(out);
            t.verifyEmpty(out.matches.deltaT);
            t.verifyEqual(d.recordedPairCount,3);
            t.verifyEqual(d.pairs.PairID,[1;2;3]);
            t.verifyEqual(d.pairs.DeltaT_s,B.time-A.time);
            t.verifyEqual(sum(d.histogram.Counts),3);
            t.verifyEqual(d.outsideAnalysisRange,3);
            t.verifyEqual(sum(d.timeBlocks.RecordedTruePairs),3);
            t.verifyEqual(d.sigma,std(B.time-A.time));
        end

        function emptyTruthAndMeasuredDataHaveExplicitSemantics(t)
            p=parameters(); p.source.pairRate=0;
            out=runSimulation(p); d=out.simulationDiagnostics;
            t.verifyEqual(d.recordedPairCount,0); t.verifyTrue(isnan(d.mean));
            t.verifyTrue(all(isnan(d.capture.CaptureRate)));
            out.dataMode="imported";
            t.verifyError(@()buildSimulationDiagnostics(out),'CoincidenceSim:NoSimulationTruth');
        end

        function recalculationPreservesPhysicalProvenance(t)
            p=parameters(); p.detector.A.timingModel="gaussian-exp-tail";
            out=runSimulation(p); q=out.params;
            q.detector.A.tailFraction=.9; q.tdc.resolution=1e-9;
            q.algorithm.window=.5e-9;
            updated=recalculateAnalysis(out,q);
            t.verifyEqual(updated.A,out.A); t.verifyEqual(updated.B,out.B);
            t.verifyEqual(updated.params.detector,out.params.detector);
            t.verifyEqual(updated.params.tdc,out.params.tdc);
            t.verifyEqual(updated.simulationDiagnostics.pairs,out.simulationDiagnostics.pairs);
            t.verifyEqual(updated.simulationDiagnostics.detector,out.simulationDiagnostics.detector);
            t.verifyEqual(updated.params.algorithm.window,.5e-9);
            actual=updated.simulationDiagnostics.capture;
            t.verifyEqual(actual.CaptureRate(actual.IsCurrentWindow),updated.metrics.WindowCaptureRate);
        end

        function diagnosticsExportAndSeedSweepUseSIUnits(t)
            folder=string(tempname); mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s'));
            p=parameters(); out=runSimulation(p);
            opts=struct('settings',false,'histogram',false,'results',false, ...
                'timestamps',false,'diagnostics',true,'unitSeconds',1e-12);
            files=exportSelectedResults(out,folder,"truth",opts);
            t.verifyEqual(numel(files),6);
            pairTable=readtable(files(3));
            t.verifyEqual(pairTable.DeltaT_s,out.simulationDiagnostics.pairs.DeltaT_s,'AbsTol',1e-20);
            histogram=readtable(files(4)); t.verifyEqual(sum(histogram.Counts),out.metrics.Nrec);
            channels=readtable(files(2));
            t.verifyEqual(channels.afterpulseCandidates,[0;0]);
            report=runRandomSeedSweep(p,struct('start',11,'step',1,'count',1), ...
                folder,"seed",struct('diagnostics',true));
            t.verifyEqual(report.successCount,1,report.log.Message(1));
            t.verifyEqual(report.log.ExportedFiles,6);
            clear cleanup
        end
    end
end

function p=parameters()
p=defaultParams(); p.source.pairRate=2000; p.measurementTime=1;
p.optics.A.transmission=1; p.optics.B.transmission=1;
for ch=["A","B"]
    p.detector.(ch).efficiency=1; p.detector.(ch).recordEfficiency=1;
    p.detector.(ch).jitter=0; p.detector.(ch).timingModel="gaussian";
end
p.detector.enableDark=false; p.detector.enableDeadTime=false; p.detector.enableAfterpulse=false;
p.tdc.enableJitter=false; p.tdc.resolution=1e-12;
p.optimization.mode="manual"; p.uncertainty.enabled=false;
end

function e=events(time)
e=struct('time',time(:),'pairID',(1:numel(time))','type',repmat("signal",numel(time),1));
end
