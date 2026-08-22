function exportSimulationResult(out, filename)
%EXPORTSIMULATIONRESULT 将仿真结果导出为 MAT 或指标汇总 CSV。
%   EXPORTSIMULATIONRESULT(OUT,FILENAME) 根据扩展名选择格式：CSV 只写出
%   metrics 中的标量汇总；其他扩展名保存完整 OUT 结构体，包含时间戳、
%   匹配、直方图、参数和 ground truth。

[~,~,ext]=fileparts(filename);
if strcmpi(ext,".csv")
    % 将指标结构体转换成便于表格软件读取的两列表格。
    m=out.metrics;
    names=string(fieldnames(m)); values=cellfun(@(x)m.(x),cellstr(names));
    writetable(table(names,values,'VariableNames',{'Metric','Value'}),filename);
else
    % v7.3 支持包含大量时间戳的结果文件。
    save(filename,"out","-v7.3");
end
end
