classdef TestWindowGeometry < matlab.unittest.TestCase
    methods(Test)
        function discreteSevenBins(t)
            [p,h]=fixture(300e-12); g=buildCoincidenceWindowGeometry(h,p);
            t.verifyNumElements(g.mainBinIndices,7);
            t.verifyEqual(g.WActual,2.1e-9,'AbsTol',1e-22);
            t.verifyEqual(g.sideWindows(2).lower,g.mainUpper+g.WActual,'AbsTol',1e-22);
            t.verifyEqual(g.sideWindows(1).upper,g.mainLower-g.WActual,'AbsTol',1e-22);
            t.verifyTrue(g.valid); t.verifyEqual(g.sideWindowCountValid,6);
        end
        function continuousFixedIndependentOfBin(t)
            values=[]; a=0; b=(-2:.05:2)'*1e-9;
            for width=[50 100 300]*1e-12
                [p,h]=fixture(width); p.algorithm.windowMode="fixed"; p.algorithm.window=2.1e-9;
                g=buildCoincidenceWindowGeometry(h,p);
                values(end+1)=countResearchWindows(a,b,g); %#ok<AGROW>
            end
            t.verifyEqual(values,repmat(values(1),size(values)));
        end
        function equalBoundsAndHalfOpen(t)
            [p,h]=fixture(300e-12); g=buildCoincidenceWindowGeometry(h,p);
            b=unique([h.centers,g.mainLower,g.mainUpper]); a=0;
            direct=countResearchWindows(a,b,g);
            counts=histcounts(b,h.edges);
            t.verifyEqual(direct,sum(counts(g.mainBinIndices)));
            p.algorithm.windowMode="fixed"; p.algorithm.window=g.WActual;
            h.peak=mean([g.mainLower,g.mainUpper]); c=buildCoincidenceWindowGeometry(h,p);
            t.verifyEqual(countResearchWindows(a,b,c),direct);
            t.verifyEqual(coincidenceIntervalMask([g.mainLower;g.mainUpper],g.mainLower,g.mainUpper,false),[true;false]);
        end
        function incompleteSideAndPartialLastBin(t)
            [p,h]=fixture(300e-12); p.algorithm.sideWindowPairs=100;
            g=buildCoincidenceWindowGeometry(h,p);
            t.verifyFalse(g.valid); t.verifyEqual(g.sideWindowCountRequested,200);
            t.verifyEqual(g.invalidReason,"INVALID_WINDOW_GEOMETRY");
            p.algorithm.sideWindowPairs=1; p.algorithm.histRange(2)=h.edges(end)-10e-12;
            h.peak=h.centers(end); p.algorithm.windowMultiplier=0;
            g=buildCoincidenceWindowGeometry(h,p); t.verifyFalse(g.mainValid);
        end
        function streamedHistogramExactAndWiderSearch(t)
            [p,~]=fixture(100e-12); a=[0;1e-6]; b=[0;1e-9;5e-9;1e-6];
            [c,e,s]=streamCoincidenceHistogram(a,b,p);
            d=reshape(b-a',[],1); expected=histcounts(d(d>=p.algorithm.histRange(1)&d<=p.algorithm.histRange(2)),e);
            t.verifyEqual(c,expected); t.verifyEqual(sum(c),s.pairCount);
            p.algorithm.histRange=[-2 2]*1e-9; [small,~,~]=streamCoincidenceHistogram(a,b,p);
            t.verifyGreaterThan(sum(c),sum(small));
        end
        function fullTruthIndependentOfSearch(t)
            [p,h]=fixture(100e-12); g=buildCoincidenceWindowGeometry(h,p);
            A=struct('time',[0;1e-6;2e-6],'pairID',[1;2;3]);
            B=struct('time',[0;1e-6+1e-9;2e-6+25e-9],'pairID',[1;2;3]);
            truth=scoreSimulatedCoincidenceTruth(A,B,g,3,"simulation");
            p.algorithm.histRange=[-1 1]*1e-9; h.searchBounds=p.algorithm.histRange;
            other=scoreSimulatedCoincidenceTruth(A,B,buildCoincidenceWindowGeometry(h,p),1,"simulation");
            t.verifyEqual(truth.Nrec_true,3); t.verifyEqual(other.Nrec_true,truth.Nrec_true);
            t.verifyEqual(other.TrueSigmaFull,truth.TrueSigmaFull);
        end
    end
end
function [p,h]=fixture(width)
p=researchParams(defaultParams()); p.algorithm.histRange=[-30 30]*1e-9;
p.algorithm.binWidth=width; p.algorithm.windowMode="bins";
p.algorithm.strictWindows=true; p.algorithm.sideWindowGuardMode="window-width";
p.algorithm.windowMultiplier=3; p.algorithm.sideWindowPairs=3;
h=buildHistogram(struct('deltaT',0),p); h.peak=0; h.peakValid=true; h.fitStatus="MAXIMUM";
end
