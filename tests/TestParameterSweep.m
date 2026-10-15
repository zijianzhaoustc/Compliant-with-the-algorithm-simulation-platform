classdef TestParameterSweep < matlab.unittest.TestCase
    methods(Test)
        function geometryAndZeroBins(t)
            for width=[10 300]*1e-12
                [p,h,m]=geometry(width,3);
                raw=calculateRawCoincidence(m,h,p);
                t.verifyEqual(raw.window,7*width,'AbsTol',1e-23);
                t.verifyEqual(raw.mainBinCount,7);
                p.algorithm.windowMultiplier=0; p=validateParams(p);
                raw=calculateRawCoincidence(m,h,p);
                t.verifyEqual(raw.window,width,'AbsTol',1e-23);
                t.verifyEqual(raw.mainBinCount,1);
            end
        end

        function exactSideWindowBoundariesAndHalfOpenCounts(t)
            [p,h,m]=geometry(10e-12,3); p.algorithm.accidentalMethod="side-window";
            p.algorithm.sideWindowPairs=2;
            events=emptyEvents(); a=estimateAccidentals(events,events,m,h,p);
            t.verifyEqual(a.guardGap,70e-12,'AbsTol',1e-24);
            t.verifyEqual(a.boundaries*1e12,[-175 -105;105 175;-245 -175;175 245],'AbsTol',1e-10);
            m.deltaT=unique(a.boundaries(:)); m.isTrue=false(size(m.deltaT));
            a=estimateAccidentals(events,events,m,h,p);
            t.verifyEqual(a.sampleCounts,ones(4,1));
            t.verifyEqual(a.countEquivalent,1); t.verifyEqual(a.validPairs,2);
            t.verifyEqual(a.status,"OK");
        end

        function strictWindowsNeverSilentlyClip(t)
            [p,h,m]=geometry(10e-12,3);
            h.peak=h.centers(1); raw=calculateRawCoincidence(m,h,p);
            t.verifyEqual(raw.status,"INVALID_MAIN_WINDOW"); t.verifyTrue(isnan(raw.count));
            h.peak=0; p.algorithm.sideWindowPairs=100; p.algorithm.accidentalMethod="side-window";
            a=estimateAccidentals(emptyEvents(),emptyEvents(),m,h,p);
            t.verifyEqual(a.status,"INVALID_SIDE_WINDOWS"); t.verifyTrue(isnan(a.rate));
            p.algorithm.strictWindows=false; h.peak=h.centers(1);
            legacy=calculateRawCoincidence(m,h,p);
            t.verifyEqual(legacy.status,"OK"); t.verifyEqual(legacy.mainBinCount,4);
        end

        function invalidPeakAndFitFailure(t)
            [p,h,m]=geometry(10e-12,3);
            h.peakValid=false; raw=calculateRawCoincidence(m,h,p);
            t.verifyEqual(raw.status,"INVALID_PEAK");
            h.peakValid=true; h.fitStatus="FIT_FAILED";
            t.verifyEqual(calculateRawCoincidence(m,h,p).status,"INVALID_PEAK");
            h.fitStatus="MAXIMUM"; h.peak=Inf;
            t.verifyEqual(calculateRawCoincidence(m,h,p).status,"INVALID_PEAK");
        end

        function mainHistogramLastEdgeIncluded(t)
            [p,h,m]=geometry(10e-12,0);
            h.peak=h.centers(end); m.deltaT=h.edges(end);
            raw=calculateRawCoincidence(m,h,p);
            t.verifyEqual(raw.count,1); t.verifyTrue(raw.includeUpperEdge);
            p.algorithm.histRange(2)=h.edges(end)-.1*p.algorithm.binWidth;
            raw=calculateRawCoincidence(m,h,p);
            t.verifyEqual(raw.status,"INVALID_MAIN_WINDOW");
        end

        function explicitRangeAndLogExpansion(t)
            f=scanFactor("source.pairRate",[]); f.inputMode="range";
            f.start=0; f.stop=.3; f.step=.1; v=expandScanValues(f);
            t.verifyEqual(v,[0 .1 .2 .3],'AbsTol',1e-15);
            f.start=3; f.stop=1; f.step=-1; t.verifyEqual(expandScanValues(f),[3 2 1]);
            f.inputMode="log"; f.start=1; f.stop=100; f.count=3;
            t.verifyEqual(expandScanValues(f),[1 10 100],'AbsTol',1e-12);
            f=scanFactor("algorithm.accidentalMethod","theory, side-window, time-shift");
            t.verifyEqual(expandScanValues(f),["theory","side-window","time-shift"]);
        end

        function channelLockAndIndependentGrid(t)
            c=smallConfig(); c.factors=scanFactor("detector.darkRate",[0 500 1000]);
            plan=buildScanGrid(c); t.verifyNumElements(plan,3);
            for p=plan'
                t.verifyEqual(p.params.detector.A.darkRate,p.params.detector.B.darkRate);
            end
            c.factors=[scanFactor("detector.darkRate",[0 500],"A");scanFactor("detector.darkRate",[0 700],"B")];
            plan=buildScanGrid(c); t.verifyNumElements(plan,4);
            t.verifyEqual(sort(arrayfun(@(r)r.params.detector.B.darkRate,plan)),[0;0;700;700]);
            c.factors=[scanFactor("detector.darkRate",[0 1]);scanFactor("detector.darkRate",2,"A")];
            t.verifyError(@()buildScanGrid(c),'CoincidenceSim:ScanOverlap');
        end

        function oatAndTwoFactorModes(t)
            c=smallConfig(); c.mode="oat";
            c.factors=[scanFactor("source.pairRate",[1000 2000]);scanFactor("algorithm.binWidth",[10 20 30])];
            plan=buildScanGrid(c); t.verifyNumElements(plan,5);
            c.mode="two-factor"; plan=buildScanGrid(c); t.verifyNumElements(plan,6);
            c.factors=c.factors(1); t.verifyError(@()buildScanGrid(c),'CoincidenceSim:ScanMode');
        end

        function disabledEffectsAndPumpAreExplicit(t)
            c=smallConfig(); c.factors=[scanFactor("detector.deadTime",[10 20]); ...
                scanFactor("detector.afterpulseLifetime",[20 40])];
            plan=buildScanGrid(c);
            t.verifyTrue(all(contains([plan.warning_codes],"EFFECT_DISABLED")));
            c.baseParams.detector.enableDeadTime=true; c.baseParams.detector.enableAfterpulse=true;
            plan=buildScanGrid(c); t.verifyFalse(any(contains([plan.warning_codes],"EFFECT_DISABLED")));
            c.baseParams.source.mode="pump"; c.factors=scanFactor("source.pairRate",[1 2]);
            t.verifyError(@()buildScanGrid(c),'CoincidenceSim:PumpScan');
        end

        function truthAndZeroDenominators(t)
            c=smallConfig(); p=c.baseParams; p.optics.A.delay=0; p.optics.B.delay=0;
            A=events([.01;.03],[1;2]); data=toyData(A,A,p);
            out=analyzeSweepVariant(data,p); r=buildAllMetricRecord(p,out);
            t.verifyEqual(out.metrics.TP,2); t.verifyEqual(out.metrics.FP,0);
            t.verifyEqual(r.Nrec_true,2); t.verifyEqual(r.Npair_true_in_window,2);
            t.verifyTrue(isnan(r.epsilon_acc_vs_true)); t.verifyTrue(isnan(r.Npair_est_total));
            data=toyData(events(.01,0),events(.01,0),p);
            r=buildAllMetricRecord(p,analyzeSweepVariant(data,p));
            t.verifyEqual(r.Npair_true_in_window,0); t.verifyTrue(isnan(r.epsilon_pair_window));
        end

        function knownBackgroundCountsAndSignedNet(t)
            c=smallConfig(); p=c.baseParams; p.algorithm.binWidth=1;
            p.algorithm.histRange=[-5.5 5.5]; p.algorithm.windowMultiplier=0;
            p.algorithm.accidentalMethod="side-window"; p.algorithm.sideWindowPairs=1;
            p.measurementTime=100;
            A=events(20,1); B=events([17.5;17.7;20;20.1;22.1;22.3],[0;0;1;0;0;0]);
            data=toyData(A,B,p); out=analyzeSweepVariant(data,p);
            % Deliberately flat background: fix the independently known toy peak.
            out.hist.peak=0;
            out.raw=calculateRawCoincidence(out.matches,out.hist,p);
            out.raw.matchesIsTrue=out.matches.isTrue;
            out.acc=estimateAccidentals(A,B,out.matches,out.hist,p);
            out.metrics=calculateMetrics(A,B,out.matches,out.raw,out.acc,out.hist,p,"simulation");
            t.verifyEqual(out.metrics.Nraw,2); t.verifyEqual(out.metrics.TP,1); t.verifyEqual(out.metrics.FP,1);
            t.verifyEqual(out.acc.sampleCounts,[2;2]); t.verifyEqual(out.metrics.Nacc,2);
            r=buildAllMetricRecord(p,out); t.verifyEqual(r.Npair_est_window,0);
            t.verifyEqual(r.matched_pair_count,6); t.verifyEqual(r.histogram_count_total,6);
            t.verifyEqual(r.epsilon_acc_vs_true,1); t.verifyEqual(r.epsilon_pair_window,-1);
            p.algorithm.sideWindowPairs=5;
            out.acc=estimateAccidentals(A,B,out.matches,out.hist,p);
            out.metrics=calculateMetrics(A,B,out.matches,out.raw,out.acc,out.hist,p,"simulation");
            t.verifyEqual(out.acc.status,"INVALID_SIDE_WINDOWS");
            t.verifyTrue(isnan(out.metrics.NnetSigned)); t.verifyTrue(isnan(out.metrics.Nnet));
        end

        function widerRangeRematchesOriginalStreams(t)
            c=smallConfig(); p=c.baseParams; p.algorithm.histRange=[-1 1]*1e-9;
            data=toyData(events(.01,1),events(.01+5e-9,1),p);
            first=analyzeSweepVariant(data,p); t.verifyEmpty(first.matches.deltaT);
            p.algorithm.histRange=[-10 10]*1e-9;
            second=analyzeSweepVariant(data,p); t.verifyNumElements(second.matches.deltaT,1);
            t.verifyEqual(second.metrics.TP,1);
        end

        function methodsReuseTimestampTruth(t)
            c=smallConfig(); p=c.baseParams; data=generateSimulationData(p);
            streamHash=scanStreamHash(data); truth=[];
            for method=["theory","side-window","time-shift"]
                p.algorithm.accidentalMethod=method; p.algorithm.timeShiftCount=2;
                out=analyzeSweepVariant(data,p);
                value=[out.metrics.RA out.metrics.RB out.metrics.TP out.metrics.FP];
                if isempty(truth), truth=value; else, t.verifyEqual(value,truth); end
                t.verifyEqual(scanStreamHash(data),streamHash);
            end
        end

        function pairAndPlanningLimitsRejectBeforeAllocation(t)
            c=smallConfig(); c.limits.maxRows=1; c.factors=scanFactor("source.pairRate",[1 2]);
            t.verifyError(@()buildScanGrid(c),'CoincidenceSim:ScanLimit');
            c=smallConfig(); c.baseParams.source.pairRate=1e15;
            t.verifyError(@()buildScanGrid(c),'CoincidenceSim:ScanLimit');
            c=smallConfig(); p=c.baseParams; p.algorithm.maxMatchPairs=3;
            A=events([0;0],[1;2]);
            t.verifyError(@()matchCoincidences(A,A,p),'CoincidenceSim:PairLimit');
            c.factors=[scanFactor("algorithm.histHalfRange",100);scanFactor("algorithm.binWidth",.001)];
            t.verifyError(@()buildScanGrid(c),'CoincidenceSim:ScanLimit');
        end

        function completeExportAnd32RowReuse(t)
            c=parameterSweepExamples(); c.outputRoot=tempname; mkdir(c.outputRoot);
            cleanup=onCleanup(@()rmdir(c.outputRoot,'s'));
            b=runParameterSweep(c); rows=b.results;
            t.verifyEqual(height(rows),32); t.verifyEqual(b.generationCount,4);
            for key=unique(rows.stream_key)'
                selected=rows(rows.stream_key==key,:);
                t.verifyEqual(numel(unique(selected.stream_hash)),1);
                t.verifyEqual(numel(unique(selected.RA_cps)),1); t.verifyEqual(numel(unique(selected.RB_cps)),1);
            end
            out=runSimulation(c.baseParams); expected=fieldnames(out.metrics);
            t.verifyTrue(all(ismember("metric_"+string(expected),string(rows.Properties.VariableNames))));
            row=rows(1,:); p=jsondecode(row.parameters_json); data=generateSimulationData(p);
            check=analyzeSweepVariant(data,p);
            for j=1:numel(expected)
                t.verifyEqual(row.("metric_"+expected{j}),check.metrics.(expected{j}));
            end
            for file=["configurations.csv","scan_results.csv","seed_summary.csv","invalid_or_errors.csv","run_status.csv"]
                path=fullfile(b.outputDirectory,file); t.verifyTrue(isfile(path)); readtable(path);
                fid=fopen(path,'r'); bytes=fread(fid,3,'uint8=>uint8'); fclose(fid);
                t.verifyEqual(bytes,uint8([239;187;191]));
            end
            config=jsondecode(fileread(fullfile(b.outputDirectory,'scan_config.json')));
            t.verifyEqual(config.baseParams.tdc.resolution,c.baseParams.tdc.resolution);
            t.verifyEqual(height(b.seedSummary),16); t.verifyTrue(all(b.seedSummary.replicate_count==2));
            second=runParameterSweep(c); t.verifyNotEqual(second.outputDirectory,b.outputDirectory);
            clear cleanup
        end

        function invalidRowsAndEmptyStreamsAreKept(t)
            c=smallConfig(); c.outputRoot=tempname; mkdir(c.outputRoot);
            cleanup=onCleanup(@()rmdir(c.outputRoot,'s'));
            c.baseParams.source.pairRate=0; c.baseParams.detector.enableDark=false;
            b=runParameterSweep(c); t.verifyEqual(b.results.status,"NO_EVENTS");
            bad=readtable(fullfile(b.outputDirectory,'invalid_or_errors.csv')); t.verifyEqual(height(bad),1);
            c.baseParams.source.pairRate=1e4; c.factors=scanFactor("algorithm.sideWindowPairs",[1 1000]);
            c.baseParams.algorithm.accidentalMethod="side-window";
            b=runParameterSweep(c); t.verifyEqual(height(b.results),2);
            t.verifyTrue(any(b.results.status=="INVALID_SIDE_WINDOWS"));
            clear cleanup
        end

        function runtimeErrorIsIsolatedAndRetainsOriginalStack(t)
            c=smallConfig(); c.outputRoot=tempname; mkdir(c.outputRoot);
            cleanup=onCleanup(@()rmdir(c.outputRoot,'s'));
            c.baseParams.source.pairRate=1000; c.baseParams.measurementTime=.02;
            c.baseParams.detector.enableDark=false;
            for ch=["A","B"]
                c.baseParams.optics.(ch).transmission=1;
                c.baseParams.detector.(ch).efficiency=1;
                c.baseParams.detector.(ch).recordEfficiency=1;
            end
            % Find a deterministic Poisson realization above a small pair budget.
            for seed=1:100
                c.baseParams.seed=seed; data=generateSimulationData(c.baseParams);
                if numel(data.A.time)>22, break; end
            end
            c.seeds=seed; c.limits.maxMatchPairs=22;
            c.baseParams.algorithm.windowMultiplier=0;
            c.factors=scanFactor("algorithm.histHalfRange",[.1 20]);
            b=runParameterSweep(c);
            t.verifyEqual(height(b.results),2);
            t.verifyTrue(any(b.results.status=="OK"));
            errorRow=b.results(b.results.status=="ERROR",:);
            t.verifyEqual(height(errorRow),1);
            t.verifyEqual(errorRow.error_identifier,"CoincidenceSim:PairLimit");
            t.verifySubstring(errorRow.error_report,'matchCoincidences');
            clear cleanup
        end

        function stopResumeAndHashMismatch(t)
            c=smallConfig(); c.outputRoot=tempname; mkdir(c.outputRoot);
            cleanup=onCleanup(@()rmdir(c.outputRoot,'s'));
            c.factors=scanFactor("algorithm.binWidth",[10 20 30]); count=0;
            b=runParameterSweep(c,struct('CancelFcn',@cancel,'ProgressFcn',@progress));
            t.verifyTrue(b.stopped); t.verifyEqual(height(b.results),1);
            c.resumeDirectory=b.outputDirectory; resumed=runParameterSweep(c);
            t.verifyEqual(height(resumed.results),3);
            t.verifyEqual(resumed.results.started_at(1),b.results.started_at(1));
            completed=runParameterSweep(c); t.verifyEqual(completed.generationCount,resumed.generationCount);
            c.seeds=7; t.verifyError(@()runParameterSweep(c),'CoincidenceSim:ResumeMismatch');
            clear cleanup
            function stop=cancel(), stop=count>=1; end
            function progress(~,~,~), count=count+1; end
        end

        function seedSummaryDoesNotMixPhysicalConditions(t)
            c=smallConfig(); c.seeds=[1 2];
            c.factors=[scanFactor("source.pairRate",[1000 2000]);scanFactor("algorithm.binWidth",[10 20])];
            plan=buildScanGrid(c); t.verifyNumElements(unique([plan.seed_group_key]),4);
            rows=repmat(buildAllMetricRecord(plan(1).params),8,1);
            for i=1:8
                rows(i)=buildAllMetricRecord(plan(i).params); rows(i).seed_group_key=plan(i).seed_group_key;
                rows(i).physical_config_id=plan(i).physical_config_id; rows(i).analysis_config_id=plan(i).analysis_config_id;
                rows(i).status="OK"; rows(i).Rnet_cps=i; rows(i).error_acc_count=2;
            end
            s=summarizeSweepSeeds(struct2table(rows)); t.verifyEqual(height(s),4);
            t.verifyEqual(s.replicate_count,2*ones(4,1));
            t.verifyEqual(s.error_acc_absolute_RMSE,2*ones(4,1));
        end

        function guiHasIndependentWorkspaceAndEditableFactors(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            t.verifyEqual(numel(app.WorkspaceTabs.Children),3);
            panel=app.ParameterSweepPanel; t.verifyGreaterThan(size(panel.Controls.Factors.Data,1),30);
            t.verifyEqual(string(app.Controls.Match.Value),"many-to-many");
            c=panel.readConfig(); t.verifyEqual(c.baseParams.algorithm.sideWindowGuardMode,"window-width");
            t.verifyEqual(c.baseParams.algorithm.matchMethod,"many-to-many");
            c=parameterSweepExamples(); panel.populate(c); panel.Controls.BaseSource.Value='配置文件';
            panel.preview(); t.verifyEqual(panel.LastPreview.analysisCount,32);
            panel.Result=struct('results',table([10;20;10;20],[1;1;3;3],(1:4)',repmat("OK",4,1), ...
                'VariableNames',{'bin_width_ps','n_bins_each_side','Rnet_signed_cps','status'}));
            panel.Controls.PlotKind.Value='热力图'; panel.plotResults();
            t.verifyNumElements(findobj(panel.Controls.Axes,'Type','surface'),1);
            clear cleanup
        end
    end
end

function c=smallConfig()
c=scanDefaultConfig(); c.baseParams.source.pairRate=1e4; c.baseParams.measurementTime=.02;
c.baseParams.optics.A.delay=0; c.baseParams.optics.B.delay=0;
c.baseParams.algorithm.binWidth=10e-12; c.baseParams.algorithm.windowMultiplier=3;
end

function [p,h,m]=geometry(width,n)
c=smallConfig(); p=c.baseParams; p.algorithm.binWidth=width; p.algorithm.windowMultiplier=n;
edges=(-50.5:50.5)*width; p.algorithm.histRange=[edges(1),edges(end)];
h=struct('edges',edges,'centers',(edges(1:end-1)+edges(2:end))/2, ...
    'peak',0,'sigma',width,'fwhm',2.355*width,'peakValid',true,'fitStatus',"MAXIMUM");
m=struct('deltaT',zeros(0,1),'isTrue',false(0,1));
end

function e=events(time,id)
e=struct('time',time(:),'pairID',id(:),'type',repmat("signal",numel(time),1));
end

function e=emptyEvents()
e=events([],[]);
end

function data=toyData(A,B,p)
p.analysis=struct('sourceCount',max(numel(A.time),numel(B.time)));
data=struct('params',p,'source',emptyEvents(),'A',A,'B',B,'stageStats',struct());
end
