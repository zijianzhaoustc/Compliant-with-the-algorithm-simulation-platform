function hash = scanHash(value)
%SCANHASH SHA-256 of exact serialized configuration or labelled stream.
digest=java.security.MessageDigest.getInstance('SHA-256');
digest.update(unicode2native(jsonencode(value),'UTF-8'));
hash=string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[])));
end
