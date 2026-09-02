function p = validateParams(p)
%VALIDATEPARAMS 检查参数合法性，并在 pump 模式下推导光子对率。
%   P = VALIDATEPARAMS(P) 对持续时间、概率、计数率、抖动、窗口和算法名称
%   进行检查。发现不合法输入时立即报错，避免错误单位或概率进入仿真内核。

% 采集时间必须为正；seed 必须为整数以确保 rng 可重复。
mustBePositive(p.measurementTime);
mustBeInteger(p.seed);
if p.source.mode == "pump"
    % 单个泵浦光子能量为 h*c/lambda；spdcProbability 定义为每泵浦光子
    % 产生并进入所研究模式的一对光子的有效概率。
    h = 6.62607015e-34; c = 299792458;
    p.source.pairRate = p.source.spdcProbability * p.source.pumpPower * ...
        p.source.laserToCrystalTransmission * p.source.pumpWavelength / (h*c);
end
mustBeNonnegative(p.source.pairRate);
unitInterval(p.source.laserToCrystalTransmission, "laser-to-crystal transmission");
% 对 A、B 两路执行相同的范围检查。
for ch = ["A","B"]
    unitInterval(p.optics.(ch).transmission, "optical transmission");
    unitInterval(p.detector.(ch).efficiency, "detector efficiency");
    unitInterval(p.detector.(ch).recordEfficiency, "record efficiency");
    mustBeNonnegative(p.detector.(ch).darkRate);
    mustBeNonnegative(p.detector.(ch).backgroundRate);
    mustBeNonnegative(p.detector.(ch).jitter);
    mustBeNonnegative(p.detector.(ch).deadTime);
    unitInterval(p.detector.(ch).afterpulseProbability, "afterpulse probability");
    mustBePositive(p.detector.(ch).afterpulseLifetime);
    mustBeNonnegative(p.tdc.(ch).jitter);
    if ~isscalar(p.tdc.(ch).bias) || ~isfinite(p.tdc.(ch).bias)
        error("CoincidenceSim:InvalidBias", "TDC channel bias must be finite.");
    end
end
% 分辨率、bin 和符合窗口都代表物理宽度，必须严格大于零。
mustBePositive(p.tdc.resolution);
mustBePositive(p.algorithm.binWidth);
mustBePositive(p.algorithm.window);
if p.algorithm.histRange(1) >= p.algorithm.histRange(2)
    error("CoincidenceSim:InvalidRange", "Histogram minimum must be below maximum.");
end
% 字符串白名单避免 switch 分支未赋值。
mustBeNonnegative(p.tdc.dnl);
mustBeNonnegative(p.tdc.inl);
if ~any(p.algorithm.matchMethod == ["one-to-one","many-to-one","one-to-many", ...
        "many-to-many","all-pairs","nearest","nearest-no-reuse","nearest-reuse", ...
        "greedy-chronological"])
    error("CoincidenceSim:InvalidMethod", "Unknown matching method.");
end
if ~any(p.algorithm.peakMethod == ["maximum","gaussian"])
    error("CoincidenceSim:InvalidMethod", "Unknown peak method.");
end
if ~any(p.algorithm.windowMode == ["fixed","sigma","bins","fwhm"])
    error("CoincidenceSim:InvalidMethod", "Unknown window mode.");
end
mustBePositive(p.algorithm.windowMultiplier);
% bin 的个数必须是整数；sigma 和 FWHM 的倍数仍允许使用小数。
if p.algorithm.windowMode=="bins", mustBeInteger(p.algorithm.windowMultiplier); end
if ~any(p.algorithm.accidentalMethod == ["none","theory","sideband","side-window","time-shift"])
    error("CoincidenceSim:InvalidMethod", "Unknown accidental method.");
end
mustBeNonnegative(p.algorithm.sidebandGuard);
mustBePositive(p.algorithm.sideWindowPairs); mustBeInteger(p.algorithm.sideWindowPairs);
mustBePositive(p.algorithm.timeShiftStart);
mustBePositive(p.algorithm.timeShiftStep);
mustBePositive(p.algorithm.timeShiftCount); mustBeInteger(p.algorithm.timeShiftCount);
end

function unitInterval(x, name)
%UNITINTERVAL 检查标量概率或效率是否位于闭区间 [0,1]。
if ~isscalar(x) || ~isfinite(x) || x < 0 || x > 1
    error("CoincidenceSim:InvalidProbability", "%s must be in [0,1].", name);
end
end
