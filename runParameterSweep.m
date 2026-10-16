function batch = runParameterSweep(config,options)
%RUNPARAMETERSWEEP Bounded physical-once, analysis-many research execution.
% OPTIONS.CancelFcn returns true to stop at the next safe boundary.
% OPTIONS.ProgressFcn receives (completed,total,row) after a durable checkpoint.
if nargin<1, config=scanDefaultConfig(); end
if ischar(config) || isstring(config), config=jsondecode(fileread(config)); end
if nargin<2, options=struct(); end
if ~isfield(options,'CancelFcn'), options.CancelFcn=@()false; end
if ~isfield(options,'ProgressFcn'), options.ProgressFcn=@(~,~,~)[]; end
[plan,preview,c]=buildScanGrid(config);
fingerprint=rmfield(c,{'outputRoot','resumeDirectory'}); configHash=scanHash(fingerprint);
[ok,revision]=system('git rev-parse HEAD');
if ok==0, revision=string(strtrim(revision)); else, revision="unknown"; end
[~,workingState]=system('git diff --stat');
sourceHash=scanCodeHash();
if strlength(c.resumeDirectory)>0
    runDir=char(c.resumeDirectory); checkpoint=fullfile(runDir,'checkpoint.mat');
    if ~isfile(checkpoint), error('CoincidenceSim:Resume','No checkpoint in selected directory.'); end
    saved=load(checkpoint,'state'); state=saved.state;
    if state.configHash~=configHash || state.revision~=revision || state.sourceHash~=sourceHash
        error('CoincidenceSim:ResumeMismatch','Configuration or code revision differs from the saved run.');
    end
    for i=1:numel(plan)
        rowPath=fullfile(runDir,'row_checkpoints',sprintf('row_%06d.mat',i));
        if isfile(rowPath)
            savedRow=load(rowPath,'row');
            if savedRow.row.parameter_hash~=plan(i).parameter_hash
                error('CoincidenceSim:ResumeMismatch','Saved result does not match the planned parameter hash.');
            end
            state.rows{i}=savedRow.row;
        end
    end
else
    if ~isfolder(c.outputRoot), mkdir(c.outputRoot); end
    [~,id]=fileparts(tempname(char(c.outputRoot)));
    batchID=string(datetime('now','TimeZone','Asia/Shanghai','Format','yyyyMMdd_HHmmss_SSS'))+"_"+string(id);
    runDir=fullfile(char(c.outputRoot),char(batchID)); mkdir(runDir);
    state=struct('configHash',configHash,'revision',revision,'sourceHash',sourceHash,'batchID',batchID, ...
        'rows',{cell(numel(plan),1)},'generationCount',0,'stopped',false);
    scanWriteJson(fullfile(runDir,'scan_config.json'),c);
    scanWriteJson(fullfile(runDir,'metadata.json'),struct('batch_id',batchID, ...
        'parameter_config_hash',configHash,'code_revision',revision,'code_source_hash',sourceHash,'working_tree_diff',string(workingState), ...
        'platform_version',version,'created_at',stamp(),'preview',preview, ...
        'units',table2struct(scanParameterCatalog()),'metricUnits', ...
        'metric_* follows calculateMetrics SI definitions; aliases have explicit ps/ns/cps suffixes', ...
        'dependence','Analysis variants share one physical stream; seeds are the independent replicates.'));
    writeUtf8BomTable(scanConfigurationsTable(plan),fullfile(runDir,'configurations.csv'));
end
state.stopped=false;
streamKeys=unique([plan.stream_key],'stable');
for key=streamKeys
    indices=find([plan.stream_key]==key);
    pending=indices(arrayfun(@(i)isempty(state.rows{i}) || state.rows{i}.status~="OK",indices));
    if isempty(pending), continue; end
    if options.CancelFcn(), state.stopped=true; break; end
    generationError=[]; data=[]; streamHash="";
    try
        data=generateSimulationData(plan(pending(1)).params);
        state.generationCount=state.generationCount+1;
        if numel(data.source.time)>c.limits.maxSourceEvents || max(numel(data.A.time),numel(data.B.time))>c.limits.maxChannelEvents
            error('CoincidenceSim:EventLimit','Actual channel event count exceeds scan limit.');
        end
        streamHash=scanStreamHash(data);
        if c.outputs.saveTimestamps
            folder=fullfile(runDir,'optional','timestamps'); if ~isfolder(folder), mkdir(folder); end
            save(fullfile(folder,char(key+".mat")),'data','-v7.3');
        end
    catch problem
        generationError=problem;
    end
    for i=pending
        if options.CancelFcn(), state.stopped=true; break; end
        timer=tic; started=stamp(); p=plan(i).params;
        try
            if ~isempty(generationError), rethrow(generationError); end
            out=analyzeSweepVariant(data,p);
            r=buildAllMetricRecord(p,out); r.status=out.sweepStatus;
            if out.acc.sideTrueCount>0
                r.warning_codes="SIDEBAND_TAIL_RISK";
            end
        catch problem
            r=buildAllMetricRecord(p); r.status="ERROR";
            r.error_identifier=string(problem.identifier);
            r.error_report=string(getReport(problem,'extended','hyperlinks','off'));
            r.invalid_reason=r.error_identifier; r.quality_flags="EXECUTION_ERROR";
        end
        fields=["physical_config_id","analysis_config_id","stream_key","seed_group_key","parameter_hash"];
        for field=fields, r.(field)=plan(i).(field); end
        r.warning_codes=strjoin([plan(i).warning_codes,r.warning_codes],';');
        r.warning_codes=strip(r.warning_codes,'both',';');
        r.batch_id=state.batchID; r.code_revision=revision; r.code_source_hash=sourceHash; r.stream_hash=streamHash;
        if ~isempty(data)
            r.source_count=numel(data.source.time); r.events_A=numel(data.A.time); r.events_B=numel(data.B.time);
        end
        r.started_at=started; r.completed_at=stamp(); r.elapsed_s=toc(timer);
        r.run_id=state.batchID+"_"+string(i); r.revision=revision; r.params_json_hash=r.parameter_hash;
        r.wall_time_s=r.elapsed_s; r.peak_memory_est_mb=plan(i).estimated_working_memory_MB;
        state.rows{i}=r;
        logFile=fopen(fullfile(runDir,'task_log.txt'),'a','n','UTF-8');
        if logFile>=0
            fprintf(logFile,'%s row=%d/%d seed=%g status=%s quality=%s elapsed_s=%.6g %s\n', ...
                r.completed_at,i,numel(plan),r.seed,r.status,r.quality_status,r.elapsed_s,r.invalid_reason);
            fclose(logFile);
        end
        saveRowCheckpoint(runDir,i,r);
        saveCheckpoint(runDir,state);
        options.ProgressFcn(nnz(~cellfun(@isempty,state.rows)),numel(plan),r);
    end
    clear data out
    exportParameterSweep(runDir,state,plan,c);
    if state.stopped, break; end
end
saveCheckpoint(runDir,state);
batch=exportParameterSweep(runDir,state,plan,c);
batch.preview=preview; batch.generationCount=state.generationCount;
end

function saveCheckpoint(folder,state)
target=fullfile(folder,'checkpoint.mat'); temporary=fullfile(folder,'checkpoint_next.mat');
% Store each row separately so a 10k-row sweep does not rewrite all results
% 10k times. The root checkpoint only carries identity and progress metadata.
state.rows=cell(numel(state.rows),1);
save(temporary,'state','-v7'); movefile(temporary,target,'f');
end

function saveRowCheckpoint(folder,index,row)
rowFolder=fullfile(folder,'row_checkpoints'); if ~isfolder(rowFolder), mkdir(rowFolder); end
target=fullfile(rowFolder,sprintf('row_%06d.mat',index));
temporary=fullfile(rowFolder,'row_next.mat');
save(temporary,'row','-v7'); movefile(temporary,target,'f');
end

function s=stamp()
s=string(datetime('now','TimeZone','Asia/Shanghai','Format',"yyyy-MM-dd'T'HH:mm:ss.SSSXXX"));
end
