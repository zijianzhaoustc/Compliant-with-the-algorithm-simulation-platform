function [r,fit,acc,aux]=estimateRecordedPairs(a,b,h,g,p,fit,observed)
%ESTIMATERECORDEDPAIRS Observable-only estimators, independent of event labels.
p=researchParams(p); r=researchResultTemplate();
if nargin<6, fit=fitIntegratedCoincidencePeak(h,p); end
if nargin<7
    [C0,Cs,side]=countResearchWindows(a,b,g);
    acc=estimateResearchAccidentals(a,b,h,g,p,side);
else
    C0=observed.C0; Cs=observed.Cs; side=observed.side; acc=observed.acc;
end
r.C0=C0; r.Cs=Cs;
r.Nacc_est=acc.countEquivalent; r.Nnet_signed=C0-r.Nacc_est;
r.fit_status=fit.status; r.fit_mu=fit.mu; r.fit_sigma=fit.sigma;
r.fit_area=fit.area; r.fit_residual_score=fit.residualScore;
[F,covF,G]=peakWindowMasses(fit,g); r.F0_est=F(1); r.Fs_est=F(2);
L=g.sideWindowCountRequested; aux=struct('sideCounts',side,'covariance',nan(4));
r.u_Nacc=sqrt(acc.variance); r.uncertainty_method="APPROX_POISSON";
if g.mainValid && fit.status=="FIT_OK" && F(1)>=p.algorithm.minCapture
    joint=string(p.algorithm.pairRecovery)=="joint-side" && acc.method=="side-window";
    if joint, D=F(1)-F(2)/L; else, D=F(1); end
    r.recovery_denominator=D;
    if isfinite(D) && D>=p.algorithm.minRecoveryDenominator
        if joint
            S=jointCovariance(fit,g,C0,Cs,G,covF);
            propagated=propagateCoincidenceUncertainty([C0,Cs,F],S,L);
            r.Npair_est=propagated.pair; r.Nacc_est=propagated.accidental;
            r.u_Npair=propagated.uPair; r.u_Nacc=propagated.uAccidental; aux.covariance=S;
            r.uncertainty_method="DELTA_BIN_POISSON_WITH_FIT_COVARIANCE";
        else
            r.Npair_est=(C0-acc.countEquivalent)/F(1);
            r.u_Npair=sqrt(max(0,(C0+acc.variance)/F(1)^2+ ...
                ((C0-acc.countEquivalent)/F(1)^2)^2*covF(1,1)));
            r.uncertainty_method="APPROX_POISSON_AND_FIT";
        end
        r.Nnet_signed=C0-r.Nacc_est; r.Rpair_est=r.Npair_est/p.measurementTime;
    end
end
[r.quality_status,flags,r.invalid_reason,diagnostics]=assessCoincidenceReliability(a,b,h,g,p,r,side);
if r.invalid_reason=="PEAK_FIT_INVALID" && fit.status=="FIT_OK"
    if F(1)<p.algorithm.minCapture, r.invalid_reason="LOW_CAPTURE_FRACTION";
    elseif ~isfinite(r.recovery_denominator) || r.recovery_denominator<p.algorithm.minRecoveryDenominator
        r.invalid_reason="SMALL_RECOVERY_DENOMINATOR";
    end
    flags(end+1)=r.invalid_reason;
end
r.stationarity_p=diagnostics.stationarityP; r.side_asymmetry_z=diagnostics.sideAsymmetryZ;
r.quality_flags=strjoin(unique([flags,acc.flags],'stable'),';');
if ~isempty(acc.flags) && r.quality_status=="RELIABLE", r.quality_status="CAUTION"; end
if p.algorithm.correlatedBackgroundPossible
    r.Npair_est=NaN; r.Rpair_est=NaN; r.u_Npair=NaN;
end
r=researchConfidenceIntervals(r);
r.geometry_json=string(jsonencode(g));
r.fit_json=string(jsonencode(rmfield(fit,{'jacobian','expected','counts','edges'})));
end

function S=jointCovariance(fit,g,C0,Cs,G,covF)
edges=fit.edges; width=diff(edges);
mainWeight=max(0,min(edges(2:end),g.mainUpper)-max(edges(1:end-1),g.mainLower))./width;
sideWeight=zeros(size(mainWeight));
for s=g.sideWindows
    sideWeight=sideWeight+max(0,min(edges(2:end),s.upper)-max(edges(1:end-1),s.lower))./width;
end
cross=[mainWeight;sideWeight]*fit.jacobian*fit.covTheta*G';
S=[diag([max(C0,0),max(Cs,0)]),cross;cross',covF];
S=(S+S')/2; [vectors,values]=eig(S); S=vectors*diag(max(0,diag(values)))*vectors';
end
