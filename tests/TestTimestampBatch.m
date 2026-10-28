classdef TestTimestampBatch < matlab.unittest.TestCase
    methods (Test)
        function batchSecondsSplitEveryPairAndHonorSelectedOutputs(t)
            root=string(tempname); mkdir(root); cleanup=onCleanup(@()rmdir(root,'s'));
            input=fullfile(root,'input'); mkdir(input); mkdir(fullfile(input,'nested'));
            values=[0;.2;(1:10)']*1e12;
            writeBin(fullfile(input,'alpha_CH1.bin'),"CH1.bin",values);
            writeBin(fullfile(input,'alpha_CH2.bin'),"CH2.bin",values);
            values=[0;.2;1;1.2;2;2.4]*1e12;
            writeBin(fullfile(input,'nested','beta_CH1.bin'),"CH1.bin",values);
            writeBin(fullfile(input,'nested','beta_CH2.bin'),"CH2.bin",values);
            p=parameters(); p.optimization.mode="manual";
            options=struct('perSecond',true,'histogram',true,'results',false,'uncertainty',false,'optimization',false);
            report=batchAnalyzeTimestampFolder(input,fullfile(root,'output'),1,p,@(~,~,~)true,options);
            t.verifyEqual(report.successCount,2); t.verifyEqual(report.log.SecondCount,[10;3]);
            t.verifyEqual(report.log.CompletedSeconds,[10;3]);
            t.verifyEqual(report.log.ExportedFiles,[11;4]);
            t.verifyTrue(all(report.log.AnalysisMode=="per-second"));
            index=readtable(fullfile(report.log.OutputFolder(1),'alpha_per_second_results','alpha_second_index.csv'));
            t.verifyEqual(index.Nraw,[2;ones(8,1);2]);
            folder=index.OutputFolder{1};
            t.verifyEqual(numel(dir(fullfile(folder,'*.csv'))),1);
            t.verifyFalse(isfile(fullfile(report.log.OutputFolder(1),'alpha_histogram.csv')));
            snapshot=load(fullfile(report.outputFolder,'batch_settings.mat'));
            t.verifyTrue(snapshot.exportOptions.perSecond);
            t.verifyFalse(snapshot.exportOptions.results);
            clear cleanup
        end

        function batchSecondsExportFourSummariesAndFullParameterList(t)
            root=string(tempname); mkdir(root); cleanup=onCleanup(@()rmdir(root,'s'));
            input=fullfile(root,'input'); mkdir(input);
            a=fullfile(input,'run_CH1.bin'); b=fullfile(input,'run_CH2.bin');
            values=[0;.2;1;1.2;2;2.4]*1e12;
            writeBin(a,"CH1.bin",values); writeBin(b,"CH2.bin",values);
            p=parameters();
            raw=importTimestampFiles(a,b,1,p,false);
            t.verifyFalse(isfield(raw,'matches')); t.verifyFalse(isfield(raw,'metrics'));
            t.verifyEqual(raw.params.measurementTime,2.4,'AbsTol',1e-12);
            report=batchAnalyzeTimestampFolder(input,fullfile(root,'output'),1,p,@(~,~,~)true,struct('perSecond',true));
            t.verifyEqual(report.successCount,1); t.verifyEqual(report.log.ExportedFiles,13);
            folder=fullfile(report.log.OutputFolder(1),'run_per_second_results','second_0003');
            t.verifyEqual(numel(dir(fullfile(folder,'*.csv'))),4);
            u=readtable(fullfile(folder,'run_second_0003_uncertainty_summary.csv'),'TextType','string');
            t.verifyEqual(u.Estimate(u.Metric=="RA"),5,'AbsTol',1e-10);
            summary=readtable(fullfile(folder,'run_second_0003_results.csv'), ...
                'VariableNamingRule','preserve','TextType','string');
            row=summary.('参数')=="params.measurementTime";
            t.verifyEqual(str2double(string(summary.('数值')(row))),.4,'AbsTol',1e-12);
            o=readtable(fullfile(folder,'run_second_0003_optimization_summary.csv'),'TextType','string');
            t.verifyEqual(o.Mode,"recommend");
            % 整段模式也使用同一组选项，未勾选的两类文件不生成。
            options=struct('histogram',false,'results',false);
            whole=batchAnalyzeTimestampFolder(input,fullfile(root,'output'),1,p,@(~,~,~)true,options);
            t.verifyEqual(whole.successCount,1);
            t.verifyEqual(numel(dir(fullfile(whole.log.OutputFolder(1),'*.csv'))),2);
            clear cleanup
        end

        function batchCancellationBetweenSecondsKeepsCompletedOutputs(t)
            root=string(tempname); mkdir(root); cleanup=onCleanup(@()rmdir(root,'s'));
            input=fullfile(root,'input'); mkdir(input);
            values=(0:.5:10)'*1e12;
            for prefix=["a","b"]
                writeBin(fullfile(input,prefix+"_CH1.bin"),"CH1.bin",values);
                writeBin(fullfile(input,prefix+"_CH2.bin"),"CH2.bin",values);
            end
            p=parameters(); p.optimization.mode="manual";
            options=struct('perSecond',true,'results',false,'uncertainty',false,'optimization',false);
            report=batchAnalyzeTimestampFolder(input,fullfile(root,'output'),1,p,@(completed,~,~)completed<.2,options);
            t.verifyTrue(report.cancelled);
            t.verifyEqual(report.log.Status,["cancelled";"cancelled"]);
            t.verifyEqual(report.log.CompletedSeconds,[2;0]);
            index=readtable(fullfile(report.log.OutputFolder(1),'a_per_second_results','a_second_index.csv'));
            t.verifyEqual(height(index),2); t.verifyEqual(index.Nraw,[2;2]);
            t.verifyTrue(isfile(fullfile(index.OutputFolder{2},'a_second_0002_histogram.csv')));
            clear cleanup
        end

        function binRepairPreservesFiniteDuplicatesAndSourceBytes(t)
            root=string(tempname); mkdir(root);
            cleanup=onCleanup(@()rmdir(root,'s'));
            path=fullfile(root,'dirty_CH1.bin');
            writeBlocks(path,"CH1.bin",{[7e10;NaN;4e10;4e10;Inf],[],[-Inf;1e10;9e10]});
            before=readBytes(path);
            [values,metadata]=readSsiDaqTimestampBin(path);
            t.verifyEqual(values,[1;4;4;7;9]*1e10);
            t.verifyEqual(metadata.originalTimestampCount,8);
            t.verifyEqual(metadata.timestampCount,5);
            t.verifyEqual(metadata.removedNonfiniteCount,3);
            t.verifyTrue(metadata.wasSorted);
            t.verifyEqual(readBytes(path),before);
            % 各块内部有序、块间乱序也必须进行完整排序。
            writeBlocks(path,"CH1.bin",{[5;6],[],[1;2]});
            [values,metadata]=readSsiDaqTimestampBin(path);
            t.verifyEqual(values,[1;2;5;6]); t.verifyTrue(metadata.wasSorted);
            t.verifyEqual(metadata.removedNonfiniteCount,0);
            clear cleanup
        end

        function cleanedTxtAndBinMatchReferenceAnalysisAndBatchExports(t)
            root=string(tempname); mkdir(root);
            cleanup=onCleanup(@()rmdir(root,'s'));
            input=fullfile(root,'input'); mkdir(input);
            a=[2e12;NaN;0;1e12;1e12;Inf;3e12];
            b=[3e12+5000;1e12+5000;-Inf;0+5000;2e12+5000;1e12+5000];
            writeBin(fullfile(input,'bin_CH1.bin'),"CH1.bin",a);
            writeBin(fullfile(input,'bin_CH2.bin'),"CH2.bin",b);
            writematrix(a,fullfile(input,'text_CH1.txt'));
            writematrix(b,fullfile(input,'text_CH2.txt'));
            writematrix([0;1;1;2;3]*1e12,fullfile(root,'clean_CH1.txt'));
            writematrix([0;1;1;2;3]*1e12+5000,fullfile(root,'clean_CH2.txt'));
            p=parameters(); p.optimization.mode="manual";
            reference=importTimestampFiles(fullfile(root,'clean_CH1.txt'), ...
                fullfile(root,'clean_CH2.txt'),1e-12,p);
            for prefix=["bin","text"]
                extension=".txt"; if prefix=="bin", extension=".bin"; end
                out=importTimestampFiles(fullfile(input,prefix+"_CH1"+extension), ...
                    fullfile(input,prefix+"_CH2"+extension),1e-12,p);
                t.verifyEqual(out.A,reference.A); t.verifyEqual(out.B,reference.B);
                t.verifyEqual(out.hist,reference.hist); t.verifyEqual(out.metrics,reference.metrics);
                t.verifyEqual(out.uncertainty.summary,reference.uncertainty.summary);
                t.verifyEqual(out.source.startCleanup.removedNonfiniteCount,2);
                t.verifyEqual(out.source.stopCleanup.removedNonfiniteCount,1);
                t.verifyTrue(out.source.startCleanup.wasSorted && out.source.stopCleanup.wasSorted);
            end
            report=batchAnalyzeTimestampFolder(input,fullfile(root,'exports'),1e-12,p);
            t.verifyEqual(report.successCount,2); t.verifyEqual(report.failedCount,0);
            t.verifyEqual(report.log.StartRemovedNonfinite,[2;2]);
            t.verifyEqual(report.log.StopRemovedNonfinite,[1;1]);
            t.verifyTrue(all(report.log.StartSorted & report.log.StopSorted));
            for k=1:2
                h=readtable(fullfile(report.log.OutputFolder(k),report.log.BaseName(k)+"_histogram.csv"));
                t.verifyEqual(h.Counts,reference.hist.counts(:));
            end
            clear cleanup
        end

        function sortedInputsAvoidSortingAndAllNonfiniteInputsStillFail(t)
            root=string(tempname); mkdir(root);
            cleanup=onCleanup(@()rmdir(root,'s'));
            path=fullfile(root,'test_CH1.bin');
            writeBlocks(path,"CH1.bin",{[0;1;1;NaN],[],[2;Inf;3]});
            [values,metadata]=readSsiDaqTimestampBin(path);
            t.verifyEqual(values,[0;1;1;2;3]); t.verifyFalse(metadata.wasSorted);
            writeBin(path,"CH1.bin",[NaN;Inf;-Inf]);
            t.verifyError(@()readSsiDaqTimestampBin(path),'CoincidenceSim:EmptyTimestampFile');
            writeBin(path,"CH1.bin",[0;1e12]);
            stop=fullfile(root,'test_CH2.txt'); writematrix([NaN;Inf;-Inf],stop);
            t.verifyError(@()importTimestampFiles(path,stop,1e-12,parameters()), ...
                'CoincidenceSim:EmptyTimestampFile');
            % 内容清洗不应掩盖文件结构损坏或不完整的数据块。
            fid=fopen(path,'ab','ieee-be'); fwrite(fid,2,'uint32'); fwrite(fid,1,'double'); fclose(fid);
            t.verifyError(@()readSsiDaqTimestampBin(path),'CoincidenceSim:TruncatedBinaryTimestamp');
            clear cleanup
        end

        function pairingKeepsDirectoriesAndDevicePrefixesSeparate(t)
            root=string(tempname); mkdir(root);
            cleanup=onCleanup(@()rmdir(root,'s'));
            mkdir(fullfile(root,'nested')); mkdir(fullfile(root,'export'));
            names=["run_CH1.bin","run_CH2.bin", ...
                "dual_tdc_run_swabian_CH1.bin","dual_tdc_run_swabian_CH2.bin", ...
                "missing_CH1.bin","duplicate_CH1.bin","duplicate_CH1.txt","duplicate_CH2.bin"];
            for name=names, touch(fullfile(root,name)); end
            touch(fullfile(root,'nested','run_StartCh.txt'));
            touch(fullfile(root,'nested','run_StopCh.txt'));
            touch(fullfile(root,'export','old_CH1.txt'));
            touch(fullfile(root,'export','old_CH2.txt'));
            [pairs,skipped]=discoverTimestampPairs(root,fullfile(root,'export'));
            t.verifyEqual(height(pairs),3);
            t.verifyEqual(height(skipped),4);
            t.verifyEqual(nnz(pairs.RelativeFolder=="nested"),1);
            swabian=contains(pairs.StartFile,'swabian');
            t.verifyEqual(nnz(swabian),1);
            t.verifyTrue(all(contains(pairs.StopFile(swabian),'swabian')));
            t.verifyFalse(any(contains(pairs.StartFile,fullfile(root,'export'))));
            clear cleanup
        end

        function exportsAgreeWithSingleImportAndKeepRequestedParameters(t)
            root=string(tempname); mkdir(root);
            cleanup=onCleanup(@()rmdir(root,'s'));
            input=fullfile(root,'input'); output=fullfile(input,'exports'); mkdir(input);
            [startFile,stopFile]=writePair(input,"run");
            p=parameters();
            single=importTimestampFiles(startFile,stopFile,1,p);
            report=batchAnalyzeTimestampFolder(input,output,1,p);
            t.verifyEqual(report.successCount,1); t.verifyEqual(report.failedCount,0);
            folder=report.log.OutputFolder(1);
            t.verifyEqual(numel(dir(fullfile(folder,'*.csv'))),4);
            h=readtable(fullfile(folder,'run_histogram.csv'));
            t.verifyEqual(h.Counts,single.hist.counts(:));
            t.verifyEqual(h.TimeDifference,single.hist.centers(:)/1e-12,'AbsTol',1e-10);
            u=readtable(fullfile(folder,'run_uncertainty_summary.csv'),'TextType','string');
            t.verifyEqual(u.Estimate,single.uncertainty.summary.Estimate,'AbsTol',1e-10);
            t.verifyEqual(u.U_Bootstrap,single.uncertainty.summary.U_Bootstrap,'AbsTol',1e-10);
            o=readtable(fullfile(folder,'run_optimization_summary.csv'),'TextType','string');
            t.verifyEqual(o.Status,single.optimization.status);
            t.verifyEqual(o.Mode,"recommend");
            summary=readtable(fullfile(folder,'run_results.csv'), ...
                'VariableNamingRule','preserve','TextType','string');
            row=summary.('参数')=="params.algorithm.binWidth";
            t.verifyEqual(str2double(string(summary.('数值')(row))),p.algorithm.binWidth);
            snapshot=load(fullfile(report.outputFolder,'batch_settings.mat'));
            t.verifyEqual(snapshot.params,p);
            % 重复运行须隔离结果，且不得把导出目录当成新输入。
            again=batchAnalyzeTimestampFolder(input,output,1,p);
            t.verifyEqual(again.successCount,1);
            t.verifyNotEqual(again.outputFolder,report.outputFolder);
            clear cleanup
        end

        function corruptPairDoesNotStopLaterPairsAndManualModeIsExplicit(t)
            root=string(tempname); mkdir(root);
            cleanup=onCleanup(@()rmdir(root,'s'));
            input=fullfile(root,'input'); mkdir(input);
            touch(fullfile(input,'a_bad_CH1.bin')); touch(fullfile(input,'a_bad_CH2.bin'));
            writePair(input,"z_good");
            p=parameters(); p.optimization.mode="manual";
            % 导出目录可以是输入目录的父目录，不应把全部输入排除。
            report=batchAnalyzeTimestampFolder(input,root,1,p);
            t.verifyEqual(report.log.Status,["failed";"success"]);
            t.verifyNotEmpty(char(report.log.Message(1)));
            o=readtable(fullfile(report.log.OutputFolder(2),'z_good_optimization_summary.csv'), ...
                'TextType','string');
            t.verifyEqual(o.Status,"disabled"); t.verifyFalse(logical(o.Applied));
            t.verifyTrue(isfile(fullfile(report.outputFolder,'batch_log.csv')));
            clear cleanup
        end

        function cancellationKeepsFinishedExportsAndMarksRemainingPairs(t)
            root=string(tempname); mkdir(root);
            cleanup=onCleanup(@()rmdir(root,'s'));
            input=fullfile(root,'input'); mkdir(input);
            writePair(input,"a"); writePair(input,"b");
            p=parameters(); p.optimization.mode="manual";
            report=batchAnalyzeTimestampFolder(input,fullfile(root,'output'),1,p, ...
                @(completed,~,~)completed<1);
            t.verifyTrue(report.cancelled);
            t.verifyEqual(report.log.Status,["success";"cancelled"]);
            log=readtable(fullfile(report.outputFolder,'batch_log.csv'),'TextType','string');
            t.verifyEqual(log.Status,report.log.Status);
            t.verifyTrue(isfile(fullfile(report.log.OutputFolder(1),'a_histogram.csv')));
            clear cleanup
        end
    end
end

function p=parameters()
p=defaultParams();
p.algorithm.binWidth=80e-12; p.algorithm.window=.8e-9;
p.algorithm.accidentalMethod="side-window";
p.uncertainty.resamples=20; p.optimization.candidateResamples=10;
end

function [a,b]=writePair(folder,prefix)
a=fullfile(folder,prefix+"_CH1.bin"); b=fullfile(folder,prefix+"_CH2.bin");
values=(0:100)'*1e10;
writeBin(a,"CH1.bin",values);
writeBin(b,"CH2.bin",values+5000);
end

function writeBin(path,channel,values)
writeBlocks(path,channel,{values});
end

function writeBlocks(path,channel,blocks)
fid=fopen(path,'wb','ieee-be'); cleanup=onCleanup(@()fclose(fid));
for text=["SSI_DAQ_TDC_TIMESTAMP_V1",channel]
    codes=uint16(char(text)); fwrite(fid,2*numel(codes),'uint32'); fwrite(fid,codes,'uint16');
end
for k=1:numel(blocks)
    values=blocks{k};
    fwrite(fid,numel(values),'uint32'); fwrite(fid,values,'double');
end
clear cleanup
end

function bytes=readBytes(path)
fid=fopen(path,'rb'); cleanup=onCleanup(@()fclose(fid));
bytes=fread(fid,Inf,'uint8=>uint8');
clear cleanup
end

function touch(path)
fid=fopen(path,'w'); fclose(fid);
end
