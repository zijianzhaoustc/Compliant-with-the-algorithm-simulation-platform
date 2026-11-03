root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(root);
folder=fullfile(root,'outputs','bagging_csv_readback'); input=fullfile(folder,'input');
if ~isfolder(input), mkdir(input); end
for prefix=["a","b"]
    writematrix((0:.5:10)',fullfile(input,prefix+"_CH1.txt"));
    writematrix((0:.5:10)',fullfile(input,prefix+"_CH2.txt"));
end
p=defaultParams(); p.optimization.mode="manual"; p.uncertainty.resamples=20;
options=struct('perSecond',true,'results',false,'uncertainty',false,'optimization',false);
report=batchAnalyzeTimestampFolder(input,fullfile(folder,'output'),1,p,@(completed,~,~)completed<.2,options);
path=fullfile(report.log.OutputFolder(1),'a_per_second_results','a_second_index.csv');
disp(path); disp(fileread(path));
index=readtable(path); disp(index.Properties.VariableNames);
explicit=readtable(path,'ReadVariableNames',true,'NumHeaderLines',0,'Delimiter',',','Encoding','UTF-8');
disp(explicit.Properties.VariableNames);
assert(height(explicit)==2 && isequal(explicit.Nraw,[2;2]));
disp('EXPLICIT_CSV_HEADER_READBACK_PASSED');
