function events = simulateOpticalPath(src, p, channel)
%SIMULATEOPTICALPATH 模拟指定通道的光学损耗和固定传播延迟。
%   EVENTS = SIMULATEOPTICALPATH(SRC,P,CHANNEL) 对 SRC 中每个光子独立进行
%   Bernoulli 保留，并在保留事件的时间戳上叠加 A 或 B 路固定延迟。
%   pairID 始终随事件传递，用于后续 ground-truth 判断。

% 根据通道名读取 A/B 路配置。
cfg = p.optics.(channel);
% transmission 是光子通过整段光路并到达探测器的概率。
keep = rand(size(src.time)) < cfg.transmission;
events.time = src.time(keep) + cfg.delay;
events.pairID = src.pairID(keep);
events.type = src.type(keep);
end
