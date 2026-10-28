function [pairs, skipped] = discoverTimestampPairs(inputFolder, excludedFolder)
%DISCOVERTIMESTAMPPAIRS 递归配对同目录、同前缀的 CH1/CH2 或 StartCh/StopCh。
%   不按相近时间猜测配对；同一组出现重复格式时整组跳过。
if nargin<2, excludedFolder=""; end
inputFolder=string(char(java.io.File(char(inputFolder)).getCanonicalPath()));
if ~isfolder(inputFolder)
    error('CoincidenceSim:MissingInputFolder','输入目录不存在：%s',inputFolder);
end
if strlength(excludedFolder)>0
    excludedFolder=string(char(java.io.File(char(excludedFolder)).getCanonicalPath()));
end
pairs=table('Size',[0 4],'VariableTypes',repmat("string",1,4), ...
    'VariableNames',{'RelativeFolder','BaseName','StartFile','StopFile'});
skipped=table('Size',[0 2],'VariableTypes',{'string','string'}, ...
    'VariableNames',{'File','Reason'});
entries=dir(fullfile(inputFolder,'**','*'));
paths=strings(0,1); folders=paths; bases=paths; channels=zeros(0,1);
for k=1:numel(entries)
    e=entries(k);
    if e.isdir, continue; end
    path=string(fullfile(e.folder,e.name));
    if strlength(excludedFolder)>0 && ...
            (strcmpi(path,excludedFolder) || startsWith(lower(path),lower(excludedFolder+filesep)))
        continue
    end
    [~,base,extension]=fileparts(e.name);
    if ~any(strcmpi(extension,{'.txt','.bin'})), continue; end
    token=regexpi(base,'^(.*?)(CH1|CH2|StartCh|StopCh)$','tokens','once');
    if isempty(token)
        skipped(end+1,:)={path,"文件名未以 CH1/CH2 或 StartCh/StopCh 结尾"}; %#ok<AGROW>
        continue
    end
    paths(end+1,1)=path; folders(end+1,1)=string(e.folder); %#ok<AGROW>
    bases(end+1,1)=string(token{1}); %#ok<AGROW>
    channels(end+1,1)=1+any(strcmpi(token{2},{'CH2','StopCh'})); %#ok<AGROW>
end
keys=lower(fullfile(folders,bases));
groups=unique(keys,'sorted');
for k=1:numel(groups)
    indices=find(keys==groups(k));
    a=indices(channels(indices)==1); b=indices(channels(indices)==2);
    if numel(a)~=1 || numel(b)~=1
        reason="缺少对应通道文件";
        if numel(a)>1 || numel(b)>1, reason="同一前缀存在重复通道文件，无法唯一配对"; end
        for j=indices(:)', skipped(end+1,:)={paths(j),reason}; end %#ok<AGROW>
        continue
    end
    relative=extractAfter(folders(a),strlength(inputFolder));
    if startsWith(relative,filesep), relative=extractAfter(relative,1); end
    name=regexprep(bases(a),'[_\- ]+$','');
    if strlength(name)==0, name="timestamps"; end
    pairs(end+1,:)={relative,name,paths(a),paths(b)}; %#ok<AGROW>
end
end
