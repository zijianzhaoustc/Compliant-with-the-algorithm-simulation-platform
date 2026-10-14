function batch = runPaperSimulations(mode, groups, outputRoot, experimentFilter)
%RUNPAPERSIMULATIONS Reproducible A-D batch runner for the paper study.
%   Every physical configuration/seed is simulated once. Window scans,
%   peak-center choices and P/SW/TS estimators reuse that timestamp stream.
%   Existing run directories are never overwritten.

if nargin<1, mode="smoke"; end
if nargin<2, groups=[]; end
if nargin<3 || strlength(string(outputRoot))==0
    outputRoot=fullfile(pwd,'outputs','paper_simulations');
end
if nargin<4, experimentFilter=[]; end
mode=string(mode); outputRoot=char(outputRoot);
configs=paperSimulationConfigs(mode,groups);
if ~isempty(experimentFilter)
    requested=string(experimentFilter);
    configs=configs(ismember([configs.experimentID],requested) | ...
        ismember([configs.configID],requested));
end
ensurePaperFolders(outputRoot);
revision=gitRevision();
batchID=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));

manifestRows=repmat(manifestTemplate(),0,1);
for i=1:numel(configs)
    c=configs(i); h=parameterHash(c.params);
    r=manifestTemplate(); r.experiment_id=c.experimentID; r.group_id=c.groupID;
    r.config_id=c.configID; r.param_hash=h; r.mode=mode;
    r.seeds=strjoin(string(c.seeds),';'); r.windows_ns=strjoin(string(c.windows*1e9),';');
    r.parameters_json=string(jsonencode(c.params)); manifestRows(end+1,1)=r; %#ok<AGROW>
end
configTable=struct2table(manifestRows);
writeUtf8BomTable(configTable,fullfile(outputRoot,'manifests','configurations.csv'));

runRows=repmat(runTemplate(),0,1); allRows=repmat(metricTemplate(),0,1);
for i=1:numel(configs)
    c=configs(i);
    for seed=c.seeds
        p=c.params; p.seed=seed; hash=parameterHash(p);
        runName=sprintf('%s__seed%03d__%s__%s',char(c.configID),seed,char(extractBefore(hash,9)),batchID);
        runDir=uniqueRunDirectory(fullfile(outputRoot,'runs'),runName);
        mkdir(runDir); started=datetime('now','TimeZone','local'); timer=tic;
        rr=runTemplate(); rr.experiment_id=c.experimentID; rr.config_id=c.configID;
        rr.seed=seed; rr.param_hash=hash; rr.run_id=string(runName);
        rr.run_directory=string(runDir); rr.started_at=string(started);
        try
            out=runSimulation(p);
            rows=evaluateConfiguration(out,c,revision,hash);
            writeUtf8BomTable(struct2table(rows),fullfile(runDir,'metrics.csv'));
            writeUtf8BomTable(struct2table(rows),fullfile(runDir,'window_sweep.csv'));
            exportFpHistogram(out,c,hash,runDir);
            settings=p; config=c; %#ok<NASGU>
            save(fullfile(runDir,'settings.mat'),'settings','config');
            rr.status="OK"; rr.N_generated=numel(out.source.time);
            rr.events_A=numel(out.A.time); rr.events_B=numel(out.B.time);
            rr.match_pairs=numel(out.matches.deltaT);
            allRows=[allRows; rows(:)]; %#ok<AGROW>
        catch problem
            rr.status="ERROR"; rr.error_message=string(getReport(problem,'extended','hyperlinks','off'));
            writeText(fullfile(runDir,'run_error.txt'),rr.error_message);
        end
        rr.elapsed_s=toc(timer); rr.completed_at=string(datetime('now','TimeZone','local'));
        writeRunLog(runDir,rr,revision,mode);
        runRows(end+1,1)=rr; %#ok<AGROW>
    end
end

runsTable=struct2table(runRows);
writeUtf8BomTable(runsTable,fullfile(outputRoot,'manifests',"runs_"+batchID+".csv"));
if ~isempty(allRows)
    rawTable=struct2table(allRows);
    rawFile=fullfile(outputRoot,'summaries',"all_runs_raw_"+batchID+".csv");
    writeUtf8BomTable(rawTable,rawFile);
else
    rawFile="";
end
batch=struct('batchID',string(batchID),'mode',mode,'outputRoot',string(outputRoot), ...
    'runs',runsTable,'rawFile',string(rawFile));
end

function rows=evaluateConfiguration(out,c,revision,hash)
rows=repmat(metricTemplate(),0,1);
if ismember(c.groupID,["C","D"])
    estimators=["theory","side-window","time-shift"];
    timeShiftCache=buildTimeShiftCache(out);
else
    estimators="theory";
    timeShiftCache={};
end
for centerMethod=c.peakCenters
    histResult=out.hist;
    if centerMethod=="theoretical"
        histResult.peak=(out.params.optics.B.delay+out.params.tdc.B.bias)- ...
            (out.params.optics.A.delay+out.params.tdc.A.bias);
    end
    for W=c.windows
        for estimator=estimators
            p=out.params; p.algorithm.windowMode="fixed"; p.algorithm.window=W;
            p.algorithm.accidentalMethod=estimator;
            raw=calculateRawCoincidence(out.matches,histResult,p);
            raw.matchesIsTrue=out.matches.isTrue;
            acc=estimateForBatch(out,histResult,p,timeShiftCache);
            metrics=calculateMetrics(out.A,out.B,out.matches,raw,acc,histResult,p,"simulation");
            row=buildMetricRow(out,c,p,metrics,acc,centerMethod,revision,hash);
            rows(end+1,1)=row; %#ok<AGROW>
        end
    end
end
if c.extraKind=="guard-k"
    guards=[3,10,30,60,100]*1e-9;
    for guard=guards
        p=out.params; p.algorithm.accidentalMethod="side-window";
        p.algorithm.sidebandGuard=guard; p.algorithm.sideWindowPairs=3;
        rows(end+1,1)=evaluateExtra(out,c,p,"guard",revision,hash); %#ok<AGROW>
    end
    for K=1:6
        p=out.params; p.algorithm.accidentalMethod="side-window";
        p.algorithm.sidebandGuard=3e-9; p.algorithm.sideWindowPairs=K;
        rows(end+1,1)=evaluateExtra(out,c,p,"K",revision,hash); %#ok<AGROW>
    end
end
end

function cache=buildTimeShiftCache(out)
p=out.params; count=p.algorithm.timeShiftCount; cache=cell(count,1);
offsets=p.algorithm.timeShiftStart+(0:count-1)'*p.algorithm.timeShiftStep;
for k=1:count
    shifted=out.B; shifted.time=mod(out.B.time+offsets(k),p.measurementTime);
    [shifted.time,order]=sort(shifted.time);
    shifted.pairID=zeros(size(shifted.pairID(order))); shifted.type=shifted.type(order);
    cache{k}=matchCoincidences(out.A,shifted,p);
end
end

function acc=estimateForBatch(out,histResult,p,cache)
if p.algorithm.accidentalMethod~="time-shift"
    acc=estimateAccidentals(out.A,out.B,out.matches,histResult,p); return
end
offsets=p.algorithm.timeShiftStart+(0:p.algorithm.timeShiftCount-1)'*p.algorithm.timeShiftStep;
counts=zeros(numel(cache),1);
for k=1:numel(cache), raw=calculateRawCoincidence(cache{k},histResult,p); counts(k)=raw.count; end
acc=struct('rate',mean(counts)/p.measurementTime, ...
    'countEquivalent',mean(counts),'method',"time-shift", ...
    'details',sprintf("mean of %d cached circular time shifts",numel(cache)), ...
    'sampleOffsets',offsets,'sampleCounts',counts);
end

function row=evaluateExtra(out,c,p,label,revision,hash)
raw=calculateRawCoincidence(out.matches,out.hist,p); raw.matchesIsTrue=out.matches.isTrue;
acc=estimateAccidentals(out.A,out.B,out.matches,out.hist,p);
m=calculateMetrics(out.A,out.B,out.matches,raw,acc,out.hist,p,"simulation");
row=buildMetricRow(out,c,p,m,acc,"fitted-"+label,revision,hash);
end

function row=buildMetricRow(out,c,p,m,acc,centerMethod,revision,hash)
row=metricTemplate(); s=out.stageStats; T=p.measurementTime;
row.experiment_id=c.experimentID; row.group_id=c.groupID; row.config_id=c.configID;
row.run_mode=c.mode;
row.seed=p.seed; row.code_revision=revision; row.param_hash=hash;
row.T_s=T; row.Rpair_per_s=p.source.pairRate;
row.eta_opt_A=p.optics.A.transmission; row.eta_opt_B=p.optics.B.transmission;
row.eta_det_A=p.detector.A.efficiency; row.eta_det_B=p.detector.B.efficiency;
row.dark_A_cps=p.detector.A.darkRate; row.dark_B_cps=p.detector.B.darkRate;
row.bg_A_cps=p.detector.A.backgroundRate; row.bg_B_cps=p.detector.B.backgroundRate;
row.pap_A=p.detector.A.afterpulseProbability*double(p.detector.enableAfterpulse);
row.pap_B=p.detector.B.afterpulseProbability*double(p.detector.enableAfterpulse);
row.ap_tau_A_ns=p.detector.A.afterpulseLifetime*1e9; row.ap_tau_B_ns=p.detector.B.afterpulseLifetime*1e9;
row.detector_dt_A_ns=p.detector.A.deadTime*1e9; row.detector_dt_B_ns=p.detector.B.deadTime*1e9;
row.enable_detector_dt=p.detector.enableDeadTime;
row.tdc_dt_A_ns=p.tdc.A.deadTime*1e9; row.tdc_dt_B_ns=p.tdc.B.deadTime*1e9;
row.enable_tdc_dt=p.tdc.enableDeadTime;
row.sigma_detector_A_ps=p.detector.A.jitter*1e12; row.sigma_detector_B_ps=p.detector.B.jitter*1e12;
row.sigma_tdc_A_ps=p.tdc.A.jitter*1e12; row.sigma_tdc_B_ps=p.tdc.B.jitter*1e12;
row.q_ps=p.tdc.resolution*1e12; row.bin_ps=p.algorithm.binWidth*1e12;
row.hist_range_ns=max(abs(p.algorithm.histRange))*1e9; row.W_ns=m.WActual*1e9;
row.peak_center_method=string(centerMethod); row.peak_center_ns=m.PeakPosition*1e9;
row.estimator=string(acc.method); row.side_guard_ns=p.algorithm.sidebandGuard*1e9;
row.side_windows_requested=2*p.algorithm.sideWindowPairs;
if string(acc.method)=="side-window", row.side_windows_valid=numel(acc.sampleCounts); else, row.side_windows_valid=NaN; end
row.RA_cps=m.RA; row.RB_cps=m.RB; row.N_generated=numel(out.source.time);
row.Nrec=m.Nrec; row.Nraw=m.Nraw; row.TP=m.TP; row.FP=m.FP;
row.Nacc_est=m.Nacc; row.Nnet_signed=m.NnetSigned; row.eta_W=m.EtaW;
row.epsilon_acc=m.EpsilonAcc; row.epsilon_net_signed=m.EpsilonNetSigned;
row.g_eff=m.Geff; row.mu_proxy=m.MuProxy;
row.detector_input_count_A=s.detectorA.inputCount; row.detector_input_count_B=s.detectorB.inputCount;
row.detector_accepted_count_A=s.detectorA.acceptedCount; row.detector_accepted_count_B=s.detectorB.acceptedCount;
row.tdc_input_count_A=s.tdcA.inputCount; row.tdc_input_count_B=s.tdcB.inputCount;
row.tdc_accepted_count_A=s.tdcA.acceptedCount; row.tdc_accepted_count_B=s.tdcB.acceptedCount;
if p.detector.enableDeadTime
    row.rho_D_A=s.detectorA.inputRate*p.detector.A.deadTime;
    row.rho_D_B=s.detectorB.inputRate*p.detector.B.deadTime;
end
if p.tdc.enableDeadTime
    row.rho_T_A=s.tdcA.inputRate*p.tdc.A.deadTime;
    row.rho_T_B=s.tdcB.inputRate*p.tdc.B.deadTime;
end
row.true_sigma_ps=m.TrueSigma*1e12; row.fitted_fwhm_ps=m.FWHM*1e12;
sigmaC=sqrt(p.detector.A.jitter^2+p.detector.B.jitter^2+ ...
    double(p.tdc.enableJitter)*(p.tdc.A.jitter^2+p.tdc.B.jitter^2)+p.tdc.resolution^2/6);
row.sigma_c_theory_ps=sigmaC*1e12; row.eta_W_theory=erf(m.WActual/(2*sqrt(2)*sigmaC));
row.capture_theory_error=m.EtaW-row.eta_W_theory;
row.status="OK"; warnings=strings(0,1);
if m.FP==0, warnings(end+1)="FP=0: epsilon_acc undefined"; end %#ok<AGROW>
if m.TP==0, warnings(end+1)="TP=0: epsilon_net undefined"; end %#ok<AGROW>
if string(acc.method)=="side-window" && isempty(acc.sampleCounts)
    warnings(end+1)="no valid side windows"; row.status="INVALID"; %#ok<AGROW>
end
row.warnings=strjoin(warnings,'; ');
end

function exportFpHistogram(out,c,hash,runDir)
edges=out.hist.edges; centers=(edges(1:end-1)+edges(2:end))/2;
allCounts=histcounts(out.matches.deltaT,edges).';
tpCounts=histcounts(out.matches.deltaT(out.matches.isTrue),edges).';
fpCounts=histcounts(out.matches.deltaT(~out.matches.isTrue),edges).';
expected=out.metrics.RA*out.metrics.RB*out.params.measurementTime*diff(edges(:));
t=table(repmat(c.experimentID,numel(centers),1),repmat(string(hash),numel(centers),1), ...
    centers(:)*1e9,allCounts,tpCounts,fpCounts,expected, ...
    'VariableNames',{'experiment_id','param_hash','lag_ns','all_pairs_counts','TP_counts','FP_counts','flat_prediction_counts'});
writeUtf8BomTable(t,fullfile(runDir,'fp_histogram.csv'));
end

function t=metricTemplate()
t=struct('experiment_id',"",'group_id',"",'config_id',"",'seed',NaN, ...
 'run_mode',"",'code_revision',"",'param_hash',"",'T_s',NaN,'Rpair_per_s',NaN, ...
 'eta_opt_A',NaN,'eta_opt_B',NaN,'eta_det_A',NaN,'eta_det_B',NaN, ...
 'dark_A_cps',NaN,'dark_B_cps',NaN,'bg_A_cps',NaN,'bg_B_cps',NaN, ...
 'pap_A',NaN,'pap_B',NaN,'ap_tau_A_ns',NaN,'ap_tau_B_ns',NaN, ...
 'detector_dt_A_ns',NaN,'detector_dt_B_ns',NaN,'enable_detector_dt',false, ...
 'tdc_dt_A_ns',NaN,'tdc_dt_B_ns',NaN,'enable_tdc_dt',false, ...
 'sigma_detector_A_ps',NaN,'sigma_detector_B_ps',NaN, ...
 'sigma_tdc_A_ps',NaN,'sigma_tdc_B_ps',NaN,'q_ps',NaN,'bin_ps',NaN, ...
 'hist_range_ns',NaN,'W_ns',NaN,'peak_center_method',"",'peak_center_ns',NaN, ...
 'estimator',"",'side_guard_ns',NaN,'side_windows_requested',NaN, ...
 'side_windows_valid',NaN,'RA_cps',NaN,'RB_cps',NaN,'N_generated',NaN, ...
 'Nrec',NaN,'Nraw',NaN,'TP',NaN,'FP',NaN,'Nacc_est',NaN,'Nnet_signed',NaN, ...
 'eta_W',NaN,'epsilon_acc',NaN,'epsilon_net_signed',NaN,'g_eff',NaN, ...
 'mu_proxy',NaN,'rho_D_A',0,'rho_D_B',0,'rho_T_A',0,'rho_T_B',0, ...
 'detector_input_count_A',NaN,'detector_input_count_B',NaN, ...
 'detector_accepted_count_A',NaN,'detector_accepted_count_B',NaN, ...
 'tdc_input_count_A',NaN,'tdc_input_count_B',NaN, ...
 'tdc_accepted_count_A',NaN,'tdc_accepted_count_B',NaN, ...
 'true_sigma_ps',NaN,'fitted_fwhm_ps',NaN,'sigma_c_theory_ps',NaN, ...
 'eta_W_theory',NaN,'capture_theory_error',NaN,'status',"",'warnings',"");
end

function t=manifestTemplate()
t=struct('experiment_id',"",'group_id',"",'config_id',"",'param_hash',"", ...
    'mode',"",'seeds',"",'windows_ns',"",'parameters_json',"");
end

function t=runTemplate()
t=struct('experiment_id',"",'config_id',"",'seed',NaN,'param_hash',"", ...
    'run_id',"",'run_directory',"",'started_at',"",'completed_at',"", ...
    'elapsed_s',NaN,'N_generated',NaN,'events_A',NaN,'events_B',NaN, ...
    'match_pairs',NaN,'status',"",'error_message',"");
end

function ensurePaperFolders(root)
folders={root,fullfile(root,'manifests'),fullfile(root,'runs'), ...
    fullfile(root,'summaries'),fullfile(root,'figures'),fullfile(root,'report')};
for k=1:numel(folders), if ~isfolder(folders{k}), mkdir(folders{k}); end, end
end

function folder=uniqueRunDirectory(parent,name)
folder=fullfile(parent,name); suffix=1;
while isfolder(folder), folder=fullfile(parent,sprintf('%s__%02d',name,suffix)); suffix=suffix+1; end
end

function revision=gitRevision()
[status,text]=system('git rev-parse --short HEAD');
if status==0, revision=strtrim(string(text)); else, revision="UNKNOWN"; end
end

function hash=parameterHash(value)
payload=unicode2native(jsonencode(value),'UTF-8');
digest=java.security.MessageDigest.getInstance('SHA-256'); digest.update(payload);
bytes=typecast(digest.digest(),'uint8'); hash=lower(string(reshape(dec2hex(bytes,2).',1,[])));
end

function writeRunLog(runDir,row,revision,mode)
textValue=sprintf(['mode=%s\nrevision=%s\nstatus=%s\nelapsed_s=%.6f\n' ...
    'N_generated=%g\nevents_A=%g\nevents_B=%g\nmatch_pairs=%g\n'], ...
    mode,revision,row.status,row.elapsed_s,row.N_generated,row.events_A,row.events_B,row.match_pairs);
writeText(fullfile(runDir,'run_log.txt'),textValue);
end

function writeText(filename,value)
fid=fopen(filename,'w','n','UTF-8');
if fid<0, error('PaperSimulation:Write','Cannot write %s.',filename); end
cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s',char(value)); clear cleanup
end
