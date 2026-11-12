function p = validateParams(p)
%VALIDATEPARAMS 检查参数合法性，并在 pump 模式下推导光子对率。
%   P = VALIDATEPARAMS(P) 对持续时间、概率、计数率、抖动、窗口和算法名称
%   进行检查。发现不合法输入时立即报错，避免错误单位或概率进入仿真内核。

% 采集时间必须为正；seed 必须为整数以确保 rng 可重复。
p=mergeParamsWithDefaults(defaultParams(),p);
mustBePositive(p.measurementTime);
if ~isscalar(p.measurementTime) || ~isfinite(p.measurementTime)
    error('CoincidenceSim:InvalidDuration','采集时长必须为有限正标量。');
end
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
    mustBeNonnegative(p.tdc.(ch).deadTime);
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
% 时间戳分窗开关必须是逻辑标量；窗长即使在关闭状态也保持有效，便于随时启用。
if ~isscalar(p.algorithm.timestampWindowMode) || ...
        ~(islogical(p.algorithm.timestampWindowMode) || isnumeric(p.algorithm.timestampWindowMode))
    error("CoincidenceSim:InvalidTimestampWindowMode", ...
        "Timestamp window mode must be a logical scalar.");
end
p.algorithm.timestampWindowMode=logical(p.algorithm.timestampWindowMode);
mustBePositive(p.algorithm.timestampWindowSize);
u=p.uncertainty;
if ~isscalar(u.enabled) || ~(islogical(u.enabled) || isnumeric(u.enabled)) || ...
        ~isfinite(u.enabled) || ~ismember(u.enabled,[0 1])
    error('CoincidenceSim:InvalidUncertainty','Bootstrap 开关必须为逻辑标量。');
end
if ~isscalar(string(u.blockMode)) || ~any(string(u.blockMode)==["auto","manual"])
    error('CoincidenceSim:InvalidUncertainty','分块模式必须为 auto 或 manual。');
end
finiteScalar(u.blockSize,eps,Inf,'blockSize');
finiteScalar(u.resamples,2,Inf,'resamples'); mustBeInteger(u.resamples);
finiteScalar(u.confidenceLevel,eps,1-eps,'confidenceLevel');
finiteScalar(u.seed,0,2^32-1,'seed'); mustBeInteger(u.seed);
finiteScalar(u.minBlocks,2,Inf,'minBlocks'); mustBeInteger(u.minBlocks);
p.uncertainty.enabled=logical(u.enabled);
p.uncertainty.blockMode=string(u.blockMode);
p.optimization=validateOptimizationParams(p.optimization);
end

function finiteScalar(x,lo,hi,name)
if ~isnumeric(x) || ~isscalar(x) || ~isfinite(x) || x<lo || x>hi
    error('CoincidenceSim:InvalidUncertainty','无效的不确定度参数 %s。',name);
end
end

function unitInterval(x, name)
%UNITINTERVAL 检查标量概率或效率是否位于闭区间 [0,1]。
if ~isscalar(x) || ~isfinite(x) || x < 0 || x > 1
    error("CoincidenceSim:InvalidProbability", "%s must be in [0,1].", name);
end
end
