function report = validateJointFitIntegration(folder,sourceFile)
%VALIDATEJOINTFITINTEGRATION 验证实际 GUI、最窄推荐/算法回退、导出和原脚本一致性。
%   第二参数可选：用户提供的原 analyze_real_spdc_1_mult.m 路径。
if nargin<1, folder=fullfile(pwd,'outputs','joint_fit_validation'); end
if nargin<2, sourceFile=''; end
if ~isfolder(folder), mkdir(folder); end
app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app));
c=app.Controls; app.ParameterTabs.SelectedTab=app.JointFitTab;
c.PairRate.Value=20000; c.Time.Value=.5;
c.TimingModelA.Value='gaussian'; c.TimingModelB.Value='gaussian';
c.BgA.Value=1e5; c.BgB.Value=1e5;
c.BootstrapEnabled.Value=false; c.OptimizationMode.Value='recommend';
c.Selection.Value='narrowest'; c.BackgroundCheck.Value=false;
c.JointFitEnabled.Value=true; c.JointFitSample.Value=20000;
c.JointFitChunk.Value=1000;
button=findall(app.UIFigure,'Type','uibutton','Text','运行新仿真');
button.ButtonPushedFcn([],[]);
assert(~isempty(app.LastResult) && app.LastResult.jointFit.valid,'GUI 联合拟合未成功。');
adaptive=app.LastResult;
assert(adaptive.optimization.valid && ~adaptive.optimization.applied);
assert(adaptive.jointFit.window.source=="narrowest-adaptive");
assert(abs(adaptive.jointFit.window.width-adaptive.optimization.window)<1e-20);
assert(height(app.JointFitTable.Data)==2);
assert(strcmp(app.ResultTable.Data{1,1},'【联合无分箱点估计】'));
assert(any(strcmp(app.ResultTable.Data(:,1),'联合拟合捕获修正完整面积')));
assert(~any(strcmp(app.ResultTable.Data(:,1),'联合拟合窗原始计数')));
plotTab=findall(app.UIFigure,'Tag','JointFitPlotTab');
plotTab.Parent.SelectedTab=plotTab; drawnow;
exportapp(app.UIFigure,fullfile(folder,'joint_fit_adaptive.png'));
exportJointFitResults(adaptive,folder,"adaptive");

% 实际点击选择性导出，仅勾选联合拟合，核对三个文件及完整 MAT 内容。
dialog=showExportDialog(app.UIFigure,adaptive);
dialogCleanup=onCleanup(@()delete(dialog));
boxes=findall(dialog,'Type','uicheckbox'); assert(numel(boxes)==12);
for index=1:numel(boxes), boxes(index).Value=false; end
jointBox=findall(dialog,'Tag','ExportChoice_jointFit');
assert(strcmp(jointBox.Enable,'on')); jointBox.Value=true;
base=findall(dialog,'Tag','ExportBaseName'); base.Value='gui_joint_only';
output=findall(dialog,'Tag','ExportFolder'); output.Value=char(folder);
drawnow; exportapp(dialog,fullfile(folder,'joint_fit_export_dialog.png'));
start=findall(dialog,'Tag','ExportStart'); start.ButtonPushedFcn([],[]);
assert(isfile(fullfile(folder,'gui_joint_only_joint_fit_summary.csv')));
assert(isfile(fullfile(folder,'gui_joint_only_joint_fit_profile.csv')));
saved=load(fullfile(folder,'gui_joint_only_joint_fit_result.mat'));
assert(isequaln(saved.jointFit,adaptive.jointFit));
assert(~isfile(fullfile(folder,'gui_joint_only_results.csv')));
clear dialogCleanup

batchCaptured=[];
dialog=showBatchExportDialog(app.UIFigure,@captureBatch,true);
jointBox=findall(dialog,'Tag','BatchJointFit'); assert(strcmp(jointBox.Enable,'on'));
boxes=findall(dialog,'Type','uicheckbox');
for index=1:numel(boxes), boxes(index).Value=false; end
jointBox.Value=true; drawnow;
exportapp(dialog,fullfile(folder,'joint_fit_batch_export_dialog.png'));
start=findall(dialog,'Tag','BatchStart'); start.ButtonPushedFcn([],[]);
assert(batchCaptured.jointFit && ~batchCaptured.results && ~batchCaptured.histogram);

seedCaptured=[];
dialog=showSeedSweepDialog(app.UIFigure,adaptive.params,@captureSeed);
jointBox=findall(dialog,'Tag','ExportChoice_jointFit'); assert(strcmp(jointBox.Enable,'on'));
boxes=findall(dialog,'Type','uicheckbox');
for index=1:numel(boxes), boxes(index).Value=false; end
jointBox.Value=true;
start=findall(dialog,'Tag','SeedSweepStart'); start.ButtonPushedFcn([],[]);
assert(seedCaptured.jointFit && ~seedCaptured.results && ~seedCaptured.histogram);

c.OptimizationMode.Value='manual'; c.WindowMode.Value='bins'; c.WindowN.Value=3;
c.RecalculateButton.ButtonPushedFcn([],[]);
fallback=app.LastResult;
assert(fallback.jointFit.window.source=="algorithm-settings");
assert(abs(fallback.jointFit.window.width-fallback.raw.window)<1e-20);
assert(fallback.jointFit.window.includeUpperEdge==fallback.raw.includeUpperEdge);
assert(isequal(adaptive.A,fallback.A) && isequal(adaptive.B,fallback.B));
drawnow; exportapp(app.UIFigure,fullfile(folder,'joint_fit_algorithm_window.png'));
exportJointFitResults(fallback,folder,"algorithm_window");
params=fallback.params; save(fullfile(folder,'validated_settings.mat'),'params');
report=struct('adaptiveWindow_s',adaptive.jointFit.window.width, ...
    'algorithmWindow_s',fallback.jointFit.window.width,'referenceChecked',false);

if ~isempty(sourceFile)
    % 临时复制为与声明一致的入口名，避免原目录同名版本干扰；原文件不改写。
    scratch=tempname; mkdir(scratch);
    referenceCleanup=onCleanup(@()removeReference(scratch));
    copyfile(sourceFile,fullfile(scratch,'analyze_real_spdc_1.m'));
    addpath(scratch,'-begin');
    timestamps=adaptive.A.time; save(fullfile(scratch,'A.mat'),'timestamps');
    timestamps=adaptive.B.time; save(fullfile(scratch,'B.mat'),'timestamps');
    j=adaptive.params.jointFit;
    opts=struct('textUnit','s','measurementTime',adaptive.params.measurementTime, ...
        'outputDir',fullfile(scratch,'result'),'makePlots',false, ...
        'lagRangeNs',adaptive.params.algorithm.histRange*1e9, ...
        'plotBinNs',adaptive.params.algorithm.binWidth*1e9, ...
        'referenceWindowNs',adaptive.jointFit.window.width*1e9, ...
        'initialSigmaNs',j.initialSigma*1e9,'minIRFSigmaNs',j.minSigma*1e9, ...
        'maxTailSigmaNs',j.maxTailSigma*1e9,'blockSeconds',j.blockSize, ...
        'maxShapeFitPairs',j.maxShapeFitPairs,'streamChunkPairs',j.streamChunkPairs, ...
        'sampleSeed',j.seed);
    reference=analyze_real_spdc_1(fullfile(scratch,'A.mat'),fullfile(scratch,'B.mat'),opts);
    names=["gaussian";"doublegaussian"]; deltaN=zeros(2,1); deltaB=zeros(2,1);
    for k=1:2
        actual=adaptive.jointFit.models.(names(k)); expected=reference.models.(names(k));
        deltaN(k)=actual.Npair-expected.Npair; deltaB(k)=actual.background-expected.background;
        assert(abs(deltaN(k))<1e-3*max(1,abs(expected.Npair)),'原脚本峰面积对照失败。');
        assert(abs(deltaB(k))<1e-3*max(1,abs(expected.background)),'原脚本背景对照失败。');
    end
    comparison=table(names,deltaN,deltaB,'VariableNames',{'Model','DeltaArea','DeltaBackground_counts_per_ns'});
    writeUtf8BomTable(comparison,fullfile(folder,'original_script_comparison.csv'));
    report.referenceChecked=true; clear referenceCleanup
end
save(fullfile(folder,'integration_report.mat'),'report');
c.JointFitEnabled.Value=false; c.RecalculateButton.ButtonPushedFcn([],[]);
assert(isempty(app.LastResult.jointFit) && isempty(app.JointFitTable.Data));
assert(isempty(findall(app.JointFitAxes,'Type','line')));
fprintf('JOINT_GUI_AND_INTEGRATION_PASSED\n'); disp(report); clear cleanup

    function captureBatch(~,~,opts)
        batchCaptured=opts;
    end

    function captureSeed(~,~,~,opts)
        seedCaptured=opts;
    end
end

function removeReference(folder)
rmpath(folder); clear analyze_real_spdc_1
if isfolder(folder), rmdir(folder,'s'); end
end
