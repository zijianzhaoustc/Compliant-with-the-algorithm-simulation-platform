function plotInferenceDiagnostics(res,p,folder)
%PLOTINFERENCEDIAGNOSTICS Export fitted PDF and held-out residual figure.
f=figure('Visible','off','Color','w'); cleanup=onCleanup(@()close(f));
tiledlayout(f,2,1);
ax=nexttile; hold(ax,'on'); x=linspace(p.inference.domain(1),p.inference.domain(2),1001);
for k=1:numel(res.folds)
    y=evaluateIRF(x,res.folds{k}.fit.model,p.inference.domain);
    plot(ax,x*1e9,y*1e-9,'DisplayName',sprintf('trained fold %d',k));
end
xlabel(ax,'Delay (ns)'); ylabel(ax,'Model PDF (1/ns)'); title(ax,'Normalized fitted system response'); grid(ax,'on');
if ~isempty(res.folds), legend(ax,'show'); end
ax=nexttile; d=res.diagnostics; hold(ax,'on');
for k=1:numel(res.folds)
    mask=d.fold==k;
    plot(ax,(d.delay_low_s(mask)+d.delay_high_s(mask))*0.5e9,d.standardized_residual(mask),'.-');
end
yline(ax,0); xlabel(ax,'Delay (ns)'); ylabel(ax,'Standardized residual');
title(ax,'Held-out region diagnostics (descriptive, dependent pairs)'); grid(ax,'on');
sgtitle(f,"Status: "+res.status+' | Exposure: '+res.exposureSource,'Interpreter','none');
exportgraphics(f,fullfile(folder,'IRF_validation.png'),'Resolution',150);
end
