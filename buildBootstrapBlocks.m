function blocks = buildBootstrapBlocks(out)
%BUILDBOOTSTRAPBLOCKS 固定整段峰和窗口，按 A 路时间归属已匹配事件。
% 跨分块边界的匹配仍保留；零计数块必须保留，所有块具有相同曝光时间。
p=out.params; T=p.measurementTime; u=p.uncertainty;
if u.blockMode=="auto"
    M=max(30,ceil(T));
else
    M=max(1,ceil(T/u.blockSize));
end
if M>1e6
    error('CoincidenceSim:TooManyBootstrapBlocks','分块数超过 100 万，请增大分块时长。');
end
dt=T/M;
index=@(t) min(M,max(1,floor(t(:)/dt)+1));
count=@(idx) accumarray(idx(:),ones(numel(idx),1),[M 1],@sum,0);
anchor=index(out.A.time(out.matches.indexA));
C=count(anchor(out.raw.mask));
edges=out.acc.sideWindowEdges; L=size(edges,1);
S=zeros(M,L);
for j=1:L
    mask=out.matches.deltaT>=edges(j,1) & out.matches.deltaT<edges(j,2);
    S(:,j)=count(anchor(mask));
end
if L==0, side=nan(M,1); else, side=mean(S,2); end
NA=count(index(out.A.time)); NB=count(index(out.B.time));
if out.dataMode=="simulation"
    TP=count(anchor(out.raw.mask & out.matches.isTrue));
    FP=C-TP;
else
    TP=nan(M,1); FP=nan(M,1);
end
blocks=struct('count',M,'blockSize',dt,'duration',T,'window',out.raw.window, ...
    'sideWindowEdges',edges,'C',C,'S',S,'side',side,'NA',NA,'NB',NB,'TP',TP,'FP',FP);
blocks.table=table((1:M)',(0:M-1)'*dt,(1:M)'*dt,NA,NB,C,side,C-side,TP,FP, ...
    'VariableNames',{'BlockIndex','Start_s','Stop_s','NA','NB','Nraw', ...
    'Nacc_side','Ncorr_side','TP','FP'});
for j=1:L, blocks.table.(sprintf('SideWindow_%d',j))=S(:,j); end
end
