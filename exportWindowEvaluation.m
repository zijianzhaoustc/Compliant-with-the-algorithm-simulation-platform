function file = exportWindowEvaluation(out, folder, baseName)
%EXPORTWINDOWEVALUATION 以候选窗口为单位导出方差和归一化评分。
o=out.optimization;
scan=o.windowScan; n=height(scan);
seed=nan(n,1);
if string(out.dataMode)=="simulation", seed(:)=out.params.seed; end
window=nan(n,1); capture=window; variance=window; score=window;
scoreMean=window; scoreStd=window;
valid=false(n,1); selected=valid;
scoreSource=repmat("unavailable",n,1);
if n>0
    window=scan.Window_s*1e9; capture=scan.CaptureEstimate;
    variance=scan.BootstrapU_side.^2; score=scan.OptimizationScore;
    valid=scan.ValidCandidate; selected=scan.Selected;
    scoreSource(isfinite(score))="candidate-bootstrap";
    if isfield(o,'bagging') && isfield(o.bagging,'ScoreVariance')
        bag=o.bagging;
        scored=isfinite(bag.ScoreVariance);
        variance(scored)=bag.ScoreVariance(scored);
        score(scored)=variance(scored)./capture(scored).^2;
        scoreMean=bag.ScoreMean; scoreStd=bag.ScoreStd;
        scoreSource(scored)="bagging-block-variance";
    end
end
evaluation=table(seed,window,capture,variance,score,scoreMean,scoreStd,valid,selected,scoreSource, ...
    'VariableNames',{'Seed','W_ns','Eta','V','J','J_mean','J_std','Valid','Selected','ScoreSource'});
file=fullfile(folder,baseName+"_window_evaluation.csv");
writeUtf8BomTable(evaluation,file);
end
