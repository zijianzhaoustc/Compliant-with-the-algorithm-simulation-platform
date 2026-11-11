function plotRateEfficiency(tbl,folder)
%PLOTRATEEFFICIENCY Independent-record rate/efficiency plot with available CIs.
% Unknown optical groups are not connected; no power is inferred from paths.
valid=isfinite(tbl.inference_Cpair_cps);
if ~any(valid), return; end
t=tbl(valid,:); f=figure('Visible','off','Color','w'); cleanup=onCleanup(@()close(f));
tiledlayout(f,3,1);
x=t.rate_B_cps;
ax=nexttile; scatter(ax,x,t.inference_Cpair_cps,28,'filled'); hold(ax,'on');
for k=1:height(t)
    low=t.inference_Cpair_CI95_low_cps(k); high=t.inference_Cpair_CI95_high_cps(k);
    if isfinite(low) && isfinite(high)
        plot(ax,[x(k) x(k)],[low high],'k-');
    end
end
ylabel(ax,'Recorded correlation rate (cps)'); grid(ax,'on');
title(ax,'Independent records; no shared response or constant efficiency assumed');
ax=nexttile; scatter(ax,x,t.inference_Fwindow,28,'filled');
ylabel(ax,'Reference-window capture fraction'); grid(ax,'on');
ax=nexttile; scatter(ax,x,t.inference_etaB_apparent,28,'filled','DisplayName','Apparent (herald background unknown/unsubtracted)');
hold(ax,'on'); known=isfinite(t.inference_etaB_given_A);
if any(known), scatter(ax,x(known),t.inference_etaB_given_A(known),36,'DisplayName','Effective conditional (specified background subtracted)'); end
legend(ax,'show','Location','best'); xlabel(ax,'Recorded B rate (cps)'); ylabel(ax,'Conditional efficiency'); grid(ax,'on');
exportgraphics(f,fullfile(folder,'rate_efficiency.png'),'Resolution',150);
end
