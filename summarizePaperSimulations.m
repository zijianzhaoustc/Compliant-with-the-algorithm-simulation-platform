function summary = summarizePaperSimulations(outputRoot)
%SUMMARIZEPAPERSIMULATIONS Aggregate independent seeds with t-based 95% CIs.
if nargin<1, outputRoot=fullfile(pwd,'outputs','paper_simulations'); end
files=dir(fullfile(outputRoot,'summaries','all_runs_raw_*.csv'));
if isempty(files), error('PaperSimulation:NoResults','No all_runs_raw_*.csv files found.'); end
tables=cell(numel(files),1);
for k=1:numel(files)
    tables{k}=readtable(fullfile(files(k).folder,files(k).name), ...
        'TextType','string','VariableNamingRule','preserve');
    if ~ismember('run_mode',tables{k}.Properties.VariableNames)
        tables{k}.run_mode=repmat("full",height(tables{k}),1);
        tables{k}.run_mode(tables{k}.T_s<1)="smoke";
    end
end
raw=vertcat(tables{:});
key=raw.config_id+"|"+string(raw.seed)+"|"+raw.param_hash+"|"+string(raw.W_ns)+"|"+ ...
    raw.peak_center_method+"|"+raw.estimator+"|"+string(raw.side_guard_ns)+"|"+ ...
    string(raw.side_windows_requested);
[~,keep]=unique(key,'last'); raw=raw(sort(keep),:);

groupVars={'experiment_id','group_id','config_id','run_mode','T_s','W_ns','peak_center_method', ...
    'estimator','side_guard_ns','side_windows_requested','Rpair_per_s', ...
    'bg_A_cps','dark_A_cps','pap_A','detector_dt_A_ns','tdc_dt_A_ns', ...
    'enable_detector_dt','enable_tdc_dt','hist_range_ns','bin_ps'};
metricVars={'RA_cps','RB_cps','Nrec','Nraw','TP','FP','Nacc_est','Nnet_signed', ...
    'eta_W','epsilon_acc','epsilon_net_signed','g_eff','mu_proxy', ...
    'side_windows_valid','true_sigma_ps','fitted_fwhm_ps','eta_W_theory','capture_theory_error'};
[groups,groupTable]=findgroups(raw(:,groupVars));
rows=repmat(summaryTemplate(groupTable(1,:)),height(groupTable),1);
for g=1:height(groupTable)
    row=summaryTemplate(groupTable(g,:)); mask=groups==g;
    row.seed_count=numel(unique(raw.seed(mask)));
    for j=1:numel(metricVars)
        name=metricVars{j}; values=raw.(name)(mask); values=values(isfinite(values));
        row.(name+"_n")=numel(values);
        if isempty(values), continue; end
        row.(name+"_mean")=mean(values); row.(name+"_std")=std(values,0);
        if numel(values)>1
            half=tCritical95(numel(values)-1)*row.(name+"_std")/sqrt(numel(values));
            row.(name+"_ci95_low")=row.(name+"_mean")-half;
            row.(name+"_ci95_high")=row.(name+"_mean")+half;
        end
    end
    rows(g)=row;
end
summary=struct2table(rows);
writeUtf8BomTable(summary,fullfile(outputRoot,'summaries','all_runs_summary.csv'));
for letter=["A","B","C","D"]
    part=summary(summary.group_id==letter,:);
    if ~isempty(part)
        names=struct('A','A_window_capture.csv','B','B_occupancy.csv', ...
            'C','C_deadtime_estimators.csv','D','D_afterpulse_and_sidewindows.csv');
        writeUtf8BomTable(part,fullfile(outputRoot,'summaries',names.(letter)));
    end
end
writeQualityChecks(raw,summary,outputRoot);
writeBScaling(raw,outputRoot);
writeResultsDraft(summary,outputRoot);
end

function writeBScaling(raw,root)
b=raw(raw.experiment_id=="B-RATE" & raw.run_mode=="full" & ...
    raw.estimator=="theory" & raw.FP>0,:);
seeds=unique(b.seed); slopes=nan(numel(seeds),1); intercepts=slopes;
for k=1:numel(seeds)
    q=b(b.seed==seeds(k),:); [rates,order]=sort(q.Rpair_per_s);
    fpRate=q.FP(order)./q.T_s(order);
    if numel(unique(rates))>=3 && all(fpRate>0)
        fit=polyfit(log(rates),log(fpRate),1); slopes(k)=fit(1); intercepts(k)=fit(2);
    end
end
valid=isfinite(slopes); slopes=slopes(valid); intercepts=intercepts(valid); seeds=seeds(valid);
perSeed=table(seeds,slopes,intercepts,'VariableNames',{'seed','loglog_slope','log_intercept'});
writeUtf8BomTable(perSeed,fullfile(root,'summaries','B_rate_scaling_per_seed.csv'));
if isempty(slopes), return; end
half=NaN; if numel(slopes)>1, half=tCritical95(numel(slopes)-1)*std(slopes)/sqrt(numel(slopes)); end
fitSummary=table(numel(slopes),mean(slopes),std(slopes),mean(slopes)-half,mean(slopes)+half, ...
    'VariableNames',{'n_seeds','slope_mean','slope_std','slope_ci95_low','slope_ci95_high'});
writeUtf8BomTable(fitSummary,fullfile(root,'summaries','B_rate_scaling_fit.csv'));
end

function row=summaryTemplate(groupRow)
row=table2struct(groupRow); row.seed_count=NaN;
metrics=["RA_cps","RB_cps","Nrec","Nraw","TP","FP","Nacc_est","Nnet_signed", ...
    "eta_W","epsilon_acc","epsilon_net_signed","g_eff","mu_proxy", ...
    "side_windows_valid","true_sigma_ps","fitted_fwhm_ps","eta_W_theory","capture_theory_error"];
for name=metrics
    row.(name+"_n")=0; row.(name+"_mean")=NaN; row.(name+"_std")=NaN;
    row.(name+"_ci95_low")=NaN; row.(name+"_ci95_high")=NaN;
end
end

function value=tCritical95(df)
% Exact two-sided 95% Student-t critical value using the base betaincinv.
if df<=0, value=NaN; return; end
q=betaincinv(.05,df/2,.5);
value=sqrt(df*(1/q-1));
end

function writeQualityChecks(raw,summary,root)
identity=raw.TP>0 & raw.FP>0 & isfinite(raw.epsilon_acc) & isfinite(raw.epsilon_net_signed);
residual=raw.epsilon_net_signed(identity)+raw.FP(identity)./raw.TP(identity).*raw.epsilon_acc(identity);
if isempty(residual), maxResidual=NaN; else, maxResidual=max(abs(residual)); end
countIdentity=all(raw.Nraw==raw.TP+raw.FP | isnan(raw.TP));
independent=summary(summary.experiment_id=="C-INDEPENDENT" & summary.estimator=="theory" & ...
    summary.peak_center_method=="theoretical",:);
if isempty(independent)
    independentText="未运行。";
else
    assessed=isfinite(independent.g_eff_ci95_low) & isfinite(independent.g_eff_ci95_high);
    if ~any(assessed)
        independentText="仅有单 seed，95% CI 不可计算；负对照尚不能作正式判定。";
    else
        inside=independent.g_eff_ci95_low(assessed)<=1 & independent.g_eff_ci95_high(assessed)>=1;
        independentText=sprintf('%d/%d 个可评估配置的 g_eff 95%% CI 包含 1。',nnz(inside),nnz(assessed));
    end
end
text=sprintf(['# 质量检查\n\n- `Nraw = TP + FP`：%s\n' ...
    '- 有符号误差传播恒等式最大绝对残差：`%.6g`\n' ...
    '- C-INDEPENDENT：%s\n' ...
    '- 置信区间：以独立 seed 为重复，使用双侧 95%% Student-t 区间；NaN 不作为 0。\n' ...
    '- smoke 数据仅验证流水线，不可作为论文定量结果。\n'], ...
    string(countIdentity),maxResidual,independentText);
writeText(fullfile(root,'report','quality_checks.md'),text);
end

function writeResultsDraft(summary,root)
groups=unique(summary.group_id);
text="# 论文结果草稿（自动生成）"+newline+newline+ ...
    "> 本文只引用 `all_runs_summary.csv` 中存在的数据；未运行点不填值。"+newline+newline;
for group=groups.'
    subset=summary(summary.group_id==group,:);
    text=text+"## "+group+" 组"+newline+newline+ ...
        sprintf('已汇总 %d 个配置/窗口/估计器单元。定量结论须结合 seed_count、有效 n 和 95%% CI 解读。\n\n',height(subset));
end
text=text+"## 限制"+newline+newline+ ...
    "E 组未执行；BASE 参数为研究设计值，不代表已实测 SPD/SPDC 参数。后脉冲模型允许递归，不能直接外推到任意真实器件。"+newline;
writeText(fullfile(root,'report','paper_results_draft.md'),text);
end

function writeText(filename,value)
fid=fopen(filename,'w','n','UTF-8');
if fid<0, error('PaperSimulation:Write','Cannot write %s.',filename); end
cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s',char(value)); clear cleanup
end
