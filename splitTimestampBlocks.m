function blocks = splitTimestampBlocks(A,B,T,D,opts)
%SPLITTIMESTAMPBLOCKS Guarded A-anchor blocks; original B events never shared.
% Empty blocks remain. Delay chunks spill to temporary MAT files above the
% total memory budget. Keep blocks.cleanup alive until all fits are complete.
o=validateInferenceOptions(opts); validateattributes(T,{'numeric'},{'scalar','finite','positive'});
o.domain=D; o=validateInferenceOptions(o); g=max(abs(D));
a=A.time(:); b=B.time(:);
for x={a,b}
    if any(~isfinite(x{1})) || any(diff(x{1})<0) || any(x{1}<0 | x{1}>T)
        error('CoincidenceSim:InvalidInference','Sorted timestamps must lie inside the acquisition gate.');
    end
end
K=max(1,ceil(T/o.blockSeconds)); width=T/K;
if width<=2*g, error('CoincidenceSim:InvalidInference','Block exposure is shorter than twice the guard.'); end
template=struct('start',0,'stop',0,'exposure',0,'countA',0,'countB',0, ...
    'rateA',0,'rateB',0,'background',0,'delta',{{}},'pairCount',0);
blocks=struct('items',repmat(template,K,1),'T',T,'domain',D,'guard',g, ...
    'cleanup',[],'spilled',false,'maxResidentPairs',0);
cache=tempname; mkdir(cache); blocks.cleanup=onCleanup(@()rmdir(cache,'s'));
resident=0; la=1; ra=0; lb=1; rb=0;
for k=1:K
    s=(k-1)*width; e=k*width;
    while la<=numel(a) && a(la)<s+g, la=la+1; end
    ra=max(ra,la-1); while ra<numel(a) && a(ra+1)<e-g, ra=ra+1; end
    while lb<=numel(b) && b(lb)<s, lb=lb+1; end
    rb=max(rb,lb-1); while rb<numel(b) && b(rb+1)<e, rb=rb+1; end
    z=template; z.start=s; z.stop=e; z.exposure=width-2*g;
    z.countA=max(0,ra-la+1); z.countB=max(0,rb-lb+1);
    z.rateA=z.countA/z.exposure; z.rateB=z.countB/width;
    % Exact overlap: A core and full B block have constant overlap Teff on D.
    z.background=z.exposure*z.rateA*z.rateB;
    chunk=zeros(min(o.maxPairsInMemory,100000),1); pos=0; left=lb; right=lb-1;
    for i=la:ra
        while left<=rb && b(left)-a(i)<D(1), left=left+1; end
        right=max(right,left-1);
        while right<rb && b(right+1)-a(i)<=D(2), right=right+1; end
        j=left;
        while j<=right
            take=min(numel(chunk)-pos,right-j+1);
            chunk(pos+(1:take))=b(j:j+take-1)-a(i); pos=pos+take; j=j+take;
            if pos==numel(chunk), flush(); end
        end
    end
    if pos>0, flush(); end
    blocks.items(k)=z;
end
    function flush()
        delta=chunk(1:pos); z.pairCount=z.pairCount+pos;
        if resident+pos<=o.maxPairsInMemory
            z.delta{end+1}=delta; resident=resident+pos;
            blocks.maxResidentPairs=max(blocks.maxResidentPairs,resident);
        else
            file=fullfile(cache,sprintf('%d_%d.mat',k,numel(z.delta)+1));
            save(file,'delta','-v7'); z.delta{end+1}=file; blocks.spilled=true;
        end
        pos=0;
    end
end
