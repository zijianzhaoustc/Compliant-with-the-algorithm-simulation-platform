function src = generatePhotonPairs(p)
%GENERATEPHOTONPAIRS 生成 CW-SPDC 光子对的 Poisson 时间点过程。
%   SRC = GENERATEPHOTONPAIRS(P) 返回按时间升序排列的产生时刻、唯一
%   pairID 和事件类型。低增益 CW-SPDC 在首版模型中近似为齐次 Poisson
%   过程；每个产生时刻同时对应 A、B 两个相关光子。

% 指数分布到达间隔的累计和构成齐次 Poisson 点过程。
times = poissonTimes(p.source.pairRate, p.measurementTime);
src.time = times;
% pairID 从 1 开始；0 专门保留给暗计数和后脉冲等非真实事件。
src.pairID = (1:numel(times)).';
src.type = repmat("pair", numel(times), 1);
end

function t = poissonTimes(rate, duration)
%POISSONTIMES 使用指数到达间隔生成时间戳，不依赖 Statistics Toolbox。
if rate <= 0, t = zeros(0,1); return; end
% 一次生成略高于期望计数的样本；极少数不足情况由 while 继续补充。
n = max(1024, ceil(rate*duration + 8*sqrt(max(rate*duration,1))));
t = zeros(0,1); last = 0;
while true
    a = last + cumsum(-log(rand(n,1))/rate);
    valid = a <= duration;
    t = [t; a(valid)]; %#ok<AGROW>
    % 本批首次越过采集终点时，后续到达只会更晚，因此可以结束。
    if ~all(valid), break; end
    last = a(end);
end
end
