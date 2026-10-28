function files = exportBatchResult(out, folder, baseName, options)
%EXPORTBATCHRESULT 按选择导出四类批处理结果，仅导出汇总，不附加抽样明细。
if ~isfolder(folder), mkdir(folder); end
histOptions=struct('settings',false,'histogram',options.histogram,'results',false, ...
    'timestamps',false,'unitSeconds',options.unitSeconds);
files=exportSelectedResults(out,folder,baseName,histOptions);
if options.results
    summary=buildMetricSummaryTable(out,true);
    rows=parameterRows(out.params,"params");
    rows=[{'Start 文件',char(out.source.startFile),''; ...
        'Stop 文件',char(out.source.stopFile),''};rows];
    if isfield(out.source,'windowStart')
        rows=[rows;{'子窗起始时间_s',mat2str(out.source.windowStart,17),''; ...
            '子窗终止时间_s',mat2str(out.source.windowStop,17),''}];
    end
    summary=[summary;cell2table(rows,'VariableNames',summary.Properties.VariableNames)];
    file=fullfile(folder,baseName+"_results.csv");
    writeUtf8BomTable(summary,file); files(end+1,1)=file;
end
if options.uncertainty
    file=fullfile(folder,baseName+"_uncertainty_summary.csv");
    writeUtf8BomTable(out.uncertainty.summary,file); files(end+1,1)=file;
end
if options.optimization
    if isempty(out.optimization)
        recommendation=table("manual",false,false,"disabled", ...
            "当前为手动模式，未执行自适应优化", ...
            'VariableNames',{'Mode','Valid','Applied','Status','Diagnostics'});
    else
        recommendation=buildOptimizationSummaryTable(out.optimization);
    end
    file=fullfile(folder,baseName+"_optimization_summary.csv");
    writeUtf8BomTable(recommendation,file); files(end+1,1)=file;
end
end

function rows=parameterRows(value,prefix)
rows=cell(0,3);
names=fieldnames(value);
for k=1:numel(names)
    name=names{k}; item=value.(name); key=prefix+"."+string(name);
    if isstruct(item)
        rows=[rows;parameterRows(item,key)]; %#ok<AGROW>
    else
        if isnumeric(item) || islogical(item), text=mat2str(item,17);
        else, text=char(strjoin(string(item),", ")); end
        rows(end+1,:)={char(key),text,'实际计算参数（时间采用 SI 秒）'}; %#ok<AGROW>
    end
end
end
