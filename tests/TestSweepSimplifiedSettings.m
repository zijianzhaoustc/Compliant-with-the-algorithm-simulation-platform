classdef TestSweepSimplifiedSettings < matlab.unittest.TestCase
    methods(Test)
        function onlyBothAndConstantTimeInGui(t)
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            panel=app.ParameterSweepPanel; data=panel.Controls.Factors.Data;
            t.verifyEqual(size(data,1),height(scanParameterCatalog()));
            t.verifyTrue(all(string(data(:,3))=="both"));
            t.verifyFalse(panel.Controls.Factors.ColumnEditable(3));
            keys=extractBefore(string(data(:,2))," | ");
            t.verifyFalse(any(ismember(keys,["measurementTime","source.pumpPower"])));
            t.verifyEqual(numel(unique(keys)),numel(keys));
            app.Controls.Time.Value=9; panel.Controls.MeasurementTime.Value=.05;
            panel.Controls.WorkingMemoryMB.Value=512.5;
            row=find(keys=="detector.darkRate"); data{row,1}=true; data{row,5}='0,500';
            panel.Controls.Factors.Data=data;
            c=panel.readConfig(); [plan,preview]=buildScanGrid(c);
            t.verifyEqual(c.baseParams.measurementTime,.05);
            t.verifyEqual(c.limits.maxWorkingMemoryMB,512.5);
            t.verifyEqual(preview.analysisCount,2);
            for entry=plan'
                t.verifyEqual(entry.params.measurementTime,.05);
                t.verifyEqual(entry.params.detector.A.darkRate,entry.params.detector.B.darkRate);
            end
            clear cleanup
        end

        function constantsAndMemorySurviveJsonAndPopulate(t)
            c=scanDefaultConfig(); c.baseParams.measurementTime=.075;
            c.limits.maxWorkingMemoryMB=1024.5;
            c.factors=scanFactor("algorithm.binWidth",[10 20]);
            c=validateScanConfig(jsondecode(jsonencode(c)));
            app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app)); app.UIFigure.Visible='off';
            panel=app.ParameterSweepPanel; panel.populate(c);
            t.verifyEqual(panel.Controls.MeasurementTime.Value,.075);
            t.verifyEqual(panel.Controls.WorkingMemoryMB.Value,1024.5);
            decoded=validateScanConfig(jsondecode(jsonencode(panel.readConfig())));
            t.verifyEqual(decoded.limits.maxWorkingMemoryMB,1024.5);
            t.verifyEqual(decoded.baseParams.measurementTime,.075);
            t.verifyEqual(numel(buildScanGrid(decoded)),2);
            t.verifyFalse(any(ismember(string({decoded.units.parameter}),["measurementTime","source.pumpPower"])));
            clear cleanup
        end

        function memoryBudgetControlsPlanning(t)
            c=scanDefaultConfig(); c.baseParams.source.pairRate=1e4; c.baseParams.measurementTime=.02;
            [plan,preview]=buildScanGrid(c); required=preview.estimatedWorkingMemoryMB;
            t.verifyGreaterThan(required,0);
            t.verifyEqual(plan.estimated_working_memory_MB,required);
            c.limits.maxWorkingMemoryMB=required/2;
            t.verifyError(@()buildScanGrid(c),'CoincidenceSim:WorkingMemoryLimit');
            c.limits.maxWorkingMemoryMB=required*2;
            [plan,preview,c]=buildScanGrid(c);
            t.verifyEqual(preview.workingMemoryLimitMB,required*2);
            t.verifyEqual(plan.params.algorithm.scanWorkingMemoryMB,c.limits.maxWorkingMemoryMB);
            t.verifyLessThan(preview.estimatedWorkingMemoryMB,preview.workingMemoryLimitMB);
        end

        function actualMatchMemoryCheckedBeforeAllocation(t)
            p=defaultParams(); p.algorithm.scanWorkingMemoryMB=1;
            p.algorithm.maxMatchPairs=2e6;
            A=struct('time',zeros(1000,1),'pairID',(1:1000)','type',repmat("signal",1000,1));
            t.verifyError(@()matchCoincidences(A,A,p),'CoincidenceSim:WorkingMemoryLimit');
            A=struct('time',zeros(100,1),'pairID',(1:100)','type',repmat("signal",100,1));
            p.algorithm.scanWorkingMemoryMB=10;
            matches=matchCoincidences(A,A,p); t.verifyNumElements(matches.deltaT,10000);
        end

        function removedFactorsAndLegacyChannelsAreRejected(t)
            for key=["measurementTime","source.pumpPower"]
                c=scanDefaultConfig(); c.factors=scanFactor(key,1);
                t.verifyError(@()buildScanGrid(c),'CoincidenceSim:ScanFactor');
            end
            for channel=["A","B"]
                c=scanDefaultConfig(); c.factors=scanFactor("detector.darkRate",1,channel);
                t.verifyError(@()buildScanGrid(c),'CoincidenceSim:ScanChannel');
            end
            c=scanDefaultConfig(); c.limits.maxWorkingMemoryMB=0;
            t.verifyError(@()buildScanGrid(c),'MATLAB:expectedPositive');
        end
    end
end
