function keep = nonParalyzableKeep(time, deadTime)
%NONPARALYZABLEKEEP 返回非延长型死时间模型下被接受的事件掩码。
%   第一个事件始终被接受；此后只有与最近一次“被接受”事件的间隔不小于
%   DEADTIME 才会被接受。死时间内被拒绝的事件不会重新启动或延长死时间。

keep=false(size(time));
lastAccepted=-inf;
for k=1:numel(time)
    if time(k)-lastAccepted>=deadTime
        keep(k)=true;
        lastAccepted=time(k);
    end
end
end
