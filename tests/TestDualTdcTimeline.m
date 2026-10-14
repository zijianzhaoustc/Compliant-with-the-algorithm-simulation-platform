classdef TestDualTdcTimeline < matlab.unittest.TestCase
    methods(Test)
        function symmetricTailQuarantinePreservesCacheAndRates(t)
            [data,o]=fixture();
            for device=["F","S"]
                d=data; key=device+"1"; d.(key)=[d.(key);60;501;2169];
                out=analyzeDualTdc(d,o); m=out.(device).metrics;
                t.verifyEqual(out.data,d);
                t.verifyEqual(m.originalCount1,4003); t.verifyEqual(m.count1,4000);
                t.verifyEqual(m.quarantinedCount1,3); t.verifyEqual(m.originalSpan_s,2169-d.(device+"1")(1),'AbsTol',1e-12);
                t.verifyLessThan(m.duration_s,31); t.verifyGreaterThan(m.rate1_cps,130);
                t.verifyEqual(m.rate1_cps,m.count1/m.duration_s);
                t.verifyEqual(height(out.timelineQuality.excludedRanges),1);
                t.verifyEqual(out.timelineQuality.excludedRanges.first_sorted_index,4001);
                t.verifyEqual(out.timelineQuality.excludedRanges.last_sorted_index,4003);
                t.verifyEqual(out.timelineQuality.excludedRanges.excluded_count,3);
                again=recalculateDualTdc(out,o);
                t.verifyEqual(again.timelineQuality.channels,out.timelineQuality.channels);
                t.verifyEqual(again.data,d);
            end
        end
        function syncTailDoesNotInflateDuration(t)
            [data,o]=fixture(); data.Fsync=[(0:2e-6:29.999998)';30.031200768];
            data.Ssync=(0:2e-6:29.999998)';
            [clean,q]=auditDualTdcTimeline(data,o);
            t.verifyEqual(q.Fsync.quarantinedCount,1);
            t.verifyLessThan(q.F.duration_s,30.001);
            t.verifyEqual(clean.Fsync(end),29.999998,'AbsTol',1e-12);
            row=q.excludedRanges.channel=="Fsync";
            t.verifyEqual(q.excludedRanges.first_timestamp_s(row),30.031200768);
        end
        function declaredDurationClipsSpdAndSync(t)
            [data,o]=fixture(); o.sync.declaredAcquisition_s=1;
            data.Fsync=(0:2e-6:20)'; data.Ssync=data.Fsync;
            [clean,q]=auditDualTdcTimeline(data,o);
            t.verifyLessThanOrEqual(clean.F1(end)-q.F.origin_s,1);
            t.verifyLessThanOrEqual(clean.S1(end)-q.S.origin_s,1);
            t.verifyEqual(clean.Fsync(end),1);
            t.verifyEqual(q.F.duration_s,1);
            t.verifyGreaterThan(q.F1.quarantinedCount,0);
            o.sync.declaredAcquisition_s=30;
            [clean,q]=auditDualTdcTimeline(data,o);
            t.verifyEqual(clean.F1,data.F1); t.verifyEqual(clean.Fsync,data.Fsync);
            t.verifyGreaterThan(q.F.duration_s,29.9); % early SYNC does not crop SPD
        end
        function noPeerCorroborationOrStrictRejection(t)
            [data,o]=fixture(); data.F1=[data.F1;35;2169];
            data.F2=[data.F2;40;2169];
            o.timelineMode="strict"; % obsolete cached option must not reactivate old policy
            r=analyzeDualTdc(data,o);
            t.verifyEqual(r.F.metrics.quarantinedCount1,2);
            t.verifyEqual(r.F.metrics.quarantinedCount2,2);
            t.verifyFalse(isfield(defaultDualTdcOptions(),'timelineMode'));
        end
        function recordsBelowCutoffAreNotAutomaticallyRemoved(t)
            [data,o]=fixture(); data.F1=[-200;-100;data.F1];
            o.sync.declaredAcquisition_s=3000;
            out=analyzeDualTdc(data,o);
            t.verifyEqual(out.timelineQuality.F1.firstIndex,1);
            t.verifyEqual(out.F.metrics.quarantinedCount1,0);
            t.verifyEqual(out.status,"ALIGNED");
            c=out.alignment.channel1;
            t.verifyEqual(c.timeF_s,out.data.F1(c.indexF));
            t.verifyGreaterThanOrEqual(min(c.indexF),3);
            t.verifyEqual(out.data,data);
        end
        function exportAndGuiExposeDifferentCountDefinitions(t)
            [data,o]=fixture(); data.F1=[data.F1;2169]; out=analyzeDualTdc(data,o);
            parent=tempname; mkdir(parent); clean=onCleanup(@()rmdir(parent,'s'));
            dest=exportDualTdcResults(out,parent);
            m=readtable(fullfile(dest,'F_full_metrics.csv'));
            t.verifyEqual(m.channel1_original_count,4001); t.verifyEqual(m.channel1_count,4000);
            t.verifyEqual(m.channel1_quarantined_count,1);
            q=readtable(fullfile(dest,'timestamp_quarantine.csv')); t.verifyEqual(height(q),1);
            app=CoincidenceSimulatorApp(); appClean=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            app.DualTdcPanel.setResult(out); rows=app.DualTdcPanel.MetricsTable.Data;
            t.verifyTrue(any(string(rows(:,1))=="计数率所用时长"));
            t.verifySubstring(app.DualTdcPanel.StatusLabel.Text,'排除 1 条');
            t.verifyFalse(isfield(app.DualTdcPanel.Controls,'TimelineMode'));
            app.DualTdcPanel.Controls.Acquisition.Value=3000;
            expanded=app.DualTdcPanel.recalculateCurrent();
            t.verifyEqual(expanded.F.metrics.count1,4001);
            app.DualTdcPanel.Controls.Acquisition.Value=30;
            reduced=app.DualTdcPanel.recalculateCurrent();
            t.verifyEqual(reduced.F.metrics.count1,4000);
            t.verifyEqual(app.DualTdcPanel.CachedResult.data,data);
            clear appClean clean
        end
        function largeRangeGuardPrecedesAllocation(t)
            o=defaultDualTdcOptions();
            t.verifyError(@()auditSyncTimestamps([0;1;1e100],o.sync),'DualTDC:TimelineRange');
        end
        function perSecondUsesAcceptedDomainEvenWhenCalledAgain(t)
            [data,o]=fixture();
            for name=["F1","F2","S1","S2"], data.(name)=data.(name)/1000; end
            data.F1=[data.F1;2169]; o.computePerSecond=true;
            out=analyzeDualTdc(data,o);
            t.verifyEqual(height(out.perSecond),2);
            t.verifyEqual(out.perSecond.channel1_count,[4000;4000]);
            t.verifyEqual(buildDualTdcPerSecond(out),out.perSecond);
            data.Fsync=(0:2e-6:.03)'; data.Ssync=data.Fsync+.017/1000;
            o.sync.enabled=true;
            syncOut=analyzeDualTdcSync(data,o);
            t.verifyEqual(syncOut.F.metrics.quarantinedCount1,1);
            t.verifyEqual(syncOut.data,data);
            t.verifyEqual(height(syncOut.perSecond),2);
            t.verifyEqual(syncOut.status,"ALIGNED");
            parent=tempname; mkdir(parent); clean=onCleanup(@()rmdir(parent,'s'));
            exportDualTdcSync(syncOut,parent);
            exported=readtable(fullfile(parent,'sync_alignment.csv'));
            t.verifyGreaterThan(exported.SPD_span_covered_fraction,.99);
            clear clean
        end
        function rawCoincidencesAreNotFileRecordCounts(t)
            o=defaultDualTdcOptions(); o.accidental.method="none";
            a=(1:4000)'*1e-6;
            d=struct('F1',a(1:3000),'F2',a(1:3000)+405e-12, ...
                'S1',a,'S2',a+[repmat(405e-12,2000,1);repmat(1005e-12,2000,1)]);
            r=analyzeDualTdc(d,o);
            t.verifyLessThan(r.F.metrics.originalCount1,r.S.metrics.originalCount1);
            t.verifyGreaterThan(r.F.metrics.Nraw,r.S.metrics.Nraw);
            t.verifyEqual(r.F.metrics.Nraw,3000); t.verifyEqual(r.S.metrics.Nraw,2000);
        end
        function validDuplicatesZeroAndSparseSmallFilesRemain(t)
            o=defaultDualTdcOptions(); d=struct('F1',[0;0;2000],'F2',[0;1;2000], ...
                'S1',[0;0;2000],'S2',[0;1;2000]);
            o.sync.declaredAcquisition_s=5000;
            [clean,q]=auditDualTdcTimeline(d,o); t.verifyEqual(clean,d); t.verifyEmpty(q.quarantine);
            t.verifyClass(q.quarantine.device,'string');
            d.F1=ones(4000,1); d.F2=(1:4000)'; d.S1=d.F1; d.S2=d.F2;
            [clean,q]=auditDualTdcTimeline(d,o); t.verifyEqual(clean,d); t.verifyEmpty(q.quarantine);
        end
        function equalityAndGlobalImportOrdering(t)
            o=defaultDualTdcOptions(); o.sync.declaredAcquisition_s=2;
            folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s'));
            p=fullfile(folder,'unsorted.txt'); writematrix([3000001;0;2000000;1000000;2000000]*1e6,p);
            [a,b,meta]=readDualTdcTimestampPair(p,p,1e-12);
            data=struct('F1',a,'F2',b,'S1',a,'S2',b,'metadata',struct('F',meta,'S',meta));
            [clean,q]=auditDualTdcTimeline(data,o);
            t.verifyEqual(clean.F1,[0;1;2;2],'AbsTol',1e-12);
            t.verifyTrue(meta.timestampOrder{1}.wasReordered);
            t.verifyEqual(q.F1.quarantinedCount,1);
            t.verifyEqual(q.excludedRanges.first_sorted_index,repmat(5,4,1));
            clear cleanup
        end
        function largeExclusionsUseBoundedRangesAndEmptyIsExplicit(t)
            o=defaultDualTdcOptions(); o.sync.declaredAcquisition_s=.001;
            a=(0:1000000)'*.001; d=struct('F1',a,'F2',a,'S1',a,'S2',a);
            [clean,q]=auditDualTdcTimeline(d,o);
            t.verifyEqual(numel(clean.F1),2);
            t.verifyEqual(height(q.excludedRanges),4);
            t.verifyEqual(q.F1.quarantinedCount,999999);
            d.F1=[2;3]; d.F2=[2;3]; d.Fsync=[0;1];
            t.verifyError(@()analyzeDualTdc(d,o),'DualTDC:EmptyAfterDurationFilter');
        end
    end
end

function [data,o]=fixture()
rng(710); f=sort(rand(4000,1)*29.999); g=f+500e-12;
data=struct('F1',f,'F2',g,'S1',.017+f,'S2',.017+g);
o=defaultDualTdcOptions(); o.binWidth=100e-12; o.histRange=[-20 20]*1e-9;
o.accidental.method="none"; o.computePerSecond=false;
end
