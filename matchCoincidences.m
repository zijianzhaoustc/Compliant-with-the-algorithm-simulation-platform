function matches = matchCoincidences(A, B, p)
%MATCHCOINCIDENCES 在时间差搜索范围内匹配两路有序时间戳。
%   MATCHES = MATCHCOINCIDENCES(A,B,P) 返回 A/B 原数组下标、时间差、两路
%   pairID 以及 ground-truth 标志。时间差约定为 deltaT = t_B - t_A。
%
%   支持原有四种规则及新增的三种最近邻/贪婪规则：
%     one-to-one  - 每个 Start 与其后第一个 Stop 配对，双方均不复用；
%     many-to-one - 每个 Start 与其后第一个 Stop 配对，Stop 可被复用；
%     one-to-many - 每个 Start 与下一个 Start 前的所有 Stop 配对；
%     many-to-many- 每个 Start 与正负搜索范围内所有 Stop 配对。
%     nearest-no-reuse - 每个 Start 选择绝对时间差最小的未使用 Stop；
%     nearest-reuse    - 每个 Start 选择最近 Stop，Stop 可重复使用；
%     greedy-chronological - 两路从早到晚用双指针贪婪配对，事件均不复用。

lo = p.algorithm.histRange(1); hi = p.algorithm.histRange(2);
switch p.algorithm.matchMethod
    case {"many-to-many","all-pairs"}
        [ia, ib] = allPairs(A.time, B.time, lo, hi);
    case "one-to-one"
        [ia, ib] = oneToOne(A.time, B.time, max(abs([lo hi])));
    case "many-to-one"
        [ia, ib] = manyToOne(A.time, B.time, max(abs([lo hi])));
    case "one-to-many"
        [ia, ib] = oneToMany(A.time, B.time, max(abs([lo hi])));
    case "nearest-no-reuse"
        [ia, ib] = nearestNeighbor(A.time,B.time,max(abs([lo hi])),false);
    case {"nearest-reuse","nearest"}
        [ia, ib] = nearestNeighbor(A.time,B.time,max(abs([lo hi])),true);
    case "greedy-chronological"
        [ia, ib] = greedyChronological(A.time,B.time,max(abs([lo hi])));
end
% 保存原事件数组下标，便于从输出追溯匹配来源。
matches.indexA = ia; matches.indexB = ib;
matches.deltaT = B.time(ib)-A.time(ia);
matches.pairIDA = A.pairID(ia); matches.pairIDB = B.pairID(ib);
% 只有同一个非零 pairID 才是真实 SPDC 符合。
matches.isTrue = matches.pairIDA > 0 & matches.pairIDA == matches.pairIDB;
end

function [ia,ib] = allPairs(a,b,lo,hi)
%ALLPAIRS 用双滑动边界枚举范围内组合，避免构造完整笛卡尔积。
% 第一遍只统计每个 Start 的匹配数，随后一次性预分配输出。相比为百万个
% Start 创建 cell，该方式明显降低实测大文件的内存开销。
counts=zeros(numel(a),1); left=1; right=0;
for i = 1:numel(a)
    % left 指向第一个满足 b-a >= lo 的 B 事件。
    while left <= numel(b) && b(left)-a(i) < lo, left = left+1; end
    right = max(right,left-1);
    % right 指向最后一个满足 b-a <= hi 的 B 事件。
    while right+1 <= numel(b) && b(right+1)-a(i) <= hi, right = right+1; end
    counts(i)=max(0,right-left+1);
end
total=sum(counts); ia=zeros(total,1); ib=zeros(total,1);
left=1; right=0; pos=1;
for i=1:numel(a)
    while left<=numel(b) && b(left)-a(i)<lo, left=left+1; end
    right=max(right,left-1);
    while right+1<=numel(b) && b(right+1)-a(i)<=hi, right=right+1; end
    n=counts(i);
    if n>0
        target=pos:pos+n-1; ia(target)=i; ib(target)=(left:right).'; pos=pos+n;
    end
end
end

function [ia,ib] = oneToOne(a,b,range)
%ONETOONE 每个 Start 匹配其后第一个未使用的 Stop。
ia=zeros(0,1); ib=zeros(0,1); i=1; j=1;
while i<=numel(a) && j<=numel(b)
    d=b(j)-a(i);
    if d<0
        j=j+1;
    elseif d>range
        i=i+1;
    else
        ia(end+1,1)=i; ib(end+1,1)=j; %#ok<AGROW>
        i=i+1; j=j+1;
    end
end
end

function [ia,ib] = manyToOne(a,b,range)
%MANYTOONE 每个 Start 使用其后第一个 Stop，同一个 Stop 允许服务多个 Start。
ia=zeros(0,1); ib=zeros(0,1); j=1;
for i=1:numel(a)
    while j<=numel(b) && b(j)<a(i), j=j+1; end
    if j>numel(b), break; end
    if b(j)-a(i)<=range
        ia(end+1,1)=i; ib(end+1,1)=j; %#ok<AGROW>
    end
end
end

function [ia,ib] = oneToMany(a,b,range)
%ONETOMANY 一个 Start 配对其后、下一个 Start 前且搜索范围内的全部 Stop。
iaCell=cell(numel(a),1); ibCell=cell(numel(a),1); j=1;
for i=1:numel(a)
    while j<=numel(b) && b(j)<a(i), j=j+1; end
    if i<numel(a), intervalEnd=min(a(i)+range,a(i+1)); else, intervalEnd=a(i)+range; end
    k=j;
    while k<=numel(b) && b(k)<=intervalEnd, k=k+1; end
    if k>j
        ibCell{i}=(j:k-1).'; iaCell{i}=repmat(i,k-j,1);
    end
    j=k;
end
ia=vertcat(iaCell{:}); ib=vertcat(ibCell{:});
end

function [ia,ib] = nearestNeighbor(a,b,range,allowReuse)
%NEARESTNEIGHBOR 按 Start 时间顺序选择绝对时间差最小的 Stop。
%   allowReuse=false 时，已选 Stop 不再参与后续 Start 的最近邻比较。
%   时间差相同时选择时间更早的 Stop，使结果可重复。
ia=zeros(0,1); ib=zeros(0,1);
if isempty(a) || isempty(b), return; end
used=false(size(b)); left=1; right=0;
for i=1:numel(a)
    while left<=numel(b) && b(left)<a(i)-range, left=left+1; end
    right=max(right,left-1);
    while right+1<=numel(b) && b(right+1)<=a(i)+range, right=right+1; end
    candidates=(left:right).';
    if ~allowReuse, candidates=candidates(~used(candidates)); end
    if isempty(candidates), continue; end
    [~,position]=min(abs(b(candidates)-a(i)));
    selected=candidates(position);
    ia(end+1,1)=i; ib(end+1,1)=selected; %#ok<AGROW>
    if ~allowReuse, used(selected)=true; end
end
end

function [ia,ib] = greedyChronological(a,b,range)
%GREEDYCHRONOLOGICAL 从最早事件开始执行时间顺序贪婪一对一匹配。
%   |A(i)-B(j)|<=range 时配对并同时推进；A 过早则丢弃 A，
%   B 过早则丢弃 B。每个事件最多使用一次。
ia=zeros(0,1); ib=zeros(0,1); i=1; j=1;
while i<=numel(a) && j<=numel(b)
    if abs(a(i)-b(j))<=range
        ia(end+1,1)=i; ib(end+1,1)=j; %#ok<AGROW>
        i=i+1; j=j+1;
    elseif a(i)<b(j)-range
        i=i+1;
    else
        j=j+1;
    end
end
end
