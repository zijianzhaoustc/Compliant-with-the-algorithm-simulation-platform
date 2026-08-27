function p = defaultParams()
%DEFAULTPARAMS 返回仿真平台的默认参数。
%   P = DEFAULTPARAMS() 创建一个嵌套结构体 P。除 GUI 显示单位外，计算
%   内核统一使用 SI 单位：时间为 s，频率/计数率为 Hz，功率为 W，长度为 m。
%
%   参数按 source、optics、detector、tdc 和 algorithm 五组组织。调用者可先
%   获取默认值，再仅覆盖实验中需要改变的字段。

% 光源：默认直接指定有效 SPDC 光子对产生率。
p.source.mode = "direct";
p.source.pairRate = 1e5;
% Pump 模式使用 P_pair = probability * P_pump * lambda/(h*c)。
p.source.pumpPower = 1e-3;
p.source.pumpWavelength = 405e-9;
p.source.spdcProbability = 1e-11;
p.source.laserToCrystalTransmission = 1.0;
% 单次采集时长和可复现实验所用随机种子。
p.measurementTime = 1.0;
p.seed = 1;

% 两路光学传输效率与固定传播延迟。
p.optics.A.transmission = 0.80; p.optics.B.transmission = 0.80;
p.optics.A.delay = 0; p.optics.B.delay = 5e-9;

% 探测效率与后端成功记录效率分开定义，避免重复计算系统效率。
p.detector.A.efficiency = 0.55; p.detector.B.efficiency = 0.55;
p.detector.A.recordEfficiency = 1.0; p.detector.B.recordEfficiency = 1.0;
% 每路暗计数率、探测器时间抖动和非延长型死时间。
p.detector.A.darkRate = 500; p.detector.B.darkRate = 500;
% 背景光与暗计数都是独立 Poisson 事件，但保留不同事件标签供可视化区分。
p.detector.A.backgroundRate = 0; p.detector.B.backgroundRate = 0;
p.detector.A.jitter = 150e-12; p.detector.B.jitter = 150e-12;
p.detector.A.deadTime = 50e-9; p.detector.B.deadTime = 50e-9;
% 后脉冲采用“发生概率 + 指数延迟寿命”模型。
p.detector.A.afterpulseProbability = 0.05; p.detector.B.afterpulseProbability = 0.05;
p.detector.A.afterpulseLifetime = 50e-9; p.detector.B.afterpulseLifetime = 50e-9;
% 各非理想效应可独立开关，便于进行对照实验。
p.detector.enableDark = true;
p.detector.enableDeadTime = false;
p.detector.enableAfterpulse = false;

% TDC 每通道电子学抖动及公共量化分辨率。
p.tdc.A.jitter = 10e-12; p.tdc.B.jitter = 10e-12;
p.tdc.A.bias = 0; p.tdc.B.bias = 0;
p.tdc.resolution = 10e-12;
p.tdc.enableJitter = true;
% DNL/INL 使用 LSB 为单位；0 表示理想均匀量化。
p.tdc.dnl = 0;
p.tdc.inl = 0;

% 直方图搜索范围、bin 宽和最终符合窗口（完整宽度而非半宽）。
p.algorithm.histRange = [-20e-9, 20e-9];
p.algorithm.binWidth = 100e-12;
p.algorithm.window = 3e-9;
% 文档规定的四种匹配方法。
p.algorithm.matchMethod = "many-to-many";
% 寻峰支持最大 bin 和局部 Gaussian 拟合。
p.algorithm.peakMethod = "maximum";
% fixed、sigma、bins、fwhm；后三者的 multiplier 默认取 3。
p.algorithm.windowMode = "fixed";
p.algorithm.windowMultiplier = 3;
% 偶然符合修正：无修正、理论法、旁带法、旁窗法或时间戳平移法。
p.algorithm.accidentalMethod = "theory";
% 旁带法和旁窗法共用峰中心两侧的保护距离。
p.algorithm.sidebandGuard = 3e-9;
% 旁窗法默认在左右各放置 3 个与主符合窗等宽的背景窗。
p.algorithm.sideWindowPairs = 3;
% 时间戳平移法默认使用 1、2、3、4、5 μs 五个循环平移并取平均。
p.algorithm.timeShiftStart = 1e-6;
p.algorithm.timeShiftStep = 1e-6;
p.algorithm.timeShiftCount = 5;
end
