function summary = summarizeSweepSeeds(t)
%SUMMARIZESWEEPSEEDS Group physical+algorithm settings excluding seed only.
if isempty(t)
    summary=table(strings(0,1),zeros(0,1),'VariableNames',{'seed_group_key','replicate_count'}); return
end
keys=unique(t.seed_group_key,'stable'); rows=cell(numel(keys),1);
metrics=["RA_cps","RB_cps","Rraw_cps","Racc_cps","Rnet_cps","Rnet_signed_cps", ...
    "epsilon_acc_vs_true","epsilon_pair_window","error_acc_count","error_pair_window_count"];
for i=1:numel(keys)
    selected=t(t.seed_group_key==keys(i),:);
    valid=selected.status=="OK" & ~contains(selected.warning_codes,"EFFECT_DISABLED");
    r=struct('seed_group_key',keys(i),'physical_config_id',selected.physical_config_id(1), ...
        'analysis_config_id',selected.analysis_config_id(1),'replicate_count',height(selected), ...
        'success_count',nnz(valid),'invalid_count',nnz(~valid));
    for metric=metrics
        values=selected.(metric)(valid); values=values(isfinite(values));
        r.(metric+"_mean")=mean(values); r.(metric+"_std")=std(values);
        if isempty(values), r.(metric+"_std")=NaN; end
    end
    pairs=["epsilon_acc_vs_true","error_acc";"epsilon_pair_window","error_pair_window"; ...
        "error_acc_count","error_acc_absolute";"error_pair_window_count","error_pair_window_absolute"];
    for j=1:size(pairs,1)
        values=selected.(pairs(j,1))(valid); values=values(isfinite(values));
        r.(pairs(j,2)+"_bias_mean")=mean(values);
        r.(pairs(j,2)+"_RMSE")=sqrt(mean(values.^2));
    end
    rows{i}=r;
end
summary=struct2table(vertcat(rows{:}));
end
