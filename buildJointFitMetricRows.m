function rows = buildJointFitMetricRows(j,includeRepeated)
%BUILDJOINTFITMETRICROWS 界面仅列联合特有指标，完整结果 CSV 可保留所有量。
if nargin<2, includeRepeated=false; end
t=j.summary; k=find(t.Selected,1); if isempty(k), k=1; end
w=j.window; origin='算法设置';
if w.source=="narrowest-adaptive", origin='最窄自适应'; end
model='非对称双高斯'; if j.primaryModel=="gaussian", model='单高斯'; end
state='不可用';
if t.Valid(k)
    state='可用（面积收敛）';
    if ~t.Converged(k), state='面积求解未收敛'; end
end
interval=sprintf('[%s, %s)',number(w.lowerEdge*1e9),number(w.upperEdge*1e9));
if w.includeUpperEdge, interval(end)=']'; end
fallback=char(w.fallbackReason); if isempty(fallback), fallback='无'; end
gaussian=find(t.Model=="gaussian",1); doubleGaussian=find(t.Model=="doublegaussian",1);
comparison=sprintf('%s / %s',number(t.NpairFull(gaussian)),number(t.NpairFull(doubleGaussian)));
rows={
    '【联合无分箱点估计】','','';
    '联合拟合主模型',model,'下列指标使用主报告模型；两个模型完整结果均可导出';
    '联合拟合状态',state,char(j.message);
    '联合拟合窗口来源',origin,'有效最窄推荐优先，含仅推荐；否则沿用算法设置';
    '联合拟合选窗回退原因',fallback,'无有效最窄推荐时记录原因';
    '联合拟合窗全宽 (ns)',number(w.width*1e9),'实际符合窗口全宽';
    '联合拟合窗边界 (ns)',interval,'保留实际左右边界及右端点包含规则';
    '联合拟合候选对数',value(t,k,'CandidatePairs'),'全时间谱搜索范围内的全部 all-pairs 候选';
    '完整相关峰面积 Npair',value(t,k,'NpairFull'),'模型估计完整记录面积；目标是 Nrec，非源端产生对数';
    '联合拟合完整相关率 (cps)',value(t,k,'PairRate_Hz'),'Npair/T';
    '单高斯 / 双高斯 Npair',comparison,'两个模型的完整相关峰面积对照';
    '联合拟合窗原始计数',value(t,k,'NrawWindow_AllPairs'),'独立 all-pairs 统计';
    '联合拟合窗偶然计数',value(t,k,'NaccWindow'),'拟合背景密度×实际窗口全宽';
    '联合拟合窗净计数',value(t,k,'NnetWindow'),'原始计数减拟合背景；保留负值';
    '联合拟合窗原始率 (cps)',value(t,k,'NrawRate_Hz'),'窗内原始计数/T';
    '联合拟合窗偶然率 (cps)',value(t,k,'NaccRate_Hz'),'窗内偶然计数/T';
    '联合拟合窗净率 (cps)',value(t,k,'NnetRate_Hz'),'窗内净计数/T；保留负值';
    '联合拟合背景 (count/ns)',value(t,k,'Background_counts_per_ns'),'时间差上的背景密度，不是通道单计数率';
    '分块理论背景 (count/ns)',value(t,k,'TheoryBackground_counts_per_ns'),'由两路分块单计数计算的对照背景';
    '联合拟合 / 理论背景',value(t,k,'BackgroundFitOverTheory'),'拟合背景密度/分块理论背景密度';
    '联合拟合窗捕获率',value(t,k,'CaptureFraction'),'拟合 IRF 在实际窗口内的积分';
    '联合拟合搜索范围捕获率',value(t,k,'LagRangeMass'),'拟合 IRF 在整个时间谱范围内的积分';
    '联合拟合捕获修正完整面积',value(t,k,'NwindowCaptureCorrected'),'窗内净计数/模型窗口捕获率';
    '联合拟合核心中心 (ns)',value(t,k,'PeakCoreCenter_s',1e9),'高斯核心中心，不等同于双高斯整体均值或众数';
    '联合拟合核心 σ (ps)',value(t,k,'CoreSigma_s',1e12),'快速高斯核心标准差';
    '联合拟合核心 FWHM (ps)',value(t,k,'CoreFWHM_s',1e12),'2√(2ln2)×核心σ，不是整体混合峰 FWHM';
    '联合拟合尾部 σ (ps)',value(t,k,'TailSigma_s',1e12),'双高斯宽分量标准差；单高斯不适用';
    '联合拟合尾部比例',value(t,k,'TailFraction'),'双高斯混合权重，不是单探测器尾部或后脉冲概率';
    '联合拟合尾部偏移 (ps)',value(t,k,'TailOffset_s',1e12),'宽分量中心相对核心中心的偏移';
    '联合 IRF 整体均值 (ns)',value(t,k,'MixtureMean_s',1e9),'核心中心+尾部权重×尾部偏移';
    '联合 IRF 整体 σ (ps)',value(t,k,'MixtureSigma_s',1e12),'两个高斯分量混合后的整体标准差';
    '联合拟合形状抽样对数',value(t,k,'ShapeFitPairs'),'仅形状抽样；面积和背景仍使用全部候选';
    '联合拟合交叉估计面积',value(t,k,'NpairCrossfit'),'奇偶时间块交叉拟合诊断；不可用时 N/A';
    '联合拟合记录真实对数 Nrec',value(t,k,'NrecTruth'),'完整链路后双路共有的真实 pairID 数，仅仿真';
    '联合拟合窗 TP / FP',sprintf('%s / %s',value(t,k,'TrueWindowPairs'),value(t,k,'FalseWindowPairs')), ...
        '同一实际窗口、all-pairs 口径的真值计数，仅仿真';
    '联合拟合完整面积误差',value(t,k,'RelativeErrorFull'),'(Npair-Nrec)/Nrec；有符号相对误差，仅仿真';
    '联合拟合窗净计数误差',value(t,k,'RelativeErrorWindow'),'(窗内净计数-TP)/TP；有符号相对误差，仅仿真';
    '联合拟合窗偶然计数误差',value(t,k,'RelativeErrorAcc'),'(窗内偶然计数-FP)/FP；有符号相对误差，仅仿真';
    '联合拟合不确定度','未计算','仅点估计；无 Bootstrap 或拟合 Bootstrap'};
if ~includeRepeated
    repeated=["联合拟合窗口来源","联合拟合选窗回退原因","联合拟合窗全宽 (ns)", ...
        "联合拟合窗边界 (ns)","联合拟合完整相关率 (cps)", ...
        "联合拟合窗原始计数","联合拟合窗偶然计数","联合拟合窗净计数", ...
        "联合拟合窗原始率 (cps)","联合拟合窗偶然率 (cps)","联合拟合窗净率 (cps)", ...
        "联合拟合窗捕获率","联合拟合核心中心 (ns)","联合拟合核心 FWHM (ps)", ...
        "联合拟合记录真实对数 Nrec","联合拟合窗 TP / FP", ...
        "联合拟合窗净计数误差","联合拟合窗偶然计数误差"];
    rows(ismember(string(rows(:,1)),repeated),:)=[];
end
end

function text=value(t,k,name,scale)
if nargin<4, scale=1; end
text='N/A';
if ismember(name,t.Properties.VariableNames), text=number(t.(name)(k)*scale); end
end

function text=number(x)
if isempty(x) || isnan(x)
    text='N/A';
elseif isinf(x)
    text='∞';
else
    text=sprintf('%.6g',x);
end
end
