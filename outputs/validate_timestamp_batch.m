root=fileparts(fileparts(mfilename('fullpath')));
cd(root); addpath(root);
files={'discoverTimestampPairs.m','batchAnalyzeTimestampFolder.m', ...
    'CoincidenceSimulatorApp.m','tests/TestTimestampBatch.m'};
for k=1:numel(files)
    issues=checkcode(files{k},'-id');
    fprintf('CODE_ANALYZER %s: %d messages\n',files{k},numel(issues));
    for j=1:numel(issues)
        fprintf('  line %d [%s] %s\n',issues(j).line,issues(j).id,issues(j).message);
    end
end
r=runtests('tests');
disp(table(r));
save('outputs/batch_full_test_results.mat','r');
assertSuccess(r);
[pairs,skipped]=discoverTimestampPairs('E:\八通道30s\新实验测试');
assert(height(pairs)==191 && height(skipped)==2);
fprintf('REAL_DIRECTORY_DISCOVERY: %d pairs, %d skipped files\n',height(pairs),height(skipped));
app=CoincidenceSimulatorApp();
cleanup=onCleanup(@()delete(app));
app.UIFigure.Visible='off';
assert(strcmp(app.Controls.BatchButton.Text,'文件夹批量计算并导出…'));
assert(app.Controls.BatchButton.Layout.Row==8 && app.StatusLabel.Layout.Row==9);
assert(~isempty(app.Controls.BatchButton.ButtonPushedFcn));
fprintf('GUI_BATCH_BUTTON_CONSTRUCTION_PASSED\n');
clear cleanup
fprintf('BATCH_FEATURE_VALIDATION_PASSED: %d tests\n',numel(r));
