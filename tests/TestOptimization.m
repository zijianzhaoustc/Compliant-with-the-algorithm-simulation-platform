classdef TestOptimization < matlab.unittest.TestCase
    %TESTOPTIMIZATION 与真值标签无关的选参、数值一致性、拒绝诊断及独立验证。
    methods (Test)
        function recommendationPreservesExistingMeasurement(t)
            p=parameters(); o=runSimulation(p); state=rng;
            p.optimization.mode="manual"; old=runSimulation(p);
            t.verifyEqual(o.A,old.A); t.verifyEqual(o.B,old.B);
            t.verifyEqual(o.metrics,old.metrics); t.verifyEqual(rng,state);
            t.verifyTrue(o.optimization.valid); t.verifyFalse(o.optimization.applied);
            t.verifyEqual(o.params.algorithm.window,p.algorithm.window);
            t.verifyEqual(o.params.algorithm.binWidth,p.algorithm.binWidth);
            scan=o.optimization.windowScan;
            chosen=find(scan.Selected);
            t.verifyEqual(chosen,find(scan.ValidCandidate,1));
            t.verifyGreaterThanOrEqual(scan.CaptureEstimate(chosen),p.optimization.targetCapture);
            t.verifyEqual(scan.ValidSideWindows(chosen),2*p.algorithm.sideWindowPairs);
        end

        function applicationUsesIndependentPeakAndRawDifferences(t)
            p=parameters(); p.optimization.mode="apply"; o=runSimulation(p);
            t.verifyTrue(o.optimization.applied);
            t.verifyEqual(o.hist.peak,o.optimization.peak);
            t.verifyEqual(o.params.algorithm.window,o.optimization.window);
            t.verifyEqual(o.hist.fwhm,2*sqrt(2*log(2))*o.optimization.sigma);
            t.verifyTrue(all(isfinite(o.hist.fitCounts)));
            t.verifyEqual(o.raw.count,nnz(abs(o.matches.deltaT-o.hist.peak)<=o.raw.window/2));
            boundaries=[o.raw.lowerEdge,o.raw.upperEdge];
            for width=[20 100 200]*1e-12
                q=o.params; q.algorithm.binWidth=width;
                h=buildHistogram(o.matches,q);
                raw=calculateRawCoincidence(o.matches,h,q,boundaries);
                t.verifyEqual(raw.mask,o.raw.mask);
            end
            q=p; q.optimization.binCandidates=[40 80 160]*1e-12;
            model=estimateCoincidencePeak(o.matches,q);
            t.verifyEqual(model.peak,o.optimization.peak);
            t.verifyEqual(model.sigma,o.optimization.sigma);
        end

        function truthLabelsCannotAffectSelection(t)
            o=runSimulation(parameters());
            A=o.A; B=o.B; A.pairID(:)=0; B.pairID(:)=0;
            m=matchCoincidences(A,B,o.params);
            blind=optimizeCoincidenceParameters(A,B,m,o.params,"imported");
            t.verifyEqual(blind.binWidth,o.optimization.binWidth);
            t.verifyEqual(blind.window,o.optimization.window);
            t.verifyEqual(blind.peak,o.optimization.peak);
            t.verifyEqual(blind.windowScan.OptimizationScore,o.optimization.windowScan.OptimizationScore);
            t.verifyTrue(all(isnan(blind.windowScan.TP)));
            t.verifyTrue(any(isfinite(o.optimization.windowScan.TP)));
            for k=1:numel(blind.candidateBootstrap)
                if isempty(blind.candidateBootstrap{k}), continue; end
                t.verifyTrue(all(isnan(blind.candidateBootstrap{k}.replicates.TP)));
            end
        end

        function sharedResamplesAndCandidateScore(t)
            p=parameters(); p.optimization.selection="bootstrap-score";
            o=runSimulation(p); t.verifyTrue(o.optimization.valid);
            scan=o.optimization.windowScan;
            t.verifyLessThanOrEqual(nnz(isfinite(scan.BootstrapB)),p.optimization.bootstrapCandidates);
            t.verifyEqual(scan.OptimizationScore,scan.BootstrapU_side.^2./scan.CaptureEstimate.^2);
            chosen=find(scan.Selected);
            t.verifyEqual(scan.OptimizationScore(chosen),min(scan.OptimizationScore,[],'omitnan'));
            sampled=find(isfinite(scan.BootstrapB));
            if numel(sampled)>1
                a=o.optimization.candidateBootstrap{sampled(1)}.replicates;
                b=o.optimization.candidateBootstrap{sampled(2)}.replicates;
                t.verifyEqual(a.NA,b.NA); t.verifyEqual(a.NB,b.NB);
                t.verifyGreaterThanOrEqual(b.Nraw,a.Nraw);
            end
        end

        function invalidDataFallsBackAndInternalWindowsDoNotOptimize(t)
            p=parameters(); p.optimization.mode="apply";
            p.source.pairRate=0; p.detector.A.backgroundRate=0; p.detector.B.backgroundRate=0;
            p.detector.A.darkRate=0; p.detector.B.darkRate=0;
            o=runSimulation(p);
            t.verifyFalse(o.optimization.valid); t.verifyFalse(o.optimization.applied);
            t.verifyEqual(o.params.algorithm.window,p.algorithm.window);
            p=parameters(); p.algorithm.sidebandGuard=1;
            o=runSimulation(p); t.verifyFalse(o.optimization.valid);
            t.verifyEqual(o.optimization.status,"no-valid-window");
            p=parameters(); o=runSimulation(p); p.algorithm.timestampWindowSize=.4;
            w=analyzeTimestampWindows(o.A,o.B,p,struct(),"simulation");
            for k=1:w.count, t.verifyEmpty(w.results{k}.optimization); end
        end

        function backgroundAndSideWindowsRejectInvalidCandidates(t)
            p=parameters(); model=struct('valid',true,'peak',0,'sigma',.2e-9, ...
                'signalTotal',1000,'backgroundDensity',1e11);
            peak=.2e-9*sqrt(2)*erfinv(2*((1:1000)'-.5)/1000-1);
            delta=[peak;linspace(-6.59e-9,-3.01e-9,100)';linspace(3.01e-9,6.59e-9,1000)'];
            matches=struct('deltaT',delta);
            empty=struct('time',zeros(0,1));
            result=optimizeCoincidenceWindow(empty,empty,matches,p,model,1.2e-9,0);
            t.verifyFalse(result.valid);
            t.verifyTrue(contains(result.table.BackgroundDiagnostic,"nonstationary-background"));
            result=optimizeCoincidenceWindow(empty,empty,matches,p,model,8e-9,0);
            t.verifyTrue(contains(result.table.BackgroundDiagnostic,"incomplete-side-windows"));
        end

        function independentHeldOutValidation(t)
            p=parameters(); p.optimization.validationMode="held-out";
            p.uncertainty.resamples=100;
            o=runSimulation(p); v=o.optimization.validation;
            t.verifyTrue(v.valid); t.verifyEqual(height(v.summary),4);
            t.verifyEmpty(intersect(v.trainingBlocks,v.evaluationBlocks));
            t.verifyEqual(v.trainingDuration+v.evaluationDuration,p.measurementTime,'AbsTol',1e-12);
            t.verifyEqual(v.summary.Window_s(4),v.trainingOptimization.window);
            t.verifyEqual(v.summary.Nraw,v.summary.TP+v.summary.FP);
            t.verifyTrue(all(v.summary.Duration_s==v.evaluationDuration));
        end

        function optimizationExportAndCompleteSweep(t)
            p=parameters(); o=runSimulation(p);
            widths=[3 1.5 2 1.5]'*1e-9; s=sweepCoincidenceWindow(o,widths);
            t.verifyEqual(s.window,widths);
            t.verifyEqual(s.Ncorr_side,s.Nraw-s.Nacc_side);
            exported=buildSweepSummaryTable(s);
            t.verifyTrue(all(ismember({'CaptureEstimate','BootstrapU_side','ValidCandidate'},exported.Properties.VariableNames)));
            folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s'));
            options=struct('settings',false,'histogram',false,'results',false,'timestamps',false, ...
                'optimization',true,'unitSeconds',1e-12);
            files=exportSelectedResults(o,folder,"opt",options);
            t.verifyGreaterThanOrEqual(numel(files),3);
            a=readtable(files(1),'VariableNamingRule','preserve');
            t.verifyEqual(a.Valid,1); t.verifyEqual(a.Applied,0);
            t.verifyEqual(a.Window_s,o.optimization.window,'RelTol',1e-12);
            t.verifyTrue(ismember('Config_targetCapture',a.Properties.VariableNames));
            clear cleanup
        end

        function malformedSettingsAndLegacyCompatibility(t)
            p=parameters(); legacy=rmfield(p,'optimization'); legacy=validateParams(legacy);
            t.verifyEqual(legacy.optimization.mode,"recommend");
            for field=["targetCapture","candidateResamples","backgroundZ"]
                bad=p; bad.optimization.(field)=NaN;
                t.verifyError(@()validateParams(bad),'CoincidenceSim:InvalidOptimization');
            end
            bad=p; bad.optimization.binCandidates=[0,1e-10];
            t.verifyError(@()validateParams(bad),'CoincidenceSim:InvalidOptimization');
            bad=p; bad.optimization.mode="invalid";
            t.verifyError(@()validateParams(bad),'CoincidenceSim:InvalidOptimization');
        end

        function recalculationUsesAllThreeAnalysisSettings(t)
            p=parameters(); old=runSimulation(p);
            old.sweep=sweepCoincidenceWindow(old,[1.5 3]*1e-9);
            p.algorithm.binWidth=50e-12; p.algorithm.window=1.7e-9;
            p.algorithm.accidentalMethod="side-window";
            p.uncertainty.resamples=123; p.uncertainty.seed=81;
            p.uncertainty.confidenceLevel=.9;
            p.optimization.mode="recommend"; p.optimization.targetCapture=.95;
            p.optimization.candidateResamples=80;
            result=recalculateAnalysis(old,p);
            t.verifyEqual(result.A,old.A); t.verifyEqual(result.B,old.B);
            t.verifyEqual(result.source,old.source);
            t.verifyEqual(result.params.algorithm.window,1.7e-9);
            t.verifyEqual(result.metrics.AccidentalMethod,"side-window");
            t.verifyEqual(result.uncertainty.bootstrap.resamples,123);
            t.verifyEqual(result.uncertainty.bootstrap.seed,81);
            t.verifyEqual(result.uncertainty.bootstrap.confidenceLevel,.9);
            t.verifyEqual(result.optimization.settings.targetCapture,.95);
            t.verifyEqual(result.optimization.settings.candidateResamples,80);
            t.verifyEqual(result.optimization.requestedAlgorithm.binWidth,50e-12);
            t.verifyFalse(isfield(result,'sweep'));
        end

        function peakModelDetectsBroadeningAndCompetingPeak(t)
            p=parameters(); q=((1:3000)'-.5)/3000;
            z=sqrt(2)*erfinv(2*q-1);
            background=linspace(-19.99,19.99,1000)'*1e-9;
            matches=struct('deltaT',[5e-9+.2e-9*z;background]);
            first=estimateCoincidencePeak(matches,p);
            t.verifyTrue(first.valid); t.verifyEqual(first.peak,5e-9,'AbsTol',20e-12);
            t.verifyEqual(first.sigma,.2e-9,'RelTol',.1);
            matches.deltaT=[5e-9+.4e-9*z;background];
            wide=estimateCoincidencePeak(matches,p);
            t.verifyTrue(wide.valid); t.verifyGreaterThan(wide.sigma,1.8*first.sigma);
            matches.deltaT=[5e-9+.2e-9*z;8e-9+.2e-9*z;background];
            competing=estimateCoincidencePeak(matches,p);
            t.verifyFalse(competing.valid);
        end
    end
end

function p=parameters()
p=defaultParams(); p.source.pairRate=2e4;
p.detector.A.backgroundRate=1e5; p.detector.B.backgroundRate=1e5;
p.optimization.candidateResamples=100;
p.optimization.bootstrapCandidates=3;
end
