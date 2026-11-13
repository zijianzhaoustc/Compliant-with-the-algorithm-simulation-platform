function files = exportJointFitResults(out,folder,baseName,includeDetails)
%EXPORTJOINTFITRESULTS 导出联合拟合 CSV，可选保存完整联合结果与参数 MAT。
if nargin<4, includeDetails=false; end
files=strings(0,1);
if ~isfield(out,'jointFit') || isempty(out.jointFit), return; end
if ~isfolder(folder), mkdir(folder); end
baseName=string(baseName);
file=fullfile(folder,baseName+"_joint_fit_summary.csv");
writeUtf8BomTable(out.jointFit.summary,file); files(end+1,1)=file;
if ~isempty(out.jointFit.histogram)
    file=fullfile(folder,baseName+"_joint_fit_profile.csv");
    writeUtf8BomTable(out.jointFit.histogram,file); files(end+1,1)=file;
end
if includeDetails
    jointFit=out.jointFit; params=out.params; dataMode=out.dataMode;
    file=fullfile(folder,baseName+"_joint_fit_result.mat");
    save(file,'jointFit','params','dataMode','-v7'); files(end+1,1)=file;
end
end
