function report = runRandomSeedSweep(p, spec, folder, baseName, options, progress)
%RUNRANDOMSEEDSWEEP 固定参数快照，仅改变 p.seed，逐次完整仿真并选择性导出。
%   SPEC.start/step/count 指定等差种子序列；导出选项与 exportSelectedResults 相同。
if nargin<6, progress=@(~,~,~)true; end
seeds=buildSeedSequence(spec.start,spec.step,spec.count);
p=validateParams(p);
names=["settings","histogram","results","sweep","timeWindows","countRates", ...
    "uncertainty","timestamps","optimization"];
for name=names
    if ~isfield(options,name), options.(name)=false; end
end
if ~any(cellfun(@(name)logical(options.(name)),cellstr(names)))
    error('CoincidenceSim:NoSeedSweepExports','至少选择一种导出内容。');
end
if ~isfield(options,'unitSeconds'), options.unitSeconds=1e-12; end
validateattributes(options.unitSeconds,{'numeric'},{'scalar','real','finite','positive'});
if options.optimization && p.optimization.mode=="manual"
    error('CoincidenceSim:MissingOptimization','请先在主界面选择自适应推荐或自动应用，或取消自适应导出。');
end
if options.sweep
    if ~isfield(options,'sweepWidths') || isempty(options.sweepWidths) || ...
            any(~isfinite(options.sweepWidths) | options.sweepWidths<=0)
        error('CoincidenceSim:InvalidSweep','请选择有效的符合窗口扫描范围。');
    end
end
baseName=string(baseName);
if ~isscalar(baseName) || strlength(strtrim(baseName))==0 || ...
        ~isempty(regexp(char(baseName),'[<>:"/\\|?*]','once')) || baseName=="." || baseName==".."
    error('CoincidenceSim:InvalidExportPrefix','文件名前缀不能为空或包含路径字符。');
end
if ~isfolder(folder), mkdir(folder); end
name="seed_sweep_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
runFolder=fullfile(folder,name); suffix=0;
while isfolder(runFolder)
    suffix=suffix+1; runFolder=fullfile(folder,name+"_"+suffix);
end
mkdir(runFolder);
params=p;
save(fullfile(runFolder,'seed_sweep_settings.mat'),'params','spec','seeds','options');
n=numel(seeds);
log=table((1:n)',seeds,repmat("pending",n,1),strings(n,1),strings(n,1),zeros(n,1), ...
    nan(n,1),nan(n,1),nan(n,1),nan(n,1),nan(n,1), ...
    'VariableNames',{'RunIndex','Seed','Status','Message','OutputFolder','ExportedFiles', ...
    'CountA','CountB','Nraw','Nacc','Rnet'});
logFile=fullfile(runFolder,'seed_sweep_log.csv');
writeUtf8BomTable(log,logFile);
randomState=rng; restore=onCleanup(@()rng(randomState));
cancelled=false;
for k=1:n
    if ~progress(k-1,n,sprintf('第 %d/%d 次仿真，随机种子 %.0f',k,n,seeds(k)))
        cancelled=true; break
    end
    current=p; current.seed=seeds(k);
    target=fullfile(runFolder,sprintf('%04d_seed_%.0f',k,seeds(k)));
    log.OutputFolder(k)=target;
    try
        out=runSimulation(current);
        if options.sweep, out.sweep=sweepCoincidenceWindow(out,options.sweepWidths); end
        if options.timeWindows
            out.timeWindows=analyzeTimestampWindows(out.A,out.B,out.params,out.source,out.dataMode);
        end
        files=exportSelectedResults(out,target,baseName+sprintf('_seed_%.0f',seeds(k)),options);
        log.CountA(k)=numel(out.A.time); log.CountB(k)=numel(out.B.time);
        log.Nraw(k)=out.metrics.Nraw; log.Nacc(k)=out.metrics.Nacc; log.Rnet(k)=out.metrics.Rnet;
        log.ExportedFiles(k)=numel(files); log.Status(k)="success";
    catch ME
        log.Status(k)="failed"; log.Message(k)=string(ME.identifier)+": "+string(ME.message);
    end
    clear out
    writeUtf8BomTable(log,logFile);
end
if cancelled
    log.Status(log.Status=="pending")="cancelled";
    writeUtf8BomTable(log,logFile);
end
report=struct('outputFolder',runFolder,'log',log,'cancelled',cancelled, ...
    'successCount',nnz(log.Status=="success"),'failedCount',nnz(log.Status=="failed"));
clear restore
end
