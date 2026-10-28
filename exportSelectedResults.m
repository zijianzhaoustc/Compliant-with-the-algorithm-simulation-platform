function files = exportSelectedResults(out, folder, baseName, options)
%EXPORTSELECTEDRESULTS 按用户选择导出设置、直方图、结果表、扫描和时间戳。
%   OPTIONS 包含 settings、histogram、results、sweep、timeWindows、countRates、
%   timestamps、uncertainty、unitSeconds 字段。缺少新增字段时默认不导出，以兼容旧调用。
%   时间戳文件采用与实测样例相同的“每行一个数值、无表头”格式。

if isfield(options,'perSecond') && options.perSecond
    files=exportTimestampSeconds(out,folder,baseName,options);
    return
end
if ~isfolder(folder), mkdir(folder); end
files=strings(0,1);
if options.settings
    params=out.params;
    file=fullfile(folder,baseName+"_settings.mat");
    save(file,"params"); files(end+1,1)=file;
end
if options.histogram
    h=out.hist;
    histogramTable=table(h.centers(:)/options.unitSeconds,h.counts(:), ...
        'VariableNames',{'TimeDifference','Counts'});
    file=fullfile(folder,baseName+"_histogram.csv");
    writeUtf8BomTable(histogramTable,file); files(end+1,1)=file;
end
if options.results
    % GUI 精简显示五项计数；结果 CSV 仍保留完整统计指标和中间配置。
    resultsTable=buildMetricSummaryTable(out,true);
    file=fullfile(folder,baseName+"_results.csv");
    writeUtf8BomTable(resultsTable,file); files(end+1,1)=file;
end
if isfield(options,'sweep') && options.sweep
    if ~isfield(out,'sweep') || ~isfield(out.sweep,'window')
        error('CoincidenceSim:MissingSweep','当前结果没有窗口扫描数据，请先点击“扫描符合窗口”。');
    end
    sweepTable=buildSweepSummaryTable(out.sweep);
    file=fullfile(folder,baseName+"_window_sweep.csv");
    writeUtf8BomTable(sweepTable,file); files(end+1,1)=file;
end
if isfield(options,'timeWindows') && options.timeWindows
    if ~isfield(out,'timeWindows') || ~isfield(out.timeWindows,'results') || ...
            isempty(out.timeWindows.results)
        error('CoincidenceSim:MissingTimeWindows', ...
            '当前结果没有时间戳分窗数据，请启用分窗模式后重新导入 Start/Stop 文件。');
    end
    % 分窗结果集中放在独立目录：一张计数汇总表，加每个子窗一张直方图表。
    windowFolder=fullfile(folder,baseName+"_time_windows");
    if ~isfolder(windowFolder), mkdir(windowFolder); end
    summaryFile=fullfile(windowFolder,baseName+"_time_window_summary.csv");
    writeUtf8BomTable(buildTimeWindowSummaryTable(out.timeWindows),summaryFile);
    files(end+1,1)=summaryFile;
    for k=1:numel(out.timeWindows.results)
        result=out.timeWindows.results{k}; h=result.hist;
        histogramTable=table(h.centers(:)/options.unitSeconds,h.counts(:), ...
            'VariableNames',{'TimeDifference','Counts'});
        histogramFile=fullfile(windowFolder,sprintf('%s_time_window_%04d_histogram.csv', ...
            baseName,k));
        writeUtf8BomTable(histogramTable,histogramFile);
        files(end+1,1)=histogramFile;
    end
end
if isfield(options,'countRates') && options.countRates
    % 逐秒计数率和拟合时间性能不进入右侧指标表，只在勾选时计算；两张表
    % 集中写入同一目录，便于对导入 TXT/BIN 的同一秒数据进行联合分析。
    [countRateTable,timingTable]=buildPerSecondCountRateTable(out);
    analysisFolder=fullfile(folder,baseName+"_per_second_analysis");
    if ~isfolder(analysisFolder), mkdir(analysisFolder); end
    countRateFile=fullfile(analysisFolder,baseName+"_per_second_count_rates.csv");
    timingFile=fullfile(analysisFolder,baseName+"_per_second_timing_fit.csv");
    writeUtf8BomTable(countRateTable,countRateFile);
    writeUtf8BomTable(timingTable,timingFile);
    files=[files;string(countRateFile);string(timingFile)];
end
if options.timestamps
    origin=0;
    if isfield(out.source,"rawOrigin"), origin=out.source.rawOrigin*out.source.unitSeconds; end
    startValues=(out.A.time+origin)/options.unitSeconds;
    stopValues=(out.B.time+origin)/options.unitSeconds;
    startFile=fullfile(folder,baseName+"_StartCh.txt");
    stopFile=fullfile(folder,baseName+"_StopCh.txt");
    writematrix(startValues,startFile,'Delimiter','tab');
    writematrix(stopValues,stopFile,'Delimiter','tab');
    files=[files;string(startFile);string(stopFile)];
end
if isfield(options,'uncertainty') && options.uncertainty
    if ~isfield(out,'uncertainty')
        error('CoincidenceSim:MissingUncertainty','请重新计算以生成统计不确定度结果。');
    end
    file=fullfile(folder,baseName+"_uncertainty_summary.csv");
    writeUtf8BomTable(out.uncertainty.summary,file); files(end+1,1)=file;
    if ~isempty(out.uncertainty.blocks)
        file=fullfile(folder,baseName+"_bootstrap_blocks.csv");
        writeUtf8BomTable(out.uncertainty.blocks.table,file); files(end+1,1)=file;
    end
    if ~isempty(out.uncertainty.bootstrap)
        file=fullfile(folder,baseName+"_bootstrap_replicates.csv");
        writeUtf8BomTable(out.uncertainty.bootstrap.replicates,file); files(end+1,1)=file;
    end
end
if isfield(options,'optimization') && options.optimization
    if ~isfield(out,'optimization') || isempty(out.optimization)
        error('CoincidenceSim:MissingOptimization','当前结果未执行自适应参数优化。');
    end
    o=out.optimization;
    file=fullfile(folder,baseName+"_optimization_summary.csv");
    writeUtf8BomTable(buildOptimizationSummaryTable(o),file); files(end+1,1)=file;
    scans={o.binScan,o.windowScan}; suffix=["_optimization_bins.csv","_optimization_windows.csv"];
    for k=1:2
        if ~isempty(scans{k})
            file=fullfile(folder,baseName+suffix(k));
            writeUtf8BomTable(scans{k},file); files(end+1,1)=file;
        end
    end
    replicates=table(); candidateBlocks=table();
    for k=1:numel(o.candidateBootstrap)
        if isempty(o.candidateBootstrap{k}), continue; end
        r=o.candidateBootstrap{k}.replicates;
        r=addvars(r,repmat(k,height(r),1),repmat(o.windowScan.Window_s(k),height(r),1), ...
            'Before',1,'NewVariableNames',{'CandidateIndex','Window_s'});
        replicates=[replicates;r]; %#ok<AGROW>
        b=o.candidateBootstrap{k}.blocks.table;
        b=addvars(b,repmat(k,height(b),1),repmat(o.windowScan.Window_s(k),height(b),1), ...
            'Before',1,'NewVariableNames',{'CandidateIndex','Window_s'});
        % 有效旁窗数不同时，补齐缺失列为 NaN，保留 Origin 可直接使用的数值列。
        if isempty(candidateBlocks)
            candidateBlocks=b;
        else
            missing=setdiff(b.Properties.VariableNames,candidateBlocks.Properties.VariableNames,'stable');
            for j=1:numel(missing), candidateBlocks.(missing{j})=nan(height(candidateBlocks),1); end
            missing=setdiff(candidateBlocks.Properties.VariableNames,b.Properties.VariableNames,'stable');
            for j=1:numel(missing), b.(missing{j})=nan(height(b),1); end
            candidateBlocks=[candidateBlocks;b(:,candidateBlocks.Properties.VariableNames)]; %#ok<AGROW>
        end
    end
    if ~isempty(replicates)
        file=fullfile(folder,baseName+"_optimization_candidate_bootstrap.csv");
        writeUtf8BomTable(replicates,file); files(end+1,1)=file;
    end
    if ~isempty(candidateBlocks)
        file=fullfile(folder,baseName+"_optimization_candidate_blocks.csv");
        writeUtf8BomTable(candidateBlocks,file); files(end+1,1)=file;
    end
    if isfield(o,'validation') && ~isempty(o.validation.summary)
        file=fullfile(folder,baseName+"_optimization_validation.csv");
        writeUtf8BomTable(o.validation.summary,file); files(end+1,1)=file;
    end
end
end
