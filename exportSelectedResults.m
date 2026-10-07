function files = exportSelectedResults(out, folder, baseName, options)
%EXPORTSELECTEDRESULTS 按用户选择导出设置、直方图、结果表、扫描和时间戳。
%   OPTIONS 包含 settings、histogram、results、sweep、timeWindows、countRates、
%   timestamps、unitSeconds 字段。缺少新增字段时默认不导出，以兼容旧调用。
%   时间戳文件采用与实测样例相同的“每行一个数值、无表头”格式。

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
    % 结果 CSV 与 GUI 右侧的四类指标顺序、名称和说明完全一致。
    resultsTable=buildMetricSummaryTable(out);
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
end
