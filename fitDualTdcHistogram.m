function h=fitDualTdcHistogram(counts,edges,p)
%FITDUALTDCHISTOGRAM Gaussian + constant background fit in ps coordinates.
centers=(edges(1:end-1)+edges(2:end))/2; bw=p.algorithm.binWidth;
h=struct('counts',counts,'edges',edges,'centers',centers,'peak',NaN, ...
    'sigma',NaN,'fwhm',NaN,'fitCounts',nan(size(counts)), ...
    'peakBin',NaN,'fitStatus',"NO_PEAK");
if isempty(counts) || max(counts)==0, return; end
[height,k]=max(counts); h.peakBin=k; background=median(counts);
left=k; right=k; half=background+(height-background)/2;
while left>1 && counts(left-1)>=half, left=left-1; end
while right<numel(counts) && counts(right+1)>=half, right=right+1; end
sigma0=max(bw,(right-left+1)*bw/2.355);
mask=abs(centers-centers(k))<=max(4*2.355*sigma0,10*bw);
x=(centers(mask)-centers(k))*1e12; y=counts(mask); scale=max(y);
initial=[log(max(height-background,1)),0,log(sigma0*1e12),max(background,0)];
fun=@(t)sum((exp(t(1))*exp(-.5*((x-t(2))/exp(t(3))).^2)+exp(t(4))-y).^2)/scale^2;
initial(4)=log(max(background,.01));
[theta,~,flag]=fminsearch(fun,initial,optimset('Display','off','MaxIter',1500,'MaxFunEvals',4000));
sigma=exp(theta(3))*1e-12; peak=centers(k)+theta(2)*1e-12;
if flag>0 && isfinite(sigma) && sigma>=bw/10 && sigma<diff(p.algorithm.histRange)/4 && ...
        abs(peak-centers(k))<=max(4*sigma0,5*bw)
    h.peak=peak; h.sigma=sigma; h.fwhm=2*sqrt(2*log(2))*sigma;
    h.fitCounts=exp(theta(1))*exp(-.5*((centers-peak)/sigma).^2)+exp(theta(4));
    h.fitStatus="GAUSSIAN";
else
    h.peak=centers(k); h.fitStatus="FIT_FAILED";
end
end
