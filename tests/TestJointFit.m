classdef TestJointFit < matlab.unittest.TestCase
    %TESTJOINTFIT 用户脚本接入后的选窗、全谱面积、独立 all-pairs 与导出验证。
    methods (Test)
        function legacyDefaultsAndInvalidParameters(t)
            p=defaultParams(); t.verifyFalse(p.jointFit.enabled);
            restored=validateParams(rmfield(p,'jointFit'));
            t.verifyEqual(restored.jointFit,p.jointFit);
            bad={0,NaN,[1 2],1i,"100"};
            for k=1:numel(bad)
                q=p; q.jointFit.initialSigma=bad{k};
                t.verifyError(@()validateParams(q),'CoincidenceSim:InvalidJointFit');
            end
            p.jointFit.maxShapeFitPairs=30.5;
            t.verifyError(@()validateParams(p),'CoincidenceSim:InvalidJointFit');
        end

        function recommendationUsesNarrowestWindowEvenWithoutApply(t)
            [o,~]=fixture(); j=o.jointFit;
            t.assertTrue(o.optimization.valid);
            t.verifyFalse(o.optimization.applied);
            t.verifyEqual(o.raw.window,o.optimization.requestedAlgorithm.window,'AbsTol',1e-20);
            t.verifyEqual(j.window.source,"narrowest-adaptive");
            t.verifyEqual(j.window.width,o.optimization.window,'AbsTol',1e-20);
            t.verifyEqual(j.window.center,o.optimization.peak,'AbsTol',1e-20);
            t.verifyTrue(j.valid);
        end

        function fallbackPreservesAllAlgorithmWindowModesAndBoundaries(t)
            [o,p]=fixture(); o.optimization=[]; p.optimization.mode="manual";
            for mode=["fixed","sigma","bins","fwhm"]
                p.algorithm.windowMode=mode; p.algorithm.windowMultiplier=2;
                h=buildHistogram(o.matches,p); raw=calculateRawCoincidence(o.matches,h,p);
                w=resolveJointFitWindow(o,p);
                t.verifyEqual(w.source,"algorithm-settings");
                t.verifyEqual([w.lowerEdge w.upperEdge],[raw.lowerEdge raw.upperEdge]);
                t.verifyEqual(w.includeUpperEdge,raw.includeUpperEdge);
            end
            p.optimization.mode="recommend"; o.optimization=struct('valid',false,'status',"no-valid-window");
            w=resolveJointFitWindow(o,p); t.verifyEqual(w.fallbackReason,"no-valid-window");
        end

        function otherSelectionStrategiesDoNotSupplyWindow(t)
            [o,p]=fixture(); p.optimization.mode="apply";
            for strategy=["bootstrap-score","bootstrap-bagging"]
                p.optimization.selection=strategy;
                w=resolveJointFitWindow(o,p);
                t.verifyEqual(w.source,"algorithm-settings");
                t.verifyEqual(w.width,p.algorithm.window,'AbsTol',1e-20);
                t.verifyEqual(w.fallbackReason,"selection-is-not-narrowest");
            end
        end

        function pointEstimatesRecoverTruthAndUseExactSuppliedWindow(t)
            [o,~]=fixture(); j=o.jointFit; s=j.summary; row=s.Model=="gaussian";
            t.verifyEqual(s.NpairFull(row),o.metrics.Nrec,'RelTol',.08);
            w=j.window; all=o.matches.deltaT;
            expected=nnz(all>=w.lowerEdge & all<=w.upperEdge);
            t.verifyEqual(s.NrawWindow_AllPairs(row),expected);
            t.verifyEqual(s.NaccWindow(row),s.Background_counts_per_ns(row)*w.width*1e9,'RelTol',1e-12);
            t.verifyEqual(s.NnetWindow(row),expected-s.NaccWindow(row),'AbsTol',1e-12);
            t.verifyEqual(j.truth.recordedPairs,o.metrics.Nrec);
            t.verifyEqual(s.TrueWindowPairs(row)+s.FalseWindowPairs(row),expected);
            t.verifyFalse(isfield(j,'bootstrap')); t.verifyFalse(isfield(j,'CI'));
        end

        function truthLabelsCannotAffectFitAndRngIsPreserved(t)
            [o,p]=fixture(); A=o.A; B=o.B;
            A.pairID(:)=0; B.pairID(:)=0;
            rng(918); before=rng;
            blind=analyzeTimestampData(A,B,p,struct(),"imported",false,true);
            t.verifyEqual(rng,before);
            t.verifyEqual(blind.jointFit.models,o.jointFit.models);
            t.verifyTrue(all(isnan(blind.jointFit.summary.NrecTruth)));
        end

        function binsUpperBoundaryAndIndependentAllPairsAreRespected(t)
            p=parameters(); p.optimization.mode="manual"; p.jointFit.enabled=false;
            o=runSimulation(p); w=resolveJointFitWindow(o,p);
            w.includeUpperEdge=false;
            first=fitUnbinnedCoincidence(o.A.time,o.B.time,p.measurementTime,p,w,o.hist.edges);
            expected=nnz(o.matches.deltaT>=w.lowerEdge & o.matches.deltaT<w.upperEdge);
            t.verifyEqual(first.windowRaw,expected);
            % 重复 A 事件时 all-pairs 必须保留两份，不能退化为一对一匹配。
            a=sort([o.A.time;o.A.time]);
            second=fitUnbinnedCoincidence(a,o.B.time,p.measurementTime,p,w,o.hist.edges);
            t.verifyEqual(second.candidatePairs,2*first.candidatePairs);
            t.verifyEqual(second.windowRaw,2*first.windowRaw);
        end

        function recalculationAndResultExportsCarrySelectedWindow(t)
            [o,p]=fixture(); p.optimization.mode="manual"; p.algorithm.window=2.2e-9;
            updated=recalculateAnalysis(o,p);
            t.verifyEqual(updated.A,o.A); t.verifyEqual(updated.B,o.B);
            t.verifyEqual(updated.jointFit.window.source,"algorithm-settings");
            t.verifyEqual(updated.jointFit.window.width,2.2e-9,'AbsTol',1e-20);
            root=string(tempname); mkdir(root); cleanup=onCleanup(@()rmdir(root,'s'));
            options=struct('settings',true,'histogram',false,'results',true,'timestamps',false,'unitSeconds',1e-12);
            files=exportSelectedResults(updated,root,"joint",options);
            t.verifyEqual(numel(files),4);
            exported=readtable(fullfile(root,'joint_joint_fit_summary.csv'),'TextType','string');
            t.verifyEqual(exported.WindowWidth_s,repmat(updated.jointFit.window.width,2,1),'AbsTol',1e-20);
            t.verifyEqual(exported.NpairFull,updated.jointFit.summary.NpairFull,'RelTol',1e-12);
            saved=load(fullfile(root,'joint_settings.mat'));
            t.verifyEqual(saved.params.jointFit,p.jointFit);
            t.verifyTrue(any(string(buildMetricSummaryTable(updated).('参数'))=="【联合无分箱点估计】"));
            clear cleanup
        end

        function sparseDataAndOutOfRangeWindowRemainExplicit(t)
            p=parameters(); p.optimization.mode="manual";
            e=struct('time',zeros(0,1),'pairID',zeros(0,1),'type',strings(0,1));
            out=analyzeTimestampData(e,e,p,struct(),"imported",false,false);
            t.verifyFalse(out.jointFit.valid); t.verifyNotEmpty(out.jointFit.message);
            p.algorithm.window=100e-9; out=runSimulation(p);
            t.verifyFalse(out.jointFit.valid);
            t.verifyEqual(out.jointFit.errorIdentifier,"CoincidenceSim:JointFitWindow");
        end

        function alternatingBlocksRetainCrossfitDiagnosticsWithoutBootstrap(t)
            p=parameters(); p.measurementTime=4.2; p.source.pairRate=2000;
            p.detector.A.backgroundRate=1e4; p.detector.B.backgroundRate=1e4;
            p.optimization.mode="manual"; o=runSimulation(p); j=o.jointFit;
            t.assertTrue(j.models.gaussian.crossFitted);
            t.verifyEqual(j.models.gaussian.Npair_crossfit,sum(j.models.gaussian.foldArea));
            t.verifyFalse(isfield(j,'bootstrap'));
            t.verifyEmpty(o.uncertainty.bootstrap);
        end

        function diagnosticBinsStayInsideActualFitRange(t)
            p=parameters(); p.optimization.mode="manual"; p.algorithm.binWidth=.3e-9;
            o=runSimulation(p); h=o.jointFit.histogram;
            t.verifyLessThanOrEqual(max(h.BinUpper_s),p.algorithm.histRange(2)+1e-20);
            t.verifyGreaterThanOrEqual(min(h.BinLower_s),p.algorithm.histRange(1)-1e-20);
            t.verifyEqual(sum(h.ObservedCounts),o.jointFit.candidatePairs);
            t.verifyEqual(sum(h.GaussianExpectedCounts),o.jointFit.candidatePairs,'AbsTol',1e-8);
        end

        function perSecondBatchAndSeedSweepExportJointPointEstimates(t)
            root=string(tempname); mkdir(root); cleanup=onCleanup(@()rmdir(root,'s'));
            [o,p]=fixture(); input=fullfile(root,'input'); mkdir(input);
            writematrix(o.A.time,fullfile(input,'pair_CH1.txt'));
            writematrix(o.B.time,fullfile(input,'pair_CH2.txt'));
            p.optimization.mode="manual";
            opts=struct('perSecond',true,'histogram',false,'results',true, ...
                'uncertainty',false,'optimization',false);
            report=batchAnalyzeTimestampFolder(input,fullfile(root,'batch'),1,p,@(~,~,~)true,opts);
            t.assertEqual(report.successCount,1,report.log.Message(1));
            files=dir(fullfile(report.outputFolder,'**','*_joint_fit_summary.csv'));
            t.verifyEqual(numel(files),1);
            seed=runRandomSeedSweep(p,struct('start',11,'step',1,'count',1), ...
                root,"joint",struct('results',true));
            t.assertEqual(seed.successCount,1,seed.log.Message(1));
            t.verifyEqual(numel(dir(fullfile(seed.outputFolder,'**','*_joint_fit_summary.csv'))),1);
            clear cleanup
        end
    end
end

function [o,p]=fixture()
p=parameters();
persistent result
if isempty(result), result=runSimulation(p); end
o=result;
end

function p=parameters()
p=defaultParams(); p.source.pairRate=2e4; p.measurementTime=.5;
p.detector.A.timingModel="gaussian"; p.detector.B.timingModel="gaussian";
p.detector.A.backgroundRate=1e5; p.detector.B.backgroundRate=1e5;
p.uncertainty.enabled=false; p.jointFit.enabled=true;
p.jointFit.maxShapeFitPairs=20000; p.jointFit.streamChunkPairs=1000;
p.optimization.checkBackground=false;
end
