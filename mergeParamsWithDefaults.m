function merged = mergeParamsWithDefaults(defaults, supplied)
%MERGEPARAMSWITHDEFAULTS 递归补齐旧版本参数文件中缺少的字段。
%   supplied 中已有值优先；仅从 defaults 补充缺失字段，使早期导出的 MAT
%   设置可在新增背景光、DNL/INL、寻峰和窗口模式后继续导入。

merged=defaults;
if ~isstruct(supplied), error("CoincidenceSim:InvalidParams","导入参数必须是结构体。"); end
names=fieldnames(supplied);
for k=1:numel(names)
    name=names{k};
    if isfield(merged,name) && isstruct(merged.(name)) && isstruct(supplied.(name))
        merged.(name)=mergeParamsWithDefaults(merged.(name),supplied.(name));
    else
        merged.(name)=supplied.(name);
    end
end
end
