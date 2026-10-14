function reportFile = auditLegacySimulation(outputRoot, archiveFile)
%AUDITLEGACYSIMULATION Non-destructively inventory and hash legacy evidence.
if nargin<1, outputRoot=fullfile(pwd,'outputs','paper_simulations'); end
if nargin<2, archiveFile=fullfile(pwd,'data','legacy','论文仿真.zip'); end
reportDir=fullfile(outputRoot); if ~isfolder(reportDir), mkdir(reportDir); end
reportFile=fullfile(reportDir,'legacy_audit.md');
if ~isfile(archiveFile)
    text=['# 历史仿真审计' newline newline ...
        '- 状态：未提供历史文件。' newline ...
        '- 期望位置：`data/legacy/论文仿真.zip`。' newline ...
        '- 因此 A seed1/seed2、C 组疑似重复及旧工作簿参数证据均无法在本仓库复核；这不阻断新的 A–D 仿真。' newline];
    writeText(reportFile,text); return
end
tempRoot=tempname; mkdir(tempRoot); cleanup=onCleanup(@()rmdir(tempRoot,'s'));
unzip(archiveFile,tempRoot); files=dir(fullfile(tempRoot,'**','*')); files=files(~[files.isdir]);
paths=strings(numel(files),1); sizes=zeros(numel(files),1); hashes=strings(numel(files),1);
for k=1:numel(files)
    full=fullfile(files(k).folder,files(k).name); paths(k)=string(erase(full,tempRoot+filesep));
    sizes(k)=files(k).bytes; hashes(k)=fileHash(full);
end
inventory=table(paths,sizes,hashes,'VariableNames',{'path','bytes','sha256'});
writeUtf8BomTable(inventory,fullfile(outputRoot,'legacy_inventory.csv'));
[uniqueHash,~,group]=unique(hashes); counts=accumarray(group,1);
duplicateHashes=uniqueHash(counts>1); duplicateLines="";
for h=duplicateHashes.'
    duplicateLines=duplicateLines+"- `"+h+"`: "+strjoin(paths(hashes==h),", ")+newline;
end
if strlength(duplicateLines)==0, duplicateLines="- 未发现逐字节重复文件。"+newline; end
text="# 历史仿真审计"+newline+newline+ ...
    "## 证据清单"+newline+newline+sprintf('- 已解包并哈希 %d 个文件；完整清单见 `legacy_inventory.csv`。\n\n',height(inventory))+ ...
    "## 字节级重复"+newline+newline+duplicateLines+newline+ ...
    "## 结论边界"+newline+newline+ ...
    "- 字节哈希可确认重复导出，但不能在缺少 MAT 参数、日志或时间戳时确认重复产生的原因。"+newline+ ...
    "- 人工汇总 Excel 仅作为二级证据；无参数快照的数值不得提升为可追溯逐运行证据。"+newline+ ...
    "- 暗计数与背景在当前模型中都是独立 Poisson 流；同 seed 下数值一致不自动构成代码错误。"+newline;
writeText(reportFile,text); clear cleanup
end

function hash=fileHash(filename)
fid=fopen(filename,'r'); cleanup=onCleanup(@()fclose(fid)); bytes=fread(fid,Inf,'uint8=>uint8');
digest=java.security.MessageDigest.getInstance('SHA-256'); digest.update(bytes);
hash=lower(string(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]))); clear cleanup
end

function writeText(filename,value)
fid=fopen(filename,'w','n','UTF-8'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',char(value)); clear cleanup
end
