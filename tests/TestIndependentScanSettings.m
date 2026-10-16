classdef TestIndependentScanSettings < matlab.unittest.TestCase
    methods(Test)
        function mainChangesNeverChangeScanSettings(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            panel=app.ParameterSweepPanel; before=panel.readConfig();
            app.Controls.PairRate.Value=987654; app.Controls.Time.Value=12;
            app.Controls.EnableDark.Value=false; app.Controls.EnableDead.Value=true;
            app.Controls.EnableAfter.Value=true; app.Controls.EnableTdcJitter.Value=false;
            app.Controls.EnableTdcDead.Value=true; app.Controls.PDEA.Value=.2;
            app.Controls.DarkA.Value=4321; app.Controls.Resolution.Value=80;
            app.Controls.SourceMode.Value='pump'; app.Controls.Acc.Value='time-shift';
            t.verifyEqual(panel.readConfig(),before);
            t.verifyFalse(isprop(panel,'ParameterProvider'));
            t.verifyFalse(isfield(panel.Controls,'BaseSource'));
            clear cleanup
        end

        function scanChangesLoadAndResetNeverTouchMain(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            app.LastResult=struct('sentinel',42); before=mainValues(app);
            panel=app.ParameterSweepPanel; base=panel.BaseSettings;
            base.Fields.source_pairRate.Value=23456;
            base.Fields.detector_darkRate.Value=321;
            base.Fields.detector_efficiency.Value=.6;
            base.Fields.optics_relativeDelay.Value=9;
            base.Fields.tdc_resolution.Value=25;
            base.Controls.EnableDead.Value=true; base.Controls.EnableAfter.Value=true;
            base.Controls.EnableTdcDead.Value=true;
            panel.Controls.MeasurementTime.Value=.03;
            c=panel.readConfig();
            t.verifyEqual(c.baseParams.source.pairRate,23456);
            t.verifyEqual(c.baseParams.detector.A.darkRate,321);
            t.verifyEqual(c.baseParams.detector.B.efficiency,.6);
            t.verifyEqual(c.baseParams.optics.B.delay-c.baseParams.optics.A.delay,9e-9,'AbsTol',1e-23);
            t.verifyEqual(c.baseParams.tdc.resolution,25e-12,'AbsTol',1e-24);
            panel.populate(validateScanConfig(jsondecode(jsonencode(c))));
            restored=panel.readConfig();
            t.verifyTrue(restored.baseParams.detector.enableAfterpulse);
            t.verifyEqual(restored.baseParams.source.pairRate,23456);
            t.verifyEqual(mainValues(app),before); t.verifyEqual(app.LastResult.sentinel,42);
            panel.setRunning(true);
            t.verifyEqual(string(base.Controls.EnableAfter.Enable),"off");
            t.verifyEqual(string(app.Controls.EnableAfter.Enable),"on");
            panel.setRunning(false);
            panel.resetDefaults(); defaults=scanDefaultConfig();
            t.verifyEqual(panel.readConfig().baseParams,validateScanConfig(defaults).baseParams);
            t.verifyEqual(mainValues(app),before); t.verifyEqual(app.LastResult.sentinel,42);
            clear cleanup
        end

        function effectWarningsUseOnlyScanSwitches(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            panel=app.ParameterSweepPanel;
            c=scanDefaultConfig(); c.factors=[scanFactor("detector.deadTime",50); ...
                scanFactor("detector.afterpulseProbability",.05);scanFactor("tdc.deadTime",50)];
            panel.populate(c); base=panel.BaseSettings;
            base.Controls.EnableDead.Value=true; base.Controls.EnableAfter.Value=true;
            base.Controls.EnableTdcDead.Value=true;
            plan=buildScanGrid(panel.readConfig());
            t.verifyFalse(any(contains([plan.warning_codes],"EFFECT_DISABLED")));
            t.verifyFalse(app.Controls.EnableDead.Value); t.verifyFalse(app.Controls.EnableAfter.Value);
            app.Controls.EnableDead.Value=true; app.Controls.EnableAfter.Value=true; app.Controls.EnableTdcDead.Value=true;
            base.Controls.EnableDead.Value=false; base.Controls.EnableAfter.Value=false; base.Controls.EnableTdcDead.Value=false;
            plan=buildScanGrid(panel.readConfig());
            t.verifyTrue(all(contains([plan.warning_codes],"EFFECT_DISABLED")));
            clear cleanup
        end

        function uncheckedFactorsUseIndependentConstants(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            panel=app.ParameterSweepPanel; panel.BaseSettings.Fields.source_pairRate.Value=1234;
            app.Controls.PairRate.Value=9999;
            c=panel.readConfig(); plan=buildScanGrid(c);
            t.verifyEqual(plan.params.source.pairRate,1234);
            data=panel.Controls.Factors.Data;
            row=find(startsWith(string(data(:,2)),"source.pairRate | "));
            data{row,1}=true; data{row,4}='fixed'; data{row,5}='5678'; panel.Controls.Factors.Data=data;
            c=panel.readConfig(); plan=buildScanGrid(c);
            t.verifyEqual(c.baseParams.source.pairRate,1234);
            t.verifyEqual(plan.params.source.pairRate,5678);
            t.verifyEqual(app.Controls.PairRate.Value,9999);
            clear cleanup
        end

        function executionUsesIndependentConfiguration(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            panel=app.ParameterSweepPanel;
            c=scanDefaultConfig(); c.baseParams.source.pairRate=2e4; c.baseParams.measurementTime=.01;
            c.baseParams.detector.enableAfterpulse=true; c.baseParams.detector.enableDeadTime=true;
            c.baseParams.tdc.enableDeadTime=true; c.factors=scanFactor("algorithm.binWidth",[100 200]);
            c.outputRoot=tempname; mkdir(c.outputRoot); filesCleanup=onCleanup(@()rmdir(c.outputRoot,'s'));
            panel.populate(c);
            app.Controls.PairRate.Value=7e5; app.Controls.EnableAfter.Value=false; before=mainValues(app);
            batch=runParameterSweep(panel.readConfig());
            t.verifyEqual(height(batch.results),2); t.verifyEqual(batch.generationCount,1);
            t.verifyTrue(all(batch.results.Rpair_per_s==2e4));
            t.verifyTrue(all(batch.results.T_s==.01));
            t.verifyTrue(all(batch.results.param_detector_enableAfterpulse));
            t.verifyTrue(all(batch.results.param_detector_enableDeadTime));
            t.verifyTrue(all(batch.results.param_tdc_enableDeadTime));
            t.verifyEqual(mainValues(app),before);
            clear filesCleanup cleanup
        end
    end
end

function values=mainValues(app)
values=struct(); names=fieldnames(app.Controls);
for j=1:numel(names)
    control=app.Controls.(names{j});
    if isprop(control,'Value'), values.(names{j})=control.Value; end
end
end
