function [out,files]=makeDualTdcSyncExample(parent)
%MAKEDUALTDCSYNCEXAMPLE Six synthetic TXT channels; never experimental data.
% Generate physical SPD events ONCE with the existing SPDC simulator.
if nargin<1, parent=fullfile(pwd,'outputs','dual_tdc_sync_examples'); end
if ~isfolder(parent), mkdir(parent); end
[~,id]=fileparts(tempname(parent)); folder=fullfile(parent,['synthetic_six_files_' id]); mkdir(folder);
s=defaultDualTdcSimulation(); original=simulateDualTdc(s);
o=defaultDualTdcOptions(); o.sync.enabled=true; o.sync.blockDuration_s=.025;
o.sync.declaredAcquisition_s=s.physical.measurementTime;
sync=(0:round(s.physical.measurementTime*o.sync.nominalFrequency_Hz)-1)'/o.sync.nominalFrequency_Hz;
data=original.data;
data.Fsync=s.F.offset_s+(1+s.F.clockPpm*1e-6)*sync;
data.Ssync=s.S.offset_s+(1+s.S.clockPpm*1e-6)*sync;
names={'F1','F2','Fsync','S1','S2','Ssync'}; files=struct();
for k=1:numel(names)
    name=names{k}; files.(name)=fullfile(folder,[name '.txt']);
    writematrix(round(data.(name)*1e12),files.(name),'Delimiter','tab');
end
out=importDualTdcSixFiles(files.F1,files.F2,files.Fsync,files.S1,files.S2,files.Ssync,1e-12,o);
% Score by eventID only AFTER analysis, never supply truth to the aligner.
truth=table();
for ch=1:2
    c=out.alignment.(sprintf('channel%d',ch));
    f=original.simulation.(sprintf('truthF%d',ch)); ss=original.simulation.(sprintf('truthS%d',ch));
    correct=NaN; precision=NaN;
    if c.status=="ALIGNED"
        correct=nnz(f.eventID(c.indexF)==ss.eventID(c.indexS)); precision=correct/max(1,c.commonCount);
    end
    truth=[truth;table(ch,c.commonCount,correct,precision,'VariableNames', ...
        {'SPD_channel','associated_count','eventID_correct_count','association_precision'})]; %#ok<AGROW>
end
writeUtf8BomTable(truth,fullfile(folder,'SYNTHETIC_eventID_validation.csv'));
settings=o; simulationSettings=s; save(fullfile(folder,'synthetic_settings.mat'),'settings','simulationSettings');
files.folder=folder; files.results=exportDualTdcResults(out,folder);
end
