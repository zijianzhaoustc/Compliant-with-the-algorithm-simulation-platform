function fit=fitIntegratedCoincidencePeak(h,p)
%FITINTEGRATEDCOINCIDENCEPEAK Unlabelled bin-integrated Gaussian+constant MLE.
% theta=[log(area), centered mean/binWidth, log(sigma/binWidth), log(bg/bin)].
fit=struct('status',"NO_PEAK",'mu',NaN,'sigma',NaN,'area',NaN,'backgroundDensity',NaN, ...
    'residualScore',NaN,'exitFlag',NaN,'message',"No counts",'theta',nan(1,4), ...
    'covTheta',nan(4),'jacobian',zeros(0,4),'expected',[],'counts',[],'edges',[], ...
    'origin',NaN,'scale',p.algorithm.binWidth,'fitBounds',[NaN NaN]);
if ~any(h.counts>0), return; end
bw=p.algorithm.binWidth; [~,peakBin]=max(h.counts); origin=h.centers(peakBin);
sigma0=h.sigma; if ~isfinite(sigma0), sigma0=bw; end
mask=abs(h.centers-origin)<=max(8*bw,6*sigma0);
mask=mask & h.edges(2:end)<=p.algorithm.histRange(2)+64*eps(abs(p.algorithm.histRange(2)));
indices=find(mask);
if numel(indices)<5, fit.status="FIT_FAILED"; fit.message="Too few complete fit bins"; return; end
edges=h.edges(indices(1):indices(end)+1); x=(edges-origin)/bw; y=double(h.counts(indices));
background=max(median(y),.05); area=max(sum(max(y-background,0)),1);
start=[log(area),0,log(max(sigma0/bw,.5)),log(background)];
options=optimset('Display','off','MaxIter',1600,'MaxFunEvals',5000,'TolX',1e-7,'TolFun',1e-7);
[theta,~,exitflag,output]=fminsearch(@objective,start,options);
lambda=model(theta); sig=exp(theta(3))*bw; mu=origin+theta(2)*bw;
fit.status="FIT_FAILED"; fit.exitFlag=exitflag; fit.message=string(output.message);
if exitflag<=0 || any(~isfinite(lambda)) || sig<bw/20 || sig>diff(edges([1 end])) || mu<edges(1) || mu>edges(end), return; end
fit.status="FIT_OK"; fit.mu=mu; fit.sigma=sig; fit.area=exp(theta(1));
fit.backgroundDensity=exp(theta(4))/bw; fit.theta=theta; fit.origin=origin;
fit.edges=edges; fit.expected=lambda; fit.counts=y; fit.fitBounds=edges([1 end]);
J=zeros(numel(y),4);
for j=1:4
    d=zeros(1,4); d(j)=1e-4;
    J(:,j)=((model(theta+d)-model(theta-d))/(2e-4))';
end
information=J'*(J./max(lambda(:),1e-12));
fit.covTheta=pinv(information); fit.jacobian=J;
terms=lambda-y; positive=y>0; terms(positive)=terms(positive)+y(positive).*log(y(positive)./lambda(positive));
fit.residualScore=2*sum(terms)/max(numel(y)-4,1);

    function expected=model(t)
        expected=exp(t(1))*gaussianIntervalProbability(x(1:end-1),x(2:end),t(2),exp(t(3)))+exp(t(4))*diff(x);
        expected=max(expected,realmin);
    end
    function loss=objective(t)
        if any(~isfinite(t)) || t(1)>35 || abs(t(2))>max(abs(x))*2 || t(3)<log(.02) || t(3)>log(max(diff(x([1 end])),1)*2) || abs(t(4))>45
            loss=1e100; return
        end
        expected=model(t); loss=sum(expected-y.*log(expected));
        if ~isfinite(loss), loss=1e100; end
    end
end
