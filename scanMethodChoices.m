function [values,labels] = scanMethodChoices(parameter)
%SCANMETHODCHOICES Supported categorical research factors and visible names.
switch string(parameter)
    case "algorithm.accidentalMethod"
        values=["theory","segment-theory","side-window","sideband","time-shift"];
        labels=["理论法（theory）","分段理论法（segment-theory）","旁窗法（side-window）","旁带法（sideband）","时间戳平移法（time-shift）"];
    case "algorithm.peakMethod"
        values=["maximum","fixed","gaussian"];
        labels=["最大 bin 寻峰（maximum）","固定峰中心（fixed）","积分高斯拟合寻峰（gaussian）"];
    case "algorithm.windowMode"
        values=["bins","fixed"]; labels=["D：峰 bin±n（完整 bin）","C：连续固定全宽 W"];
    case "algorithm.sideWindowGuardMode"
        values=["window-width","fixed-center"]; labels=["主窗边缘外 G=W","历史峰中心保护距离"];
    case "algorithm.pairRecovery"
        values=["joint-side","basic"]; labels=["旁窗峰尾联合修正","基础捕获率修正"];
    case "algorithm.uncertaintyMethod"
        values=["delta","bootstrap"]; labels=["协方差 Delta 近似","同步时间块重采样"];
    case "algorithm.timeShiftMode"
        values=["overlap","circular"]; labels=["有效重叠区间","历史循环平移（边界假设）"];
    case "scenarios.backgroundMode"
        values=["constant","step","linear","sinusoidal"]; labels=["恒定","阶跃","线性漂移","正弦波动"];
    case "scenarios.jitterModel"
        values=["gaussian","double-gaussian","exponential-tail"]; labels=["Gaussian","双 Gaussian","指数长尾"];
    otherwise
        values=strings(1,0); labels=strings(1,0);
end
end
