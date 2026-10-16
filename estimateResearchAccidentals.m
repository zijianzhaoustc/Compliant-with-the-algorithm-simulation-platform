function acc=estimateResearchAccidentals(a,b,h,g,p,sideCounts)
%ESTIMATERESEARCHACCIDENTALS Timestamp-only background estimates, no labels.
T=p.measurementTime; W=g.WActual; a=a(:); b=b(:); method=string(p.algorithm.accidentalMethod);
acc=struct('rate',NaN,'countEquivalent',NaN,'method',method,'details',"", ...
    'sampleOffsets',zeros(0,1),'sampleCounts',zeros(0,1),'status',"OK", ...
    'boundaries',zeros(0,2),'validPairs',g.sideWindowCountValid/2,'guardGap',g.guardGapActual, ...
    'guardMode',string(p.algorithm.sideWindowGuardMode),'sideTrueCount',NaN, ...
    'variance',NaN,'effectiveExposures',[],'flags',strings(1,0),'segmentCounts',[],'segmentDurations',[]);
if ~g.mainValid, acc.status=g.legacyReason; return; end
switch method
    case "none", value=0; variance=0;
    case "theory"
        value=numel(a)*numel(b)*W/T;
        variance=(W/T)^2*(numel(a)*numel(b)^2+numel(b)*numel(a)^2);
    case "segment-theory"
        edges=0:p.algorithm.segmentDuration:T; if edges(end)<T, edges(end+1)=T; end
        durations=diff(edges); na=histcounts(a,edges); nb=histcounts(b,edges);
        value=W*sum(na.*nb./durations);
        variance=W^2*sum((na.*nb.^2+nb.*na.^2)./durations.^2);
        acc.segmentCounts=[na(:),nb(:)]; acc.segmentDurations=durations;
    case "side-window"
        acc.boundaries=[[g.sideWindows.lower]',[g.sideWindows.upper]'];
        acc.sampleCounts=sideCounts; acc.sampleOffsets=mean(acc.boundaries,2)-h.peak;
        if ~g.valid, acc.status="INVALID_SIDE_WINDOWS"; return; end
        L=numel(sideCounts); value=sum(sideCounts)/L; variance=sum(sideCounts)/L^2;
    case "sideband"
        windows=[g.histSearchBounds(1),g.guardLeftBounds(1);g.guardRightBounds(2),g.histSearchBounds(2)];
        widths=max(0,diff(windows,1,2)); valid=widths>0;
        count=sum(countTdcPairsInWindows(a,b,windows(valid,:)));
        width=sum(widths);
        if width<=0, acc.status="INVALID_SIDE_WINDOWS"; return; end
        value=count*W/width; variance=count*(W/width)^2; acc.boundaries=windows(valid,:);
    case "time-shift"
        shifts=p.algorithm.timeShiftStart+(0:p.algorithm.timeShiftCount-1)'*p.algorithm.timeShiftStep;
        rates=nan(size(shifts)); exposures=zeros(size(shifts)); counts=zeros(size(shifts));
        for j=1:numel(shifts)
            shift=shifts(j);
            if p.algorithm.timeShiftMode=="circular"
                shifted=sort(mod(b+shift,T)); exposures(j)=T;
                counts(j)=countTdcPairsInWindows(a,shifted,[g.mainLower,g.mainUpper],g.includeUpperEdge);
            else
                % Erode common acquisition support by the full lag window:
                % every retained A has an entire valid B coincidence window.
                lower=max(0,shift-g.mainLower); upper=min(T,T+shift-g.mainUpper);
                exposures(j)=max(0,upper-lower);
                keep=a>=lower & a<upper;
                counts(j)=countTdcPairsInWindows(a(keep),b+shift,[g.mainLower,g.mainUpper]);
            end
            if exposures(j)>0, rates(j)=counts(j)/exposures(j); end
        end
        acc.sampleOffsets=shifts; acc.sampleCounts=counts; acc.effectiveExposures=exposures;
        if any(exposures<=0), acc.status="INVALID_SHIFT_EXPOSURE"; return; end
        value=mean(rates)*T; variance=sum(counts./exposures.^2)*T^2/numel(shifts)^2;
        acc.sampleOffsets=shifts; acc.sampleCounts=counts; acc.effectiveExposures=exposures;
        acc.flags="SHARED_SHIFT_COVARIANCE_APPROXIMATION";
        if any(abs(shifts)<=g.WActual+3*h.sigma), acc.flags(end+1)="SHIFT_PEAK_OVERLAP_RISK"; end
        if p.algorithm.timeShiftMode=="circular", acc.flags(end+1)="CIRCULAR_SHIFT_BOUNDARY_ASSUMPTION"; end
    otherwise, error('CoincidenceSim:ResearchEstimator','Unsupported estimator.');
end
acc.countEquivalent=value; acc.rate=value/T; acc.variance=variance;
acc.details="Research geometry; approximate count variance; observable timestamps only";
end
