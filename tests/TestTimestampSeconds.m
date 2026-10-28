classdef TestTimestampSeconds < matlab.unittest.TestCase
    methods (Test)
        function tenSecondsProduceTenSelectableHistograms(t)
            root=string(tempname); mkdir(root); cleanup=onCleanup(@()rmdir(root,'s'));
            timestamps=[0;.2;(1:10)'];
            out=importFixture(root,timestamps,timestamps,parameters()); original=out;
            options=exportOptions(); options.histogram=true;
            files=exportSelectedResults(out,root,"ten",options);
            t.verifyEqual(numel(files),11);
            index=readtable(fullfile(root,'ten_per_second_results','ten_second_index.csv'));
            t.verifyEqual(index.Start_s,(0:9)'); t.verifyEqual(index.Stop_s,(1:10)');
            expected=[2;ones(8,1);2];
            t.verifyEqual(index.CountA,expected); t.verifyEqual(index.CountB,expected);
            t.verifyEqual(index.Nraw,expected); t.verifyEqual(sum(index.CountA),numel(timestamps));
            for k=1:10
                h=readtable(fullfile(index.OutputFolder{k},sprintf('ten_second_%04d_histogram.csv',k)));
                t.verifyEqual(sum(h.Counts),expected(k));
                t.verifyEqual(numel(dir(fullfile(index.OutputFolder{k},'*.csv'))),1);
            end
            t.verifyEqual(out,original);
            clear cleanup
        end

        function partialSecondUsesActualDurationAndPreservesAbsoluteTimestamps(t)
            root=string(tempname); mkdir(root); cleanup=onCleanup(@()rmdir(root,'s'));
            % 0.4 ns 的跨秒符合只属于整段结果，不应串入任一独立子窗。
            a=100+[0;.9999999998;1.5;2.4]; b=100+[.2;1.0000000002;1.5;2.4];
            out=importFixture(root,a,b,parameters());
            options=exportOptions(); options.settings=true; options.results=true;
            options.uncertainty=true; options.timestamps=true; options.optimization=true;
            exportSelectedResults(out,root,"partial",options);
            index=readtable(fullfile(root,'partial_per_second_results','partial_second_index.csv'));
            t.verifyEqual(index.CountA,[2;1;1]); t.verifyEqual(index.CountB,[1;2;1]);
            t.verifyEqual(index.Nraw,[0;1;1]);
            t.verifyEqual(index.Duration_s,[1;1;.4],'AbsTol',1e-12);
            folder=index.OutputFolder{3};
            snapshot=load(fullfile(folder,'partial_second_0003_settings.mat'));
            t.verifyEqual(snapshot.params.measurementTime,.4,'AbsTol',1e-12);
            u=readtable(fullfile(folder,'partial_second_0003_uncertainty_summary.csv'),'TextType','string');
            t.verifyEqual(u.Estimate(u.Metric=="RA"),2.5,'AbsTol',1e-10);
            t.verifyEqual(u.Estimate(u.Metric=="Nraw"),1);
            replicates=readtable(fullfile(folder,'partial_second_0003_bootstrap_replicates.csv'));
            t.verifyEqual(height(replicates),out.params.uncertainty.resamples);
            restored=readmatrix(fullfile(folder,'partial_second_0003_StartCh.txt'));
            t.verifyEqual(restored,102.4,'AbsTol',1e-12);
            recommendation=readtable(fullfile(folder,'partial_second_0003_optimization_summary.csv'),'TextType','string');
            t.verifyEqual(recommendation.Status,"disabled");
            t.verifyFalse(isfile(fullfile(folder,'partial_second_0003_histogram.csv')));
            clear cleanup
        end

        function emptySecondsStillExportIndependentUncertaintyAndRecommendation(t)
            root=string(tempname); mkdir(root); cleanup=onCleanup(@()rmdir(root,'s'));
            p=parameters(); p.optimization.mode="recommend";
            times=[0;.2;2.1;2.4]; out=importFixture(root,times,times,p);
            options=exportOptions(); options.uncertainty=true; options.optimization=true;
            exportSelectedResults(out,root,"empty",options);
            index=readtable(fullfile(root,'empty_per_second_results','empty_second_index.csv'));
            t.verifyEqual(index.CountA,[2;0;2]);
            folder=index.OutputFolder{2};
            recommendation=readtable(fullfile(folder,'empty_second_0002_optimization_summary.csv'),'TextType','string');
            t.verifyEqual(recommendation.Mode,"recommend"); t.verifyFalse(logical(recommendation.Applied));
            t.verifyNotEqual(recommendation.Status,"not-run");
            u=readtable(fullfile(folder,'empty_second_0002_uncertainty_summary.csv'),'TextType','string');
            t.verifyEqual(u.Estimate(u.Metric=="Nraw"),0);
            t.verifyFalse(isfile(fullfile(folder,'empty_second_0002_results.csv')));
            clear cleanup
        end
    end
end

function p=parameters()
p=defaultParams(); p.optimization.mode="manual"; p.uncertainty.resamples=20;
p.optimization.candidateResamples=10; p.algorithm.accidentalMethod="none";
end

function options=exportOptions()
options=struct('settings',false,'histogram',false,'results',false,'timestamps',false, ...
    'uncertainty',false,'optimization',false,'unitSeconds',1,'perSecond',true);
end

function out=importFixture(root,a,b,p)
start=fullfile(root,'fixture_CH1.txt'); stop=fullfile(root,'fixture_CH2.txt');
writematrix(a,start); writematrix(b,stop); out=importTimestampFiles(start,stop,1,p);
end
