classdef TestDualWindowIntegration < matlab.unittest.TestCase
    methods(Test)
        function advancedGuiRoundTrip(t)
            app=CoincidenceSimulatorApp(); clean=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            panel=app.ParameterSweepPanel; panel.Controls.Advanced.Value=true;
            panel.Controls.Advanced.ValueChangedFcn([],[]);
            t.verifyTrue(panel.BaseSettings.AllowIndependentChannels);
            panel.BaseSettings.Fields.detector_backgroundRate.Value=100;
            panel.BaseSettings.FieldsB.detector_backgroundRate.Value=700;
            c=panel.readConfig(); t.verifyEqual(c.baseParams.detector.A.backgroundRate,100);
            t.verifyEqual(c.baseParams.detector.B.backgroundRate,700);
            data=panel.Controls.Factors.Data; keys=extractBefore(string(data(:,2))," | ");
            row=find(keys=="measurementTime"); data{row,1}=true; data{row,5}='.05,.1';
            panel.Controls.Factors.Data=data; c=panel.readConfig();
            panel.populate(validateScanConfig(jsondecode(jsonencode(c))));
            t.verifyEqual(numel(buildScanGrid(panel.readConfig())),2);
            t.verifyEqual(panel.readConfig().baseParams.detector.B.backgroundRate,700);
            clear clean
        end
        function strictSingleGuiAndExperimentalExport(t)
            app=CoincidenceSimulatorApp(); clean=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            app.Controls.Research.Value=true; app.Controls.Time.Value=.05; app.Controls.PairRate.Value=1e4;
            app.Controls.Peak.Value='fixed'; app.Controls.FixedCenter.Value=5;
            app.Controls.WindowMode.Value='fixed'; app.Controls.Window.Value=1;
            button=findall(app.UIFigure,'Type','uibutton','Text','运行新仿真');
            button.ButtonPushedFcn([],[]);
            t.verifyNotEmpty(app.LastResult); o=app.LastResult;
            t.verifyTrue(isfield(o,'research')); t.verifyEqual(numel(o.matches.indexA),numel(o.matches.deltaT));
            t.verifyNotEmpty(app.ResultTable.Data);
            o=analyzeResearchTimestamps(o.A,o.B,o.params,struct('time',[]),"imported");
            folder=tempname; mkdir(folder); files=onCleanup(@()rmdir(folder,'s'));
            exportSimulationResult(o,fullfile(folder,'metrics.csv'));
            t.verifyTrue(isnan(o.research.Nrec_true)); t.verifyTrue(isfile(fullfile(folder,'metrics.csv')));
            clear files clean
        end
        function fiveMethodsBothModesAndSchema(t)
            c=scanDefaultConfig(); c.baseParams.measurementTime=.05; c.baseParams.source.pairRate=2e4;
            c.baseParams.algorithm.peakMethod="fixed"; c.baseParams.algorithm.fixedPeakCenter=5e-9;
            c.baseParams.algorithm.window=1e-9;
            c.factors=[scanFactor("algorithm.windowMode",["bins","fixed"]); ...
                scanFactor("algorithm.accidentalMethod",["theory","segment-theory","side-window","sideband","time-shift"])];
            c.outputRoot=tempname; mkdir(c.outputRoot); clean=onCleanup(@()rmdir(c.outputRoot,'s'));
            b=runParameterSweep(c);
            t.verifyEqual(height(b.results),10); t.verifyEqual(b.generationCount,1);
            t.verifyTrue(all(b.results.status=="OK"));
            t.verifyEqual(numel(unique(b.results.stream_hash)),1);
            t.verifyEqual(numel(unique(b.results.Nrec_true)),1);
            required=["Npair_est","u_Npair","quality_status","geometry_json","metric_EpsilonNet","metric_CAR"];
            t.verifyTrue(all(ismember(required,string(b.results.Properties.VariableNames))));
            for name=["manifest.csv","per_run_metrics.csv","aggregate.csv","invalid_cases.csv", ...
                    "summary_for_origin/pair_estimator_vs_truth.csv"]
                t.verifyTrue(isfile(fullfile(b.outputDirectory,name)));
            end
            clear clean
        end
        function streamingScratchBoundAndBudget(t)
            p=researchParams(defaultParams()); p.algorithm.pairChunkSize=100;
            p.algorithm.histRange=[-1 1]*1e-9; p.algorithm.binWidth=100e-12;
            a=zeros(150,1); [c,~,info]=streamCoincidenceHistogram(a,a,p);
            t.verifyEqual(sum(c),22500); t.verifyLessThanOrEqual(info.maxScratchPairs,100);
            p.algorithm.scanWorkingMemoryMB=.0001;
            t.verifyError(@()streamCoincidenceHistogram(a,a,p),'CoincidenceSim:WorkingMemoryLimit');
        end
        function expectationCoverageUsesIndependentSeeds(t)
            folder=tempname; mkdir(folder); clean=onCleanup(@()rmdir(folder,'s'));
            r=validateResearchCoverage(folder,5001:5200);
            t.verifyEqual(r.validIntervals,200); t.verifyTrue(r.accepted);
            t.verifyGreaterThan(r.MCSE,0); t.verifyNotEqual(r.Coverage95,r.realizedCountCompatibility);
            clear clean
        end
        function calibrationCannotBeForgedByBoolean(t)
            p=researchParams(defaultParams()); p.measurementTime=.05;
            p.algorithm.qualityCalibrated=true; p.algorithm.qualityCalibrationHash=repmat("a",1,64);
            d=generateSimulationData(p); o=analyzeResearchTimestamps(d.A,d.B,p,d.source,"simulation");
            t.verifyNotEqual(o.research.quality_status,"RELIABLE");
            t.verifyError(@()calibrateResearchReliability(p,1:30,15:44),'CoincidenceSim:Calibration');
        end
        function legacyGolden(t)
            path=fullfile(fileparts(mfilename('fullpath')),'fixtures','legacy_default_golden.json');
            reference=jsondecode(fileread(path)); o=runSimulation(defaultParams());
            t.verifyEqual(scanStreamHash(o),string(reference.stream_hash));
            t.verifyEqual(scanHash(o.metrics),string(reference.metric_hash));
            t.verifyEqual(scanHash(o.hist.counts),string(reference.histogram_hash));
        end
        function explicitModeAliasesAndCoupledRange(t)
            p=researchParams(defaultParams()); p.algorithm.windowMode="CONTINUOUS_TIME";
            p.algorithm.sideWindowGuardMode="FROM_MAIN_EDGE_G_EQUALS_W";
            p=validateParams(p); t.verifyEqual(p.algorithm.windowMode,"fixed");
            t.verifyEqual(p.algorithm.sideWindowGuardMode,"window-width");
            c=scanDefaultConfig(); c.advancedFactors=true;
            c.factors=[scanFactor("algorithm.histLeft",30);scanFactor("algorithm.histRight",40)];
            plan=buildScanGrid(c); t.verifyEqual(plan.params.algorithm.histRange,[30 40]*1e-9);
        end
    end
end
