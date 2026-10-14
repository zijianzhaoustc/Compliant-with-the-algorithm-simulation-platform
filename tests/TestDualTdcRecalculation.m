classdef TestDualTdcRecalculation < matlab.unittest.TestCase
    methods(Test)
        function totalBinCountIncludesEvenWindows(t)
            o=defaultDualTdcOptions(); o.histRange=[-1 1]*1e-9;
            a=(1:200)'*1e-6; b=a+205e-12+linspace(-50e-12,50e-12,200)';
            o.accidental.method="none";
            for n=[1 5 8 12]
                o.mainBinCount=n; validateDualTdcOptions(o);
                r=analyzeDualTdcDevice(a,b,o,1);
                bins=dualTdcMainBins(o,r.histogram.peakBin);
                t.verifyEqual(numel(bins),n);
                t.verifyEqual(r.metrics.actualWindow_ps,n*10,'AbsTol',1e-9);
                t.verifyEqual(r.metrics.Nraw,sum(r.histogram.counts(bins)));
                t.verifyEqual(r.metrics.NnetSigned,r.metrics.Nraw);
                if mod(n,2)==0, t.verifyEqual(max(bins)-r.histogram.peakBin,r.histogram.peakBin-min(bins)+1); end
            end
        end
        function boundedCounterMatchesAllPairsBruteForce(t)
            a=[0;1;1;2]; b=[0;1;1;2;3]; windows=[-1 0;0 1;1 2]; right=[false;true;false];
            d=b.'-a; expected=zeros(3,1);
            for k=1:3
                keep=d>=windows(k,1) & d<windows(k,2);
                if right(k), keep=keep | d==windows(k,2); end
                expected(k)=nnz(keep);
            end
            t.verifyEqual(countTdcPairsInWindows(a,b,windows,right),expected);
        end
        function allFiveMethodsAgreeWithSingleTdcReference(t)
            [a,b,h,o,p]=fixture();
            A=struct('time',a,'pairID',zeros(size(a)),'type',repmat("measured",size(a)));
            B=struct('time',b,'pairID',zeros(size(b)),'type',repmat("measured",size(b)));
            d=b.'-a; matches=struct('deltaT',d(d>=o.histRange(1) & d<=o.histRange(2)));
            for method=["none","theory","sideband","side-window","time-shift"]
                o.accidental.method=method; p.algorithm.accidentalMethod=method;
                bins=dualTdcMainBins(o,h.peakBin); windows=h.edges([bins(1),bins(end)+1]);
                acc=estimateDualTdcAccidentals(a,b,h,o,p.measurementTime,windows);
                reference=estimateAccidentals(A,B,matches,h,p);
                t.verifyEqual(acc.counts,reference.countEquivalent,'AbsTol',1e-7, ...
                    sprintf('method=%s',method));
            end
        end
        function theoryAndNoneDoNotRequireProtocolSideBins(t)
            o=defaultDualTdcOptions(); o.histRange=[-100 100]*1e-12;
            o.mainBinCount=9; o.sideBeforeBins=[100 200]; a=(1:200)'*1e-6; b=a+5e-12;
            o.accidental.method="theory"; r=analyzeDualTdcDevice(a,b,o,1);
            t.verifyEqual(r.metrics.status,"OK");
            t.verifyEqual(r.metrics.Nacc,200*200*90e-12,'AbsTol',1e-14);
            t.verifyEqual(r.metrics.NnetSigned,r.metrics.Nraw-r.metrics.Nacc);
        end
        function timeShiftUsesLocalOriginForOverlapSubsets(t)
            [a,b,h,o,p]=fixture(); o.accidental.method="time-shift";
            bins=dualTdcMainBins(o,h.peakBin); windows=h.edges([bins(1),bins(end)+1]);
            first=estimateDualTdcAccidentals(a,b,h,o,p.measurementTime,windows);
            later=estimateDualTdcAccidentals(a+.07,b+.07,h,o,p.measurementTime,windows);
            t.verifyEqual(later.counts,first.counts);
            t.verifyEqual(later.sampleCounts,first.sampleCounts);
        end
        function invalidBinOrAccidentalSettingsAreExplicit(t)
            o=defaultDualTdcOptions(); o.mainBinCount=1.5;
            t.verifyError(@()validateDualTdcOptions(o),'MATLAB:expectedInteger');
            o.mainBinCount=31; t.verifyError(@()validateDualTdcOptions(o),'DualTDC:Options');
            o.accidental.method="none"; validateDualTdcOptions(o);
            o.accidental.timeShiftCount=0;
            t.verifyError(@()validateDualTdcOptions(o),'MATLAB:expectedPositive');
            t.verifyError(@()recalculateDualTdc([],o),'DualTDC:NoCachedData');
        end
        function cachedRecalculationDoesNotReadFilesOrRegenerate(t)
            previous=simulateDualTdc();
            previous.data.metadata.F.fileA="missing_F1.bin";
            o=previous.options; o.binWidth=25e-12; o.mainBinCount=8; o.accidental.method="none";
            actual=recalculateDualTdc(previous,o);
            t.verifyEqual(actual.data,previous.data);
            t.verifyEqual(actual.simulation,previous.simulation);
            t.verifyFalse(isfield(actual,'truth')); % old scores must not survive new association settings
            t.verifyEqual(actual.F.metrics.actualWindow_ps,200,'AbsTol',1e-9);
            t.verifyEqual(actual.F.metrics.Nacc,0);
            t.verifyEqual(actual.F.metrics.NnetSigned,actual.F.metrics.Nraw);
            t.verifySubstring(actual.recalculation.source,'no file I/O');
        end
        function guiButtonUsesCacheAndExportsCurrentSettings(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            panel=app.DualTdcPanel;
            t.verifyEqual(string(panel.Controls.Recalculate.Enable),"off");
            t.verifyError(@()panel.recalculateCurrent(),'DualTDC:NoCachedData');
            previous=simulateDualTdc(); panel.setResult(previous);
            t.verifyEqual(string(panel.Controls.Recalculate.Enable),"on");
            panel.Controls.F1.Value='this_file_does_not_exist.bin';
            panel.Controls.BinWidth.Value=25; panel.Controls.MainBins.Value=8;
            panel.Controls.Acc.Value='theory'; panel.Controls.SideGuard.Value=2.5;
            panel.Controls.SideWindowPairs.Value=4; panel.Controls.ShiftStart.Value=2;
            panel.Controls.ShiftStep.Value=3; panel.Controls.ShiftCount.Value=7;
            callback=panel.Controls.Recalculate.ButtonPushedFcn; callback([],[]);
            actual=panel.Result; t.verifyNotEmpty(actual);
            t.verifyEqual(actual.data,previous.data);
            t.verifyEqual(actual.options.mainBinCount,8);
            t.verifyEqual(actual.options.accidental.method,"theory");
            t.verifyEqual(actual.options.accidental.sidebandGuard,2.5e-9,'AbsTol',1e-23);
            t.verifyEqual(actual.options.accidental.sideWindowPairs,4);
            t.verifyEqual(actual.options.accidental.timeShiftStart,2e-6,'AbsTol',1e-20);
            t.verifyEqual(actual.options.accidental.timeShiftStep,3e-6,'AbsTol',1e-20);
            t.verifyEqual(actual.options.accidental.timeShiftCount,7);
            t.verifySubstring(panel.StatusLabel.Text,'未重读文件');
            folder=tempname; mkdir(folder); filesCleanup=onCleanup(@()rmdir(folder,'s'));
            dest=panel.exportTo(folder); m=readtable(fullfile(dest,'F_full_metrics.csv'));
            h=readtable(fullfile(dest,'F_full_histogram.csv'));
            t.verifyEqual(m.main_bin_count,8); t.verifyEqual(nnz(h.main_window_bin),8);
            t.verifyEqual(m.actual_window_ps,200,'AbsTol',1e-9);
            t.verifyEqual(string(m.accidental_method),"theory");
            t.verifyTrue(isnan(m.Nacc_side_count));
            t.verifyEqual(m.Nnet_signed_count,m.Nraw_count-m.Nacc_count,'AbsTol',1e-8);
            clear filesCleanup cleanup
        end
        function legacyOptionsStillUseProtocol(t)
            o=defaultDualTdcOptions(); o=rmfield(o,{'mainBinCount','accidental'});
            validateDualTdcOptions(o); t.verifyEqual(dualTdcMainBins(o,100),97:103);
            cfg=dualTdcAccidentalOptions(o); t.verifyEqual(cfg.method,"protocol");
        end
    end
end

function [a,b,h,o,p]=fixture()
o=defaultDualTdcOptions(); o.histRange=[-1 1]*1e-9; o.mainBinCount=5;
o.accidental.sidebandGuard=.3e-9; o.accidental.sideWindowPairs=2;
o.accidental.timeShiftStart=1.3e-6; o.accidental.timeShiftStep=.7e-6; o.accidental.timeShiftCount=3;
a=(1:200)'*1e-6; b=a+205e-12+linspace(-600e-12,600e-12,200)';
edges=o.histRange(1)+(0:200)*o.binWidth; k=121;
d=b.'-a; h=struct('edges',edges,'peakBin',k,'peak',mean(edges(k:k+1)), ...
    'sigma',20e-12,'fwhm',2*sqrt(2*log(2))*20e-12,'counts',histcounts(d(:),edges));
p=defaultParams(); p.measurementTime=.001; p.algorithm.matchMethod="all-pairs";
p.algorithm.histRange=o.histRange; p.algorithm.binWidth=o.binWidth;
p.algorithm.windowMode="bins"; p.algorithm.windowMultiplier=2;
p.algorithm.sidebandGuard=o.accidental.sidebandGuard; p.algorithm.sideWindowPairs=o.accidental.sideWindowPairs;
p.algorithm.timeShiftStart=o.accidental.timeShiftStart; p.algorithm.timeShiftStep=o.accidental.timeShiftStep;
p.algorithm.timeShiftCount=o.accidental.timeShiftCount;
end
