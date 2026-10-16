classdef TestScanMethodPicker < matlab.unittest.TestCase
    methods(Test)
        function dropdownAppliesSingleValue(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            panel=app.ParameterSweepPanel;
            for entry=["algorithm.accidentalMethod","algorithm.peakMethod"]
                data=panel.Controls.Factors.Data; row=find(startsWith(string(data(:,2)),entry+" | "));
                callback=panel.Controls.Factors.CellSelectionCallback;
                callback([],struct('Indices',[row,5])); editor=panel.MethodEditor;
                [choices,labels]=scanMethodChoices(entry);
                t.verifyEqual(string(editor.FixedMethod.ItemsData),choices);
                t.verifyEqual(string(editor.FixedMethod.Items),labels);
                editor.Mode.Value='fixed'; editor.Mode.ValueChangedFcn([],[]);
                t.verifyEqual(string(editor.FixedMethod.Enable),"on");
                t.verifyTrue(all(arrayfun(@(c)string(c.Enable)=="off",editor.Checks)));
                editor.FixedMethod.Value=char(choices(end)); editor.Apply.ButtonPushedFcn([],[]);
                t.verifyFalse(isvalid(editor.Figure));
                data=panel.Controls.Factors.Data;
                t.verifyTrue(data{row,1}); t.verifyEqual(string(data{row,4}),"fixed");
                t.verifyEqual(string(data{row,5}),choices(end));
            end
            c=panel.readConfig(); plan=buildScanGrid(c);
            t.verifyNumElements(plan,1);
            t.verifyEqual(plan.params.algorithm.accidentalMethod,"time-shift");
            t.verifyEqual(plan.params.algorithm.peakMethod,"gaussian");
            clear cleanup
        end

        function checkboxListsProduceSixVariants(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            panel=app.ParameterSweepPanel;
            for entry=["algorithm.accidentalMethod","algorithm.peakMethod"]
                data=panel.Controls.Factors.Data; row=find(startsWith(string(data(:,2)),entry+" | "));
                panel.openMethodEditor(row); editor=panel.MethodEditor;
                editor.Mode.Value='list'; editor.Mode.ValueChangedFcn([],[]);
                t.verifyEqual(string(editor.FixedMethod.Enable),"off");
                for box=editor.Checks, box.Value=true; end
                editor.Apply.ButtonPushedFcn([],[]);
            end
            c=panel.readConfig(); [plan,preview]=buildScanGrid(c);
            t.verifyEqual(preview.analysisCount,6); t.verifyEqual(preview.physicalGenerationCount,1);
            t.verifyEqual(numel(unique([plan.analysis_config_id])),6);
            decoded=validateScanConfig(jsondecode(jsonencode(c)));
            t.verifyEqual(numel(buildScanGrid(decoded)),6);
            clear cleanup
        end

        function cancelEmptySelectionAndParentClose(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            panel=app.ParameterSweepPanel; before=panel.Controls.Factors.Data;
            row=find(startsWith(string(before(:,2)),"algorithm.accidentalMethod | "));
            panel.openMethodEditor(row); editor=panel.MethodEditor;
            editor.Mode.Value='list'; editor.Mode.ValueChangedFcn([],[]);
            for box=editor.Checks, box.Value=false; end
            editor.Apply.ButtonPushedFcn([],[]);
            t.verifyTrue(isvalid(editor.Figure)); t.verifyEqual(panel.Controls.Factors.Data,before);
            editor.Cancel.ButtonPushedFcn([],[]);
            t.verifyFalse(isvalid(editor.Figure)); t.verifyEqual(panel.Controls.Factors.Data,before);
            panel.openMethodEditor(row); fig=panel.MethodEditor.Figure;
            delete(app); t.verifyFalse(isvalid(fig)); clear cleanup
        end

        function methodsRejectNumericRangeAndLog(t)
            for key=["algorithm.accidentalMethod","algorithm.peakMethod"]
                for mode=["range","log"]
                    c=scanDefaultConfig(); f=scanFactor(key,[]); f.inputMode=mode;
                    c.factors=f;
                    t.verifyError(@()buildScanGrid(c),'CoincidenceSim:ScanCategoricalInput');
                end
            end
        end

        function categoricalInputModeCellOpensPicker(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            panel=app.ParameterSweepPanel; data=panel.Controls.Factors.Data;
            row=find(startsWith(string(data(:,2)),"algorithm.peakMethod | "));
            data{row,4}='range'; panel.Controls.Factors.Data=data;
            callback=panel.Controls.Factors.CellEditCallback;
            callback([],struct('Indices',[row,4],'PreviousData','list'));
            t.verifyEqual(panel.Controls.Factors.Data{row,4},'list');
            t.verifyTrue(isvalid(panel.MethodEditor.Figure));
            clear cleanup
        end
    end
end
