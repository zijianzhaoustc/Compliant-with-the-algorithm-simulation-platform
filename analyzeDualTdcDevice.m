function result=analyzeDualTdcDevice(a,b,o,duration,context)
%ANALYZEDUALTDCDEVICE Device-local all-pairs counting and signed subtraction.
if nargin<4, duration=max([a(:);b(:)])-min([a(:);b(:)]); end
if nargin<5, context=struct(); end
h=dualTdcHistogram(a,b,o); k=h.peakBin;
widths=o.sweepWidths(:);
if isfinite(h.sigma), widths=unique([widths;6*h.sigma;10*h.sigma],'stable'); end
main=dualTdcMainBins(o,k); mainWidth=numel(main)*o.binWidth;
if ~any(abs(widths-mainWidth)<1e-24), widths(end+1)=mainWidth; end
rateCounts=[numel(a),numel(b)];
if isfield(context,'rateCounts'), rateCounts=context.rateCounts; end
m=struct('duration_s',duration,'count1',numel(a),'count2',numel(b), ...
    'rate1_cps',ratio(rateCounts(1),duration),'rate2_cps',ratio(rateCounts(2),duration), ...
    'Nraw',NaN,'Nacc',NaN,'NnetSigned',NaN,'actualWindow_ps',NaN, ...
    'peak_ps',h.peak*1e12,'sigma_ps',h.sigma*1e12,'FWHM_ps',h.fwhm*1e12, ...
    'status',"NO_PEAK",'warnings',"");
cfg=dualTdcAccidentalOptions(o); m.accidentalMethod=cfg.method;
m.mainBinCount=numel(main); m.windowLeft_ps=NaN; m.windowRight_ps=NaN;
sweep=table(widths*1e12,nan(numel(widths),1), ...
    nan(numel(widths),1),nan(numel(widths),1),nan(numel(widths),1), ...
    'VariableNames',{'requestedWidth_ps','actualWidth_ps','Nraw_count','Nacc_count','NnetSigned_count'});
acc=struct('method',cfg.method,'counts',NaN,'warnings',"", ...
    'sampleOffsets_s',[],'sampleCounts',[],'timeOrigin_s',NaN);
if isfinite(k)
    if min(main)>=1 && max(main)<=numel(h.counts)
        m.Nraw=sum(h.counts(main)); m.actualWindow_ps=mainWidth*1e12;
        m.windowLeft_ps=h.edges(main(1))*1e12; m.windowRight_ps=h.edges(main(end)+1)*1e12;
        m.status="OK";
        windows=nan(height(sweep)+1,2); windows(1,:)=h.edges([main(1),main(end)+1]);
        for i=1:height(sweep)
            half=max(0,round((widths(i)/o.binWidth-1)/2)); bins=k+(-half:half);
            if abs(widths(i)-mainWidth)<1e-24, bins=main; end
            if min(bins)<1 || max(bins)>numel(h.counts), continue; end
            actual=numel(bins)*o.binWidth; raw=sum(h.counts(bins));
            windows(i+1,:)=h.edges([bins(1),bins(end)+1]);
            sweep{i,2:3}=[actual*1e12,raw];
        end
        acc=estimateDualTdcAccidentals(a,b,h,o,duration,windows,context);
        m.Nacc=acc.counts(1); m.NnetSigned=m.Nraw-m.Nacc; m.warnings=acc.warnings;
        sweep.Nacc_count=acc.counts(2:end);
        sweep.NnetSigned_count=sweep.Nraw_count-sweep.Nacc_count;
        if ~isfinite(m.Nacc), m.status="INVALID_BACKGROUND"; end
    else
        m.status="INVALID_WINDOW";
    end
end
sweep.accidental_method=repmat(cfg.method,height(sweep),1);
result=struct('histogram',h,'metrics',m,'sweep',sweep,'options',o,'accidental',acc);
end

function y=ratio(n,d)
if d>0, y=n/d; else, y=NaN; end
end
