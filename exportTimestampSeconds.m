function [files, details] = exportTimestampSeconds(out, folder, baseName, options, progress)
%EXPORTTIMESTAMPSECONDS 对已导入的时间戳逐秒独立分析并选择性导出。
%   中间区间左闭右开，末段包含终点并按实际时长计算。逐段处理和释放结果，
%   不重新读取原文件；Bootstrap 和优化沿用本次导入的用户设置。
if nargin<5, progress=@(~,~,~)true; end
if string(out.dataMode)~="imported"
    error('CoincidenceSim:ImportedDataRequired','逐秒独立导出需要先导入时间戳。');
end
for name=["sweep","timeWindows","countRates"]
    if isfield(options,name) && options.(name)
        error('CoincidenceSim:PerSecondExportOptions','逐秒独立导出请取消扫描、预分窗和原逐秒计数率表选项。');
    end
end
duration=out.params.measurementTime;
nearest=round(duration);
if abs(duration-nearest)<=64*eps(max(1,abs(duration)))
    count=max(1,nearest);
else
    count=max(1,ceil(duration));
end
secondsFolder=fullfile(folder,baseName+"_per_second_results");
if ~isfolder(secondsFolder), mkdir(secondsFolder); end
files=strings(0,1);
params=out.params;
% 自动应用过整段推荐时，每秒仍从用户原始算法设置独立选参。
if isfield(out,'optimization') && ~isempty(out.optimization)
    params.algorithm=out.optimization.requestedAlgorithm;
end
options.perSecond=false;
nextA=1; nextB=1;
startSeconds=(0:count-1)'; stopSeconds=min((1:count)',duration);
countA=zeros(count,1); countB=countA; nRaw=countA;
outputFolders=strings(count,1);
completed=0; cancelled=false; optimizationStatus=strings(count,1);
for k=1:count
    if ~progress(k-1,count,sprintf('第 %d/%d 秒',k,count))
        cancelled=true; break
    end
    first=startSeconds(k); last=stopSeconds(k);
    [a,nextA]=takeWindow(out.A,nextA,first,last,k==count);
    [b,nextB]=takeWindow(out.B,nextB,first,last,k==count);
    p=params; p.measurementTime=last-first; p.analysis.sourceCount=NaN;
    source=out.source;
    source.secondIndex=k; source.windowStart=first; source.windowStop=last;
    if isfield(source,'rawOrigin')
        source.rawOrigin=source.rawOrigin+first/source.unitSeconds;
    end
    result=analyzeTimestampData(a,b,p,source,"imported");
    name=baseName+sprintf('_second_%04d',k);
    target=fullfile(secondsFolder,sprintf('second_%04d',k));
    currentOptions=options;
    disabledOptimization=isfield(options,'optimization') && options.optimization && isempty(result.optimization);
    if disabledOptimization, currentOptions.optimization=false; end
    if isfield(options,'batchSummary') && options.batchSummary
        exported=exportBatchResult(result,target,name,options);
    else
        exported=exportSelectedResults(result,target,name,currentOptions);
    end
    if disabledOptimization && ~(isfield(options,'batchSummary') && options.batchSummary)
        recommendation=table("manual",false,false,"disabled", ...
            "当前为手动模式，未执行自适应优化", ...
            'VariableNames',{'Mode','Valid','Applied','Status','Diagnostics'});
        file=fullfile(target,name+"_optimization_summary.csv");
        writeUtf8BomTable(recommendation,file); exported(end+1,1)=file; %#ok<AGROW>
    end
    files=[files;exported]; %#ok<AGROW>
    countA(k)=numel(a.time); countB(k)=numel(b.time); nRaw(k)=result.metrics.Nraw;
    outputFolders(k)=target;
    optimizationStatus(k)="disabled";
    if ~isempty(result.optimization), optimizationStatus(k)=result.optimization.status; end
    completed=k;
    clear result a b
end
indices=(1:completed)';
index=table(indices,startSeconds(indices),stopSeconds(indices),stopSeconds(indices)-startSeconds(indices), ...
    countA(indices),countB(indices),nRaw(indices),outputFolders(indices), ...
    'VariableNames',{'SecondIndex','Start_s','Stop_s','Duration_s','CountA','CountB','Nraw','OutputFolder'});
file=fullfile(secondsFolder,baseName+"_second_index.csv");
writeUtf8BomTable(index,file); files(end+1,1)=file;
details=struct('count',count,'completedCount',completed,'cancelled',cancelled, ...
    'optimizationStatus',strjoin(unique(optimizationStatus(indices)),";"));
end

function [segment,next]=takeWindow(events,next,first,last,isLast)
begin=next;
while next<=numel(events.time) && ...
        (events.time(next)<last || (isLast && events.time(next)<=last))
    next=next+1;
end
indices=begin:next-1;
segment=struct('time',events.time(indices)-first, ...
    'pairID',events.pairID(indices),'type',events.type(indices));
end
