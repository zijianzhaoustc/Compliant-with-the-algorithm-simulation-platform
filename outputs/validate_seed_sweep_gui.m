root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(root);
folder=fullfile(root,'outputs','seed_sweep_gui_validation');
if ~isfolder(folder), mkdir(folder); end
app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app));
app.Controls.PairRate.Value=2000; app.Controls.Time.Value=.2; app.Controls.Seed.Value=17;
app.Controls.BootstrapB.Value=20; app.Controls.OptimizationMode.Value='manual';
p=defaultParams(); p.source.pairRate=2000; p.measurementTime=.2; p.seed=17;
p.uncertainty.resamples=20; p.optimization.mode="manual";
out=runSimulation(p);
out.sweep=sweepCoincidenceWindow(out,[1;2]*1e-9);
q=out.params; q.algorithm.timestampWindowSize=.1;
out.timeWindows=analyzeTimestampWindows(out.A,out.B,q,out.source,out.dataMode);
app.LastResult=out;
single=showExportDialog(app.UIFigure,out);
boxes=findall(single,'Type','uicheckbox'); singleTags=sort(string({boxes.Tag}));
singleLabels=sort(string({boxes.Text})); delete(single);
app.Controls.SeedSweepButton.ButtonPushedFcn(app.Controls.SeedSweepButton,[]);
d=findall(groot,'Type','figure','Name','随机种子步进扫描'); assert(numel(d)==1);
boxes=findall(d,'Type','uicheckbox');
assert(numel(boxes)==9 && isequal(sort(string({boxes.Tag})),singleTags));
assert(isequal(sort(string({boxes.Text})),singleLabels));
for k=1:numel(boxes)
    boxes(k).Value=any(strcmp(boxes(k).Tag,{'ExportChoice_settings','ExportChoice_histogram','ExportChoice_results'}));
end
field=findall(d,'Tag','SeedStart'); field.Value=11;
field=findall(d,'Tag','SeedStep'); field.Value=2;
field=findall(d,'Tag','SeedCount'); field.Value=2; field.ValueChangedFcn(field,[]);
field=findall(d,'Tag','SeedOutputFolder'); field.Value=folder;
field=findall(d,'Tag','SeedBaseName'); field.Value='gui';
drawnow; exportapp(d,fullfile(root,'outputs','seed_sweep_dialog.png'));
button=findall(d,'Tag','SeedSweepStart'); button.ButtonPushedFcn(button,[]);
assert(~isvalid(d)); assert(contains(app.StatusLabel.Text,'成功 2，失败 0'));
assert(isequaln(app.LastResult,out));
folders=dir(fullfile(folder,'seed_sweep_*')); [~,latest]=max([folders.datenum]);
batch=fullfile(folders(latest).folder,folders(latest).name);
log=readtable(fullfile(batch,'seed_sweep_log.csv'),'TextType','string');
assert(isequal(log.Seed,[11;13]) && all(log.Status=="success") && all(log.ExportedFiles==3));
snapshot=load(fullfile(batch,'seed_sweep_settings.mat')); assert(snapshot.params.seed==17);
for k=1:height(log)
    expectedParams=snapshot.params; expectedParams.seed=log.Seed(k);
    expected=runSimulation(expectedParams);
    prefix=sprintf('gui_seed_%d',log.Seed(k));
    actual=load(fullfile(log.OutputFolder(k),prefix+"_settings.mat"));
    assert(isequaln(actual.params,expected.params));
    h=readtable(fullfile(log.OutputFolder(k),prefix+"_histogram.csv"));
    assert(isequal(h.Counts,expected.hist.counts(:)));
end
clear cleanup
fprintf('SEED_SWEEP_GUI_EXPORT_PASSED\n');
