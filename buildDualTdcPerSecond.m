function result=buildDualTdcPerSecond(out)
%BUILDDUALTDCPERSECOND Half-open A-owned blocks; include cross-boundary B pairs.
% Each coincidence belongs to its channel-1 event's block, exactly once.
o=out.options; block=1; % Physical one-second diagnostics, independent of model blocks.
rows=cell(0,15);
for device={'F','S'}
    name=device{1}; a=out.data.([name '1']); b=out.data.([name '2']);
    lo=floor(min(a(1),b(1))/block)*block; hi=max(a(end),b(end));
    count=max(1,ceil((hi-lo)/block)); ai=1; bi=1;
    for k=1:count
        start=lo+(k-1)*block; stop=min(lo+k*block,hi); last=k==count;
        astart=ai; while ai<=numel(a) && (a(ai)<stop || (last && a(ai)<=stop)), ai=ai+1; end
        bstart=bi; while bi<=numel(b) && (b(bi)<stop || (last && b(bi)<=stop)), bi=bi+1; end
        aa=a(astart:ai-1); ownB=bstart:bi-1;
        left=lower(b,start+o.histRange(1)); right=lower(b,stop+o.histRange(2)+eps(stop));
        context=struct('rateCounts',[numel(aa),numel(ownB)],'shiftB',b(ownB),'origin_s',start);
        r=analyzeDualTdcDevice(aa,b(left:right-1),o,max(stop-start,eps),context);
        syncCount=NaN;
        if isfield(out.data,[name 'sync'])
            sy=out.data.([name 'sync']); l=lower(sy,start); u=lower(sy,stop);
            if last, u=lower(sy,stop+eps(stop)); end
            syncCount=u-l;
        end
        residual=NaN;
        if name=='F' && ismember(out.status,["ALIGNED","PARTIAL"])
            values=[];
            for ch=1:2
                c=out.alignment.(sprintf('channel%d',ch));
                keep=c.timeF_s>=start & c.timeF_s<stop;
                if last, keep=keep | c.timeF_s==stop; end
                values=[values;c.residual_s(keep)]; %#ok<AGROW>
            end
            if ~isempty(values), residual=std(values)*1e12; end
        end
        rows(end+1,:)={string(name),start,stop,numel(aa),numel(ownB), ...
            numel(aa)/max(stop-start,eps),numel(ownB)/max(stop-start,eps), ...
            syncCount/max(stop-start,eps),r.metrics.Nraw,r.metrics.NnetSigned, ...
            r.metrics.peak_ps,r.metrics.sigma_ps,r.metrics.FWHM_ps,residual,r.metrics.status}; %#ok<AGROW>
    end
end
result=cell2table(rows,'VariableNames',{'device','start_s','end_s','channel1_count','channel2_count', ...
    'channel1_rate_cps','channel2_rate_cps','sync_rate_cps','Nraw_count','Nnet_signed_count', ...
    'peak_ps','sigma_ps','FWHM_ps','relative_residual_sigma_ps','qa_flag'});
result.Nacc_count=result.Nraw_count-result.Nnet_signed_count;
cfg=dualTdcAccidentalOptions(o); result.accidental_method=repmat(cfg.method,height(result),1);
end

function i=lower(v,t)
l=1; r=numel(v)+1;
while l<r
    m=floor((l+r)/2); if v(m)<t, l=m+1; else, r=m; end
end
i=l;
end
