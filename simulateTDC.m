function events = simulateTDC(events, p, channel)
%SIMULATETDC 模拟 FPGA-TDC 的电子学抖动、时间量化和死时间。
%   EVENTS = SIMULATETDC(EVENTS,P,CHANNEL) 对探测器输出事件添加指定通道
%   的零均值 Gaussian 抖动，再按公共 TDC 分辨率舍入到最近量化格点；
%   启用时，最后使用与探测器相同的非延长型死时间模型筛除事件。

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
if p.tdc.enableDeadTime && p.tdc.(channel).deadTime>0
    % 非延长型模型只由最近一次被 TDC 接受的事件启动阻塞区间；
    % 阻塞期间到达但被丢弃的事件不会延长死时间。
    keep=nonParalyzableKeep(events.time,p.tdc.(channel).deadTime);
    events.time=events.time(keep); events.pairID=events.pairID(keep);
    events.type=events.type(keep);
end
end
