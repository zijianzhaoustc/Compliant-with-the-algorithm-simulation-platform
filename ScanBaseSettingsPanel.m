classdef ScanBaseSettingsPanel < handle
    %SCANBASESETTINGSPANEL Standalone research parameters, with no app callbacks.
    properties
        Params
        Fields=struct()
        Controls=struct()
        Catalog
    end
    methods
        function panel=ScanBaseSettingsPanel(parent,p)
            if nargin<2, p=defaultParams(); end
            panel.Catalog=scanParameterCatalog();
            extra=table(["optics.transmission";"optics.relativeDelay";"detector.efficiency"; ...
                "detector.recordEfficiency";"tdc.resolution";"tdc.bias";"tdc.dnl";"tdc.inl"], ...
                ["光路传输效率";"B相对A的光路延迟";"探测效率 PDE";"记录效率"; ...
                "TDC分辨率";"TDC公共偏置";"TDC DNL";"TDC INL"], ...
                ["0-1 (both)";"ns";"0-1 (both)";"0-1 (both)";"ps";"ps (both)";"LSB";"LSB"], ...
                [1;1e-9;1;1;1e-12;1e-12;1;1],'VariableNames',panel.Catalog.Properties.VariableNames);
            panel.Catalog=[panel.Catalog;extra];
            outer=uigridlayout(parent,[3 1]); outer.RowHeight={28,26,'1x'};
            effects=uigridlayout(outer,[1 5]); effects.Padding=[0 0 0 0];
            effects.ColumnWidth=repmat({'1x'},1,5);
            names=["EnableDark","EnableDead","EnableAfter","EnableTdcJitter","EnableTdcDead"];
            labels=["启用暗计数","启用探测器死时间","启用后脉冲","启用TDC抖动","启用TDC死时间"];
            for j=1:numel(names), panel.Controls.(names(j))=uicheckbox(effects,'Text',char(labels(j))); end
            uilabel(outer,'Text','本页为扫描独立基准；未勾选的扫描因素使用这里的固定值。通道参数共用both，光源为直接光子对率模式。', ...
                'WordWrap','on');
            grid=uigridlayout(outer,[height(panel.Catalog),3]); grid.Scrollable='on';
            grid.ColumnWidth={250,240,'1x'}; grid.RowHeight=repmat({28},1,height(panel.Catalog));
            for j=1:height(panel.Catalog)
                key=panel.Catalog.parameter(j); name=matlab.lang.makeValidName(char(key));
                uilabel(grid,'Text',char(panel.Catalog.label(j)));
                [choices,choiceLabels]=scanMethodChoices(key);
                if isempty(choices)
                    panel.Fields.(name)=uieditfield(grid,'numeric');
                else
                    panel.Fields.(name)=uidropdown(grid,'Items',cellstr(choiceLabels), ...
                        'ItemsData',cellstr(choices));
                end
                uilabel(grid,'Text',char(panel.Catalog.unit(j)));
            end
            panel.populate(p);
        end

        function populate(panel,p)
            p=mergeParamsWithDefaults(defaultParams(),p);
            if string(p.source.mode)~="direct"
                error('CoincidenceSim:ScanBaseSource','Independent research settings require source.mode=direct.');
            end
            shared=["optics.transmission","detector.efficiency","detector.recordEfficiency", ...
                "detector.darkRate","detector.backgroundRate","detector.jitter","detector.deadTime", ...
                "detector.afterpulseProbability","detector.afterpulseLifetime", ...
                "tdc.jitter","tdc.deadTime","tdc.bias"];
            for key=shared
                parts=split(key,'.');
                if ~isequaln(p.(parts(1)).A.(parts(2)),p.(parts(1)).B.(parts(2)))
                    error('CoincidenceSim:ScanBaseChannels','Independent both settings require equal A/B values for %s.',key);
                end
            end
            if abs(sum(p.algorithm.histRange))>64*eps(max(abs(p.algorithm.histRange)))
                error('CoincidenceSim:ScanBaseRange','Research histogram range must be symmetric [-H,H].');
            end
            panel.Params=p;
            for j=1:height(panel.Catalog)
                key=panel.Catalog.parameter(j); name=matlab.lang.makeValidName(char(key));
                value=getBaseValue(p,key,panel.Catalog.scale(j));
                if isstring(value), value=char(value); end
                panel.Fields.(name).Value=value;
            end
            panel.Controls.EnableDark.Value=p.detector.enableDark;
            panel.Controls.EnableDead.Value=p.detector.enableDeadTime;
            panel.Controls.EnableAfter.Value=p.detector.enableAfterpulse;
            panel.Controls.EnableTdcJitter.Value=p.tdc.enableJitter;
            panel.Controls.EnableTdcDead.Value=p.tdc.enableDeadTime;
        end

        function p=readParameters(panel)
            p=panel.Params;
            for j=1:height(panel.Catalog)
                key=panel.Catalog.parameter(j); name=matlab.lang.makeValidName(char(key));
                p=setBaseValue(p,key,panel.Fields.(name).Value,panel.Catalog.scale(j));
            end
            p.detector.enableDark=panel.Controls.EnableDark.Value;
            p.detector.enableDeadTime=panel.Controls.EnableDead.Value;
            p.detector.enableAfterpulse=panel.Controls.EnableAfter.Value;
            p.tdc.enableJitter=panel.Controls.EnableTdcJitter.Value;
            p.tdc.enableDeadTime=panel.Controls.EnableTdcDead.Value;
            p=validateParams(p);
        end

        function setEnabled(panel,enabled)
            state='off'; if enabled, state='on'; end
            groups={panel.Fields,panel.Controls};
            for j=1:numel(groups)
                names=fieldnames(groups{j});
                for k=1:numel(names), groups{j}.(names{k}).Enable=state; end
            end
        end
    end
end

function value=getBaseValue(p,key,scale)
switch key
    case "optics.transmission", value=p.optics.A.transmission/scale;
    case "optics.relativeDelay", value=(p.optics.B.delay-p.optics.A.delay)/scale;
    case "detector.efficiency", value=p.detector.A.efficiency/scale;
    case "detector.recordEfficiency", value=p.detector.A.recordEfficiency/scale;
    case "tdc.resolution", value=p.tdc.resolution/scale;
    case "tdc.bias", value=p.tdc.A.bias/scale;
    case "tdc.dnl", value=p.tdc.dnl/scale;
    case "tdc.inl", value=p.tdc.inl/scale;
    otherwise, value=scanGetParameter(p,key,"both");
end
end

function p=setBaseValue(p,key,value,scale)
switch key
    case "optics.transmission"
        p.optics.A.transmission=value*scale; p.optics.B.transmission=value*scale;
    case "optics.relativeDelay", p.optics.B.delay=p.optics.A.delay+value*scale;
    case "detector.efficiency"
        p.detector.A.efficiency=value*scale; p.detector.B.efficiency=value*scale;
    case "detector.recordEfficiency"
        p.detector.A.recordEfficiency=value*scale; p.detector.B.recordEfficiency=value*scale;
    case "tdc.resolution", p.tdc.resolution=value*scale;
    case "tdc.bias", p.tdc.A.bias=value*scale; p.tdc.B.bias=value*scale;
    case "tdc.dnl", p.tdc.dnl=value*scale;
    case "tdc.inl", p.tdc.inl=value*scale;
    otherwise, p=scanSetParameter(p,key,value,"both");
end
end
