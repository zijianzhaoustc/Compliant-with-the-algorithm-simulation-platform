function j = validateJointFitParams(j)
%VALIDATEJOINTFITPARAMS 校验联合无分箱点估计参数，时间单位为秒。
if ~(islogical(j.enabled) || isnumeric(j.enabled)) || ~isscalar(j.enabled) || ...
        ~isreal(j.enabled) || ~isfinite(j.enabled) || ~ismember(j.enabled,[0 1])
    error('CoincidenceSim:InvalidJointFit','联合拟合开关必须为逻辑标量。');
end
if ~isscalar(string(j.primaryModel)) || ...
        ~any(string(j.primaryModel)==["gaussian","doublegaussian"])
    error('CoincidenceSim:InvalidJointFit','联合拟合模型必须为 gaussian 或 doublegaussian。');
end
for name=["initialSigma","minSigma","maxTailSigma","blockSize", ...
        "maxShapeFitPairs","streamChunkPairs"]
    x=j.(name);
    if ~isnumeric(x) || ~isreal(x) || ~isscalar(x) || ~isfinite(x) || x<=0
        error('CoincidenceSim:InvalidJointFit','联合拟合参数 %s 必须为有限正标量。',name);
    end
end
if j.minSigma>j.initialSigma || j.maxTailSigma<=j.minSigma
    error('CoincidenceSim:InvalidJointFit','最小 σ 不得超过初始 σ，尾部 σ 上限必须大于最小 σ。');
end
for name=["maxShapeFitPairs","streamChunkPairs"]
    if j.(name)~=floor(j.(name)) || j.(name)<30
        error('CoincidenceSim:InvalidJointFit','%s 必须为不小于 30 的整数。',name);
    end
end
if ~isnumeric(j.seed) || ~isreal(j.seed) || ~isscalar(j.seed) || ...
        ~isfinite(j.seed) || j.seed<0 || j.seed>2^32-1 || j.seed~=floor(j.seed)
    error('CoincidenceSim:InvalidJointFit','联合拟合种子必须为 0～4294967295 的整数。');
end
j.enabled=logical(j.enabled); j.primaryModel=string(j.primaryModel);
end
