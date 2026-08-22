function files = exportSelectedResults(out, folder, baseName, options)
%EXPORTSELECTEDRESULTS 按用户选择导出设置、直方图、结果表和两路时间戳。
%   OPTIONS 包含 settings、histogram、results、timestamps、unitSeconds 字段。
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
    writetable(histogramTable,file); files(end+1,1)=file;
end
if options.results
    m=out.metrics; names=string(fieldnames(m));
    values=cellfun(@(name)m.(name),cellstr(names));
    resultsTable=table(names,values,'VariableNames',{'Metric','Value'});
    file=fullfile(folder,baseName+"_results.csv");
    writetable(resultsTable,file); files(end+1,1)=file;
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
