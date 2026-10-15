classdef TestDualTdcGui < matlab.unittest.TestCase
    methods(Test)
        function optionalSyncControlsAndViews(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app));
            app.UIFigure.Visible='off'; panel=app.DualTdcPanel;
            t.verifyFalse(panel.Controls.UseSync.Value);
            t.verifyEqual(panel.Controls.SyncFrequency.Value,500000);
            panel.Controls.UseSync.Value=true; o=panel.readOptions();
            t.verifyTrue(o.sync.enabled); t.verifyEqual(o.sync.model,"auto");
            plain=simulateDualTdc(); d=plain.data; s=plain.simulation.settings;
            pulse=(0:49999)'*2e-6;
            d.Fsync=s.F.offset_s+(1+s.F.clockPpm*1e-6)*pulse;
            d.Ssync=s.S.offset_s+(1+s.S.clockPpm*1e-6)*pulse;
            out=analyzeDualTdc(d,o); panel.setResult(out);
            t.verifyTrue(ismember(out.status,["ALIGNED","PARTIAL"]),out.alignment.reason);
            t.verifyNotEmpty(panel.SyncRateAxes.Children);
            t.verifyNotEmpty(panel.PerSecondTable.Data);
            t.verifyEqual(numel(findall(panel.OverlayAxes,'Type','bar')),2);
            panel.setResult(plain);
            t.verifyEmpty(panel.SyncRateAxes.Children); t.verifyEmpty(panel.PerSecondTable.Data);
            clear cleanup
        end
        function customBinWidthReachesAnalysisAndExport(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app));
            app.UIFigure.Visible='off'; panel=app.DualTdcPanel;
            t.verifyEqual(panel.Controls.BinWidth.Value,10,'AbsTol',1e-10);
            panel.Controls.BinWidth.Value=25; o=panel.readOptions();
            t.verifyEqual(o.binWidth,25e-12,'AbsTol',1e-24);
            out=simulateDualTdc(defaultDualTdcSimulation(),o); panel.setResult(out);
            t.verifyEqual(diff(out.F.histogram.edges),repmat(25e-12,1,numel(out.F.histogram.counts)), ...
                'AbsTol',1e-23);
            t.verifyEqual(out.F.metrics.actualWindow_ps,175,'AbsTol',1e-9);
            k=out.F.histogram.peakBin;
            t.verifyEqual(out.F.metrics.Nraw,sum(out.F.histogram.counts(k+(-3:3))));
            t.verifyEqual(out.F.metrics.Nacc,sum(out.F.histogram.counts(k-(14:20))));
            folder=tempname; mkdir(folder); filesCleanup=onCleanup(@()rmdir(folder,'s'));
            dest=panel.exportTo(folder); csv=readtable(fullfile(dest,'F_full_metrics.csv'));
            t.verifyEqual(csv.bin_width_ps,25,'AbsTol',1e-9);
            t.verifyEqual(csv.actual_window_ps,175,'AbsTol',1e-9);
            saved=load(fullfile(dest,'settings_and_alignment.mat'),'settings');
            t.verifyEqual(saved.settings.binWidth,o.binWidth);
            clear filesCleanup cleanup
        end
        function oldAndNewPagesRenderAndClearStaleMatches(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app));
            app.UIFigure.Visible='off';
            t.verifyEqual(numel(app.WorkspaceTabs.Children),3);
            t.verifyClass(app.WorkspaceTabs.Parent,'matlab.ui.container.GridLayout');
            t.verifyNotEmpty(app.Controls.PairRate);
            out=simulateDualTdc(); panel=app.DualTdcPanel; panel.setResult(out);
            t.verifyEqual(panel.Result.status,"ALIGNED");
            t.verifyNotEmpty(panel.MetricsTable.Data);
            t.verifyNotEmpty(panel.ResidualAxes.Children);
            rng(512); data=struct();
            for name=["F1","F2","S1","S2"], data.(name)=cumsum(-log(rand(1000,1))/1e5); end
            panel.setResult(analyzeDualTdc(data));
            t.verifyEqual(panel.Result.status,"UNALIGNED");
            t.verifyEmpty(panel.ResidualAxes.Children);
            t.verifyFalse(any(contains(string(panel.MetricsTable.Data(:,1)),"共同")));
            clear cleanup
        end
    end
end
