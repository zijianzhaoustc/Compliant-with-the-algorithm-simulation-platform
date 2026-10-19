function result=analyzeDualTdcDevice(a,b,o,duration)
%ANALYZEDUALTDCDEVICE Device-local all-pairs counting and signed subtraction.
if nargin<4, duration=max([a(:);b(:)])-min([a(:);b(:)]); end
h=dualTdcHistogram(a,b,o); k=h.peakBin;
m=struct('duration_s',duration,'count1',numel(a),'count2',numel(b), ...
    'rate1_cps',ratio(numel(a),duration),'rate2_cps',ratio(numel(b),duration), ...
    'Nraw',NaN,'Nacc',NaN,'NnetSigned',NaN,'actualWindow_ps',NaN, ...
    'peak_ps',h.peak*1e12,'sigma_ps',h.sigma*1e12,'FWHM_ps',h.fwhm*1e12, ...
    'status',"NO_PEAK",'warnings',"");
sweep=table(o.sweepWidths(:)*1e12,nan(numel(o.sweepWidths),1), ...
    nan(numel(o.sweepWidths),1),nan(numel(o.sweepWidths),1),nan(numel(o.sweepWidths),1), ...
    'VariableNames',{'requestedWidth_ps','actualWidth_ps','Nraw_count','Nacc_count','NnetSigned_count'});
if isfinite(k)
    main=k+(-o.mainHalfBins:o.mainHalfBins);
    side=k-(o.sideBeforeBins(1):o.sideBeforeBins(2));
    if min(main)>=1 && max(main)<=numel(h.counts) && min(side)>=1 && max(side)<=numel(h.counts)
        m.Nraw=sum(h.counts(main)); m.Nacc=sum(h.counts(side))*numel(main)/numel(side);
        m.NnetSigned=m.Nraw-m.Nacc; m.actualWindow_ps=numel(main)*o.binWidth*1e12;
        m.status="OK";
        if isfinite(h.sigma) && o.sideBeforeBins(1)*o.binWidth<3*h.sigma
            m.warnings="Specified side bins may contain the true peak tail; accidental estimate is a protocol value, not ground truth.";
        end
        density=sum(h.counts(side))/(numel(side)*o.binWidth);
        for i=1:height(sweep)
            half=max(0,round((o.sweepWidths(i)/o.binWidth-1)/2)); bins=k+(-half:half);
            if min(bins)<1 || max(bins)>numel(h.counts), continue; end
            actual=numel(bins)*o.binWidth; raw=sum(h.counts(bins)); acc=density*actual;
            sweep{i,2:5}=[actual*1e12,raw,acc,raw-acc];
        end
    else
        m.status="INVALID_WINDOW";
    end
end
result=struct('histogram',h,'metrics',m,'sweep',sweep,'options',o);
end

function y=ratio(n,d)
if d>0, y=n/d; else, y=NaN; end
end
