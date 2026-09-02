function h = buildHistogram(matches, p)
%BUILDHISTOGRAM 构建时间差直方图并估计峰中心和宽度。
%   maximum 使用最大 bin 附近的加权质心；gaussian 使用 fminsearch 对局部
%   峰进行“常数背景 + Gaussian”拟合。两种模式都返回 sigma 和 FWHM，供
%   自动符合窗口使用。该实现只依赖 MATLAB 基础函数。

lo=p.algorithm.histRange(1); hi=p.algorithm.histRange(2); bw=p.algorithm.binWidth;
span=hi-lo;
ratio=span/bw;
% 当范围与 bin 宽理论上整除时，浮点除法可能得到 200+ε；直接 ceil 会
% 错误地产生 201 个 bin。先将机器精度范围内的近整数归一为整数。
nearestInteger=round(ratio);
ratioTolerance=64*eps(max(1,abs(ratio)));
if abs(ratio-nearestInteger)<=ratioTolerance
    nBins=max(1,nearestInteger);
else
    % 不能整除时使用一个完整宽度的末 bin 覆盖上限，而不压缩所有 bin。
    nBins=max(1,ceil(ratio));
end
% 必须按用户指定的 bw 逐项构造边界；linspace(lo,hi,...) 会重新等分范围，
% 从而改变实际 bin 宽。非整除情况下最后一个边界可能略高于 hi，但每个
% bin 的宽度都严格保持为用户设置值。
edges=lo+(0:nBins)*bw;
counts = histcounts(matches.deltaT,edges);
centers = (edges(1:end-1)+edges(2:end))/2;

peak=(lo+hi)/2; sigma=NaN; fitCounts=nan(size(counts));
if ~isempty(counts) && max(counts)>0
    [maxCount,k]=max(counts);
    background=median(counts);
    signal=max(counts-background,0);
    % 半高区域用于给峰宽和 Gaussian 优化提供稳定初值。
    halfLevel=background+0.5*max(maxCount-background,0);
    left=k; right=k;
    while left>1 && counts(left-1)>=halfLevel, left=left-1; end
    while right<numel(counts) && counts(right+1)>=halfLevel, right=right+1; end
    fwhm0=max(bw,edges(right+1)-edges(left));
    sigma0=max(bw/2.355,fwhm0/2.355);

    if p.algorithm.peakMethod=="gaussian"
        % 拟合区至少覆盖峰两侧 4 个初始 FWHM，并限制在直方图边界内。
        fitMask=abs(centers-centers(k))<=max(4*fwhm0,8*bw);
        x=centers(fitMask); y=counts(fitMask);
        scale=max(max(y),1);
        theta0=[log(max(maxCount-background,1)),centers(k),log(sigma0),background];
        objective=@(th)sum((exp(th(1)).*exp(-0.5*((x-th(2))/exp(th(3))).^2)+th(4)-y).^2)/scale^2;
        options=optimset('Display','off','MaxIter',1000,'MaxFunEvals',3000);
        theta=fminsearch(objective,theta0,options);
        candidateSigma=exp(theta(3));
        if isfinite(theta(2)) && isfinite(candidateSigma) && candidateSigma>=bw/10 && candidateSigma<(hi-lo)
            peak=theta(2); sigma=candidateSigma;
            fitCounts=exp(theta(1)).*exp(-0.5*((centers-peak)/sigma).^2)+theta(4);
        end
    end

    % 最大值模式或 Gaussian 拟合失败时使用局部背景扣除加权质心。
    if ~isfinite(sigma)
        neighborhood=max(1,left-2):min(numel(counts),right+2);
        w=signal(neighborhood);
        if sum(w)>0, peak=sum(centers(neighborhood).*w)/sum(w); else, peak=centers(k); end
        sigma=sigma0;
    end
end

h=struct("edges",edges,"centers",centers,"counts",counts,"peak",peak, ...
    "sigma",sigma,"fwhm",2*sqrt(2*log(2))*sigma,"fitCounts",fitCounts, ...
    "peakMethod",p.algorithm.peakMethod);
end
