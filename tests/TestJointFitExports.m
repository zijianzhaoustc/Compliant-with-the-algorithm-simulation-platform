classdef TestJointFitExports < matlab.unittest.TestCase
    %TESTJOINTFITEXPORTS 联合拟合指标完整性、独立导出和 CSV/MAT 一致性。
    methods (Test)
        function uniqueJointMetricsAppearFirstAndCompleteValuesRemainExportable(t)
            [o,~]=fixture(); summary=buildMetricSummaryTable(o); j=o.jointFit;
            t.verifyEqual(string(summary.('参数')(1)),"【联合无分箱点估计】");
            labels=string(summary.('参数'));
            required=["完整相关峰面积 Npair","联合拟合背景 (count/ns)", ...
                "联合拟合捕获修正完整面积","联合拟合核心 σ (ps)","联合 IRF 整体 σ (ps)"];
            t.verifyTrue(all(ismember(required,labels)));
            repeated=["联合拟合窗全宽 (ns)","联合拟合窗原始计数","联合拟合窗净率 (cps)", ...
                "联合拟合窗 TP / FP","联合拟合记录真实对数 Nrec"];
            t.verifyFalse(any(ismember(repeated,labels)));
            summary=buildMetricSummaryTable(o,true); labels=string(summary.('参数'));
            k=find(j.summary.Selected,1);
            pairs={"联合拟合窗净率 (cps)",'NnetRate_Hz',1; ...
                "联合拟合核心 σ (ps)",'CoreSigma_s',1e12; ...
                "联合拟合完整相关率 (cps)",'PairRate_Hz',1};
            for index=1:size(pairs,1)
                actual=str2double(string(summary.('数值')(labels==pairs{index,1})));
                expected=j.summary.(pairs{index,2})(k)*pairs{index,3};
                t.verifyEqual(actual,expected,'RelTol',5e-6);
            end
        end

        function reportedMixtureMomentsAndCoreFwhmHaveCorrectMeaning(t)
            [o,p]=fixture(); j=o.jointFit; s=j.models.doublegaussian.displayShape;
            s.mu=2; s.sigma1=.1; s.sigma2=.4; s.alpha=.25; s.delta=.6;
            j.models.doublegaussian.displayShape=s;
            table=buildJointFitSummaryTable(j,p.measurementTime);
            k=table.Model=="doublegaussian";
            t.verifyEqual(table.MixtureMean_s(k),2.15e-9,'AbsTol',1e-23);
            t.verifyEqual(table.MixtureSigma_s(k),sqrt(.115)*1e-9,'AbsTol',1e-23);
            t.verifyEqual(table.CoreFWHM_s(k),2*sqrt(2*log(2))*.1e-9,'AbsTol',1e-23);
            k=table.Model=="gaussian";
            t.verifyEqual(table.MixtureSigma_s(k),table.CoreSigma_s(k),'RelTol',1e-12);
            t.verifyEqual(table.NnetRate_Hz,table.NnetWindow/p.measurementTime);
        end

        function independentJointExportContainsCsvCurveAndCompleteMat(t)
            [o,~]=fixture(); root=string(tempname); cleanup=onCleanup(@()removeFolder(root));
            files=exportSelectedResults(o,root,"only",options());
            t.verifyEqual(numel(files),3); t.verifyFalse(isfile(fullfile(root,'only_results.csv')));
            saved=load(fullfile(root,'only_joint_fit_result.mat'));
            t.verifyEqual(saved.jointFit,o.jointFit); t.verifyEqual(saved.params,o.params);
            t.verifyEqual(saved.dataMode,o.dataMode);
            table=readtable(fullfile(root,'only_joint_fit_summary.csv'),'TextType','string');
            t.verifyEqual(table.NnetRate_Hz,o.jointFit.summary.NnetRate_Hz,'RelTol',1e-12);
            t.verifyEqual(table.MixtureSigma_s,o.jointFit.summary.MixtureSigma_s,'RelTol',1e-12);
            h=readtable(fullfile(root,'only_joint_fit_profile.csv'));
            t.verifyEqual(h.ObservedCounts,o.jointFit.histogram.ObservedCounts);
            clear cleanup
        end

        function combinedSelectionExportsOnceAndPreservesCompleteMetricValues(t)
            [o,~]=fixture(); root=string(tempname); cleanup=onCleanup(@()removeFolder(root));
            opts=options(); opts.results=true;
            files=exportSelectedResults(o,root,"both",opts);
            t.verifyEqual(numel(files),4); t.verifyEqual(numel(unique(files)),4);
            file=fullfile(root,'both_results.csv');
            importOptions=detectImportOptions(file,'VariableNamingRule','preserve', ...
                'NumHeaderLines',0,'Delimiter',',');
            importOptions=setvartype(importOptions,importOptions.VariableNames,'string');
            importOptions=setvaropts(importOptions,importOptions.VariableNames,'TreatAsMissing',{});
            table=readtable(file,importOptions);
            expected=buildJointFitMetricRows(o.jointFit,true);
            count=size(expected,1);
            t.verifyEqual(table.('参数')(1:count),string(expected(:,1)));
            t.verifyEqual(table.('数值')(2:count),string(expected(2:end,2)));
            clear cleanup
        end

        function unavailableFitStillExportsDiagnosticSummaryAndMat(t)
            [o,~]=fixture(); j=o.jointFit; j.valid=false; j.models=struct();
            j.status="unavailable"; j.message="测试不可用状态"; j.histogram=table();
            j.summary=buildJointFitSummaryTable(j,o.params.measurementTime); o.jointFit=j;
            root=string(tempname); cleanup=onCleanup(@()removeFolder(root));
            files=exportSelectedResults(o,root,"bad",options());
            t.verifyEqual(numel(files),2);
            t.verifyFalse(isfile(fullfile(root,'bad_joint_fit_profile.csv')));
            t.verifyTrue(all(isnan(j.summary.CoreSigma_s)));
            t.verifyEqual(j.summary.NrecTruth,repmat(j.truth.recordedPairs,2,1));
            rows=buildJointFitMetricRows(j);
            t.verifyEqual(string(rows{strcmp(rows(:,1),'联合拟合核心 σ (ps)'),2}),"N/A");
            clear cleanup
        end

        function disabledJointAnalysisRejectsExplicitExportsBeforeWriting(t)
            [o,p]=fixture(); o.jointFit=[]; p.jointFit.enabled=false;
            root=string(tempname); cleanup=onCleanup(@()removeFolder(root));
            t.verifyError(@()exportSelectedResults(o,root,"no",options()),'CoincidenceSim:MissingJointFit');
            t.verifyFalse(isfolder(root));
            t.verifyError(@()runRandomSeedSweep(p,struct('start',1,'step',1,'count',1), ...
                root,"no",struct('jointFit',true)),'CoincidenceSim:MissingJointFit');
            t.verifyError(@()batchAnalyzeTimestampFolder(pwd,root,1,p,@(~,~,~)true, ...
                struct('jointFit',true)),'CoincidenceSim:MissingJointFit');
            t.verifyFalse(isfolder(root)); clear cleanup
        end

        function wholeAndPerSecondBatchAndSeedAllowOnlyJointFiles(t)
            [o,p]=fixture(); root=string(tempname); mkdir(root); cleanup=onCleanup(@()removeFolder(root));
            input=fullfile(root,'input'); mkdir(input);
            writematrix(o.A.time,fullfile(input,'pair_CH1.txt'));
            writematrix(o.B.time,fullfile(input,'pair_CH2.txt'));
            opts=struct('histogram',false,'results',false,'uncertainty',false, ...
                'optimization',false,'evaluation',false,'jointFit',true);
            for perSecond=[false true]
                opts.perSecond=perSecond;
                report=batchAnalyzeTimestampFolder(input,fullfile(root,'batch'),1,p,@(~,~,~)true,opts);
                t.assertEqual(report.successCount,1,report.log.Message(1));
                t.verifyEqual(numel(dir(fullfile(report.outputFolder,'**','*_joint_fit_result.mat'))),1);
                t.verifyEqual(numel(dir(fullfile(report.outputFolder,'**','*_joint_fit_summary.csv'))),1);
                t.verifyEqual(numel(dir(fullfile(report.outputFolder,'**','*_results.csv'))),0);
            end
            report=runRandomSeedSweep(p,struct('start',8,'step',1,'count',1), ...
                root,"seed",struct('jointFit',true));
            t.assertEqual(report.successCount,1,report.log.Message(1));
            t.verifyEqual(report.log.ExportedFiles,3); clear cleanup
        end

        function legacyCsvEntryAlsoExportsCompleteJointFiles(t)
            [o,~]=fixture(); root=string(tempname); mkdir(root); cleanup=onCleanup(@()removeFolder(root));
            exportSimulationResult(o,fullfile(root,'legacy.csv'));
            t.verifyTrue(isfile(fullfile(root,'legacy_joint_fit_summary.csv')));
            t.verifyTrue(isfile(fullfile(root,'legacy_joint_fit_profile.csv')));
            saved=load(fullfile(root,'legacy_joint_fit_result.mat'));
            t.verifyEqual(saved.jointFit.summary,o.jointFit.summary); clear cleanup
        end

        function explicitOffDoesNotExportJointSidecars(t)
            [o,~]=fixture(); root=string(tempname); cleanup=onCleanup(@()removeFolder(root));
            opts=options(); opts.results=true; opts.jointFit=false;
            files=exportSelectedResults(o,root,"off",opts);
            t.verifyEqual(files,string(fullfile(root,'off_results.csv')));
            t.verifyEmpty(dir(fullfile(root,'*_joint_fit_*'))); clear cleanup
        end

        function fixedWindowsIncludeTheirCompleteJointResultsWhenSelected(t)
            [o,p]=fixture(); p.algorithm.timestampWindowSize=.15;
            o.timeWindows=analyzeTimestampWindows(o.A,o.B,p,o.source,o.dataMode);
            root=string(tempname); cleanup=onCleanup(@()removeFolder(root));
            opts=options(); opts.timeWindows=true;
            exportSelectedResults(o,root,"windows",opts);
            t.verifyEqual(numel(dir(fullfile(root,'**','*_time_window_*_joint_fit_result.mat'))),2);
            t.verifyTrue(isfile(fullfile(root,'windows_joint_fit_result.mat'))); clear cleanup
        end
    end
end

function [o,p]=fixture()
p=defaultParams(); p.source.pairRate=2e4; p.measurementTime=.3;
p.detector.A.timingModel="gaussian"; p.detector.B.timingModel="gaussian";
p.detector.A.backgroundRate=1e5; p.detector.B.backgroundRate=1e5;
p.uncertainty.enabled=false; p.optimization.mode="manual"; p.jointFit.enabled=true;
p.jointFit.maxShapeFitPairs=10000; p.jointFit.streamChunkPairs=1000;
persistent result
if isempty(result), result=runSimulation(p); end
o=result;
end

function opts=options()
opts=struct('settings',false,'histogram',false,'results',false,'timestamps',false, ...
    'jointFit',true,'unitSeconds',1e-12);
end

function removeFolder(folder)
% 只清理本测试通过 tempname 创建的独立目录。
if isfolder(folder), rmdir(folder,'s'); end
end
