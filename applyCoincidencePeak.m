function h = applyCoincidencePeak(h,model)
%APPLYCOINCIDENCEPEAK 同步独立峰参数和每个直方图 bin 的模型积分。
h.peak=model.peak; h.sigma=model.sigma;
h.fwhm=2*sqrt(2*log(2))*model.sigma;
cdf=.5*(1+erf((h.edges-model.peak)/(sqrt(2)*model.sigma)));
h.fitCounts=model.signalTotal*diff(cdf)+model.backgroundDensity*diff(h.edges);
h.peakMethod="unbinned-gaussian";
end
