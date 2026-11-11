function diagnostics = diagnoseIRFModel(blocks,res)
%DIAGNOSEIRFMODEL Independent evaluation-region residuals, not fit bins.
rows=cell(0,10); D=blocks.domain; edges=linspace(D(1),D(2),41);
for k=1:numel(res.folds)
    fold=res.folds{k}; m=fold.fit.model; v=blocks.items(fold.evaluationBlocks);
    for j=1:numel(edges)-1
        interval=edges(j:j+1); observed=0;
        for c=1:numel(v)
            for q=1:numel(v(c).delta)
                d=unbinnedDataChunk(v(c).delta{q});
                observed=observed+nnz(d>=interval(1) & (d<interval(2) | (j==40 & d==interval(2))));
            end
        end
        [~,mass]=evaluateIRF([],m,interval);
        expected=sum([v.background])*diff(interval)+fold.evaluation.N*mass;
        residual=NaN; if expected>0, residual=(observed-expected)/sqrt(expected); end
        tail=abs(mean(interval)-m.mu)>3*m.sigma1;
        rows(end+1,:)={k,interval(1),interval(2),observed,expected,residual,tail, ...
            fold.fit.logLik,fold.evaluation.logLik,fold.fit.identifiable}; %#ok<AGROW>
    end
end
diagnostics=cell2table(rows,'VariableNames',{'fold','delay_low_s','delay_high_s', ...
    'observed_pairs','predicted_pairs','standardized_residual','is_tail', ...
    'training_composite_logLik','evaluation_composite_logLik','identifiable'});
end
