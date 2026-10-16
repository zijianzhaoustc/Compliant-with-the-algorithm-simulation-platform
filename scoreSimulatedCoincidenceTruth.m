function [truth,delta]=scoreSimulatedCoincidenceTruth(A,B,g,C0,dataMode)
%SCORESIMULATEDCOINCIDENCETRUTH Labels are read only here, never by estimators.
names=["Nrec_true","TP_window_true","Nacc_window_true","F0_true","Fs_true","TrueSigmaFull"];
for name=names, truth.(name)=NaN; end
delta=zeros(0,1);
if string(dataMode)~="simulation" || ~isfield(A,'pairID') || ~isfield(B,'pairID'), return; end
pa=find(A.pairID>0); pb=find(B.pairID>0);
[~,ia,ib]=intersect(A.pairID(pa),B.pairID(pb));
delta=B.time(pb(ib))-A.time(pa(ia)); truth.Nrec_true=numel(delta);
if ~isempty(delta), truth.TrueSigmaFull=std(delta,0); end
if ~g.mainValid, return; end
truth.TP_window_true=nnz(coincidenceIntervalMask(delta,g.mainLower,g.mainUpper,g.includeUpperEdge));
truth.Nacc_window_true=C0-truth.TP_window_true;
if truth.Nrec_true>0
    truth.F0_true=truth.TP_window_true/truth.Nrec_true;
    captured=0;
    for s=g.sideWindows
        if s.valid, captured=captured+nnz(coincidenceIntervalMask(delta,s.lower,s.upper,s.includeUpper)); end
    end
    if g.valid, truth.Fs_true=captured/truth.Nrec_true; end
end
end
