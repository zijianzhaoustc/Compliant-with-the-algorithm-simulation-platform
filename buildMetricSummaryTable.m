function summary = buildMetricSummaryTable(out, includeIntermediate)
%BUILDMETRICSUMMARYTABLE 主界面仅显示五项符合计数的统计不确定度。
%   导出时传入 includeIntermediate=true，保留完整统计指标和配置。
%   数值型中间量始终保存在 out.uncertainty 中，不受显示筛选影响。

if nargin<2, includeIntermediate=false; end

m=out.metrics;
rows={
    '【计数性能】','','';
    'A通道计数率 RA',fmt(m.RA),'判断 A 路总事件水平 (cps)';
    'B通道计数率 RB',fmt(m.RB),'判断 B 路总事件水平 (cps)';
    '原始符合率 Rraw',fmt(m.Rraw),'窗口内所有匹配事件 (cps)';
    '偶然符合率 Racc',fmt(m.Racc),'无修正/理论/旁带/旁窗/时间戳平移法 (cps)';
    '原始符合计数 Nraw',fmt(m.Nraw),'当前测量时间内窗口中的实际匹配数';
    '偶然符合计数 Nacc',fmt(m.Nacc),'Racc×T，对应本次测量时长的期望偶然计数';
    '偶然符合修正算法',char(accidentalMethodDisplayName(m.AccidentalMethod)),'本次结果采用的偶然符合处理方式';
    '净符合率 Rnet',fmt(m.Rnet),'去除偶然符合后的有效符合 (cps)';
    '仿真真实符合率 Rtrue',fmt(m.Rtrue),'基于 pairID 的可记录真实符合（仅仿真）';
    '偶然符合占比 facc',fmt(m.AccidentalFraction),'Racc/Rraw';
    '【时间性能】','','';
    '符合峰位置 t0',fmt(m.PeakPosition*1e9),'ns';
    '真实光子对 RMS σtrue',fmt(m.TrueSigma*1e12),'std(相同 pairID 的 Δt)，仅仿真 (ps)';
    '符合峰 RMS σpeak',fmt(m.PeakSigma*1e12),'实际符合时间谱寻峰/拟合宽度 (ps)';
    'FWHM',fmt(m.FWHM*1e12),'ps';
    '峰位置误差',fmt(m.PeakPositionError*1e12),'寻峰值与仿真理论峰值之差 (ps)';
    '【算法性能】','','';
    'TP / FP / FN',triple(m),'真实 / 误配 / 漏配';
    '查准率 P',fmt(m.Precision),'TP/(TP+FP)';
    '查全率 R',fmt(m.Recall),'TP/(TP+FN)';
    '调和平均数 F1',fmt(m.F1),'2PR/(P+R)';
    '符合窗口几何捕获率',fmt(m.WindowCaptureRate),'仅检查真实对时差落窗比例，不含匹配算法漏配';
    '窗口捕获率 ηW',fmt(m.EtaW),'TP/Nrec；Nrec 为双通道共有的不同非零 pairID 数';
    '偶然符合误差 εacc',fmt(m.EpsilonAcc),'(Nacc-FP)/FP；有符号相对误差，仅仿真';
    '净符合恢复误差 εnet',fmt(m.EpsilonNet),'(Nnet-TP)/TP；Nnet 为实际修正后的计数，仅仿真';
    '有效局部背景因子 geff',fmt(m.Geff),'FP/(RA·RB·W·T)；W 为实际窗口全宽，仅仿真';
    '【系统效率与性能】','','';
    'CAR',fmt(m.CAR),'Rnet/Racc';
    'SNR',fmt(m.SNR),'Nnet/sqrt(Nraw+Nacc)';
    '理论 PDEA / PDEB',pair(m.PDETheoryA,m.PDETheoryB),'参数设置的探测器光子探测效率';
    '符合估计 PDEA / PDEB',pair(m.PDEEstimateA,m.PDEEstimateB),'条件效率除以本路传输效率和记录效率';
    '理论 A|B / B|A 条件系统效率',pair(m.EtaConditionalTheoryA,m.EtaConditionalTheoryB),'ηpath·PDE·ηrec';
    '符合估计 A|B / B|A 条件系统效率',pair(m.EtaConditionalEstimateA,m.EtaConditionalEstimateB), ...
        'A|B=Rnet/RBcorr，B|A=Rnet/RAcorr';
    '理论双路联合探测效率',fmt(m.EtaJointTheory),'ηA|B·ηB|A';
    '符合估计双路联合探测效率',fmt(m.EtaJointEstimate),'Rnet/Rpair（仅仿真）'};

summary=cell2table(rows,'VariableNames',{'参数','数值','作用'});
if isfield(out,'optimization') && ~isempty(out.optimization)
    o=out.optimization;
    state='不可用'; stateInfo=['沿用当前参数；' char(o.status)];
    if o.valid
        if o.applied
            state='已自动应用'; stateInfo='正式结果采用推荐 bin、窗口及独立峰参数';
        else
            state='仅推荐'; stateInfo='当前计算参数保持原设置';
        end
    end
    diagnostic=char(strjoin(o.diagnostics,'；'));
    if isempty(diagnostic), diagnostic='通过峰形、捕获率与已启用的统计约束检查'; end
    optimizationRows={
        '【自适应符合参数】','','';
        '自适应优化状态',state,stateInfo;
        '推荐 bin 宽 (ps)',fmt(o.binWidth*1e12),'跨 bin 相位的 Shimazaki-Shinomoto 代价与稳定性';
        '推荐窗口全宽 (ns)',fmt(o.window*1e9),'按预设捕获率与背景约束选择';
        '模型估计峰捕获率',fmt(o.captureEstimate),'Gaussian 峰模型估计；不是仿真真值 ηW';
        '独立峰位置 / σ (ps)',pair(o.peak*1e12,o.sigma*1e12),'从未分箱时间差拟合，与显示 bin 宽分开';
        '优化诊断',diagnostic,'默认固定参数 Bootstrap；不包含参数选择的随机性'};
    summary=[summary;cell2table(optimizationRows,'VariableNames',summary.Properties.VariableNames)];
end
if isfield(out,'uncertainty')
    m=out.metrics;
    comparison={
        '【偶然符合估计与真值验证】','','';
        '实际偶然符合 Nacc_GT',fmt(m.Nacc_GT),'FP：当前主窗误配数；仅仿真';
        '实际相关符合 Ncorr_GT',fmt(m.Ncorr_GT),'TP：当前主窗同源对；不是 Nrec';
        '旁窗法偶然计数 Nacc_side',fmt(m.Nacc_side),'全部有效等宽旁窗计数的平均值';
        '理论法偶然计数 Nacc_theory',fmt(m.Nacc_theory),'NA·NB·W_effective/T';
        '旁窗法净计数 Ncorr_side',fmt(m.Ncorr_side),'Nraw-Nacc_side；不截断负值';
        '理论法净计数 Ncorr_theory',fmt(m.Ncorr_theory),'Nraw-Nacc_theory；不截断负值';
        '旁窗法偶然相对误差',fmt(m.epsilon_acc_side),'(Nacc_side-FP)/FP';
        '理论法偶然相对误差',fmt(m.epsilon_acc_theory),'(Nacc_theory-FP)/FP';
        '旁窗法净符合恢复相对误差',fmt(m.epsilon_corr_side),'(Ncorr_side-TP)/TP';
        '理论法净符合恢复相对误差',fmt(m.epsilon_corr_theory),'(Ncorr_theory-TP)/TP';
        '两种偶然估计差值',fmt(m.Delta_acc_methods),'Nacc_side-Nacc_theory';
        '【统计不确定度分析】','',''};
    summary=[summary;cell2table(comparison,'VariableNames',summary.Properties.VariableNames)];
    t=out.uncertainty.summary;
    displayed=["Nraw","Nacc_side","Nacc_theory","Ncorr_side","Ncorr_theory"];
    labels=["原始符合计数 Nraw","旁窗偶然符合 Nacc_side", ...
        "理论偶然符合 Nacc_theory","旁窗净符合 Ncorr_side","理论净符合 Ncorr_theory"];
    if includeIntermediate, selected=t.Metric(:)'; else, selected=displayed; end
    for metric=selected
        k=find(t.Metric==metric,1);
        if isempty(k), continue; end
        label=char(metric);
        labelIndex=find(displayed==metric,1);
        if ~isempty(labelIndex), label=char(labels(labelIndex)); end
        value=sprintf('%s ± %s',fmt(t.Estimate(k)),fmt(t.U_Poisson(k)));
        info=sprintf('估计值 ± 解析 u；Bootstrap u=%s；%.3g%% CI=[%s, %s]', ...
            fmt(t.U_Bootstrap(k)),100*t.ConfidenceLevel(k), ...
            fmt(t.CI_Lower(k)),fmt(t.CI_Upper(k)));
        if includeIntermediate
            info=sprintf('%s；uRel=%s；状态=%s',info,fmt(t.Relative_U(k)),t.ValidityFlag(k));
            if startsWith(metric,["Cov_","Corr_"])
                value=fmt(t.Estimate(k)); info='联合分块抽样统计量';
            end
        end
        summary=[summary;cell2table({label,value,info},'VariableNames',summary.Properties.VariableNames)]; %#ok<AGROW>
    end
    if includeIntermediate
        config={
            '采集时长 T (s)',fmt(t.T_s(1)),'速率与理论估计使用固定采集时间';
            '有效符合窗宽 W (ns)',fmt(t.W_effective_s(1)*1e9),'背景估计与主窗实际宽度一致';
            '有效旁窗数量 L',fmt(t.ValidSideWindows(1)),'完整落在时间谱内的等宽旁窗';
            '旁窗总计数',fmt(t.Nside_total(1)),'解析不确定度直接输入';
            '实际分块时长 (s)',fmt(t.BlockSize_s(1)),'等时长分块；匹配对以 A 路时间归属';
            'Bootstrap 分块数',fmt(t.BlockCount(1)),'独立同分布近似；需检查分块尺度稳定性';
            'Bootstrap 次数 / 种子',sprintf('%d / %d',t.BootstrapB(1),t.BootstrapSeed(1)),'固定峰与窗口，联合有放回抽样';
            '解析计算假设','近似参考值',char(out.uncertainty.analytical.assumption);
            '统计诊断',char(strjoin(out.uncertainty.messages,'；')),'不可用值显示 N/A，不等于零不确定度'};
        summary=[summary;cell2table(config,'VariableNames',summary.Properties.VariableNames)];
    end
end
end

function s=fmt(x)
%FMT 有限数使用紧凑格式，不可由实测数据确定的指标显示 N/A。
if isnan(x), s='N/A'; elseif isinf(x), s='∞'; else, s=sprintf('%.6g',x); end
end

function s=pair(a,b)
%PAIR 将 A/B 两个对应数值放在同一单元格中。
s=sprintf('%s / %s',fmt(a),fmt(b));
end

function s=triple(m)
%TRIPLE 实测 TXT 无 pairID 时不伪造 TP/FP/FN。
if isnan(m.TP), s='N/A'; else, s=sprintf('%d / %d / %d',m.TP,m.FP,m.FN); end
end
