function g=buildCoincidenceWindowGeometry(h,p)
%BUILDCOINCIDENCEWINDOWGEOMETRY Authoritative main/guard/side lag geometry (SI).
a=p.algorithm; mode=string(a.windowMode);
discrete=ismember(mode,["bins","discrete","DISCRETE_BINS"]);
name="CONTINUOUS_TIME"; if discrete, name="DISCRETE_BINS"; end
limits=[max(a.histRange(1),h.edges(1)),min(a.histRange(2),h.edges(end))];
if isfield(h,'searchBounds'), limits=[max(limits(1),h.searchBounds(1)),min(limits(2),h.searchBounds(2))]; end
peak=h.peak; k=discretize(peak,h.edges); n=a.windowMultiplier;
requested=a.window; if discrete, requested=(2*n+1)*a.binWidth; end
g=struct('mode',name,'peakCenterEstimate',peak,'peakBinIndex',k,'mainBinIndices',[], ...
    'mainLower',NaN,'mainUpper',NaN,'WRequested',requested,'WActual',NaN, ...
    'guardGapActual',NaN,'guardLeftBounds',[NaN NaN],'guardRightBounds',[NaN NaN], ...
    'sideWindows',struct('side',{},'index',{},'lower',{},'upper',{},'width',{},'valid',{},'includeUpper',{}), ...
    'sideWindowCountRequested',2*a.sideWindowPairs,'sideWindowCountValid',0, ...
    'histSearchBounds',limits,'mainValid',false,'valid',false,'invalidReason',"INVALID_WINDOW_GEOMETRY", ...
    'legacyReason',"INVALID_PEAK",'includeUpperEdge',false,'binPhase',h.edges(1));
peakOK=isfinite(peak) && ~isnan(k);
if isfield(h,'peakValid'), peakOK=peakOK && h.peakValid; end
if isfield(h,'fitStatus'), peakOK=peakOK && h.fitStatus~="FIT_FAILED"; end
if ~peakOK, return; end
if discrete
    indices=k+(-n:n);
    if indices(1)<1 || indices(end)>numel(h.edges)-1, g.legacyReason="INVALID_MAIN_WINDOW"; return; end
    g.mainBinIndices=indices; bounds=h.edges([indices(1),indices(end)+1]);
else
    bounds=peak+[-.5 .5]*a.window;
end
tol=64*eps(max(abs([limits,bounds])));
if bounds(1)<limits(1)-tol || bounds(2)>limits(2)+tol
    g.legacyReason="INVALID_MAIN_WINDOW"; return
end
g.mainLower=bounds(1); g.mainUpper=bounds(2); g.WActual=diff(bounds); g.mainValid=true;
g.includeUpperEdge=abs(bounds(2)-h.edges(end))<=tol && abs(bounds(2)-limits(2))<=tol;
guardMode="window-width"; if isfield(a,'sideWindowGuardMode'), guardMode=string(a.sideWindowGuardMode); end
if ismember(guardMode,["fixed-center","LEGACY_FIXED_CENTER"])
    nearLeft=peak-max(a.sidebandGuard,g.WActual/2); nearRight=peak+max(a.sidebandGuard,g.WActual/2);
else
    nearLeft=bounds(1)-g.WActual; nearRight=bounds(2)+g.WActual;
end
g.guardLeftBounds=[nearLeft,bounds(1)]; g.guardRightBounds=[bounds(2),nearRight];
g.guardGapActual=nearRight-bounds(2);
for j=1:a.sideWindowPairs
    for side=["left","right"]
        if side=="left", e=nearLeft-[j,j-1]*g.WActual; else, e=nearRight+[j-1,j]*g.WActual; end
        valid=e(1)>=limits(1)-tol && e(2)<=limits(2)+tol;
        g.sideWindows(end+1)=struct('side',side,'index',j,'lower',e(1),'upper',e(2), ...
            'width',g.WActual,'valid',valid,'includeUpper',abs(e(2)-h.edges(end))<=tol && abs(e(2)-limits(2))<=tol); %#ok<AGROW>
    end
end
g.sideWindowCountValid=nnz([g.sideWindows.valid]);
g.valid=g.sideWindowCountValid==g.sideWindowCountRequested;
g.legacyReason="INVALID_SIDE_WINDOWS";
if g.valid, g.invalidReason=""; g.legacyReason="OK"; end
end
