function width = resolveCoincidenceWindow(histResult, p)
%RESOLVECOINCIDENCEWINDOW 根据窗口模式返回完整符合窗口宽度。
%   fixed：直接使用 p.algorithm.window；
%   sigma：峰中心左右各 n*sigma，总宽 2*n*sigma；
%   bins：峰中心左右各 n 个 bin，总宽 2*n*binWidth；
%   fwhm：峰中心左右各 n*FWHM，总宽 2*n*FWHM。

n=p.algorithm.windowMultiplier;
switch p.algorithm.windowMode
    case "fixed"
        width=p.algorithm.window;
    case "sigma"
        width=2*n*histResult.sigma;
    case "bins"
        width=2*n*p.algorithm.binWidth;
    case "fwhm"
        width=2*n*histResult.fwhm;
end
if ~isfinite(width) || width<=0
    width=p.algorithm.window;
end
end
