function dt = sampleDetectorTiming(n,cfg)
%SAMPLEDETECTORTIMING 单通道零均值 IRF 抽样，单位为秒。
%   Gaussian 核心加可选 Bernoulli 指数延迟：G+Z*E-q*tau。
%   A/B 分别抽样，长尾不产生额外事件，也不改变 pairID。
%   Gaussian 分支保持原来的随机抽样顺序。
dt=cfg.jitter*randn(n,1);
model="gaussian";
if isfield(cfg,'timingModel'), model=string(cfg.timingModel); end
switch model
    case "gaussian"
        return
    case "gaussian-exp-tail"
        if cfg.tailFraction==0, return; end
        mask=rand(n,1)<cfg.tailFraction;
        dt(mask)=dt(mask)-cfg.tailTau*log(max(rand(nnz(mask),1),realmin));
        % 去除解析均值，保持配置的光路延迟/通道偏置的均值含义。
        dt=dt-cfg.tailFraction*cfg.tailTau;
    otherwise
        error('CoincidenceSim:InvalidTimingModel','未知探测器时间响应模型。');
end
end
