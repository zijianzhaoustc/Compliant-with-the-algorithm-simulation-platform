function events = simulateTDC(events, p, channel)
%SIMULATETDC 模拟 FPGA-TDC 的电子学抖动和时间量化。
%   EVENTS = SIMULATETDC(EVENTS,P,CHANNEL) 对探测器输出事件添加指定通道
%   的零均值 Gaussian 抖动，再按公共 TDC 分辨率舍入到最近量化格点。

% 电子学抖动和探测器抖动分开建模，便于验证方差平方和规律。
if p.tdc.enableJitter
    events.time = events.time + p.tdc.(channel).jitter*randn(size(events.time));
end
% 固定通道偏置模拟电缆、比较器与通道校准残差。
events.time = events.time + p.tdc.(channel).bias;
% round(t/q)*q 表示理想均匀 TDC 的最近邻量化。
q = p.tdc.resolution;
code = round(events.time/q);
% 用确定性的周期 DNL 和慢变 INL 扰动模拟非理想转换曲线。参数均以 LSB
% 表示，默认 0；该简化模型用于敏感性研究，不替代器件实测校准表。
dnlError = p.tdc.dnl*q.*sin(2*pi*code/16);
inlError = p.tdc.inl*q.*sin(2*pi*code/4096);
events.time = code*q + dnlError + inlError;
% 抖动可能改变相邻事件顺序，因此量化后必须重新排序并同步元数据。
[events.time, order] = sort(events.time);
events.pairID = events.pairID(order); events.type = events.type(order);
% 删除抖动后落到采集区间之外的时间戳。
inside = events.time >= 0 & events.time <= p.measurementTime;
events.time = events.time(inside); events.pairID = events.pairID(inside);
events.type = events.type(inside);
end
