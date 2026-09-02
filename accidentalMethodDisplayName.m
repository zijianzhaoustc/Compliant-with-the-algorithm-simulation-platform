function name = accidentalMethodDisplayName(method)
%ACCIDENTALMETHODDISPLAYNAME 将偶然符合算法内部标识转换为中文显示名称。
%   NAME = ACCIDENTALMETHODDISPLAYNAME(METHOD) 同时供结果表、窗口扫描导出和
%   GUI 状态栏使用，避免同一种算法在不同输出中出现不一致的命名。

switch string(method)
    case "none"
        name="无修正";
    case "theory"
        name="理论法";
    case "sideband"
        name="旁带法";
    case "side-window"
        name="旁窗法";
    case "time-shift"
        name="时间戳平移法";
    otherwise
        % 未知标识原样保留，便于发现来自旧版本或外部 MAT 文件的取值。
        name="未知（"+string(method)+"）";
end
end
