function [values,labels] = scanMethodChoices(parameter)
%SCANMETHODCHOICES Supported categorical research factors and visible names.
switch string(parameter)
    case "algorithm.accidentalMethod"
        values=["theory","side-window","time-shift"];
        labels=["理论法（theory）","旁窗法（side-window）","时间戳平移法（time-shift）"];
    case "algorithm.peakMethod"
        values=["maximum","gaussian"];
        labels=["最大值寻峰（maximum）","高斯拟合寻峰（gaussian）"];
    otherwise
        values=strings(1,0); labels=strings(1,0);
end
end
