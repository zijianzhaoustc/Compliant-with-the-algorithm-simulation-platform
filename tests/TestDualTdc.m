classdef TestDualTdc < matlab.unittest.TestCase
    methods(Test)
        function chunkedHistogramEqualsBruteForce(t)
            o=defaultDualTdcOptions(); o.histRange=[-2,2]*1e-9;
            o.maxPairChunk=7; rng(41);
            a=sort(rand(40,1)*10e-9); b=sort(rand(50,1)*10e-9);
            h=dualTdcHistogram(a,b,o); d=b.'-a;
            t.verifyEqual(h.counts,histcounts(d(:),h.edges));
            t.verifyLessThanOrEqual(h.maxPairScratchCount,7);
        end
        function fixedSevenBinRuleAndSignedNet(t)
            o=defaultDualTdcOptions(); o.histRange=[-1,1]*1e-9;
            a=(1:100)'*1e-6; b=a+105e-12;
            r=analyzeDualTdcDevice(a,b,o,1);
            t.verifyEqual(r.metrics.Nraw,100);
            t.verifyEqual(r.metrics.Nacc,0);
            t.verifyEqual(r.metrics.actualWindow_ps,70,'AbsTol',1e-10);
            t.verifyEqual(r.metrics.NnetSigned,r.metrics.Nraw-r.metrics.Nacc);
        end
        function existingTxtAndBinFormats(t)
            folder=tempname; mkdir(folder); clean=onCleanup(@()rmdir(folder,'s'));
            a=fullfile(folder,'a.txt'); b=fullfile(folder,'b.bin');
            values=[1e12;2e12;3e12]; writematrix(values,a);
            fid=fopen(b,'wb','ieee-be');
            writeString(fid,'SSI_DAQ_TDC_TIMESTAMP_V1'); writeString(fid,'CH2.bin');
            fwrite(fid,3,'uint32'); fwrite(fid,values+5000,'double'); fclose(fid);
            [x,y,m]=readDualTdcTimestampPair(a,b,1e-12);
            t.verifyEqual(x,[0;1;2],'AbsTol',1e-12);
            t.verifyEqual(y-x,repmat(5e-9,3,1),'AbsTol',1e-15);
            t.verifyEqual(m.formatB,"ssi-daq-bin"); clear clean
        end
        function affineAlignmentWithIndependentLossAndOffset(t)
            rng(503); f1=cumsum(-log(rand(18000,1))/2e5); f2=cumsum(-log(rand(18000,1))/2e5);
            scale=1+37e-6; keep1=rand(size(f1))>.12; keep2=rand(size(f2))>.08;
            s1=.024+scale*f1(keep1)+15e-12*randn(nnz(keep1),1);
            s2=.024+2e-9+scale*f2(keep2)+15e-12*randn(nnz(keep2),1);
            o=defaultDualTdcOptions(); a=alignDualTdcTimestamps(f1,f2,s1,s2,o.alignment);
            t.verifyEqual(a.status,"ALIGNED");
            t.verifyEqual(a.relativeClockPpm,37,'AbsTol',.01);
            t.verifyGreaterThan(a.channel1.commonCount,.99*nnz(keep1));
            original=find(keep1); t.verifyEqual(a.channel1.indexF,original(a.channel1.indexS));
            t.verifyEqual(numel(unique(a.channel1.indexS)),a.channel1.commonCount);
            t.verifyLessThan(a.channel1.residualSigma_ps,20);
        end
        function unrelatedAndPeriodicStreamsAreUnaligned(t)
            rng(507); f1=cumsum(-log(rand(6000,1))/1e5); f2=cumsum(-log(rand(6000,1))/1e5);
            s1=cumsum(-log(rand(6000,1))/1e5); s2=cumsum(-log(rand(6000,1))/1e5);
            o=defaultDualTdcOptions(); a=alignDualTdcTimestamps(f1,f2,s1,s2,o.alignment);
            t.verifyEqual(a.status,"UNALIGNED"); t.verifyEmpty(a.channel1.indexF);
            periodic=(1:6000)'*1e-6;
            a=alignDualTdcTimestamps(periodic,periodic,periodic+.1,periodic+.1,o.alignment);
            t.verifyEqual(a.status,"UNALIGNED"); t.verifyEmpty(a.channel2.indexS);
        end
        function clockDisagreementRejectsAllAssociations(t)
            rng(509); f=cumsum(-log(rand(8000,1))/1e5); g=cumsum(-log(rand(8000,1))/1e5);
            o=defaultDualTdcOptions(); a=alignDualTdcTimestamps(f,g,.1+f,.1+g*1.00002,o.alignment);
            t.verifyEqual(a.status,"UNALIGNED"); t.verifyEmpty(a.channel1.indexF);
            t.verifyTrue(isnan(a.channel1.commonCount));
        end
        function sharedSimulationAndCommonSubset(t)
            s=defaultDualTdcSimulation(); o=defaultDualTdcOptions(); out=simulateDualTdc(s,o);
            t.verifyEqual(out.status,"ALIGNED");
            t.verifyGreaterThan(out.truth.channel1.precision,.999);
            t.verifyGreaterThan(out.truth.channel2.recall,.99);
            t.verifyLessThanOrEqual(out.truth.channel1.recall,1);
            t.verifyLessThanOrEqual(out.truth.channel2.recall,1);
            t.verifyLessThanOrEqual(out.alignment.channel1.commonCount, ...
                min(out.alignment.channel1.eligibleF,out.alignment.channel1.eligibleS));
            t.verifyEqual(out.alignment.relativeClockPpm,out.truth.relativeClockPpm,'AbsTol',.01);
            t.verifyEqual(out.common.F.metrics.count1,out.common.S.metrics.count1);
            t.verifyEqual(out.common.F.metrics.count2,out.common.S.metrics.count2);
            t.verifyLessThan(out.common.F.metrics.count1,out.overlap.F.metrics.count1);
            t.verifyEqual(out.common.F.metrics.actualWindow_ps,70,'AbsTol',1e-10);
        end
        function sideWindowUsesExactlyBins14Through20(t)
            o=defaultDualTdcOptions(); o.histRange=[-1,1]*1e-9;
            a=(1:114)'*1e-6;
            b=a+[repmat(405e-12,100,1); (405+10*repelem((-20:-14)',2))*1e-12];
            r=analyzeDualTdcDevice(a,b,o,1);
            t.verifyEqual(r.metrics.Nraw,100); t.verifyEqual(r.metrics.Nacc,14);
            t.verifyEqual(r.metrics.NnetSigned,86);
            k=r.histogram.peakBin; t.verifyEqual(sum(r.histogram.counts(k-(14:20))),14);
        end
        function exportAndFourFileReimport(t)
            folder=tempname; mkdir(folder); clean=onCleanup(@()rmdir(folder,'s'));
            s=defaultDualTdcSimulation(); out=simulateDualTdc(s);
            names={'F1','F2','S1','S2'}; paths=cell(1,4);
            for k=1:4
                paths{k}=fullfile(folder,[names{k} '.txt']);
                writematrix(out.data.(names{k})*1e12,paths{k});
            end
            imported=importDualTdcFiles(paths{:},1e-12);
            t.verifyEqual(imported.status,"ALIGNED");
            t.verifyEqual(imported.F.histogram.totalPairs,out.F.histogram.totalPairs,'AbsTol',2);
            exported=exportDualTdcResults(imported,folder);
            t.verifyTrue(isfile(fullfile(exported,'F_common_histogram.csv')));
            t.verifyTrue(isfile(fullfile(exported,'S_overlap_metrics.csv')));
            metrics=readtable(fullfile(exported,'F_full_metrics.csv'));
            t.verifyEqual(metrics.Nnet_signed_count,metrics.Nraw_count-metrics.Nacc_side_count);
            t.verifyNotEqual(exportDualTdcResults(imported,folder),exported); clear clean
        end
        function unalignedExportHasNoEventMatches(t)
            rng(901); data=struct();
            for name=["F1","F2","S1","S2"], data.(name)=cumsum(-log(rand(2000,1))/1e5); end
            out=analyzeDualTdc(data); t.verifyEqual(out.status,"UNALIGNED");
            folder=tempname; mkdir(folder); clean=onCleanup(@()rmdir(folder,'s'));
            dest=exportDualTdcResults(out,folder);
            t.verifyFalse(isfile(fullfile(dest,'SPD1_event_associations.csv')));
            t.verifyFalse(isfile(fullfile(dest,'F_common_metrics.csv')));
            t.verifyTrue(isfile(fullfile(dest,'F_full_histogram.csv'))); clear clean
        end
        function gaussianFitRecoversKnownWidth(t)
            o=defaultDualTdcOptions(); o.histRange=[-2,2]*1e-9;
            n=10001; quantiles=((1:n)'-.5)/n;
            a=(1:n)'*1e-6; b=a+400e-12+50e-12*sqrt(2)*erfinv(2*quantiles-1);
            r=analyzeDualTdcDevice(a,b,o,1);
            t.verifyEqual(r.histogram.fitStatus,"GAUSSIAN");
            t.verifyEqual(r.metrics.peak_ps,400,'AbsTol',2);
            t.verifyEqual(r.metrics.sigma_ps,50,'AbsTol',2);
            t.verifyEqual(r.metrics.FWHM_ps,2*sqrt(2*log(2))*r.metrics.sigma_ps,'AbsTol',1e-10);
        end
        function signedNetCanBeNegative(t)
            o=defaultDualTdcOptions(); o.histRange=[-1,1]*1e-9;
            offsets=[repmat(405e-12,100,1);(405+10*repelem((-20:-14)',50))*1e-12];
            a=(1:numel(offsets))'*1e-6; r=analyzeDualTdcDevice(a,a+offsets,o,1);
            t.verifyEqual(r.metrics.NnetSigned,-250);
        end
        function malformedInputAndMemoryBudgetAreExplicit(t)
            o=defaultDualTdcOptions(); o.maxResidentBytes=100;
            t.verifyError(@()validateDualTdcOptions(o),'DualTDC:MemoryBudget');
            d=struct('F1',[1;0],'F2',[0;1],'S1',[0;1],'S2',[0;1]);
            t.verifyError(@()analyzeDualTdc(d),'DualTDC:Unsorted');
        end
    end
end
function writeString(fid,value)
u=uint16(value); fwrite(fid,2*numel(u),'uint32'); fwrite(fid,u,'uint16');
end
