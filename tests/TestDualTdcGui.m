classdef TestDualTdcGui < matlab.unittest.TestCase
    methods(Test)
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
            t.verifyEqual(numel(app.WorkspaceTabs.Children),2);
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
