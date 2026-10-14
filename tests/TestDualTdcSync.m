classdef TestDualTdcSync < matlab.unittest.TestCase
    methods(Test)
        function perfectThirtySecondAudit(t)
            o=defaultDualTdcOptions(); sync=(0:14999999)'*2e-6;
            q=auditSyncTimestamps(sync,o.sync);
            t.verifyEqual(q.count,15000000);
            t.verifyEqual(q.frequency_Hz,500000,'AbsTol',.002);
            t.verifyEqual(q.expectedCyclesInSpan,15000000);
            t.verifyEqual(q.missingCandidateCount,0);
            t.verifyEqual(q.glitchCount,0); t.verifyEqual(q.qaFlag,"OK");
            t.verifyEqual(sum(q.rates100ms.sync_count),q.count);
            t.verifyEqual(height(q.rates100ms),300);
            t.verifyGreaterThan(min(q.rates100ms.sync_count),49000);
        end
        function missingBurstAndGlitchAudit(t)
            o=defaultDualTdcOptions(); v=(0:49999)'*2e-6;
            v([51,1001:1200])=[]; v=sort([v;v(300)+.1e-6]);
            q=auditSyncTimestamps(v,o.sync);
            t.verifyEqual(q.missingCandidateCount,201);
            t.verifyEqual(q.glitchCount,1); t.verifyNotEmpty(q.burstIntervals);
            t.verifyEqual(q.expectedCyclesInSpan,50000);
            t.verifyEqual(q.lookupTime(2000),.004,'AbsTol',1e-14);
        end
        function noSpdCannotResolvePeriodicAmbiguity(t)
            o=defaultDualTdcOptions(); f=(0:49999)'*2e-6;
            qf=auditSyncTimestamps(f,o.sync); qs=auditSyncTimestamps(.13+1.000025*f,o.sync);
            coarse=struct('channel1',struct('coarse',struct('status',"UNSUPPORTED")), ...
                'channel2',struct('coarse',struct('status',"UNSUPPORTED")));
            m=alignTdcBySync(qf,qs,coarse,o);
            t.verifyEqual(m.status,"UNALIGNED"); t.verifyFalse(m.integerAmbiguityResolved);
            t.verifyEqual(m.relativeClockPpm,25,'AbsTol',.01);
        end
        function knownCycleOffsetAndChannelDelay(t)
            [d,o]=scenario(.3,.3); d.Ssync=d.Ssync(54:end);
            out=analyzeDualTdc(d,o);
            t.verifyEqual(out.status,"ALIGNED",out.alignment.reason);
            t.verifyTrue(out.sync.model.integerAmbiguityResolved);
            t.verifyEqual(out.sync.model.cycleOffset,-53);
            t.verifyEqual(out.sync.model.relativeClockPpm,25,'AbsTol',.01);
            t.verifyEqual(out.sync.model.channelDelay_s,[30e-9,30.07e-9],'AbsTol',80e-12);
            t.verifyGreaterThan(out.alignment.channel1.commonCount,500);
            t.verifyEqual(out.common.F.metrics.count1,out.common.S.metrics.count1);
        end
        function earlyStopReportsExtrapolation(t)
            [d,o]=scenario(30,20); out=analyzeDualTdc(d,o);
            t.verifyEqual(out.status,"PARTIAL",out.alignment.reason);
            t.verifyEqual(out.sync.F.activeSpan_s,20,'AbsTol',3e-6);
            t.verifyNotEmpty(char(out.sync.model.extrapolationWarning));
            t.verifyLessThan(max(out.alignment.channel1.timeF_s),20);
            t.verifyTrue(isnan(applyTdcSyncMap(out.sync.model,25)));
            t.verifyGreaterThan(max(d.F1),29);
        end
        function nonlinearClockAndNonintegerJumpRejected(t)
            [d,o]=scenario(.3,.3); d.Ssync=d.Ssync+40e-9*(d.Fsync/.3).^2;
            d.S1=d.S1+40e-9*(d.F1/.3).^2; d.S2=d.S2+40e-9*(d.F2/.3).^2;
            o.sync.model="affine"; out=analyzeDualTdc(d,o);
            t.verifyEqual(out.status,"UNALIGNED"); t.verifyEmpty(out.alignment.channel1.indexF);
            sync=(0:49999)'*2e-6; sync(25001:end)=sync(25001:end)+.7e-6;
            q=auditSyncTimestamps(sync,o.sync);
            t.verifyGreaterThan(q.uncertainIntervalCount,0);
            t.verifyEqual(q.qaFlag,"CYCLE_INDEX_UNCERTAIN");
        end
        function sixFilesUseSharedDeviceOrigin(t)
            folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s'));
            files={fullfile(folder,'a.txt'),fullfile(folder,'b.txt'),fullfile(folder,'sync.txt')};
            writematrix([1e12+5000;1e12+1e6],files{1});
            writematrix([1e12+7000;1e12+1.5e6],files{2});
            writematrix([1e12;1e12+2e6;1e12+4e6],files{3});
            [times,meta]=readTdcTimestampGroup(files,1e-12,1e8);
            t.verifyEqual(times{1}(1),5e-9,'AbsTol',1e-20);
            t.verifyEqual(times{2}(1),7e-9,'AbsTol',1e-20);
            t.verifyEqual(times{3}(1),0);
            t.verifyEqual(meta.rawOrigin,1e12);
            unsupported=fullfile(folder,'sample.ttbin'); fid=fopen(unsupported,'w'); fclose(fid);
            t.verifyError(@()readTdcTimestampGroup({unsupported},1e-12,1e8),'DualTDC:SwabianTtbin');
            clear cleanup
        end
        function overlappingBarsRetainNativePeakAndProbability(t)
            out=simulateDualTdc(); fig=figure('Visible','off'); cleanup=onCleanup(@()close(fig));
            ax=axes(fig); plotted=drawDualTdcOverlay(ax,out,"full","probability");
            t.verifyEqual(sum(plotted.F_probability_or_count),1,'AbsTol',1e-12);
            t.verifyEqual(sum(plotted.S_probability_or_count),1,'AbsTol',1e-12);
            t.verifyEqual(plotted.F_count,out.F.histogram.counts(:));
            t.verifyEqual(numel(findall(ax,'Type','bar')),2);
            t.verifyEqual(numel(findobj(ax,'Type','line')),2); clear cleanup
        end
        function randomSyncLossStillUsesPhysicalCycles(t)
            [d,o]=scenario(.3,.3); rng(321);
            d.Fsync=d.Fsync(rand(size(d.Fsync))>.01);
            d.Ssync=d.Ssync(rand(size(d.Ssync))>.02);
            out=analyzeDualTdc(d,o);
            t.verifyEqual(out.status,"ALIGNED",out.alignment.reason);
            t.verifyGreaterThan(out.sync.S.missingCandidateCount,1000);
            t.verifyEqual(out.sync.model.relativeClockPpm,25,'AbsTol',.01);
            t.verifyLessThan(out.alignment.channel1.residualSigma_ps,20);
        end
        function segmentedSmoothDriftAndIntegerJump(t)
            [d,o]=scenario(.3,.3); o.sync.blockDuration_s=.025;
            d.Ssync=d.Ssync+3e-9*(d.Fsync/.3).^2;
            d.S1=d.S1+3e-9*(d.F1/.3).^2; d.S2=d.S2+3e-9*(d.F2/.3).^2;
            out=analyzeDualTdc(d,o);
            t.verifyEqual(out.status,"ALIGNED",out.alignment.reason);
            t.verifyGreaterThan(height(out.sync.model.segments),1);
            [d,o]=scenario(.3,.3);
            d.Ssync(d.Fsync>.15)=d.Ssync(d.Fsync>.15)+2e-6;
            d.S1(d.F1>.15)=d.S1(d.F1>.15)+2e-6;
            d.S2(d.F2>.15)=d.S2(d.F2>.15)+2e-6;
            out=analyzeDualTdc(d,o);
            t.verifyEqual(out.status,"UNALIGNED"); t.verifyEmpty(out.alignment.channel1.indexF);
        end
        function perSecondOwnsCrossBoundaryCoincidenceOnce(t)
            o=defaultDualTdcOptions(); o.histRange=[-1 1]*1e-9;
            a=[.2;1-2e-12;1+3e-12;1.8]; b=a+5e-12;
            d=struct('F1',a,'F2',b,'S1',a+.1,'S2',b+.1);
            out=analyzeDualTdc(d,o); rows=buildDualTdcPerSecond(out);
            t.verifyEqual(sum(rows.Nraw_count(rows.device=="F")),out.F.metrics.Nraw);
            t.verifyEqual(sum(rows.channel1_count(rows.device=="F")),4);
            t.verifyEqual(sum(rows.channel2_count(rows.device=="F")),4);
        end
        function commonPeakUsesUntransformedNativeTimes(t)
            [d,o]=scenario(.3,.3); out=analyzeDualTdc(d,o);
            c1=out.alignment.channel1; c2=out.alignment.channel2;
            lo=max(c1.overlapF_s(1),c2.overlapF_s(1)); hi=min(c1.overlapF_s(2),c2.overlapF_s(2));
            a=c1.indexF(c1.timeF_s>=lo & c1.timeF_s<=hi);
            b=c2.indexF(c2.timeF_s>=lo & c2.timeF_s<=hi);
            native=dualTdcHistogram(d.F1(a),d.F2(b),o);
            t.verifyEqual(out.common.F.histogram.counts,native.counts);
            t.verifyEqual(out.F.metrics.actualWindow_ps,70,'AbsTol',1e-9);
            t.verifyNotEmpty(char(out.F.metrics.warnings));
            t.verifyTrue(any(abs(out.F.sweep.requestedWidth_ps-10*out.F.metrics.sigma_ps)<1e-8));
            t.verifyTrue(all(min(abs([70;200;500;1000;2000]-out.F.sweep.requestedWidth_ps'),[],2)<1e-8));
        end
        function syncSettingsAndMemoryGuard(t)
            [d,o]=scenario(.3,.3); o.maxResidentBytes=4e6; o.maxPairChunk=10000;
            t.verifyError(@()analyzeDualTdc(d,o),'DualTDC:MemoryBudget');
            o=defaultDualTdcOptions(); o.sync.blockDuration_s=0;
            t.verifyError(@()validateDualTdcOptions(o),'MATLAB:expectedPositive');
        end
        function tinyFinalBlockIsMergedNotSilentlySkipped(t)
            [d,o]=scenario(.300146,.300146); o.sync.model="segmented"; o.sync.blockDuration_s=.1;
            out=analyzeDualTdc(d,o);
            t.verifyEqual(out.status,"ALIGNED",out.alignment.reason);
            t.verifyEqual(height(out.sync.model.segments),3);
            t.verifyEqual(out.sync.model.segments.endF_s(end),out.sync.model.coverageF_s(2));
            t.verifyGreaterThanOrEqual(min(out.sync.model.segments.validation_count),o.alignment.minAnchors);
        end
        function legacyOptionsWithoutSyncFieldsRemainUsable(t)
            [d,o]=scenario(.3,.3); o=rmfield(o,{'sync','computePerSecond'});
            out=analyzeDualTdc(d,o);
            t.verifyEqual(out.status,"ALIGNED"); t.verifyFalse(isfield(out,'sync'));
        end
    end
end

function [data,o]=scenario(duration,syncDuration)
rng(177); n=4000; f=sort(.001+(duration-.002)*rand(n,1));
g=f+5e-9+100e-12*randn(n,1); a=1.000025; offset=.017+7*2e-6;
sync=(0:round(syncDuration*5e5)-1)'*2e-6;
data=struct('F1',f,'F2',g,'S1',offset+a*f+30e-9+8e-12*randn(n,1), ...
    'S2',offset+a*g+30.07e-9+8e-12*randn(n,1),'Fsync',sync,'Ssync',offset+a*sync);
o=defaultDualTdcOptions(); o.sync.enabled=true; o.sync.blockDuration_s=min(1,duration/3);
end
