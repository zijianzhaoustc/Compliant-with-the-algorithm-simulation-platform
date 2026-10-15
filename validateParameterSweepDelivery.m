function report = validateParameterSweepDelivery()
%VALIDATEPARAMETERSWEEPDELIVERY Full regression + persisted reviewable examples.
root=fileparts(mfilename('fullpath')); addpath(root);
id=char(datetime('now','TimeZone','Asia/Shanghai','Format','yyyyMMdd_HHmmss_SSS'));
folder=fullfile(root,'outputs','parameter_sweep_validation',['delivery_' id]); mkdir(folder);
examples=fullfile(root,'examples'); if ~isfolder(examples), mkdir(examples); end
for mode=["smoke","research"]
    c=parameterSweepExamples(mode); [~,~,c]=buildScanGrid(c);
    c.outputRoot='outputs/parameter_sweep';
    scanWriteJson(fullfile(examples,"parameter_sweep_"+mode+".json"),c);
end
baselineVerified=false;
if isfile(fullfile(root,'baseline_parameter_sweep.mat'))
    old=load(fullfile(root,'baseline_parameter_sweep.mat'),'baseline');
    current=runSimulation(defaultParams());
    assert(isequaln(current.A,old.baseline.A)); assert(isequaln(current.B,old.baseline.B));
    assert(isequaln(current.source,old.baseline.source));
    assert(isequaln(current.matches,old.baseline.matches));
    assert(isequaln(current.metrics,old.baseline.metrics));
    baselineVerified=true;
end
results=runtests(fullfile(root,'tests'));
testTable=table(string({results.Name})',[results.Passed]',[results.Failed]', ...
    [results.Incomplete]',[results.Duration]', ...
    'VariableNames',{'test','passed','failed','incomplete','duration_s'});
writeUtf8BomTable(testTable,fullfile(folder,'all_tests.csv')); disp(testTable);
assertSuccess(results);
c=parameterSweepExamples("smoke"); smoke=runParameterSweep(c);
assert(height(smoke.results)==32); assert(smoke.generationCount==4);
assert(all(smoke.results.status=="OK"));
readback=readtable(fullfile(smoke.outputDirectory,'scan_results.csv'),'VariableNamingRule','preserve');
assert(height(readback)==32); assert(isequaln(readback.Nraw_count,smoke.results.Nraw_count));
assert(isequal(string(readback.Properties.VariableNames),string(smoke.results.Properties.VariableNames)));
c=scanDefaultConfig(); c.baseParams.measurementTime=.01; c.seeds=[1 2];
c.factors=[scanFactor("algorithm.accidentalMethod",["theory","side-window","time-shift"]); ...
    scanFactor("algorithm.timeShiftStart",[1 5]); scanFactor("algorithm.timeShiftStep",[1 2]); ...
    scanFactor("algorithm.timeShiftCount",[2 3])];
methods=runParameterSweep(c);
assert(height(methods.results)==48); assert(methods.generationCount==2);
assert(all(methods.results.status=="OK"));
paper=runPaperSimulations("smoke",[],fullfile(folder,'paper_smoke'));
assert(all(paper.runs.status=="OK"));
report=struct('validated_at',id,'matlab_version',version,'test_count',numel(results), ...
    'passed',nnz([results.Passed]),'failed',nnz([results.Failed]), ...
    'baseline_identical',baselineVerified,'smoke_directory',smoke.outputDirectory, ...
    'smoke_rows',height(smoke.results),'smoke_physical_generations',smoke.generationCount, ...
    'method_directory',methods.outputDirectory,'method_rows',height(methods.results), ...
    'method_physical_generations',methods.generationCount,'paper_run_count',height(paper.runs), ...
    'paper_output_directory',paper.outputRoot,'report_directory',string(folder));
scanWriteJson(fullfile(folder,'validation_summary.json'),report); disp(report);
end
