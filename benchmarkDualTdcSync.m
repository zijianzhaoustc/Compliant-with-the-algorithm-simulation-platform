function [result,out]=benchmarkDualTdcSync(n)
%BENCHMARKDUALTDCSYNC Whole six-stream MHz SPD + multi-million SYNC benchmark.
% Process lifetime peak is conservative, not an isolated allocation profiler.
if nargin<1, n=3000000; end
validateattributes(n,{'numeric'},{'scalar','integer','positive'});
state=rng; cleanup=onCleanup(@()rng(state)); rng(1714);
f=cumsum(-log(rand(n,1))/1e6); g=f+5e-9+100e-12*randn(n,1);
data=struct('F1',f,'F2',sort(g),'S1',.1+1.000025*f+30e-9, ...
    'S2',sort(.1+1.000025*g+30.07e-9));
data.Fsync=(0:ceil(max(f(end),g(end))*500000))'*2e-6;
data.Ssync=.1+1.000025*data.Fsync;
o=defaultDualTdcOptions(); o.sync.enabled=true; o.maxResidentBytes=4e9;
process=System.Diagnostics.Process.GetCurrentProcess(); process.Refresh(); initial=double(process.WorkingSet64);
timer=tic; out=analyzeDualTdc(data,o); elapsed=toc(timer);
process.Refresh(); peak=double(process.PeakWorkingSet64); current=double(process.WorkingSet64);
result=table(n,numel(data.Fsync),4*n+2*numel(data.Fsync),elapsed,initial,peak,current, ...
    out.status,out.sync.model.relativeClockPpm,out.F.metrics.rate1_cps, ...
    out.F.histogram.maxPairScratchCount,o.maxPairChunk, ...
    'VariableNames',{'SPD_events_per_channel','SYNC_events_per_device','timestamp_total', ...
    'elapsed_s','initial_working_set_bytes','process_lifetime_peak_working_set_bytes','final_working_set_bytes', ...
    'alignment_status','relative_clock_ppm','F1_rate_cps','max_pair_scratch_count','pair_chunk_limit'});
result.reason=string(out.alignment.reason);
assert(out.F.histogram.maxPairScratchCount<=o.maxPairChunk);
clear cleanup
end
