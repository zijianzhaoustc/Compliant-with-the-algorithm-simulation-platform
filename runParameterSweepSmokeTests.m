function results = runParameterSweepSmokeTests()
%RUNPARAMETERSWEEPSMOKETESTS Standalone MATLAB validation with PASS/FAIL summary.
root=fileparts(mfilename('fullpath')); addpath(root);
results=runtests({fullfile(root,'tests','TestParameterSweep.m'), ...
    fullfile(root,'tests','TestScanMethodPicker.m')});
report=table(string({results.Name})', [results.Passed]',[results.Failed]',[results.Incomplete]', ...
    [results.Duration]','VariableNames',{'test','PASS','FAIL','INCOMPLETE','duration_s'});
folder=fullfile(root,'outputs','parameter_sweep_validation'); if ~isfolder(folder), mkdir(folder); end
id=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
writeUtf8BomTable(report,fullfile(folder,['validation_' id '.csv']));
disp(report); assertSuccess(results);
end
