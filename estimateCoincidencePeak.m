function model = estimateCoincidencePeak(matches,p)
%ESTIMATECOINCIDENCEPEAK 固定分辨率 pilot 定位后，未分箱 Gaussian+均匀背景拟合。
% 不读取 pairID 或 isTrue。输出用于选参的模型诊断，而非精确参数标准误。
model=struct('valid',false,'peak',NaN,'sigma',NaN,'signalTotal',NaN, ...
    'backgroundDensity',NaN,'modelDeviation',NaN,'status',"insufficient-peak", ...
    'roi',[NaN NaN],'signalCounts',0);
delta=matches.deltaT(:);
if numel(delta)<p.optimization.minPeakCounts, return; end
pilot=p; pilot.algorithm.binWidth=max(p.tdc.resolution,diff(p.algorithm.histRange)/2048);
% 防止大搜索范围形成过大 pilot 数组。
pilot.algorithm.binWidth=max(pilot.algorithm.binWidth,diff(p.algorithm.histRange)/20000);
pilot.algorithm.peakMethod="maximum";
h=buildHistogram(matches,pilot);
background=median(h.counts);
% 用平滑 pilot 的半高宽初始化，避免低计数 bin 的单个凹点把 ROI 截得过窄。
smooth=conv(h.counts,[1 2 3 2 1]/9,'same');
[maximum,peakBin]=max(smooth); excess=maximum-background;
if excess<max(5*sqrt(max(1,background)),3), model.status="no-significant-peak"; return; end
left=peakBin; right=peakBin;
while left>1 && smooth(left-1)>=background+excess/2, left=left-1; end
while right<numel(smooth) && smooth(right+1)>=background+excess/2, right=right+1; end
sigma0=max([p.tdc.resolution,2*pilot.algorithm.binWidth, ...
    (h.edges(right+1)-h.edges(left))/(2*sqrt(2*log(2)))]);
h.peak=h.centers(peakBin);
radius=max(6*sigma0,8*pilot.algorithm.binWidth);
roi=[max(p.algorithm.histRange(1),h.peak-radius),min(p.algorithm.histRange(2),h.peak+radius)];
local=delta(delta>=roi(1) & delta<=roi(2));
if numel(local)<p.optimization.minPeakCounts, return; end
% 使用不同时间差及其权重，避免对大量重复量化时间差重复计算似然。
[x,~,idx]=unique((local-h.peak)/sigma0);
weights=accumarray(idx,1); edges=(roi-h.peak)/sigma0;
q0=max(.1,min(.99,1-background*diff(roi)/pilot.algorithm.binWidth/numel(local)));
start=[0,0,log(q0/(1-q0))];
options=optimset('Display','off','MaxIter',1200,'MaxFunEvals',2400,'TolX',1e-7);
[theta,~,exitflag]=fminsearch(@objective,start,options);
mu=theta(1); s=exp(theta(2)); q=1/(1+exp(-theta(3)));
normalization=normalCDF((edges(2)-mu)/s)-normalCDF((edges(1)-mu)/s);
model.peak=h.peak+mu*sigma0; model.sigma=s*sigma0;
model.roi=roi; model.signalCounts=q*numel(local);
model.signalTotal=model.signalCounts/normalization;
model.backgroundDensity=(1-q)*numel(local)/diff(roi);
% 经验 CDF 与 Gaussian+背景混合模型的距离；含离散量化的半个跳跃。
empirical=(cumsum(weights)-weights/2)/sum(weights);
fitted=q*(normalCDF((x-mu)/s)-normalCDF((edges(1)-mu)/s))/normalization ...
    +(1-q)*(x-edges(1))/diff(edges);
model.modelDeviation=max(abs(empirical-fitted));
outside=abs(h.centers-model.peak)>max(4*model.sigma,2*pilot.algorithm.binWidth);
competing=any(h.counts(outside)-background>max(5*sqrt(max(1,background)),.25*excess));
if exitflag<=0 || ~isfinite(model.sigma) || model.sigma<p.tdc.resolution/2 || ...
        model.signalCounts<p.optimization.minPeakCounts || q<.1
    model.status="unresolved-or-weak-peak";
elseif model.peak-4*model.sigma<p.algorithm.histRange(1) || ...
        model.peak+4*model.sigma>p.algorithm.histRange(2)
    model.status="peak-at-search-boundary";
elseif model.modelDeviation>p.optimization.maxModelDeviation
    model.status="non-gaussian-or-multiple-peaks";
elseif competing
    model.status="multiple-peaks-or-long-tail";
else
    model.valid=true; model.status="ok";
end

    function loss=objective(th)
        meanValue=th(1); spread=exp(th(2)); fraction=1/(1+exp(-th(3)));
        if ~all(isfinite(th)) || abs(meanValue)>2 || spread<.1 || spread>3 || abs(th(3))>30
            loss=1e30; return
        end
        z=normalCDF((edges(2)-meanValue)/spread)-normalCDF((edges(1)-meanValue)/spread);
        density=fraction*exp(-.5*((x-meanValue)/spread).^2)/(sqrt(2*pi)*spread*z) ...
            +(1-fraction)/diff(edges);
        loss=-sum(weights.*log(max(realmin,density)))/sum(weights);
    end
end

function y=normalCDF(x)
y=.5*(1+erf(x/sqrt(2)));
end
