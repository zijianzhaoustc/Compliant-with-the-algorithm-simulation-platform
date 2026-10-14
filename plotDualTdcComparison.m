function files=plotDualTdcComparison(out,folder)
%PLOTDUALTDCCOMPARISON Export PNG/PDF and exact plotted Origin data.
if ~isfolder(folder), mkdir(folder); end
files=strings(0,1);
for group=["full","overlap","common"]
    if group~="full" && out.(group).status~="ALIGNED", continue; end
    fig=figure('Visible','off','Color','w','Position',[100 100 900 600]);
    cleanup=onCleanup(@()close(fig)); ax=axes(fig);
    t=drawDualTdcOverlay(ax,out,group,"probability");
    name=char("F_S_"+group+"_overlay");
    writeUtf8BomTable(t,fullfile(folder,[name '.csv']));
    exportgraphics(fig,fullfile(folder,[name '.png']),'Resolution',200);
    exportgraphics(fig,fullfile(folder,[name '.pdf']),'ContentType','vector');
    files=[files;string(fullfile(folder,[name '.png']));string(fullfile(folder,[name '.pdf']))]; %#ok<AGROW>
    clear cleanup
end
end
