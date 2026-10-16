function time=poissonScenarioTimes(rate,T,s)
%POISSONSCENARIOTIMES Exact thinning of a bounded deterministic rate profile.
if rate<=0, time=zeros(0,1); return; end
peak=rate;
if s.backgroundMode~="constant", peak=rate*(1+s.backgroundAmplitude); end
time=zeros(0,1); last=0; batch=max(1024,ceil(peak*T+8*sqrt(peak*T)));
while true
    candidate=last+cumsum(-log(max(rand(batch,1),realmin))/peak);
    inside=candidate<=T; candidate=candidate(inside);
    x=candidate/T; amplitude=s.backgroundAmplitude;
    switch string(s.backgroundMode)
        case "constant", profile=ones(size(x));
        case "step", profile=1+amplitude*(2*(x>=.5)-1);
        case "linear", profile=1+amplitude*(2*x-1);
        case "sinusoidal", profile=1+amplitude*sin(2*pi*candidate/s.backgroundPeriod);
        otherwise, error('CoincidenceSim:ScenarioMode','Unknown background rate profile.');
    end
    keep=rand(size(candidate))<rate*profile/peak; time=[time;candidate(keep)]; %#ok<AGROW>
    if ~all(inside), break; end
    last=candidate(end);
end
end
