classdef TestUncertainty < matlab.unittest.TestCase
    %TESTUNCERTAINTY 联合分块、解析公式、真值语义及导出回归。
    methods (Test)
        function automaticAnalysisAndBlockConservation(t)
            o=fixture(); b=o.uncertainty.blocks;
            t.verifyEqual(b.count,30);
            t.verifyEqual(sum(b.C),o.metrics.Nraw);
            t.verifyEqual(sum(b.side),o.metrics.Nacc_side,'AbsTol',1e-12);
            t.verifyEqual(sum(b.NA),numel(o.A.time));
            t.verifyEqual(sum(b.NB),numel(o.B.time));
            t.verifyEqual(sum(b.TP),o.metrics.TP);
            t.verifyEqual(sum(b.FP),o.metrics.FP);
            t.verifyEqual(o.metrics.Nraw,o.metrics.TP+o.metrics.FP);
            t.verifyEqual(o.metrics.Nacc_GT,o.metrics.FP);
            t.verifyEqual(o.metrics.Ncorr_GT,o.metrics.TP);
            t.verifyEqual(o.uncertainty.bootstrap.resamples,2000);
            t.verifyEqual(height(o.uncertainty.bootstrap.replicates),2000);
        end

        function crossingBoundaryAndExposure(t)
            p=defaultParams(); p.measurementTime=2;
            p.uncertainty.blockMode="manual"; p.uncertainty.blockSize=1;
            p.algorithm.binWidth=.1e-9; p.algorithm.window=1e-9;
            A=events([.2;1-1e-9;1.5;2-6e-9]);
            B=events(A.time+5e-9);
            o=analyzeTimestampData(A,B,p,struct(),'simulation');
            t.verifyEqual(o.metrics.Nraw,4);
            t.verifyEqual(o.uncertainty.blocks.C,[2;2]);
            t.verifyEqual(o.uncertainty.blocks.NB,[1;3]);
            t.verifyEqual(o.uncertainty.blocks.blockSize,1);
            p.measurementTime=2.1; p.uncertainty.blockSize=1;
            o=analyzeTimestampData(A,B,p,struct(),'simulation');
            t.verifyEqual(o.uncertainty.blocks.count,3);
            t.verifyEqual(o.uncertainty.blocks.blockSize,.7,'AbsTol',1e-15);
            p.measurementTime=60; p.uncertainty.blockMode="auto";
            o=analyzeTimestampData(A,B,p,struct(),'simulation');
            t.verifyEqual(o.uncertainty.blocks.count,60);
            t.verifyEqual(o.uncertainty.blocks.blockSize,1);
        end

        function analyticalFormulaAndCovariance(t)
            o=fixture(); a=o.uncertainty.analytical.standardUncertainty;
            L=numel(o.acc.sideWindowCounts); total=sum(o.acc.sideWindowCounts);
            na=numel(o.A.time); nb=numel(o.B.time); f=o.raw.window/o.params.measurementTime;
            t.verifyEqual(a(1),sqrt(o.raw.count));
            t.verifyEqual(a(2),sqrt(total)/L,'AbsTol',1e-12);
            t.verifyEqual(a(3),f*sqrt(nb^2*na+na^2*nb),'AbsTol',1e-12);
            t.verifyEqual(a(4)^2,a(1)^2+a(2)^2,'RelTol',1e-12);
            bs=o.uncertainty.bootstrap; c=bs.covariance;
            t.verifyEqual(bs.standardUncertainty(4)^2,c(1,1)+c(2,2)-2*c(1,2),'AbsTol',1e-9);
            t.verifyEqual(bs.standardUncertainty(5)^2,c(1,1)+c(3,3)-2*c(1,3),'AbsTol',1e-9);
            r=bs.replicates;
            t.verifyEqual(r.Nacc_theory,r.NA.*r.NB*f,'AbsTol',1e-12);
            t.verifyEqual(r.Ncorr_side,r.Nraw-r.Nacc_side);
            t.verifyEqual(r.Error_corr_side,r.Ncorr_side-r.TP);
        end

        function reproducibleAndGlobalRngUnchanged(t)
            o=fixture(); rng(57); before=rng;
            first=runBlockBootstrap(o.uncertainty.blocks,o.params.uncertainty);
            t.verifyEqual(rng,before);
            second=runBlockBootstrap(o.uncertainty.blocks,o.params.uncertainty);
            t.verifyEqual(first.replicates,second.replicates);
            p=o.params; p.uncertainty.enabled=false;
            disabled=runSimulation(p); state=rng;
            p.uncertainty.enabled=true;
            enabled=runSimulation(p);
            t.verifyEqual(enabled.A,disabled.A); t.verifyEqual(enabled.B,disabled.B);
            t.verifyEqual(enabled.metrics,disabled.metrics);
            t.verifyEqual(rng,state);
        end

        function negativeNetAndSharedSamples(t)
            p=defaultParams(); u=p.uncertainty;
            b=struct('count',3,'blockSize',1,'duration',3,'window',.01, ...
                'C',[1;2;3],'side',[4;5;6],'S',[4;5;6], ...
                'NA',[10;20;40],'NB',[20;10;40],'TP',[1;2;3],'FP',zeros(3,1));
            bs=runBlockBootstrap(b,u);
            t.verifyEqual(bs.point(4),-9);
            t.verifyEqual(bs.replicates.Ncorr_side,repmat(-9,u.resamples,1));
            t.verifyEqual(bs.standardUncertainty(4),0,'AbsTol',1e-14);
            % C 和 side 完全相关，共同抽样应抵消波动；独立抽样无法通过。
            t.verifyGreaterThan(bs.covariance(1,2),0);
            t.verifyTrue(all(isnan(bs.replicates.epsilon_acc_side)));
        end

        function importedTruthAndSubwindowSuppression(t)
            o=fixture(); p=o.params;
            A=o.A; B=o.B; A.pairID(:)=0; B.pairID(:)=0;
            measured=analyzeTimestampData(A,B,p,struct(),'imported');
            t.verifyTrue(all(isnan([measured.metrics.TP,measured.metrics.FP, ...
                measured.metrics.epsilon_acc_side,measured.metrics.epsilon_corr_theory])));
            t.verifyTrue(all(isnan(measured.uncertainty.summary.GroundTruth)));
            t.verifyTrue(all(isnan(measured.uncertainty.bootstrap.replicates.TP)));
            p.algorithm.timestampWindowSize=.4;
            w=analyzeTimestampWindows(A,B,p,struct(),'imported');
            for k=1:w.count
                t.verifyEmpty(w.results{k}.uncertainty.bootstrap);
                t.verifyEmpty(w.results{k}.uncertainty.blocks);
            end
            t.verifyNotEmpty(measured.uncertainty.bootstrap);
            [rates,~]=buildPerSecondCountRateTable(measured);
            t.verifyEqual(height(rates),ceil(p.measurementTime));
            changed=p; changed.uncertainty.seed=9;
            again=recalculateAnalysis(measured,changed);
            t.verifyEqual(again.uncertainty.bootstrap.seed,9);
        end

        function emptySideWindowsAndSparseCounts(t)
            p=defaultParams(); p.measurementTime=1;
            p.algorithm.sidebandGuard=1;
            A=events(.5); B=events(.5+5e-9);
            o=analyzeTimestampData(A,B,p,struct(),'simulation');
            t.verifyTrue(isnan(o.metrics.Nacc_side));
            t.verifyTrue(isnan(o.uncertainty.bootstrap.standardUncertainty(2)));
            t.verifyNotEmpty(o.uncertainty.messages);
            p.algorithm.sidebandGuard=3e-9;
            o=analyzeTimestampData(A,B,p,struct(),'simulation');
            t.verifyEqual(o.metrics.Nacc_side,0);
            t.verifyTrue(isnan(o.uncertainty.analytical.standardUncertainty(2)));
            t.verifyTrue(isnan(o.uncertainty.bootstrap.standardUncertainty(2)));
            p.uncertainty.blockMode="manual"; p.uncertainty.blockSize=2;
            o=analyzeTimestampData(A,B,p,struct(),'simulation');
            t.verifyEmpty(o.uncertainty.bootstrap);
            t.verifyTrue(all(isnan(o.uncertainty.summary.U_Bootstrap)));
            empty=events(zeros(0,1));
            o=analyzeTimestampData(empty,empty,defaultParams(),struct(),'simulation');
            t.verifyTrue(isnan(o.uncertainty.analytical.standardUncertainty(1)));
            t.verifyTrue(isnan(o.uncertainty.bootstrap.standardUncertainty(1)));
        end

        function effectiveBinWidthAndLegacySettings(t)
            p=defaultParams(); p=rmfield(p,'uncertainty');
            p=validateParams(p); t.verifyTrue(p.uncertainty.enabled);
            p.algorithm.histRange=[0,10]*1e-9; p.algorithm.binWidth=1e-9;
            p.algorithm.windowMode="bins"; p.algorithm.windowMultiplier=2;
            A=events((.1:.1:.9)'); B=events(A.time+.1e-9);
            o=analyzeTimestampData(A,B,p,struct(),'simulation');
            t.verifyEqual(o.raw.window,3e-9,'AbsTol',1e-20);
            t.verifyEqual(o.acc.effectiveWindow,o.raw.window);
            t.verifyEqual(o.acc.theoryCount,numel(A.time)*numel(B.time)*o.raw.window,'AbsTol',1e-20);
            t.verifyEqual(sum(o.uncertainty.blocks.side),o.acc.sideCount,'AbsTol',1e-12);
        end

        function percentileAndValidation(t)
            b=summarizeBootstrap([(1:5)',(2:6)'],[3,4],["x","y"],.5);
            t.verifyEqual(b.CI,[2,3;4,5]);
            p=defaultParams();
            for field=["resamples","blockSize","confidenceLevel","seed","minBlocks"]
                bad=p; bad.uncertainty.(field)=NaN;
                t.verifyError(@()validateParams(bad),'CoincidenceSim:InvalidUncertainty');
            end
            bad=p; bad.uncertainty.resamples=1;
            t.verifyError(@()validateParams(bad),'CoincidenceSim:InvalidUncertainty');
        end

        function threeNumericExportsAndUiSummary(t)
            o=fixture(); folder=tempname; mkdir(folder);
            cleanup=onCleanup(@()rmdir(folder,'s'));
            options=struct('settings',false,'histogram',false,'results',false, ...
                'timestamps',false,'uncertainty',true,'unitSeconds',1e-12);
            files=exportSelectedResults(o,folder,"test",options);
            t.verifyNumElements(files,3);
            a=readtable(files(1),'VariableNamingRule','preserve','Encoding','UTF-8');
            b=readtable(files(2),'VariableNamingRule','preserve','Encoding','UTF-8');
            r=readtable(files(3),'VariableNamingRule','preserve','Encoding','UTF-8');
            t.verifyEqual(height(r),2000); t.verifyEqual(sum(b.Nraw),o.metrics.Nraw);
            t.verifyTrue(all(ismember({'Estimate','U_Poisson','U_Bootstrap', ...
                'CI_Lower','CI_Upper','GroundTruth','ValidityFlag','W_effective_s'},a.Properties.VariableNames)));
            summary=buildMetricSummaryTable(o);
            names=string(summary.('参数'));
            section=find(names=="【统计不确定度分析】",1);
            t.verifyEqual(names(section+1:end),["原始符合计数 Nraw"; ...
                "旁窗偶然符合 Nacc_side";"理论偶然符合 Nacc_theory"; ...
                "旁窗净符合 Ncorr_side";"理论净符合 Ncorr_theory"]);
            t.verifyEqual(nnz(names=="A通道计数率 RA"),1);
            t.verifyEqual(nnz(names=="B通道计数率 RB"),1);
            t.verifyTrue(all(contains(string(summary.('数值')(section+1:end))," ± ")));
            t.verifyTrue(all(contains(string(summary.('作用')(section+1:end)),"Bootstrap u=")));
            % GUI 筛选不影响完整 CSV 或结果结构中的速率和协方差。
            t.verifyTrue(all(ismember(["RA","RB","Cov_raw_acc_side"],o.uncertainty.summary.Metric)));
            options.uncertainty=false; options.results=true;
            resultFiles=exportSelectedResults(o,folder,"full",options);
            full=readtable(resultFiles(1),'VariableNamingRule','preserve','Encoding','UTF-8');
            t.verifyTrue(all(ismember(["RA","RB","Cov_raw_acc_side","Bootstrap 分块数"],string(full.('参数')))));
            clear cleanup
        end
    end
end

function o=fixture()
p=defaultParams(); p.source.pairRate=2e4;
p.detector.A.backgroundRate=1e5; p.detector.B.backgroundRate=1e5;
p.algorithm.sideWindowPairs=3; p.algorithm.window=1e-9;
o=runSimulation(p);
end

function e=events(time)
e=struct('time',time(:),'pairID',(1:numel(time))','type',repmat("signal",numel(time),1));
end
