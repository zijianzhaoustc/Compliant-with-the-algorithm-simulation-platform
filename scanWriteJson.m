function scanWriteJson(path,value)
%SCANWRITEJSON Write UTF-8 JSON with explicit cleanup on errors.
fid=fopen(path,'w','n','UTF-8');
if fid<0, error('CoincidenceSim:ExportOpenFailed','Cannot write %s',path); end
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
