function plotted=drawDualTdcOverlay(ax,out,group,normalization,showAnalysis)
%DRAWDUALTDCOVERLAY Transparent overlapping bars and native Gaussian fits.
% Probability per bin = count / total histogram count, not a fitted density.
if nargin<3, group="full"; end
if nargin<4, normalization="probability"; end
if nargin<5, showAnalysis=false; end
% Bars intentionally hide their legend handles. Plain cla leaves these old
% bars alive, and preserves manual zoom/hold state across recalculation.
cla(ax,'reset');
if group=="full", f=out.F; s=out.S;
elseif isfield(out,char(group)) && out.(group).status=="ALIGNED"
    f=out.(group).F; s=out.(group).S;
else
    title(ax,'No validated common acquisition / events'); plotted=table(); return
end
hf=f.histogram; hs=s.histogram;
if numel(hf.edges)~=numel(hs.edges) || any(abs(hf.edges-hs.edges)>1e-22)
    error('DualTDC:OverlayBins','Overlaid histograms require identical bin edges.');
end
df=1; ds=1; label='Counts';
if normalization=="probability"
    df=sum(hf.counts); ds=sum(hs.counts); label='Probability per bin';
    if df==0, df=NaN; end
    if ds==0, ds=NaN; end
end
x=hf.centers(:)*1e12; yf=hf.counts(:)/df; ys=hs.counts(:)/ds;
fitF=hf.fitCounts(:)/df; fitS=hs.fitCounts(:)/ds;
hold(ax,'on');
bar(ax,x,yf,1,'FaceColor',[.22 .57 .76],'FaceAlpha',.48,'EdgeColor','none','HandleVisibility','off');
bar(ax,x,ys,1,'FaceColor',[1 .49 .25],'FaceAlpha',.42,'EdgeColor','none','HandleVisibility','off');
plot(ax,x,fitF,'Color',[.05 .05 .05],'LineWidth',1.7, ...
    'DisplayName',sprintf('FPGA: FWHM %.2f ps',f.metrics.FWHM_ps));
plot(ax,x,fitS,'Color',[.87 .07 .06],'LineWidth',1.7, ...
    'DisplayName',sprintf('Swabian: FWHM %.2f ps',s.metrics.FWHM_ps));
hold(ax,'off'); xlabel(ax,'Time difference t_2 - t_1 (ps)'); ylabel(ax,label);
title(ax,char("Native coincidence peak / "+group)); legend(ax,'Location','best');
if showAnalysis
    title(ax,{char("Native coincidence peak / "+group), ...
        sprintf('%g ps/bin | %d bin | %s | Nnet F/S: %.3g / %.3g', ...
        f.options.binWidth*1e12,f.metrics.mainBinCount,f.metrics.accidentalMethod, ...
        f.metrics.NnetSigned,s.metrics.NnetSigned)});
    for device=["F","S"]
        if device=="F", m=f.metrics; color=[.12 .38 .65]; else, m=s.metrics; color=[.85 .25 .08]; end
        if isfinite(m.windowLeft_ps) && isfinite(m.windowRight_ps)
            xline(ax,m.windowLeft_ps,':','Color',color,'HandleVisibility','off','Tag',char(device+"_main_window_left"));
            xline(ax,m.windowRight_ps,':','Color',color,'HandleVisibility','off','Tag',char(device+"_main_window_right"));
        end
    end
end
set(ax,'Box','on','TickDir','in');
peaks=[hf.peak hs.peak]; sigmas=[hf.sigma hs.sigma];
if all(isfinite(peaks)) && all(isfinite(sigmas))
    half=max(5*max(sigmas),.5e-9);
    xlim(ax,[max(hf.edges(1),min(peaks)-half),min(hf.edges(end),max(peaks)+half)]*1e12);
end
plotted=table(x,hf.counts(:),hs.counts(:),yf,ys,fitF,fitS, ...
    'VariableNames',{'lag_ps','F_count','S_count','F_probability_or_count', ...
    'S_probability_or_count','F_gaussian_probability_or_count','S_gaussian_probability_or_count'});
end
