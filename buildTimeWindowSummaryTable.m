function summary = buildTimeWindowSummaryTable(windowed)
%BUILDTIMEWINDOWSUMMARYTABLE 汇总每个时间分窗的通道和符合计数。
%   每行对应一个子时间窗；Nacc 是偶然符合率乘以该子窗有效时长得到的
%   期望计数，可能为小数。Nnet=max(0,Nraw-Nacc)。

n=numel(windowed.results);
index=(1:n)';
startSeconds=windowed.start(:);
stopSeconds=windowed.stop(:);
durationSeconds=stopSeconds-startSeconds;
countA=zeros(n,1); countB=zeros(n,1);
nRaw=zeros(n,1); nAcc=zeros(n,1); nNet=zeros(n,1);
method=strings(n,1);

for k=1:n
    result=windowed.results{k};
    countA(k)=numel(result.A.time);
    countB(k)=numel(result.B.time);
    nRaw(k)=result.metrics.Nraw;
    nAcc(k)=result.metrics.Nacc;
    nNet(k)=max(0,nRaw(k)-nAcc(k));
    method(k)=accidentalMethodDisplayName(result.metrics.AccidentalMethod);
end

summary=table(index,startSeconds,stopSeconds,durationSeconds,countA,countB, ...
    nRaw,nAcc,nNet,method,'VariableNames', ...
    {'分窗序号','起始时间_s','终止时间_s','有效时长_s','A通道计数', ...
    'B通道计数','原始符合计数_Nraw','偶然符合计数_Nacc', ...
    '净符合计数_Nnet','偶然符合修正算法'});
end
