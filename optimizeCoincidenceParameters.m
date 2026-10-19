function optimization = optimizeCoincidenceParameters(A,B,matches,p,dataMode)
%OPTIMIZECOINCIDENCEPARAMETERS 先建模再选 bin/窗口；推荐与正式测量结果分开。
if nargin<5, dataMode="imported"; end
optimization=struct('valid',false,'applied',false,'mode',p.optimization.mode, ...
    'binWidth',NaN,'window',NaN,'peak',NaN,'sigma',NaN,'sideGuard',NaN, ...
    'captureEstimate',NaN,'status',"not-run",'binScan',table(),'windowScan',table(), ...
    'diagnostics',strings(0,1),'peakModel',[], 'candidateBootstrap',{{}}, ...
    'uncertaintyScope',"fixed-parameters; parameter-selection uncertainty excluded", ...
    'settings',p.optimization,'uncertaintySettings',p.uncertainty, ...
    'requestedAlgorithm',p.algorithm,'effectiveAlgorithm',p.algorithm);
if ~any(string(p.algorithm.matchMethod)==["many-to-many","all-pairs"])
    optimization.status="unsupported-matching-rule";
    optimization.diagnostics="自动优化需要 all-pairs 匹配；保留当前手动结果"; return
end
model=estimateCoincidencePeak(matches,p);
optimization.peakModel=model; optimization.peak=model.peak; optimization.sigma=model.sigma;
if ~model.valid
    optimization.status=model.status;
    switch model.status
        case "insufficient-peak", message="峰区事件不足，无法稳定估计峰形";
        case "no-significant-peak", message="没有显著主峰，无法自动推荐";
        case "unresolved-or-weak-peak", message="峰分辨不足或拟合不稳定，请检查分辨率与采集量";
        case "peak-at-search-boundary", message="峰接近搜索边界，请扩大时间谱范围";
        otherwise, message="峰形存在多峰、长尾或明显非 Gaussian 特征，不自动应用参数";
    end
    optimization.diagnostics=message; return
end
bins=optimizeHistogramBin(matches,p,model);
optimization.binScan=bins.table;
if ~bins.valid
    optimization.status="unstable-bin-boundaries";
    optimization.diagnostics="没有通过 bin 相位稳定性检查的候选"; return
end
optimization.binWidth=bins.binWidth;
windows=optimizeCoincidenceWindow(A,B,matches,p,model);
optimization.windowScan=windows.table; optimization.candidateBootstrap=windows.candidateBootstrap;
if ~windows.valid
    optimization.status="no-valid-window";
    optimization.diagnostics="没有同时满足捕获率、旁窗完整性、背景统计和选择策略的候选窗口";
else
    optimization.valid=true; optimization.status="ok";
    optimization.window=windows.window; optimization.captureEstimate=windows.captureEstimate;
    optimization.sideGuard=windows.sideGuard;
end
% 推荐已经确定后才加入真值诊断；这些字段完全不参与选参。
t=optimization.windowScan; n=height(t); TP=nan(n,1); FP=nan(n,1); eta=nan(n,1);
if string(dataMode)=="simulation"
    trueDelta=sort(matches.deltaT(matches.isTrue));
    eligible=numel(intersect(A.pairID(A.pairID>0),B.pairID(B.pairID>0)));
    for k=1:n
        TP(k)=countSortedInterval(trueDelta,model.peak-t.Window_s(k)/2,model.peak+t.Window_s(k)/2);
    end
    FP=t.Nraw-TP;
    if eligible>0, eta=TP/eligible; end
end
t.TP=TP; t.FP=FP; t.EtaW=eta;
t.epsilon_acc_side=relative(t.Nacc_side-FP,FP);
t.epsilon_acc_theory=relative(t.Nacc_theory-FP,FP);
t.epsilon_corr_side=relative(t.Ncorr_side-TP,TP);
t.epsilon_corr_theory=relative(t.Ncorr_theory-TP,TP);
optimization.windowScan=t;
end

function r=relative(a,b)
r=a./b; r(b==0)=NaN;
end
