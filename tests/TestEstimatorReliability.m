classdef TestEstimatorReliability < matlab.unittest.TestCase
    methods(Test)
        function exactJointFormulaAndCovariance(t)
            N=1000; background=20; F=[.7 .3]; L=6;
            C0=N*F(1)+background; Cs=N*F(2)+L*background;
            v=[C0 Cs F]; S=diag([C0 Cs 0 0]);
            r=propagateCoincidenceUncertainty(v,S,L);
            t.verifyEqual(r.pair,N,'AbsTol',1e-10);
            t.verifyEqual(r.accidental,background,'AbsTol',1e-10);
            traditional=(C0-Cs/L)/F(1);
            t.verifyLessThan(abs(r.pair-N),abs(traditional-N));
            S(1,2)=10; S(2,1)=10;
            correlated=propagateCoincidenceUncertainty(v,S,L);
            t.verifyNotEqual(correlated.uPair,r.uPair);
        end
        function noTruthLeakAndExperimentalUnknown(t)
            p=fixture(); d=generateSimulationData(p);
            x=analyzeResearchTimestamps(d.A,d.B,p,d.source,"simulation");
            d.A.pairID(:)=0; d.B.pairID(:)=0; d.A.type(:)="noise"; d.B.type(:)="noise";
            y=analyzeResearchTimestamps(d.A,d.B,p,d.source,"simulation");
            t.verifyEqual(x.research.Npair_est,y.research.Npair_est);
            t.verifyEqual(x.research.F0_est,y.research.F0_est);
            t.verifyEqual(x.research.quality_status,y.research.quality_status);
            t.verifyEqual(y.research.Nrec_true,0); t.verifyTrue(isnan(y.research.epsilon_pair_total));
            z=analyzeResearchTimestamps(d.A,d.B,p,struct('time',[]),"experimental");
            t.verifyTrue(isnan(z.research.Nrec_true)); t.verifyTrue(isnan(z.metrics.TP));
        end
        function integratedFitAndIdealRecovery(t)
            p=fixture(); p.algorithm.window=2e-9;
            d=generateSimulationData(p); o=analyzeResearchTimestamps(d.A,d.B,p,d.source,"simulation");
            t.verifyEqual(o.fit.status,"FIT_OK");
            t.verifyLessThan(abs(o.research.Npair_est/o.research.Nrec_true-1),.1);
            t.verifyEqual(o.research.quality_status,"CAUTION"); % No unvalidated RELIABLE.
            t.verifyGreaterThan(o.research.u_Npair,0);
        end
        function ambiguousAndEmpty(t)
            p=fixture(); p.algorithm.correlatedBackgroundPossible=true;
            d=generateSimulationData(p); o=analyzeResearchTimestamps(d.A,d.B,p,d.source,"simulation");
            t.verifyEqual(o.research.invalid_reason,"CORRELATED_BACKGROUND_NOT_IDENTIFIABLE");
            t.verifyTrue(isnan(o.research.Npair_est));
            p.algorithm.correlatedBackgroundPossible=false; p.source.pairRate=0;
            d=generateSimulationData(p); o=analyzeResearchTimestamps(d.A,d.B,p,d.source,"simulation");
            t.verifyEqual(o.research.Nrec_true,0); t.verifyTrue(isnan(o.research.epsilon_pair_total));
            t.verifyEqual(o.research.quality_status,"INVALID");
        end
        function bootstrapRefitsAndPreservesRandomStream(t)
            p=fixture(); p.algorithm.uncertaintyMethod="bootstrap";
            p.algorithm.bootstrapReplicates=10; p.algorithm.bootstrapBlockDuration=.02;
            d=generateSimulationData(p); state=rng;
            o=analyzeResearchTimestamps(d.A,d.B,p,d.source,"simulation");
            t.verifyEqual(rng,state); t.verifyEqual(o.research.bootstrap_blocks,5);
            t.verifyEqual(o.research.bootstrap_replicates,10);
            t.verifyEqual(o.research.uncertainty_method,"SYNCHRONOUS_BLOCK_BOOTSTRAP_FULL_REFIT");
            t.verifyGreaterThan(o.research.u_Npair,0);
            t.verifySubstring(o.research.quality_flags,'BLOCK_BOUNDARY_PAIRS_EXCLUDED');
        end
        function scenariosHaveDistinctBackgroundIds(t)
            p=fixture(); p.scenarios.correlatedBackgroundRate=2000;
            p.scenarios.jitterModel="double-gaussian";
            p.scenarios.backgroundMode="step"; p.scenarios.backgroundAmplitude=.8;
            p.detector.A.backgroundRate=1000; p.detector.B.backgroundRate=1000;
            p.detector.enableAfterpulse=true; p.tdc.enableDeadTime=true;
            d=generateSimulationData(p);
            for ev={d.A,d.B}
                e=ev{1}; keep=e.backgroundCorrelationID>0;
                t.verifyGreaterThan(nnz(keep),0); t.verifyTrue(all(e.pairID(keep)==0));
                t.verifyEqual(numel(e.time),numel(e.backgroundCorrelationID));
            end
            o=analyzeResearchTimestamps(d.A,d.B,p,d.source,"simulation");
            t.verifyEqual(o.research.quality_status,"INVALID");
        end
        function signedNegativeAndInvalidData(t)
            v=[2 60 .8 0]; r=propagateCoincidenceUncertainty(v,diag([2 60 0 0]),6);
            t.verifyLessThan(r.pair,0); t.verifyLessThan(r.pair*.8,0);
            p=fixture(); A=struct('time',[.02;.01]); B=struct('time',.01);
            t.verifyError(@()analyzeResearchTimestamps(A,B,p),'CoincidenceSim:DataQualityInvalid');
        end
        function advancedFactorsAndFixedC(t)
            c=scanDefaultConfig(fixture()); c.advancedFactors=true;
            c.factors=[scanFactor("measurementTime",[.05 .1]);scanFactor("detector.backgroundRate",[0 100],"A"); ...
                scanFactor("algorithm.windowMode",["bins","fixed"])];
            plan=buildScanGrid(c); t.verifyNumElements(plan,8);
            t.verifyNumElements(unique([plan.physical_config_id]),4);
            t.verifyNumElements(unique([plan.analysis_config_id]),2);
        end
        function observableNonstationarityIsFlagged(t)
            p=fixture(); p.measurementTime=1; p.algorithm.segmentDuration=.1;
            h=buildHistogram(struct('deltaT',5e-9),p); h.peak=5e-9;
            g=buildCoincidenceWindowGeometry(h,p);
            a=[linspace(.001,.499,100),linspace(.501,.999,1000)]';
            r=researchResultTemplate(); r.fit_status="FIT_OK"; r.Npair_est=100;
            r.Nnet_signed=100; r.F0_est=1; r.Fs_est=0; r.fit_residual_score=1;
            [state,flags,~,diagnostics]=assessCoincidenceReliability(a,a,h,g,p,r,zeros(4,1));
            t.verifyEqual(state,"CAUTION"); t.verifyTrue(any(flags=="NONSTATIONARY"));
            t.verifyLessThan(diagnostics.stationarityP,.001);
        end
    end
end
function p=fixture()
p=researchParams(defaultParams()); p.measurementTime=.1; p.source.pairRate=2e4;
p.detector.enableDark=false; p.algorithm.windowMode="fixed"; p.algorithm.window=1e-9;
p.algorithm.histRange=[-15 15]*1e-9; p.algorithm.sideWindowPairs=2;
p.algorithm.sideWindowGuardMode="window-width"; p.algorithm.strictWindows=true;
p.algorithm.peakMethod="fixed"; p.algorithm.fixedPeakCenter=5e-9;
end
