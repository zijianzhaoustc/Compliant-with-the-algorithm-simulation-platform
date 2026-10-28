function seeds = buildSeedSequence(startSeed, step, count)
%BUILDSEEDSEQUENCE 生成 MATLAB twister 支持的整数种子等差序列。
validateattributes(startSeed,{'numeric'},{'scalar','real','finite','integer','>=',0,'<=',2^32-1});
validateattributes(step,{'numeric'},{'scalar','real','finite','integer','nonzero'});
validateattributes(count,{'numeric'},{'scalar','real','finite','integer','>=',1,'<=',1e6});
last=double(startSeed)+double(step)*(double(count)-1);
if ~isfinite(last) || last<0 || last>2^32-1
    error('CoincidenceSim:InvalidSeedRange','种子序列必须全部位于 0 到 4294967295 之间。');
end
seeds=double(startSeed)+(0:double(count)-1)'*double(step);
end
