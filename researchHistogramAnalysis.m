function [h,fit,g]=researchHistogramAnalysis(counts,p)
%RESEARCHHISTOGRAMANALYSIS One unlabelled peak/geometry path for all resamples.
q=p; q.algorithm.peakMethod="maximum";
h=buildHistogram(struct('histogramCounts',counts),q); h.peakMethod=p.algorithm.peakMethod;
fit=fitIntegratedCoincidencePeak(h,p);
if p.algorithm.peakMethod=="gaussian"
    h.peak=fit.mu; h.sigma=fit.sigma; h.fwhm=2*sqrt(2*log(2))*fit.sigma;
    h.peakValid=fit.status=="FIT_OK"; h.fitStatus=fit.status;
elseif p.algorithm.peakMethod=="fixed"
    h.peak=p.algorithm.fixedPeakCenter; h.peakValid=isfinite(h.peak); h.fitStatus="FIXED_CENTER";
end
if fit.status=="FIT_OK"
    h.fitCounts=fit.area*gaussianIntervalProbability(h.edges(1:end-1),h.edges(2:end),fit.mu,fit.sigma)+ ...
        fit.backgroundDensity*diff(h.edges);
end
g=buildCoincidenceWindowGeometry(h,p);
end
