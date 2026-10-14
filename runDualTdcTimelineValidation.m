function folder=runDualTdcTimelineValidation()
%RUNDUALTDCTIMELINEVALIDATION All available automated tests, unique output.
root=fileparts(mfilename('fullpath')); addpath(root);
parent=fullfile(root,'outputs','timeline_fix'); if ~isfolder(parent), mkdir(parent); end
[~,id]=fileparts(tempname(parent)); folder=fullfile(parent,id); mkdir(folder);
diary(fullfile(folder,'test_log.txt')); cleanup=onCleanup(@()diary('off'));
results=runtests(fullfile(root,'tests')); t=table(results);
writeUtf8BomTable(t(:,{'Name','Passed','Failed','Incomplete','Duration'}),fullfile(folder,'test_results.csv'));
fprintf('Tests: %d; passed: %d; failed: %d; incomplete: %d\n',numel(results), ...
    nnz([results.Passed]),nnz([results.Failed]),nnz([results.Incomplete]));
fprintf('Timeline validation output: %s\n',folder);
assertSuccess(results); clear cleanup
end
