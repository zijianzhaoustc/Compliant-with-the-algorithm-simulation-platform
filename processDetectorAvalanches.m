function events = processDetectorAvalanches(primary,deadTime,probability,lifetime,duration)
%PROCESSDETECTORAVALANCHES 耦合处理非延长型死时间和递归后脉冲。
%   PRIMARY 是已排序、已裁剪至 [0,duration] 的原始候选事件。
%   每次取最早候选，通过死时间判定才记录、更新死时间并以 probability
%   生成至多一个指数延迟后脉冲。后脉冲遵循同样规则，可继续产生后代。
%   被拒绝事件不延长死时间、不生成后代。后脉冲 pairID=0。
%   使用最小堆保存待处理后脉冲，与原始事件游标合并，避免反复排序大数组。

nPrimary=numel(primary.time);
capacity=max(16,nPrimary);
time=zeros(capacity,1); pairID=zeros(capacity,1); type=strings(capacity,1);
heap=zeros(max(16,nPrimary),1); heapSize=0;
nextPrimary=1; accepted=0; lastAccepted=-inf;
while nextPrimary<=nPrimary || heapSize>0
    % 同时刻优先处理原始事件；保证结果和事件标签选择可重复。
    isPrimary=nextPrimary<=nPrimary;
    if isPrimary && heapSize>0
        isPrimary=primary.time(nextPrimary)<=heap(1);
    end
    if isPrimary
        candidate=primary.time(nextPrimary);
        candidateID=primary.pairID(nextPrimary);
        candidateType=primary.type(nextPrimary);
        nextPrimary=nextPrimary+1;
    else
        candidate=heap(1); candidateID=0; candidateType="afterpulse";
        % 弹出堆顶，用末节点补位并向下恢复最小堆。
        tail=heap(heapSize); heapSize=heapSize-1;
        if heapSize>0
            pos=1;
            while 2*pos<=heapSize
                child=2*pos;
                if child<heapSize && heap(child+1)<heap(child), child=child+1; end
                if tail<=heap(child), break; end
                heap(pos)=heap(child); pos=child;
            end
            heap(pos)=tail;
        end
    end
    if candidate-lastAccepted<deadTime, continue; end
    lastAccepted=candidate;
    accepted=accepted+1;
    if accepted>capacity
        capacity=2*capacity;
        time(capacity,1)=0; pairID(capacity,1)=0; type(capacity,1)="";
    end
    time(accepted)=candidate; pairID(accepted)=candidateID; type(accepted)=candidateType;

    % 只有已接受的雪崩才抽样；后脉冲若位于死时间内，会在出堆时被拒绝。
    if rand<probability
        delay=-lifetime*log(max(rand,realmin));
        % 防止浮点舍入使极短延迟变成零，确保递归时间严格前进。
        afterTime=candidate+max(delay,eps(candidate));
        if afterTime<=duration
            heapSize=heapSize+1;
            if heapSize>numel(heap), heap(2*numel(heap),1)=0; end
            pos=heapSize;
            while pos>1
                parent=floor(pos/2);
                if heap(parent)<=afterTime, break; end
                heap(pos)=heap(parent); pos=parent;
            end
            heap(pos)=afterTime;
        end
    end
end
events=struct("time",time(1:accepted),"pairID",pairID(1:accepted), ...
    "type",type(1:accepted));
end
