function bs = summarizeBootstrap(samples, point, names, confidenceLevel)
%SUMMARIZEBOOTSTRAP 使用 N-1 标准差与线性插值百分位区间，无额外工具箱。
bs.names=names;
bs.point=point;
bs.standardUncertainty=std(samples,0,1);
B=size(samples,1); alpha=(1-confidenceLevel)/2;
sorted=sort(samples,1);
bs.CI=interp1((1:B)',sorted,1+(B-1)*[alpha;1-alpha],'linear');
invalid=any(~isfinite(samples),1);
bs.standardUncertainty(invalid)=NaN; bs.CI(:,invalid)=NaN;
bs.relativeUncertainty=bs.standardUncertainty./abs(point);
bs.relativeUncertainty(~isfinite(point) | point==0)=NaN;
bs.covariance=cov(samples);
bs.correlation=nan(numel(point));
denom=bs.standardUncertainty'*bs.standardUncertainty;
valid=isfinite(denom) & denom>0;
bs.correlation(valid)=bs.covariance(valid)./denom(valid);
bs.replicates=array2table(samples,'VariableNames',cellstr(names));
bs.replicates=addvars(bs.replicates,(1:B)','Before',1,'NewVariableNames','Replicate');
bs.confidenceLevel=confidenceLevel;
end
