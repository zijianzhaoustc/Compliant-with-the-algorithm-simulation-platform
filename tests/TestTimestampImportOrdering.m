classdef TestTimestampImportOrdering < matlab.unittest.TestCase
    methods(TestMethodSetup)
        function quietExpectedWarnings(t)
            state=warning('off','CoincidenceSim:TimestampReordered');
            t.addTeardown(@()warning(state));
        end
    end
    methods(Test)
        function binSortsWithinAndAcrossBlocksWithoutChangingFile(t)
            folder=temporaryFolder(t); file=fullfile(folder,'a.bin');
            writeBin(file,{[30;10;10],zeros(0,1),[5;20]}); before=readBytes(file);
            [v,m]=readSsiDaqTimestampBin(file);
            t.verifyEqual(v,[5;10;10;20;30]); t.verifyEqual(m.timestampCount,5);
            t.verifyTrue(m.timestampOrder.wasReordered);
            t.verifyEqual(m.timestampOrder.descendingAdjacentCount,2);
            t.verifyEqual(readBytes(file),before);
        end
        function orderedBinAndDuplicatesAreUnchanged(t)
            folder=temporaryFolder(t); file=fullfile(folder,'a.bin');
            writeBin(file,{[5;10;10],[20;30]});
            [v,m]=readSsiDaqTimestampBin(file);
            t.verifyEqual(v,[5;10;10;20;30]); t.verifyFalse(m.timestampOrder.wasReordered);
            t.verifyEqual(m.timestampOrder.descendingAdjacentCount,0);
        end
        function binNonfiniteIsNotSilentlyDeleted(t)
            folder=temporaryFolder(t); file=fullfile(folder,'a.bin');
            for invalid=[NaN Inf -Inf]
                writeBin(file,{[3;1],[invalid;2]});
                t.verifyError(@()readSsiDaqTimestampBin(file),'CoincidenceSim:NonfiniteTimestamps');
            end
        end
        function txtPairSortsBeforeChoosingCommonOrigin(t)
            folder=temporaryFolder(t); a=fullfile(folder,'a.txt'); b=fullfile(folder,'b.txt');
            writematrix([3e12;1e12;2e12;2e12],a); writematrix([4e12;1e12+5000;2e12],b);
            [x,y,m]=readDualTdcTimestampPair(a,b,1e-12);
            t.verifyEqual(x,[0;1;1;2]); t.verifyEqual(y,[5e-9;1;3],'AbsTol',1e-15);
            t.verifyEqual(m.origin,1e12);
            t.verifyTrue(m.timestampOrder{1}.wasReordered); t.verifyTrue(m.timestampOrder{2}.wasReordered);
        end
        function mixedSixChannelReaderSharesOriginAfterSorting(t)
            folder=temporaryFolder(t); a=fullfile(folder,'a.bin'); b=fullfile(folder,'b.txt'); sy=fullfile(folder,'sync.bin');
            writeBin(a,{[1e12+5000;1e12+2e6],[1e12+1e6]});
            writematrix([1e12+3e6;1e12+7000;1e12+2e6],b);
            writeBin(sy,{[1e12+4e6;1e12],[1e12+2e6]});
            [values,m]=readTdcTimestampGroup({a,b,sy},1e-12,1e8);
            t.verifyEqual(values{1}(1),5e-9,'AbsTol',1e-20);
            t.verifyEqual(values{2}(1),7e-9,'AbsTol',1e-20);
            t.verifyEqual(values{3},[0;2e-6;4e-6],'AbsTol',1e-20);
            t.verifyEqual(m.rawOrigin,1e12);
            t.verifyTrue(all(cellfun(@(q)q.wasReordered,m.timestampOrder)));
            q=timestampImportQuality(struct('metadata',struct('F',m)));
            t.verifyEqual(height(q),3); t.verifyEqual(q.channel,["SPD1";"SPD2";"SYNC"]);
        end
        function txtNonfiniteIsNotSilentlyDeleted(t)
            folder=temporaryFolder(t); file=fullfile(folder,'bad.txt');
            for invalid=[NaN Inf -Inf]
                writematrix([3;invalid;1],file);
                t.verifyError(@()readTdcTimestampGroup({file},1e-12,1e8),'CoincidenceSim:NonfiniteTimestamps');
                t.verifyError(@()readDualTdcTimestampPair(file,file,1e-12),'DualTDC:Text');
            end
        end
        function chunkBoundaryAndWarningAreAuditable(t)
            [v,q]=prepareImportedTimestamps([(1:100000)';-1;100001],'synthetic.txt');
            t.verifyEqual(v(1),-1); t.verifyEqual(numel(v),100002);
            t.verifyEqual(q.descendingAdjacentCount,1);
            warning('on','CoincidenceSim:TimestampReordered');
            t.verifyWarning(@()prepareImportedTimestamps([2;1],'synthetic.txt'),'CoincidenceSim:TimestampReordered');
        end
        function singleTdcBinImportAlsoAcceptsReorderedTags(t)
            folder=temporaryFolder(t); a=fullfile(folder,'a.bin'); b=fullfile(folder,'b.bin');
            writeBin(a,{[3e6;0;1e6]}); writeBin(b,{[1e6+5000;3e6+5000;5000]});
            p=defaultParams(); p.algorithm.matchMethod="all-pairs";
            out=importTimestampFiles(a,b,1,p);
            t.verifyEqual(out.A.time,[0;1e-6;3e-6],'AbsTol',1e-20);
            t.verifyEqual(out.B.time,[5e-9;1.005e-6;3.005e-6],'AbsTol',1e-20);
        end
        function fourFileAnalysisAndExportMatchSortedReference(t)
            folder=temporaryFolder(t); original=simulateDualTdc(); names={'F1','F2','S1','S2'};
            paths=cell(1,4); referencePaths=paths;
            for k=1:4
                raw=original.data.(names{k})*1e12;
                paths{k}=fullfile(folder,[names{k} '.bin']); writeBin(paths{k},{flipud(raw)});
                referencePaths{k}=fullfile(folder,[names{k} '_sorted.bin']); writeBin(referencePaths{k},{raw});
            end
            actual=importDualTdcFiles(paths{:}); expected=importDualTdcFiles(referencePaths{:});
            t.verifyEqual(actual.status,expected.status);
            t.verifyEqual(actual.F.histogram.counts,expected.F.histogram.counts);
            t.verifyEqual(actual.S.histogram.counts,expected.S.histogram.counts);
            t.verifyEqual(actual.alignment.channel1.indexF,expected.alignment.channel1.indexF);
            app=CoincidenceSimulatorApp(); t.addTeardown(@()delete(app)); app.UIFigure.Visible='off';
            app.DualTdcPanel.setResult(actual);
            t.verifySubstring(app.DualTdcPanel.StatusLabel.Text,'已自动升序重排 4 路');
            dest=exportDualTdcResults(actual,folder);
            q=readtable(fullfile(dest,'timestamp_import_quality.csv'));
            t.verifyEqual(height(q),4); t.verifyTrue(all(q.was_reordered));
            t.verifyTrue(all(contains(string(q.association_index_basis),'after ascending sort')));
        end
    end
end

function folder=temporaryFolder(t)
folder=tempname; mkdir(folder); t.addTeardown(@()rmdir(folder,'s'));
end
function writeBin(file,blocks)
fid=fopen(file,'wb','ieee-be'); cleanup=onCleanup(@()fclose(fid));
writeString(fid,'SSI_DAQ_TDC_TIMESTAMP_V1'); writeString(fid,'test.bin');
for k=1:numel(blocks), fwrite(fid,numel(blocks{k}),'uint32'); fwrite(fid,blocks{k},'double'); end
clear cleanup
end
function writeString(fid,value)
u=uint16(value); fwrite(fid,2*numel(u),'uint32'); fwrite(fid,u,'uint16');
end
function bytes=readBytes(file)
fid=fopen(file,'rb'); cleanup=onCleanup(@()fclose(fid)); bytes=fread(fid,Inf,'*uint8'); clear cleanup
end
