function options = readExportSelection(controls, unitSeconds)
%READEXPORTSELECTION 将共用导出控件读成 exportSelectedResults 的选项。
options=struct();
for name=string(fieldnames(controls))'
    options.(name)=controls.(name).Value;
end
options.unitSeconds=unitSeconds;
end
