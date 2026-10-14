classdef TestDualTdcPlotRefresh < matlab.unittest.TestCase
    methods(Test)
        function repeatedOverlaysReplaceHiddenBars(t)
            out=simulateDualTdc(); fig=figure('Visible','off'); cleanup=onCleanup(@()close(fig));
            ax=axes(fig);
            for k=1:4
                old=findall(ax,'Type','bar'); drawDualTdcOverlay(ax,out);
                t.verifyEqual(numel(findall(ax,'Type','bar')),2);
                t.verifyFalse(any(isgraphics(old)));
            end
            clear cleanup
        end
        function invalidCommonRemovesAllPreviousGraphics(t)
            out=simulateDualTdc(); fig=figure('Visible','off'); cleanup=onCleanup(@()close(fig));
            ax=axes(fig); drawDualTdcOverlay(ax,out);
            old=findall(ax,'Type','bar'); out.common.status="UNALIGNED";
            drawDualTdcOverlay(ax,out,"common");
            t.verifyFalse(any(isgraphics(old))); t.verifyEmpty(ax.Children);
            t.verifySubstring(string(ax.Title.String),'No validated'); clear cleanup
        end
        function cachedButtonUpdatesEveryPlotAfterZoomOrHold(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            p=app.DualTdcPanel; original=simulateDualTdc(); p.setResult(original);
            oldF=findobj(p.HistogramF,'Type','line','DisplayName','FPGA full');
            oldBars=findall(p.OverlayAxes,'Type','bar');
            for ax=[p.HistogramF,p.HistogramS,p.ResidualAxes,p.SweepAxes,p.OverlayAxes]
                hold(ax,'on'); xlim(ax,[100000 200000]); ylim(ax,[100000 200000]);
            end
            p.Controls.BinWidth.Value=25; p.Controls.MainBins.Value=8; p.Controls.Acc.Value='none';
            callback=p.Controls.Recalculate.ButtonPushedFcn; callback([],[]);
            out=p.Result; t.verifyNotEmpty(out);
            t.verifyEqual(out.data,original.data);
            t.verifyFalse(isgraphics(oldF)); t.verifyFalse(any(isgraphics(oldBars)));
            t.verifyEqual(numel(findall(p.OverlayAxes,'Type','bar')),2);
            f=findobj(p.HistogramF,'Type','line','DisplayName','FPGA full');
            s=findobj(p.HistogramS,'Type','line','DisplayName','Swabian full');
            t.verifyNumElements(f,1); t.verifyNumElements(s,1);
            t.verifyEqual(f.XData,out.F.histogram.centers*1e12);
            t.verifyEqual(f.YData,out.F.histogram.counts);
            t.verifyEqual(s.YData,out.S.histogram.counts);
            t.verifyEqual(numel(f.YData),ceil(diff(out.options.histRange)/25e-12-1e-10));
            t.verifyEqual(string(p.OverlayAxes.YLimMode),"auto");
            t.verifyEqual(string(p.ResidualAxes.XLimMode),"auto");
            t.verifyLessThan(max(p.ResidualAxes.XLim),1);
            t.verifyLessThan(max(p.HistogramF.XLim),1e5);
            sweep=findobj(p.SweepAxes,'Type','line');
            t.verifyNumElements(sweep,2);
            t.verifyTrue(any(arrayfun(@(h)isequaln(h.YData(:),out.F.sweep.NnetSigned_count),sweep)));
            marker=findall(p.OverlayAxes,'Tag','F_main_window_left');
            t.verifyNumElements(marker,1); t.verifyEqual(marker.Value,out.F.metrics.windowLeft_ps);
            t.verifySubstring(join(string(p.OverlayAxes.Title.String)), '25 ps/bin');
            t.verifySubstring(p.StatusLabel.Text,'刷新所有图');
            clear cleanup
        end
        function windowOnlyChangeRefreshesAnnotationsNotNativeShape(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            p=app.DualTdcPanel; original=simulateDualTdc(); p.setResult(original);
            p.Controls.MainBins.Value=11; p.Controls.Acc.Value='none'; p.recalculateCurrent();
            t.verifyEqual(p.Result.F.histogram.counts,original.F.histogram.counts);
            t.verifyEqual(p.Result.F.metrics.actualWindow_ps,110,'AbsTol',1e-9);
            left=findall(p.OverlayAxes,'Tag','F_main_window_left'); right=findall(p.OverlayAxes,'Tag','F_main_window_right');
            t.verifyEqual(right.Value-left.Value,110,'AbsTol',1e-9);
            titleText=join(string(p.OverlayAxes.Title.String));
            t.verifySubstring(titleText,'11 bin'); t.verifySubstring(titleText,'none');
            t.verifyEqual(numel(findall(p.OverlayAxes,'Type','bar')),2);
            clear cleanup
        end
        function syncPlotsRefreshAndClearAcrossCachedRecalculations(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            p=app.DualTdcPanel; original=simulateDualTdc(); data=original.data; s=original.simulation.settings;
            pulse=(0:49999)'*2e-6;
            data.Fsync=s.F.offset_s+(1+s.F.clockPpm*1e-6)*pulse;
            data.Ssync=s.S.offset_s+(1+s.S.clockPpm*1e-6)*pulse;
            o=defaultDualTdcOptions(); o.sync.enabled=true;
            p.Controls.UseSync.Value=true; p.setResult(analyzeDualTdc(data,o));
            old=findall(p.SyncRateAxes,'Type','stair');
            hold(p.SyncRateAxes,'on'); ylim(p.SyncRateAxes,[1e9 2e9]);
            hold(p.SyncAxes,'on'); xlim(p.SyncAxes,[100 200]);
            p.Controls.SyncBlock.Value=.025; p.Controls.SyncModel.Value='segmented';
            p.Controls.BinWidth.Value=25; p.Controls.MainBins.Value=8; p.Controls.Acc.Value='none';
            p.recalculateCurrent();
            t.verifyFalse(any(isgraphics(old)));
            t.verifyEqual(numel(findall(p.SyncRateAxes,'Type','stair')),2);
            t.verifyLessThan(max(p.SyncRateAxes.YLim),1e7);
            drift=findobj(p.SyncAxes,'Type','line'); t.verifyNumElements(drift,1);
            t.verifyEqual(drift.XData(:),p.Result.sync.model.drift.startF_s);
            t.verifyEqual(drift.YData(:),p.Result.sync.model.drift.relative_ppm);
            p.Controls.UseSync.Value=false; p.recalculateCurrent();
            t.verifyEmpty(p.SyncAxes.Children); t.verifyEmpty(p.SyncRateAxes.Children);
            tab=ancestor(p.OverlayAxes,'uitab'); tab.Parent.SelectedTab=tab; drawnow nocallbacks;
            t.verifyEqual(numel(findall(p.OverlayAxes,'Type','bar')),2);
            clear cleanup
        end
    end
end
