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
    axes=["Rpair_per_s","T_s","bin_width_ps","n_bins_each_side","K_requested", ...
        "hist_half_range_ns","dark_A_cps","dark_B_cps","bg_A_cps","bg_B_cps", ...
        "detectorJitter_A_ps","detectorJitter_B_ps","tdcJitter_A_ps","tdcJitter_B_ps", ...
        "param_algorithm_window","param_algorithm_fixedPeakCenter","param_algorithm_segmentDuration"];
    for name=axes
        if ismember(name,string(selected.Properties.VariableNames)), r.(name)=selected.(name)(1); end
    end
    for name=["mode","estimator","peak_method"]
        if ismember(name,string(selected.Properties.VariableNames)), r.(name)=selected.(name)(1); end
    end
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
    scientific=valid;
    if ismember('quality_status',selected.Properties.VariableNames)
        scientific=valid & selected.quality_status~="INVALID";
    end
    r.seed_count=height(selected); r.scientific_valid_count=nnz(scientific);
    for name=["Npair_est","Nacc_est","F0_est","Fs_est","fit_sigma","u_Npair","u_Nacc"]
        if ~ismember(name,string(selected.Properties.VariableNames)), continue; end
        x=selected.(name)(scientific); x=x(isfinite(x));
        r.(name+"_mean")=mean(x); r.(name+"_std")=std(x); if isempty(x), r.(name+"_std")=NaN; end
    end
    for target=["pair","acc"]
        name="signed_error_"+target;
        if ~ismember(name,string(selected.Properties.VariableNames)), continue; end
        x=selected.(name)(scientific); x=x(isfinite(x));
        r.(target+"_Bias")=mean(x); r.(target+"_MAE")=mean(abs(x)); r.(target+"_RMSE")=sqrt(mean(x.^2));
        truthName="Nrec_true"; if target=="acc", truthName="Nacc_window_true"; end
        truth=selected.(truthName)(scientific); truth=truth(isfinite(truth)); denominator=mean(truth);
        r.(target+"_relative_bias")=NaN; r.(target+"_relative_RMSE")=NaN;
        if denominator>0
            r.(target+"_relative_bias")=mean(x)/denominator;
            r.(target+"_relative_RMSE")=sqrt(mean(x.^2))/denominator;
        end
    end
    for kind=["expected","realized_compatibility"]
        name="coverage95_"+kind;
        if ~ismember(name,string(selected.Properties.VariableNames)), continue; end
        x=selected.(name)(scientific); x=x(isfinite(x)); count=numel(x); probability=mean(x);
        r.(name)=probability; r.(name+"_replicates")=count;
        r.(name+"_MCSE")=sqrt(probability*(1-probability)/max(count,1));
        r.(name+"_sufficient_repetitions")=count>=200;
    end
    rows{i}=r;
end
summary=struct2table(vertcat(rows{:}));
end
