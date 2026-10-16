function hash = scanStreamHash(data)
%SCANSTREAMHASH Bounded hashing of source and TDC (time,pairID,type) arrays.
d=java.security.MessageDigest.getInstance('SHA-256');
for field=["source","A","B"]
    events=data.(field); d.update(unicode2native(char(field),'UTF-8'));
    d.update(typecast(uint64(numel(events.time)),'uint8'));
    for start=1:10000:numel(events.time)
        idx=start:min(start+9999,numel(events.time));
        d.update(typecast(double(events.time(idx)),'uint8'));
        d.update(typecast(double(events.pairID(idx)),'uint8'));
        d.update(unicode2native(jsonencode(events.type(idx)),'UTF-8'));
        if isfield(events,'backgroundCorrelationID'), d.update(typecast(double(events.backgroundCorrelationID(idx)),'uint8')); end
    end
end
hash=string(lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[])));
end
