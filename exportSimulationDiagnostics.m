function files = exportSimulationDiagnostics(out,folder,baseName)
%EXPORTSIMULATIONDIAGNOSTICS 固定 SI 单位导出真实峰形、计数和捕获率。
if ~isfield(out,'simulationDiagnostics') || string(out.dataMode)~="simulation"
    error('CoincidenceSim:NoSimulationTruth','请先运行仿真以生成真实峰形诊断。');
end
target=fullfile(folder,baseName+"_simulation_diagnostics");
if ~isfolder(target), mkdir(target); end
d=out.simulationDiagnostics;
names=["summary","channels","pairs","histogram","capture","timeBlocks"];
suffix=["summary","channels","true_pairs","true_histogram","true_capture","time_blocks"];
files=strings(numel(names),1);
for k=1:numel(names)
    files(k)=fullfile(target,baseName+"_"+suffix(k)+".csv");
    writeUtf8BomTable(d.(names(k)),files(k));
end
end
