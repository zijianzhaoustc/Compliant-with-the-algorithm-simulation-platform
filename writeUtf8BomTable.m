function writeUtf8BomTable(dataTable, filename)
%WRITEUTF8BOMTABLE 将表格写为便于 Windows Excel 识别的 UTF-8 CSV。
%   MATLAB 的普通 UTF-8 CSV 可能不含 BOM，Excel 双击打开时可能按
%   本地 ANSI/GBK 解码而产生乱码。本函数先写入 EF BB BF 标记，
%   再将完整 UTF-8 文件的字节放在 BOM 之后。

target=char(filename);
[folder,~]=fileparts(target);
if isempty(folder), folder=pwd; end
temporary=[tempname(folder) '.csv'];
cleanup=onCleanup(@()deleteIfPresent(temporary));
writetable(dataTable,temporary,'Encoding','UTF-8');

inputID=fopen(temporary,'r');
if inputID<0, error('CoincidenceSim:ExportOpenFailed','无法读取临时 CSV：%s',temporary); end
try
    content=fread(inputID,Inf,'uint8=>uint8'); fclose(inputID);
catch ME
    fclose(inputID); rethrow(ME);
end

outputID=fopen(target,'w');
if outputID<0, error('CoincidenceSim:ExportOpenFailed','无法创建导出文件：%s',target); end
try
    fwrite(outputID,uint8([239 187 191]),'uint8');
    fwrite(outputID,content,'uint8');
    fclose(outputID);
catch ME
    fclose(outputID); rethrow(ME);
end
clear cleanup
end

function deleteIfPresent(filename)
%DELETEIFPRESENT 成功或异常退出时删除中间 CSV。
if isfile(filename), delete(filename); end
end
