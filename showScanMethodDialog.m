function editor = showScanMethodDialog(parent,parameter,currentValues,inputMode,onApply)
%SHOWSCANMETHODDIALOG Dropdown for one method, checkboxes for a method list.
[values,labels]=scanMethodChoices(parameter);
if isempty(values), error('CoincidenceSim:ScanMethod','This factor is not a method.'); end
selected=expandScanValues(scanFactor(parameter,currentValues));
selected=values(ismember(values,string(selected)));
if isempty(selected), selected=values(1); end
if ~ismember(string(inputMode),["fixed","list"]), inputMode="list"; end
pos=parent.Position;
fig=uifigure('Name','选择扫描方法','WindowStyle','modal', ...
    'Position',[pos(1)+max(0,(pos(3)-560)/2),pos(2)+max(0,(pos(4)-410)/2),560,410]);
g=uigridlayout(fig,[numel(values)+6,2]); g.ColumnWidth={130,'1x'};
g.RowHeight=[{28,30,32,24},repmat({28},1,numel(values)),{36,'1x'}];
g.Padding=[14 12 14 12];
catalog=scanParameterCatalog(true); match=find(catalog.parameter==string(parameter),1);
heading=char(catalog.label(match));
label=uilabel(g,'Text',heading,'FontWeight','bold'); label.Layout.Column=[1 2];
uilabel(g,'Text','选择方式');
mode=uidropdown(g,'Items',{'固定一个方法（fixed）','逐个比较所选方法（list）'}, ...
    'ItemsData',{'fixed','list'},'Value',char(inputMode));
uilabel(g,'Text','固定方法');
fixed=uidropdown(g,'Items',cellstr(labels),'ItemsData',cellstr(values),'Value',char(selected(1)));
label=uilabel(g,'Text','列表扫描：勾选需要逐个运行的方法'); label.Layout.Column=[1 2];
checks=gobjects(1,numel(values));
for i=1:numel(values)
    checks(i)=uicheckbox(g,'Text',char(labels(i)),'Value',ismember(values(i),selected));
    checks(i).Layout.Column=[1 2];
end
apply=uibutton(g,'Text','应用并启用此因素','ButtonPushedFcn',@applySelection);
cancel=uibutton(g,'Text','取消','ButtonPushedFcn',@(~,~)delete(fig));
note=uilabel(g,'Text','应用后自动勾选该行。方法只使用 fixed/list；range/log 用于数值参数。', ...
    'WordWrap','on'); note.Layout.Column=[1 2];
mode.ValueChangedFcn=@(~,~)updateEnabled(); updateEnabled();
addlistener(parent,'ObjectBeingDestroyed',@(~,~)closeDialog());
editor=struct('Figure',fig,'Mode',mode,'FixedMethod',fixed,'Checks',checks, ...
    'Apply',apply,'Cancel',cancel,'Values',values);

    function updateEnabled()
        single=strcmp(mode.Value,'fixed');
        fixed.Enable='off'; multiEnable='on';
        if single, fixed.Enable='on'; multiEnable='off'; end
        for k=1:numel(checks), checks(k).Enable=multiEnable; end
    end

    function applySelection(~,~)
        if strcmp(mode.Value,'fixed')
            chosen=string(fixed.Value);
        else
            chosen=values(arrayfun(@(c)c.Value,checks));
        end
        if isempty(chosen)
            note.Text='至少勾选一种方法后再应用。'; return
        end
        onApply(chosen,string(mode.Value));
        delete(fig);
    end

    function closeDialog()
        if isvalid(fig), delete(fig); end
    end
end
