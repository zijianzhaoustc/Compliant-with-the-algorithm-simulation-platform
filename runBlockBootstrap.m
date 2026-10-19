function bs = runBlockBootstrap(blocks, u)
%RUNBLOCKBOOTSTRAP 联合抽取完整分块向量，重建理论估计而非相加局部乘积。
% 局部 RandStream 不改变 Monte Carlo 使用的全局随机状态。分批限制索引内存。
M=blocks.count; B=u.resamples;
if M<2
    error('CoincidenceSim:InsufficientBootstrapBlocks','Bootstrap 至少需要两个等时长分块。');
end
stream=RandStream('mt19937ar','Seed',u.seed);
% 输入每行一个块，所有列在每轮使用完全相同的抽样索引。
X=[blocks.C,blocks.side,blocks.NA,blocks.NB,blocks.TP,blocks.FP];
sums=zeros(B,size(X,2));
batch=max(1,floor(1e6/M));
for first=1:batch:B
    last=min(B,first+batch-1);
    I=randi(stream,M,M,last-first+1);
    for j=1:size(X,2)
        values=X(:,j);
        sums(first:last,j)=sum(reshape(values(I),size(I)),1)';
    end
end
[samples,names]=statistics(sums,blocks.window/blocks.duration);
[point,~]=statistics(sum(X,1),blocks.window/blocks.duration);
bs=summarizeBootstrap(samples,point,names,u.confidenceLevel);
bs.blockCount=M; bs.blockSize=blocks.blockSize; bs.resamples=B; bs.seed=u.seed;
% 未观察到事件时经验分布退化，不报告误导性的零标准不确定度。
unobserved=[sum(blocks.C)==0, isempty(blocks.S) || sum(blocks.S,'all')==0, ...
    sum(blocks.NA)==0 || sum(blocks.NB)==0, false,false, ...
    sum(blocks.NA)==0,sum(blocks.NB)==0];
unobserved(4)=unobserved(1) || unobserved(2);
unobserved(5)=unobserved(1) || unobserved(3);
bad=find(unobserved);
if unobserved(2), bad=[bad,10,11,13,15,17]; end
if unobserved(3), bad=[bad,10,12,14,16,18]; end
bad=unique(bad);
bs.standardUncertainty(bad)=NaN; bs.CI(:,bad)=NaN;
bs.relativeUncertainty(bad)=NaN;
bs.covariance(bad,:)=NaN; bs.covariance(:,bad)=NaN;
bs.correlation(bad,:)=NaN; bs.correlation(:,bad)=NaN;
end

function [y,names]=statistics(x,f)
raw=x(:,1); side=x(:,2); NA=x(:,3); NB=x(:,4); TP=x(:,5); FP=x(:,6);
theory=f*NA.*NB; corrSide=raw-side; corrTheory=raw-theory;
y=[raw,side,theory,corrSide,corrTheory,NA,NB,TP,FP,side-theory, ...
    side-FP,theory-FP,corrSide-TP,corrTheory-TP, ...
    ratio(side-FP,FP),ratio(theory-FP,FP),ratio(corrSide-TP,TP),ratio(corrTheory-TP,TP)];
names=["Nraw","Nacc_side","Nacc_theory","Ncorr_side","Ncorr_theory", ...
    "NA","NB","TP","FP","Delta_acc_methods","Error_acc_side","Error_acc_theory", ...
    "Error_corr_side","Error_corr_theory","epsilon_acc_side","epsilon_acc_theory", ...
    "epsilon_corr_side","epsilon_corr_theory"];
end

function y=ratio(a,b)
y=a./b; y(b==0)=NaN;
end
