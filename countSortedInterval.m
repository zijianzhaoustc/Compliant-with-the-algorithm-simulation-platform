function count = countSortedInterval(x,lower,upper,includeUpper)
%COUNTSORTEDINTERVAL 在已排序原始时间差上二分计数，不受直方图 bin 影响。
if nargin<4, includeUpper=true; end
count=bound(upper,includeUpper)-bound(lower,false);
    function index=bound(value,inclusive)
        lo=1; hi=numel(x)+1;
        while lo<hi
            mid=floor((lo+hi)/2);
            if x(mid)<value || (inclusive && x(mid)==value)
                lo=mid+1;
            else
                hi=mid;
            end
        end
        index=lo;
    end
end
