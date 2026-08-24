function exportSimulationResult(out, filename)
%EXPORTSIMULATIONRESULT 将仿真结果导出为 MAT 或指标汇总 CSV。
%   EXPORTSIMULATIONRESULT(OUT,FILENAME) 根据扩展名选择格式：CSV 只写出
%   按 GUI 的四类指标定义写出汇总表；其他扩展名保存完整 OUT 结构体，包含时间戳、
%   匹配、直方图、参数和 ground truth。

[~,~,ext]=fileparts(filename);
if strcmpi(ext,".csv")
    writeUtf8BomTable(buildMetricSummaryTable(out),filename);
else
    % v7.3 支持包含大量时间戳的结果文件。
    save(filename,"out","-v7.3");
end
end
