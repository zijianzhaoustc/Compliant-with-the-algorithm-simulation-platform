function r=researchConfidenceIntervals(r)
%RESEARCHCONFIDENCEINTERVALS Normal delta/Poisson intervals without truncation.
r.CI_Npair_lower=r.Npair_est-1.95996398454005*r.u_Npair;
r.CI_Npair_upper=r.Npair_est+1.95996398454005*r.u_Npair;
r.CI_Nacc_lower=r.Nacc_est-1.95996398454005*r.u_Nacc;
r.CI_Nacc_upper=r.Nacc_est+1.95996398454005*r.u_Nacc;
end
