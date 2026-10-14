function files = plotPaperSimulations(outputRoot)
%PLOTPAPERSIMULATIONS Create available A-D figures without inventing points.
if nargin<1, outputRoot=fullfile(pwd,'outputs','paper_simulations'); end
summaryFile=fullfile(outputRoot,'summaries','all_runs_summary.csv');
if ~isfile(summaryFile), summarizePaperSimulations(outputRoot); end
s=readtable(summaryFile,'TextType','string','VariableNamingRule','preserve');
figureDir=fullfile(outputRoot,'figures'); if ~isfolder(figureDir), mkdir(figureDir); end
files=strings(0,1);

% A: finite-window capture, theory estimator because eta_W is estimator independent.
mask=startsWith(s.experiment_id,"A-J") & s.estimator=="theory";
a=s(mask & s.run_mode==preferredMode(s,mask),:);
if ~isempty(a)
    fig=figure('Visible','off','Color','w'); hold on; grid on;
    ids=unique(a.experiment_id,'stable'); colors=lines(numel(ids));
    for k=1:numel(ids)
        q=a(a.experiment_id==ids(k) & a.peak_center_method=="theoretical",:);
        [x,order]=sort(q.W_ns); y=q.eta_W_mean(order);
        lo=y-q.eta_W_ci95_low(order); hi=q.eta_W_ci95_high(order)-y;
        errorbar(x,y,lo,hi,'o-','Color',colors(k,:),'DisplayName',ids(k));
        plot(x,q.eta_W_theory_mean(order),'--','Color',colors(k,:),'HandleVisibility','off');
    end
    xlabel('Coincidence window total width W (ns)'); ylabel('\eta_W');
    title('A: Gaussian finite-window capture'); legend('Location','southeast');
    files=[files; saveFigure(fig,figureDir,'A_capture')]; close(fig);
end

% B: Poisson accidental baseline across pair rate.
mask=s.experiment_id=="B-RATE" & s.estimator=="theory";
b=s(mask & s.run_mode==preferredMode(s,mask),:);
if ~isempty(b)
    fig=figure('Visible','off','Color','w'); tiledlayout(1,2);
    nexttile; errorbar(b.Rpair_per_s,b.g_eff_mean, ...
        b.g_eff_mean-b.g_eff_ci95_low,b.g_eff_ci95_high-b.g_eff_mean,'o-');
    yline(1,'--'); set(gca,'XScale','log'); grid on;
    xlabel('Pair rate (s^{-1})'); ylabel('g_{eff}'); title('Poisson baseline');
    nexttile; loglog(b.Rpair_per_s,b.FP_mean,'o-'); grid on;
    xlabel('Pair rate (s^{-1})'); ylabel('FP per acquisition'); title('Accidental scaling');
    files=[files; saveFigure(fig,figureDir,'B_pair_rate_scaling')]; close(fig);
end

% C: estimator errors and local-dead-time conditions.
mask=startsWith(s.experiment_id,"C-") & s.experiment_id~="C-INDEPENDENT" & s.W_ns==3;
c=s(mask & s.run_mode==preferredMode(s,mask),:);
if ~isempty(c)
    fig=figure('Visible','off','Color','w'); hold on; grid on;
    estimators=["theory","side-window","time-shift"]; marks=['o','s','^'];
    ids=unique(c.experiment_id,'stable');
    for j=1:numel(estimators)
        y=nan(numel(ids),1); lo=y; hi=y;
        for k=1:numel(ids)
            q=c(c.experiment_id==ids(k) & c.estimator==estimators(j),:);
            if ~isempty(q), y(k)=q.epsilon_acc_mean(1); lo(k)=y(k)-q.epsilon_acc_ci95_low(1); hi(k)=q.epsilon_acc_ci95_high(1)-y(k); end
        end
        errorbar((1:numel(ids))+.08*(j-2),y,lo,hi,marks(j),'DisplayName',estimators(j));
    end
    yline(0,'--'); xticks(1:numel(ids)); xticklabels(ids); xtickangle(30);
    ylabel('\epsilon_{acc}'); title('C: accidental-estimator signed error'); legend('Location','best');
    files=[files; saveFigure(fig,figureDir,'C_estimator_errors')]; close(fig);
end

% D: afterpulse probability and side-window response.
mask=startsWith(s.experiment_id,"D-AP") & s.estimator=="side-window";
d=s(mask & s.run_mode==preferredMode(s,mask),:);
if ~isempty(d)
    fig=figure('Visible','off','Color','w'); scatter(d.pap_A,d.epsilon_acc_mean,55,d.side_guard_ns,'filled');
    grid on; colorbar; xlabel('Afterpulse probability'); ylabel('\epsilon_{acc,SW}');
    title('D: afterpulse and side-window sensitivity');
    files=[files; saveFigure(fig,figureDir,'D_sidewindow_guard')]; close(fig);
end

% FP-only lag evidence: aggregate the newest ten formal seed runs per config.
cPrefixes=["C-OFF__R2000000","C-D50__R2000000","C-D100__REP", ...
    "C-T233__R2000000","C-T10__REP","C-BOTH__R2000000"];
[lag,ratios,labels]=aggregateLagRatios(outputRoot,cPrefixes,10);
if ~isempty(lag)
    fig=figure('Visible','off','Color','w'); plot(lag,ratios,'LineWidth',1.1); grid on;
    xlim([-15,15]); yline(1,'--'); xlabel('Lag relative to theoretical center (ns)');
    ylabel('FP counts / flat prediction'); title('C: FP-only local lag structure');
    legend(labels,'Location','best'); files=[files; saveFigure(fig,figureDir,'C_fp_lag')]; close(fig);
end
dPrefixes=["D-BASE__MAIN","D-AP01__MAIN","D-AP03__MAIN","D-AP05__MAIN", ...
    "D-AP05-NO-DT__CONTROL","D-FULL__MAIN"];
[lag,ratios,labels]=aggregateLagRatios(outputRoot,dPrefixes,10);
if ~isempty(lag)
    fig=figure('Visible','off','Color','w'); plot(lag,ratios,'LineWidth',1.1); grid on;
    xlim([-120,120]); yline(1,'--'); xlabel('Lag relative to theoretical center (ns)');
    ylabel('FP counts / flat prediction'); title('D: afterpulse FP-only lag structure');
    legend(labels,'Location','best'); files=[files; saveFigure(fig,figureDir,'D_afterpulse_fp_lag')]; close(fig);
end
end

function mode=preferredMode(s,mask)
if any(s.run_mode(mask)=="full"), mode="full"; else, mode="smoke"; end
end

function [relativeLag,ratios,labels]=aggregateLagRatios(root,prefixes,nSeeds)
relativeLag=[]; ratios=[]; labels=strings(0,1);
for prefix=prefixes
    files=dir(fullfile(root,'runs',char(prefix+"__seed*"),'fp_histogram.csv'));
    if isempty(files), continue; end
    [~,order]=sort([files.datenum],'descend'); files=files(order(1:min(nSeeds,numel(order))));
    fp=[]; expected=[]; lag=[];
    for k=1:numel(files)
        t=readtable(fullfile(files(k).folder,files(k).name),'VariableNamingRule','preserve');
        if isempty(fp), fp=zeros(height(t),1); expected=fp; lag=t.lag_ns; end
        fp=fp+t.FP_counts; expected=expected+t.flat_prediction_counts;
    end
    ratio=fp./expected; center=5;
    if isempty(relativeLag)
        relativeLag=lag-center;
    elseif numel(lag)~=numel(relativeLag) || any(abs((lag-center)-relativeLag)>1e-9)
        ratio=interp1(lag-center,ratio,relativeLag,'linear',NaN);
    end
    label=prefix;
    for token=["__R2000000","__REP","__MAIN","__CONTROL"], label=erase(label,token); end
    ratios(:,end+1)=ratio; labels(end+1)=label; %#ok<AGROW>
end
end

function files=saveFigure(fig,folder,name)
png=fullfile(folder,[name '.png']); pdf=fullfile(folder,[name '.pdf']);
exportgraphics(fig,png,'Resolution',180); exportgraphics(fig,pdf,'ContentType','vector');
files=[string(png);string(pdf)];
end
