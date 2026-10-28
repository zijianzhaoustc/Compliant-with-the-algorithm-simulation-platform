classdef TestRandomSeedSweep < matlab.unittest.TestCase
    methods (Test)
        function sequenceSupportsBothDirectionsAndRejectsOverflow(t)
            t.verifyEqual(buildSeedSequence(1,3,4),[1;4;7;10]);
            t.verifyEqual(buildSeedSequence(7,-3,3),[7;4;1]);
            t.verifyEqual(buildSeedSequence(0,1,1),0);
            t.verifyEqual(buildSeedSequence(2^32-1,1,1),2^32-1);
            t.verifyError(@()buildSeedSequence(0,-1,2),'CoincidenceSim:InvalidSeedRange');
            t.verifyError(@()buildSeedSequence(2^32-1,1,2),'CoincidenceSim:InvalidSeedRange');
        end

        function eachSeedMatchesStandaloneSimulationAndLeavesBaseParametersFixed(t)
            root=string(tempname); mkdir(root); cleanup=onCleanup(@()rmdir(root,'s'));
            p=parameters(); p.seed=42; p.optimization.mode="manual"; original=p;
            options=struct('settings',true,'histogram',true,'timestamps',true,'unitSeconds',1);
            spec=struct('start',10,'step',3,'count',3); state=rng;
            report=runRandomSeedSweep(p,spec,root,"test",options);
            t.verifyEqual(rng,state); t.verifyEqual(p,original);
            t.verifyEqual(report.log.Seed,[10;13;16]); t.verifyEqual(report.successCount,3);
            t.verifyEqual(report.log.ExportedFiles,[4;4;4]);
            streams=cell(3,1);
            for k=1:3
                q=p; q.seed=report.log.Seed(k); expected=runSimulation(q);
                folder=report.log.OutputFolder(k); prefix=sprintf('test_seed_%d',q.seed);
                settings=load(fullfile(folder,prefix+"_settings.mat"));
                t.verifyEqual(settings.params,expected.params);
                streams{k}=readmatrix(fullfile(folder,prefix+"_StartCh.txt"));
                t.verifyEqual(streams{k},expected.A.time,'AbsTol',1e-13);
                b=readmatrix(fullfile(folder,prefix+"_StopCh.txt"));
                t.verifyEqual(b,expected.B.time,'AbsTol',1e-13);
                h=readtable(fullfile(folder,prefix+"_histogram.csv"));
                t.verifyEqual(h.Counts,expected.hist.counts(:));
                t.verifyFalse(isfile(fullfile(folder,prefix+"_results.csv")));
            end
            t.verifyFalse(isequal(streams{1},streams{2}));
            snapshot=load(fullfile(report.outputFolder,'seed_sweep_settings.mat'));
            t.verifyEqual(snapshot.params,p); t.verifyEqual(snapshot.spec,spec);
            clear cleanup
        end

        function allSelectiveExportCategoriesAreGeneratedForEachSimulation(t)
            root=string(tempname); mkdir(root); cleanup=onCleanup(@()rmdir(root,'s'));
            p=parameters(); p.algorithm.timestampWindowSize=.05;
            options=struct('settings',true,'histogram',true,'results',true,'sweep',true, ...
                'timeWindows',true,'countRates',true,'uncertainty',true,'timestamps',true, ...
                'optimization',true,'unitSeconds',1e-12,'sweepWidths',[1;2]*1e-9);
            report=runRandomSeedSweep(p,struct('start',7,'step',1,'count',1),root,"all",options);
            t.verifyEqual(report.successCount,1,report.log.Message(1));
            folder=report.log.OutputFolder(1); prefix="all_seed_7";
            suffix=["_settings.mat","_histogram.csv","_results.csv","_window_sweep.csv", ...
                "_uncertainty_summary.csv","_bootstrap_blocks.csv","_bootstrap_replicates.csv", ...
                "_StartCh.txt","_StopCh.txt","_optimization_summary.csv"];
            for ending=suffix, t.verifyTrue(isfile(fullfile(folder,prefix+ending))); end
            windows=fullfile(folder,prefix+"_time_windows");
            t.verifyEqual(numel(dir(fullfile(windows,'*_histogram.csv'))),4);
            rates=fullfile(folder,prefix+"_per_second_analysis");
            t.verifyTrue(isfile(fullfile(rates,prefix+"_per_second_count_rates.csv")));
            t.verifyTrue(isfile(fullfile(rates,prefix+"_per_second_timing_fit.csv")));
            clear cleanup
        end

        function cancellationKeepsFinishedSeedsAndInvalidSelectionsCreateNoBatch(t)
            root=string(tempname); mkdir(root); cleanup=onCleanup(@()rmdir(root,'s'));
            p=parameters(); p.optimization.mode="manual";
            options=struct('histogram',true);
            report=runRandomSeedSweep(p,struct('start',3,'step',2,'count',3),root,"cancel", ...
                options,@(completed,~,~)completed<1);
            t.verifyTrue(report.cancelled); t.verifyEqual(report.successCount,1);
            t.verifyEqual(report.log.Status,["success";"cancelled";"cancelled"]);
            t.verifyTrue(isfile(fullfile(report.log.OutputFolder(1),'cancel_seed_3_histogram.csv')));
            log=readtable(fullfile(report.outputFolder,'seed_sweep_log.csv'),'TextType','string');
            t.verifyEqual(log.Status,report.log.Status);
            rejected=fullfile(root,'rejected');
            t.verifyError(@()runRandomSeedSweep(p,struct('start',1,'step',1,'count',2), ...
                rejected,"empty",struct()),'CoincidenceSim:NoSeedSweepExports');
            t.verifyFalse(isfolder(rejected));
            clear cleanup
        end
    end
end

function p=parameters()
p=defaultParams(); p.source.pairRate=2000; p.measurementTime=.2;
p.uncertainty.resamples=20; p.optimization.candidateResamples=10;
end
