function [timestamps, metadata] = readSsiDaqTimestampBin(filename)
%READSSIDAQTIMESTAMPBIN 读取 SSI DAQ 分块二进制时间戳文件。
%   文件格式为大端 QDataStream：两个 QString（格式标识、通道文件名），
%   后接若干块；每块由 uint32 记录数和相应数量的 big-endian double 组成。
%   double 数值的单位为 ps。函数先扫描块头统计总记录数，再预分配并读取，
%   避免大文件动态扩容造成额外内存峰值。

fid=fopen(filename,'rb','ieee-be');
if fid<0
    error("CoincidenceSim:CannotOpenBinaryTimestamp", ...
        "无法打开二进制时间戳文件：%s",filename);
end
cleanup=onCleanup(@()fclose(fid));

magic=readQtString(fid,filename);
channelName=readQtString(fid,filename);
if magic~="SSI_DAQ_TDC_TIMESTAMP_V1"
    error("CoincidenceSim:UnsupportedBinaryTimestamp", ...
        "不支持的 BIN 时间戳格式标识：%s",magic);
end
dataStart=ftell(fid);

% 第一遍只扫描块头并跳过数据，得到精确的总记录数和块数。
totalCount=uint64(0); blockCount=uint64(0);
fseek(fid,0,'eof'); fileSize=ftell(fid); fseek(fid,dataStart,'bof');
while ftell(fid)<fileSize
    blockHeaderPosition=ftell(fid);
    count=fread(fid,1,'uint32=>uint32');
    if isempty(count)
        error("CoincidenceSim:TruncatedBinaryTimestamp", ...
            "BIN 文件在块头处提前结束：%s",filename);
    end
    bytesRemaining=fileSize-ftell(fid);
    blockBytes=double(count)*8;
    if blockBytes>bytesRemaining
        error("CoincidenceSim:TruncatedBinaryTimestamp", ...
            "BIN 数据块不完整（位置 %d，需要 %.0f 字节，仅余 %.0f 字节）：%s", ...
            blockHeaderPosition,blockBytes,bytesRemaining,filename);
    end
    totalCount=totalCount+uint64(count);
    blockCount=blockCount+1;
    if fseek(fid,blockBytes,'cof')~=0
        error("CoincidenceSim:BinaryTimestampSeekFailed", ...
            "无法跳过 BIN 数据块：%s",filename);
    end
end
if totalCount==0
    error("CoincidenceSim:EmptyTimestampFile","BIN 时间戳文件不包含记录：%s",filename);
end
if totalCount>uint64(flintmax)
    error("CoincidenceSim:BinaryTimestampTooLarge", ...
        "BIN 时间戳数量超过 MATLAB 可精确索引范围：%s",filename);
end

% 第二遍分块读取，读取时同时检查块内及跨块的非递减顺序。
timestamps=zeros(double(totalCount),1);
fseek(fid,dataStart,'bof'); writePosition=1; previousLast=-Inf;
for blockIndex=1:double(blockCount)
    count=fread(fid,1,'uint32=>double');
    block=fread(fid,count,'double=>double');
    if numel(block)~=count
        error("CoincidenceSim:TruncatedBinaryTimestamp", ...
            "BIN 文件第 %d 个数据块不完整：%s",blockIndex,filename);
    end
    if any(~isfinite(block)) || any(diff(block)<0) || (~isempty(block) && block(1)<previousLast)
        error("CoincidenceSim:UnsortedTimestamps", ...
            "BIN 时间戳包含非有限值或未按非递减顺序排列：%s",filename);
    end
    if ~isempty(block)
        target=writePosition:(writePosition+count-1);
        timestamps(target)=block;
        writePosition=writePosition+count;
        previousLast=block(end);
    end
end

metadata=struct('magic',magic,'channelName',channelName,'unitSeconds',1e-12, ...
    'blockCount',double(blockCount),'timestampCount',double(totalCount));
end

function value = readQtString(fid,filename)
%READQTSTRING 读取 QDataStream 以字节数开头的大端 UTF-16 QString。
byteCount=fread(fid,1,'uint32=>double');
if isempty(byteCount) || mod(byteCount,2)~=0
    error("CoincidenceSim:InvalidBinaryTimestampHeader", ...
        "BIN 文件包含无效 QString 长度：%s",filename);
end
codeUnits=fread(fid,byteCount/2,'uint16=>uint16');
if numel(codeUnits)~=byteCount/2
    error("CoincidenceSim:TruncatedBinaryTimestamp", ...
        "BIN 文件头字符串不完整：%s",filename);
end
value=string(char(codeUnits.'));
end
