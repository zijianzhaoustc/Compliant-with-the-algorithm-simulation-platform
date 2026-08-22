function events = simulateDetector(photons, p, channel)
%SIMULATEDETECTOR 模拟单通道探测器及记录电子学。
%   EVENTS = SIMULATEDETECTOR(PHOTONS,P,CHANNEL) 依次施加 PDE/记录效率、
%   探测器 Gaussian 抖动、暗计数、后脉冲、采集区间裁剪和非延长型死时间。
%   信号事件保留原 pairID；暗计数和后脉冲的 pairID 固定为 0。

cfg = p.detector.(channel);
% 光子探测和后端成功记录合并成一次独立 Bernoulli 试验。
keep = rand(size(photons.time)) < cfg.efficiency*cfg.recordEfficiency;
time = photons.time(keep) + cfg.jitter*randn(nnz(keep),1);
pairID = photons.pairID(keep);
type = repmat("signal", nnz(keep), 1);

if p.detector.enableDark && cfg.darkRate > 0
    % 暗计数是与入射光子无关的独立 Poisson 过程。
    dark = localPoissonTimes(cfg.darkRate, p.measurementTime);
    time = [time; dark]; pairID = [pairID; zeros(numel(dark),1)];
    type = [type; repmat("dark",numel(dark),1)];
end
if cfg.backgroundRate > 0
    % 背景光产生的探测事件与 SPDC pair 无关，但与暗计数分开标记。
    background = localPoissonTimes(cfg.backgroundRate, p.measurementTime);
    time = [time; background]; pairID = [pairID; zeros(numel(background),1)];
    type = [type; repmat("background",numel(background),1)];
end
if p.detector.enableAfterpulse && cfg.afterpulseProbability > 0 && ~isempty(time)
    % 每次已有 avalanche 以给定概率触发一个指数延迟后脉冲。
    make = rand(size(time)) < cfg.afterpulseProbability;
    ap = time(make) - cfg.afterpulseLifetime*log(rand(nnz(make),1));
    inside = ap >= 0 & ap <= p.measurementTime;
    time = [time; ap(inside)]; pairID = [pairID; zeros(nnz(inside),1)];
    type = [type; repmat("afterpulse",nnz(inside),1)];
end
% 合并各种事件后按时间排序，同时保持 pairID/type 对齐。
[time, order] = sort(time); pairID = pairID(order); type = type(order);
% 探测器抖动或后脉冲延迟可能使事件超出有效采集区间。
inside = time >= 0 & time <= p.measurementTime;
time = time(inside); pairID = pairID(inside); type = type(inside);
if p.detector.enableDeadTime && cfg.deadTime > 0
    % 非延长型模型只由最近一次“被接受”事件开启死时间。
    keep = nonParalyzableKeep(time, cfg.deadTime);
    time = time(keep); pairID = pairID(keep); type = type(keep);
end
events = struct("time",time,"pairID",pairID,"type",type);
end

function t = localPoissonTimes(rate, duration)
%LOCALPOISSONTIMES 生成独立暗计数时间点，无需 Statistics Toolbox。
n = max(1024, ceil(rate*duration + 8*sqrt(max(rate*duration,1))));
t = zeros(0,1); last = 0;
while true
    a = last + cumsum(-log(rand(n,1))/rate);
    valid = a <= duration; t = [t; a(valid)]; %#ok<AGROW>
    if ~all(valid), break; end
    last = a(end);
end
end

function keep = nonParalyzableKeep(t, deadTime)
%NONPARALYZABLEKEEP 返回非延长型死时间模型下被接受的事件掩码。
keep = false(size(t)); last = -inf;
for k = 1:numel(t)
    if t(k)-last >= deadTime, keep(k) = true; last = t(k); end
end
end
