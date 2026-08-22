function raw = calculateRawCoincidence(matches, histResult, p)
%CALCULATERAWCOINCIDENCE 统计峰值附近符合窗口中的原始符合。
%   RAW = CALCULATERAWCOINCIDENCE(MATCHES,HISTRESULT,P) 使用完整窗口宽度
%   p.algorithm.window，以直方图峰值为中心选择事件对。RAW.mask 与匹配数组
%   等长，可用于回查每一对事件及其 ground truth。

% 根据 fixed/sigma/bins/fwhm 模式解析完整窗口宽度。
window=resolveCoincidenceWindow(histResult,p);
mask = abs(matches.deltaT-histResult.peak) <= window/2;
raw.mask = mask;
raw.count = nnz(mask);
raw.window = window;
% 计数除以有效采集时间得到 cps。
raw.rate = raw.count/p.measurementTime;
end
