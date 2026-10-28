function report = batchAnalyzeTimestampFolder(inputFolder, outputFolder, unitSeconds, p, progress, exportOptions)
%BATCHANALYZETIMESTAMPFOLDER 按同一参数快照逐对分析并导出四类 CSV。
%   PROGRESS(completed,total,message) 返回 true 时继续，false 时在组间取消。
%   每批生成独立目录，保留输入子目录；错误与未配对文件写入清单。
if nargin<5, progress=@(~,~,~)true; end
if nargin<6, exportOptions=struct(); end
defaults=struct('perSecond',false,'histogram',true,'results',true, ...
    'uncertainty',true,'optimization',true,'unitSeconds',1e-12);
for name=string(fieldnames(defaults))'
    if ~isfield(exportOptions,name), exportOptions.(name)=defaults.(name); end
end
for name=["perSecond","histogram","results","uncertainty","optimization"]
    value=exportOptions.(name);
    if ~(islogical(value) || isnumeric(value)) || ~isscalar(value) || ~ismember(value,[0 1])
        error('CoincidenceSim:InvalidBatchExport','导出选项 %s 必须为逻辑标量。',name);
    end
end
if ~any([exportOptions.histogram exportOptions.results exportOptions.uncertainty exportOptions.optimization])
    error('CoincidenceSim:NoBatchExports','至少选择一种批处理导出内容。');
end
validateattributes(exportOptions.unitSeconds,{'numeric'},{'scalar','real','finite','positive'});
exportOptions.batchSummary=true;
p=validateParams(p);
validateattributes(unitSeconds,{'numeric'},{'scalar','real','finite','positive'});
inputFolder=string(char(java.io.File(char(inputFolder)).getCanonicalPath()));
outputFolder=string(char(java.io.File(char(outputFolder)).getCanonicalPath()));
% 扫描先于创建输出，且排除输入目录内已有的导出目录。
excluded="";
if startsWith(lower(outputFolder),lower(inputFolder+filesep)), excluded=outputFolder; end
[pairs,skipped]=discoverTimestampPairs(inputFolder,excluded);
if isempty(pairs)
    error('CoincidenceSim:NoTimestampPairs','未找到可唯一配对的 CH1/CH2 或 StartCh/StopCh TXT/BIN。');
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
name="batch_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
runFolder=fullfile(outputFolder,name); suffix=0;
while isfolder(runFolder)
    suffix=suffix+1; runFolder=fullfile(outputFolder,name+"_"+suffix);
end
mkdir(runFolder);
params=p;
save(fullfile(runFolder,'batch_settings.mat'),'params','unitSeconds','inputFolder','exportOptions');
writeUtf8BomTable(skipped,fullfile(runFolder,'batch_skipped.csv'));
log=pairs;
log.Status=repmat("pending",height(log),1);
log.Message=strings(height(log),1);
log.OutputFolder=strings(height(log),1);
log.OptimizationStatus=strings(height(log),1);
log.StartRemovedNonfinite=nan(height(log),1); log.StopRemovedNonfinite=nan(height(log),1);
log.StartSorted=false(height(log),1); log.StopSorted=false(height(log),1);
mode="whole"; if exportOptions.perSecond, mode="per-second"; end
log.AnalysisMode=repmat(mode,height(log),1);
log.SecondCount=zeros(height(log),1); log.CompletedSeconds=zeros(height(log),1);
log.ExportedFiles=zeros(height(log),1);
logFile=fullfile(runFolder,'batch_log.csv');
writeUtf8BomTable(log,logFile);
cancelled=false;
for k=1:height(pairs)
    message=sprintf('第 %d/%d 组：%s',k,height(pairs),pairs.BaseName(k));
    if ~progress(k-1,height(pairs),message)
        cancelled=true; break
    end
    folder=fullfile(runFolder,pairs.RelativeFolder(k),sprintf('%04d_%s',k,pairs.BaseName(k)));
    log.OutputFolder(k)=folder;
    try
        out=importTimestampFiles(pairs.StartFile(k),pairs.StopFile(k),unitSeconds,p,~exportOptions.perSecond);
        log.StartRemovedNonfinite(k)=out.source.startCleanup.removedNonfiniteCount;
        log.StopRemovedNonfinite(k)=out.source.stopCleanup.removedNonfiniteCount;
        log.StartSorted(k)=out.source.startCleanup.wasSorted;
        log.StopSorted(k)=out.source.stopCleanup.wasSorted;
        if exportOptions.perSecond
            callback=@(completed,total,note)progress(k-1+completed/max(1,total),height(pairs),message+"；"+note);
            [files,details]=exportTimestampSeconds(out,folder,pairs.BaseName(k),exportOptions,callback);
            log.SecondCount(k)=details.count; log.CompletedSeconds(k)=details.completedCount;
            log.OptimizationStatus(k)=details.optimizationStatus;
            cancelled=details.cancelled;
        else
            files=exportBatchResult(out,folder,pairs.BaseName(k),exportOptions);
            log.OptimizationStatus(k)="disabled";
            if ~isempty(out.optimization), log.OptimizationStatus(k)=out.optimization.status; end
        end
        log.ExportedFiles(k)=numel(files);
        log.Status(k)="success";
        if cancelled, log.Status(k)="cancelled"; end
    catch ME
        log.Status(k)="failed";
        log.Message(k)=string(ME.identifier)+": "+string(ME.message);
    end
    clear out
    writeUtf8BomTable(log,logFile);
    if cancelled, break; end
end
if cancelled
    log.Status(log.Status=="pending")="cancelled";
    writeUtf8BomTable(log,logFile);
end
report=struct('outputFolder',runFolder,'log',log,'skipped',skipped, ...
    'successCount',nnz(log.Status=="success"),'failedCount',nnz(log.Status=="failed"), ...
    'cancelled',cancelled);
end
