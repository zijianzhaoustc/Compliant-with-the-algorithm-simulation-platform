function out = runSimulation(p)
%RUNSIMULATION 执行完整的双通道时间戳 Monte Carlo 仿真。
%   OUT = RUNSIMULATION(P) 验证参数并固定随机种子，然后按物理数据流调用
%   各独立模块。OUT 保存全部中间结果，既服务 GUI，也方便批处理和调试。

% 参数验证可能在 pump 模式下计算并写回有效 pairRate。
p=validateParams(p); rng(p.seed,"twister");
% 1. 产生带唯一 pairID 的 SPDC 光子对。
src=generatePhotonPairs(p);
% 2. 两路独立经历光学传输损耗和固定延迟。
A=simulateOpticalPath(src,p,"A"); B=simulateOpticalPath(src,p,"B");
% 3. 模拟探测器非理想因素和记录过程。
A=simulateDetector(A,p,"A"); B=simulateDetector(B,p,"B");
% 4. 模拟 TDC 电子学抖动及量化。
A=simulateTDC(A,p,"A"); B=simulateTDC(B,p,"B");
% 5. 仿真和实测时间戳从这里开始进入完全相同的分析管线。
p.analysis.sourceCount=numel(src.time);
out=analyzeTimestampData(A,B,p,src,"simulation");
end
