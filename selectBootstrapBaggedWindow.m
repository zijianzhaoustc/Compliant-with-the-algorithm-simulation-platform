function [bag, finalBlocks] = selectBootstrapBaggedWindow(A,B,matches,p,model,widths,valid,guard,capture,upSide)
%SELECTBOOTSTRAPBAGGEDWINDOW 缓存净计数块，按设置次数共享索引重抽样后聚合选窗。
%   仅使用观测时间与匹配索引；不读取 pairID、TP/FP 或 isTrue。
%   第二输出复用最终窗口的缓存，供原有 runBlockBootstrap 计算 u 与 CI。
widths=widths(:); valid=valid(:); capture=capture(:); upSide=upSide(:);
seed=mod(double(p.uncertainty.seed)+99173,2^32);
bag=struct('valid',false,'selectedIndex',NaN,'status',"no-valid-window", ...
    'Reps',p.optimization.baggingResamples,'PoolIndices',zeros(0,1),'PoolWindows_s',zeros(0,1), ...
    'SelectedWindows_s',zeros(0,1),'MeanSelectedWindow_s',NaN, ...
    'SelectedWindowSD_s',NaN,'FinalWindow_s',NaN,'Seed',seed, ...
    'FallbackReason',"",'RangeFallback',false,'BlockCount',NaN, ...
    'CacheBuildCount',0,'RejectedIndices',zeros(0,1), ...
    'SelectionFrequency',nan(numel(widths),1),'ValidCandidates',valid, ...
    'ScoreVariance',nan(numel(widths),1),'ScoreMean',nan(numel(widths),1), ...
    'ScoreStd',nan(numel(widths),1));
finalBlocks=[];
if ~p.uncertainty.enabled
    bag.status="bagging-requires-bootstrap";
    bag.FallbackReason="Bagging 需要启用分块 Bootstrap。"; return
end
allValid=find(valid);
if isempty(allValid), return; end
% 有效窗口全集与候选池都按宽度排序，平分时优先较小窗口。
[~,order]=sort(widths(allValid)); allValid=allValid(order);
eligible=allValid(widths(allValid)<=1.40*widths(allValid(1)));
if isempty(eligible)
    eligible=allValid; bag.RangeFallback=true;
    bag.FallbackReason="限定范围无有效候选，使用全部有效窗口。";
end
capacity=min([11,max(1,p.optimization.bootstrapCandidates),numel(eligible)]);
pool=eligible(1);
% 一半余量给解析评分较优者，剩余余量覆盖宽度范围。
analytic=upSide(eligible).^2./capture(eligible).^2;
analytic(~isfinite(analytic))=Inf;
[~,rank]=sortrows([analytic,widths(eligible)],[1 2]);
for candidate=eligible(rank)'
    if numel(pool)>=1+ceil((capacity-1)/2), break; end
    if ~ismember(candidate,pool), pool(end+1,1)=candidate; end %#ok<AGROW>
end
slots=capacity-numel(pool);
targets=linspace(widths(eligible(1)),widths(eligible(end)),slots+1);
% 最窄端已强制入池，其余均匀目标覆盖中间宽度和最宽端。
for target=targets(2:end)
    if numel(pool)>=capacity, break; end
    remaining=eligible(~ismember(eligible,pool));
    [~,nearest]=min(abs(widths(remaining)-target));
    pool(end+1,1)=remaining(nearest); %#ok<AGROW>
end
[~,order]=sort(widths(pool)); pool=pool(order);
bag.PoolIndices=pool; bag.PoolWindows_s=widths(pool);
cache=cell(numel(pool),1); keep=true(numel(pool),1); X=[];
for j=1:numel(pool)
    index=pool(j);
    blocks=makeBlocks(A,B,matches,p,model,widths(index),guard(index));
    bag.CacheBuildCount=bag.CacheBuildCount+1;
    if blocks.count<max(2,p.uncertainty.minBlocks)
        bag.BlockCount=blocks.count; bag.status="insufficient-bagging-blocks";
        bag.FallbackReason="有效块数不足，请使用现有分块控件缩短目标块长。"; return
    end
    if j==1
        M=blocks.count; bag.BlockCount=M; dt=blocks.blockSize; X=nan(M,numel(pool));
    elseif blocks.count~=M || blocks.blockSize~=dt
        bag.status="bagging-score-unavailable";
        bag.FallbackReason="候选时间块边界不一致。"; return
    end
    net=blocks.C(:)-blocks.side(:);
    if isempty(blocks.S) || size(blocks.S,2)~=2*p.algorithm.sideWindowPairs || ...
            any(~isfinite(net)) || ~isfinite(capture(index)) || capture(index)<=0
        keep(j)=false; bag.ValidCandidates(index)=false;
    else
        X(:,j)=net; cache{j}=blocks; %#ok<AGROW> 首个候选确定块数后一次预分配
    end
end
bag.RejectedIndices=pool(~keep); pool=pool(keep); cache=cache(keep); X=X(:,keep);
bag.PoolIndices=pool; bag.PoolWindows_s=widths(pool);
if isempty(pool)
    bag.status="bagging-score-unavailable";
    bag.FallbackReason="候选缺少完整旁窗或存在非有限净计数块。"; return
end
chosen=zeros(bag.Reps,1); wins=zeros(numel(pool),1);
captureSquared=capture(pool)'.^2;
scoreMean=zeros(size(captureSquared)); scoreM2=scoreMean;
stream=RandStream('mt19937ar','Seed',seed);
for b=1:bag.Reps
    I=randi(stream,M,M,1);
    ub2=M*var(X(I,:),1,1);
    J=ub2./captureSquared;
    if any(~isfinite(J))
        bag.status="bagging-score-unavailable";
        bag.FallbackReason="重抽样的方差评分存在非有限值。"; return
    end
    % 汇总同一轮候选评分，避免保存全部重抽样矩阵。
    delta=J-scoreMean;
    scoreMean=scoreMean+delta/b;
    scoreM2=scoreM2+delta.*(J-scoreMean);
    [~,winner]=min(J);
    chosen(b)=widths(pool(winner)); wins(winner)=wins(winner)+1;
end
bag.ScoreVariance(pool)=M*var(X,1,1);
bag.ScoreMean(pool)=scoreMean;
if bag.Reps>1
    bag.ScoreStd(pool)=sqrt(max(0,scoreM2)/(bag.Reps-1));
end
if isscalar(pool)
    bag.status="bagging-single-candidate";
else
    bag.status="ok";
end
bag.SelectedWindows_s=chosen;
bag.MeanSelectedWindow_s=mean(chosen); bag.SelectedWindowSD_s=std(chosen,0);
bag.SelectionFrequency(pool)=wins/bag.Reps;
% 投影到全部有效窗口，而非仅投影到池内窗口。
allValid=allValid(bag.ValidCandidates(allValid));
[~,nearest]=min(abs(widths(allValid)-bag.MeanSelectedWindow_s));
choice=allValid(nearest);
cached=find(pool==choice,1);
if isempty(cached)
    finalBlocks=makeBlocks(A,B,matches,p,model,widths(choice),guard(choice));
    bag.CacheBuildCount=bag.CacheBuildCount+1;
else
    finalBlocks=cache{cached};
end
if finalBlocks.count~=M || finalBlocks.blockSize~=dt || ...
        isempty(finalBlocks.S) || size(finalBlocks.S,2)~=2*p.algorithm.sideWindowPairs || ...
        any(~isfinite(finalBlocks.C-finalBlocks.side))
    bag.status="bagging-score-unavailable";
    bag.ValidCandidates(choice)=false;
    bag.RejectedIndices=unique([bag.RejectedIndices;choice]);
    bag.FallbackReason="最终投影窗口的净计数块不可评估。"; finalBlocks=[]; return
end
bag.valid=true; bag.selectedIndex=choice; bag.FinalWindow_s=widths(choice);
end

function blocks=makeBlocks(A,B,matches,p,model,width,guard)
q=p; q.algorithm.windowMode="fixed"; q.algorithm.window=width;
q.algorithm.accidentalMethod="side-window"; q.algorithm.sidebandGuard=guard;
q.algorithm.binWidth=max(p.tdc.resolution,min(p.optimization.binCandidates));
blind=struct('deltaT',matches.deltaT,'indexA',matches.indexA);
a=struct('time',A.time); b=struct('time',B.time);
h=applyCoincidencePeak(buildHistogram(blind,q),model);
r=calculateRawCoincidence(blind,h,q); acc=estimateAccidentals(a,b,blind,h,q);
provisional=struct('params',q,'A',a,'B',b,'matches',blind,'hist',h, ...
    'raw',r,'acc',acc,'dataMode',"imported");
blocks=buildBootstrapBlocks(provisional);
end
