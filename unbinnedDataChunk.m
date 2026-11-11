function d = unbinnedDataChunk(chunk)
%UNBINNEDDATACHUNK Read one bounded delta chunk, optionally cached on disk.
if ischar(chunk) || isstring(chunk)
    s=load(chunk,'delta'); d=s.delta;
else
    d=chunk;
end
d=d(:);
end
