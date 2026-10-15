function out = runSimulation(p)
%RUNSIMULATION 执行完整的双通道时间戳 Monte Carlo 仿真。
%   OUT = RUNSIMULATION(P) 验证参数并固定随机种子，然后按物理数据流调用
%   各独立模块。OUT 保存全部中间结果，既服务 GUI，也方便批处理和调试。

% 参数验证可能在 pump 模式下计算并写回有效 pairRate。
data=generateSimulationData(p);
out=analyzeTimestampData(data.A,data.B,data.params,data.source,"simulation");
out.stageStats=data.stageStats;
end
