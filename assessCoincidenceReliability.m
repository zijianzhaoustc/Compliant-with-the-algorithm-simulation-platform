function [status,flags,reason,d]=assessCoincidenceReliability(a,b,h,g,p,r,side)
%ASSESSCOINCIDENCERELIABILITY Observable data/configuration only; never truth.
flags=strings(1,0); reason=""; status="CAUTION";
d=struct('stationarityP',NaN,'sideAsymmetryZ',NaN);
if any(~isfinite([a(:);b(:)])) || any(diff(a)<0) || any(diff(b)<0) || ...
        any(a<0 | a>p.measurementTime) || any(b<0 | b>p.measurementTime)
    status="INVALID"; reason="DATA_QUALITY_INVALID"; flags=reason; return
end
if ~g.valid
    status="INVALID"; reason="INVALID_WINDOW_GEOMETRY"; flags=reason; return
end
if r.fit_status~="FIT_OK" || ~isfinite(r.Npair_est)
    status="INVALID"; reason="PEAK_FIT_INVALID"; flags=reason; return
end
if p.algorithm.correlatedBackgroundPossible
    status="INVALID"; reason="CORRELATED_BACKGROUND_NOT_IDENTIFIABLE"; flags=reason; return
end
edges=0:p.algorithm.segmentDuration:p.measurementTime;
if edges(end)<p.measurementTime, edges(end+1)=p.measurementTime; end
if numel(edges)>2
    counts=[histcounts(a,edges);histcounts(b,edges)]; durations=diff(edges);
    expected=sum(counts,2)*durations/p.measurementTime;
    valid=expected>0; q=sum((counts(valid)-expected(valid)).^2./expected(valid));
    df=max(1,2*(numel(durations)-1)); d.stationarityP=gammainc(q/2,df/2,'upper');
    if d.stationarityP<p.algorithm.stationarityAlpha, flags(end+1)="NONSTATIONARY"; end
end
if ~isempty(side) && all(isfinite(side))
    left=sum(side(1:2:end)); right=sum(side(2:2:end));
    d.sideAsymmetryZ=abs(left-right)/sqrt(max(left+right,1));
    if d.sideAsymmetryZ>p.algorithm.sideAsymmetryThreshold, flags(end+1)="SIDEBAND_ASYMMETRY"; end
end
if r.Fs_est/max(g.sideWindowCountRequested*r.F0_est,eps)>p.algorithm.sideTailThreshold
    flags(end+1)="SIDEBAND_CONTAMINATED";
end
if r.fit_residual_score>p.algorithm.residualThreshold, flags(end+1)="PEAK_MODEL_RESIDUAL"; end
if r.Nnet_signed<0, flags(end+1)="NEGATIVE_NET_COUNT"; end
if p.algorithm.uncertaintyMethod~="bootstrap" && ...
        (p.detector.enableDeadTime || p.detector.enableAfterpulse || p.tdc.enableDeadTime || max(numel(a),numel(b))*g.WActual/p.measurementTime>.01)
    flags(end+1)="COUNT_COVARIANCE_APPROXIMATION";
end
calibrated=false;
if p.algorithm.qualityCalibrated && isfield(p.algorithm,'qualityCalibration')
    profile=p.algorithm.qualityCalibration;
    calibrated=isfield(profile,'hash') && isfield(profile,'sourceHash') && string(profile.sourceHash)==scanCodeHash() && profile.validated && ...
        string(profile.scopeHash)==researchCalibrationScope(p) && ...
        string(profile.hash)==scanHash(rmfield(profile,'hash')) && ...
        isempty(intersect(profile.trainingSeeds,profile.validationSeeds));
end
if ~calibrated, flags(end+1)="UNCALIBRATED_QUALITY_PROFILE"; end
flags(end+1)="CORRELATED_BACKGROUND_EXCLUDED_BY_ASSUMPTION";
if calibrated && numel(flags)==1, status="RELIABLE"; else, status="CAUTION"; end
% No residual/side/count thresholds are represented as validated by default.
if isempty(h.counts), status="INVALID"; reason="PEAK_FIT_INVALID"; end
end
