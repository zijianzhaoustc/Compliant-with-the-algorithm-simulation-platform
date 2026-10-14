function configs = paperSimulationConfigs(mode, groups)
%PAPERSIMULATIONCONFIGS Build explicit A-D paper simulation configurations.
%   CONFIGS = PAPERSIMULATIONCONFIGS("smoke") returns one representative
%   physical configuration for every required experiment ID. "full" returns
%   the prescribed scans. Window/estimator variants are intentionally stored
%   on each physical configuration so one timestamp stream is reused.

if nargin<1, mode="smoke"; end
if nargin<2 || isempty(groups), groups=["A","B","C","D"]; end
mode=string(mode); groups=upper(string(groups));
if ~ismember(mode,["smoke","full"])
    error('PaperSimulation:Mode','mode must be "smoke" or "full".');
end

base=paperBaseParams();
if mode=="smoke"
    base.measurementTime=.02;
    seeds=1;
else
    seeds=1:10;
end
template=struct('experimentID',"",'groupID',"",'configID',"", ...
    'params',base,'windows',3e-9,'peakCenters',"fitted", ...
    'seeds',seeds,'extraKind',"none",'mode',mode);
configs=repmat(template,0,1);

    function add(id,group,variant,p,windows,centers,extra)
        c=template; c.experimentID=string(id); c.groupID=string(group);
        c.configID=string(id)+"__"+string(variant); c.params=p;
        c.windows=windows(:).'; c.peakCenters=string(centers);
        c.extraKind=string(extra); configs(end+1,1)=c; %#ok<AGROW>
    end

if ismember("A",groups)
    widths=[.1:.1:2,3,4]*1e-9;
    for jitter=[50,150,300]
        p=base; p.detector.A.jitter=jitter*1e-12; p.detector.B.jitter=jitter*1e-12;
        add("A-J"+jitter,"A","J"+jitter,p,widths,["theoretical","fitted"],"none");
    end
    tdcValues=[5,8,10,15]; if mode=="smoke", tdcValues=5; end
    for jt=tdcValues
        p=base; p.tdc.A.jitter=jt*1e-12; p.tdc.B.jitter=jt*1e-12;
        add("A-TDC-SENS","A","T"+jt,p,widths,["theoretical","fitted"],"none");
    end
end

if ismember("B",groups)
    rates=[.5,1,2,3,5,7,10]*1e6; if mode=="smoke", rates=1e6; end
    for rate=rates
        p=base; p.source.pairRate=rate;
        if mode=="full" && rate<=1e6, p.measurementTime=4; end
        add("B-RATE","B","R"+rate,p,3e-9,"fitted","none");
    end
    backgrounds=[0,5e3,2e4,5e4,1e5]; if mode=="smoke", backgrounds=5e4; end
    for bg=backgrounds
        p=base; p.detector.A.backgroundRate=bg; p.detector.B.backgroundRate=bg;
        add("B-BACKGROUND","B","BG"+bg,p,3e-9,"fitted","none");
    end
    bgValues=[0,5e4]; if mode=="smoke", bgValues=5e4; end
    for bg=bgValues
        p=base; p.detector.A.backgroundRate=bg; p.detector.B.backgroundRate=bg;
        p.algorithm.histRange=[-100,100]*1e-9;
        add("B-WINDOW","B","BG"+bg,p,[.1,.3,.5,1,2,3,5,8,10,20]*1e-9,"fitted","none");
    end
    p=base; p.detector.enableDark=true; p.detector.A.darkRate=5e4; p.detector.B.darkRate=5e4;
    add("B-DARK-VS-BG","B","DARK",p,3e-9,"fitted","none");
    p=base; p.detector.A.backgroundRate=5e4; p.detector.B.backgroundRate=5e4;
    add("B-DARK-VS-BG","B","BG",p,3e-9,"fitted","none");
end

if ismember("C",groups)
    modes={"C-OFF",0,0;"C-D50",50,0;"C-D100",100,0; ...
        "C-T233",0,2.33;"C-T10",0,10;"C-BOTH",50,2.33};
    representativeIndices=1:size(modes,1);
    if mode=="full", representativeIndices=[3,5]; end
    for i=representativeIndices
        p=deadTimeParams(base,modes{i,2},modes{i,3}); p.source.pairRate=2e6;
        add(modes{i,1},"C","REP",p,3e-9,"fitted","none");
    end
    priority={"C-OFF",0,0;"C-D50",50,0;"C-T233",0,2.33;"C-BOTH",50,2.33};
    rates=[.5,1,2,5]*1e6; if mode=="smoke", rates=1e6; end
    for i=1:size(priority,1)
        for rate=rates
            p=deadTimeParams(base,priority{i,2},priority{i,3}); p.source.pairRate=rate;
            add(priority{i,1},"C","R"+rate,p,[1,3,5,10]*1e-9,"fitted","none");
        end
    end
    for i=1:size(priority,1)
        p=deadTimeParams(base,priority{i,2},priority{i,3});
        p.source.pairRate=0; p.detector.A.backgroundRate=1e6; p.detector.B.backgroundRate=1e6;
        if mode=="smoke", p.measurementTime=.1; end
        % 平坦独立流没有可寻的相关峰；必须预先固定中心，避免从噪声最大值
        % 选择窗口所造成的择峰偏差。
        add("C-INDEPENDENT","C",priority{i,1},p,3e-9,"theoretical","none");
    end
end

if ismember("D",groups)
    names=["D-BASE","D-BG50K","D-DARK50K","D-AP01","D-AP03","D-AP05","D-FULL"];
    for name=names
        p=deadTimeParams(base,50,2.33); p.algorithm.histRange=[-250,250]*1e-9;
        p.algorithm.binWidth=100e-12;
        switch name
            case "D-BG50K"
                p.detector.A.backgroundRate=5e4; p.detector.B.backgroundRate=5e4;
            case "D-DARK50K"
                p.detector.enableDark=true; p.detector.A.darkRate=5e4; p.detector.B.darkRate=5e4;
            case {"D-AP01","D-AP03","D-AP05"}
                probability=str2double(extractAfter(name,"D-AP"))/100;
                p.detector.enableAfterpulse=true;
                p.detector.A.afterpulseProbability=probability; p.detector.B.afterpulseProbability=probability;
            case "D-FULL"
                p.detector.enableDark=true; p.detector.A.darkRate=500; p.detector.B.darkRate=500;
                p.detector.A.backgroundRate=5e4; p.detector.B.backgroundRate=5e4;
                p.detector.enableAfterpulse=true;
        end
        extra="none"; if name=="D-AP05", extra="guard-k"; end
        add(name,"D","MAIN",p,3e-9,"fitted",extra);
    end
    p=base; p.detector.enableAfterpulse=true;
    p.algorithm.histRange=[-250,250]*1e-9; p.algorithm.binWidth=100e-12;
    add("D-AP05-NO-DT","D","CONTROL",p,3e-9,"fitted","none");
end
end

function p=paperBaseParams()
p=defaultParams();
p.source.mode="direct"; p.source.pairRate=1e6; p.measurementTime=2;
p.optics.A.transmission=.8; p.optics.B.transmission=.8;
p.optics.A.delay=0; p.optics.B.delay=5e-9;
p.detector.A.efficiency=.55; p.detector.B.efficiency=.55;
p.detector.A.recordEfficiency=1; p.detector.B.recordEfficiency=1;
p.detector.A.darkRate=0; p.detector.B.darkRate=0;
p.detector.A.backgroundRate=0; p.detector.B.backgroundRate=0;
p.detector.A.jitter=150e-12; p.detector.B.jitter=150e-12;
p.detector.A.deadTime=50e-9; p.detector.B.deadTime=50e-9;
p.detector.A.afterpulseProbability=.05; p.detector.B.afterpulseProbability=.05;
p.detector.A.afterpulseLifetime=50e-9; p.detector.B.afterpulseLifetime=50e-9;
p.detector.enableDark=false; p.detector.enableDeadTime=false; p.detector.enableAfterpulse=false;
p.tdc.A.jitter=10e-12; p.tdc.B.jitter=10e-12;
p.tdc.A.deadTime=2.33e-9; p.tdc.B.deadTime=2.33e-9;
p.tdc.A.bias=0; p.tdc.B.bias=0; p.tdc.resolution=10e-12;
p.tdc.enableJitter=true; p.tdc.enableDeadTime=false; p.tdc.dnl=0; p.tdc.inl=0;
p.algorithm.matchMethod="many-to-many"; p.algorithm.peakMethod="gaussian";
p.algorithm.windowMode="fixed"; p.algorithm.window=3e-9;
p.algorithm.histRange=[-50,50]*1e-9; p.algorithm.binWidth=50e-12;
p.algorithm.sidebandGuard=3e-9; p.algorithm.sideWindowPairs=3;
p.algorithm.timeShiftStart=1e-6; p.algorithm.timeShiftStep=1e-6;
p.algorithm.timeShiftCount=5; p.algorithm.accidentalMethod="theory";
end

function p=deadTimeParams(p,detectorNs,tdcNs)
p.detector.enableDeadTime=detectorNs>0;
p.detector.A.deadTime=detectorNs*1e-9; p.detector.B.deadTime=detectorNs*1e-9;
p.tdc.enableDeadTime=tdcNs>0;
p.tdc.A.deadTime=tdcNs*1e-9; p.tdc.B.deadTime=tdcNs*1e-9;
end
