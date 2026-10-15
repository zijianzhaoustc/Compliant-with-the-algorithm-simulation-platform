function hash = scanCodeHash()
%SCANCODEHASH Content fingerprint includes uncommitted MATLAB implementation.
root=fileparts(mfilename('fullpath')); files=dir(fullfile(root,'*.m'));
[~,order]=sort(string({files.name})); files=files(order);
manifest=struct();
for i=1:numel(files)
    manifest.(matlab.lang.makeValidName(files(i).name))=scanHash(fileread(fullfile(root,files(i).name)));
end
hash=scanHash(manifest);
end
