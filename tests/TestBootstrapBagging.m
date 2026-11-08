classdef TestBootstrapBagging < matlab.unittest.TestCase
    methods (Test)
        function customCountValidationAndLegacySettings(t)
            p=defaultParams(); t.verifyEqual(p.optimization.baggingResamples,101);
            legacy=p; legacy.optimization=rmfield(legacy.optimization,'baggingResamples');
            restored=validateParams(legacy);
            t.verifyEqual(restored.optimization.baggingResamples,101);
            for count=[1 32 401 100000]
                q=p; q.optimization.baggingResamples=count; q=validateParams(q);
                t.verifyEqual(q.optimization.baggingResamples,count);
            end
            invalid={0,-1,1.5,NaN,Inf,100001,[],[1 2],"401",true,1+1i};
            for k=1:numel(invalid)
                q=p; q.optimization.baggingResamples=invalid{k};
                t.verifyError(@()validateParams(q),'CoincidenceSim:InvalidOptimization');
            end
        end

        function customCountsUseRequestedDrawsAndPreserveBootstrapBudgets(t)
            [o,p,model]=fixture(); state=rng;
            original=optimizeCoincidenceWindow(o.A,o.B,o.matches,p,model);
            for count=[1 32 401]
                p.optimization.baggingResamples=count;
                actual=optimizeCoincidenceWindow(o.A,o.B,o.matches,p,model);
                t.assertTrue(actual.valid,actual.status); bag=actual.bagging;
                t.verifyEqual(bag.Reps,count);
                t.verifySize(bag.SelectedWindows_s,[count 1]);
                prefix=min(count,original.bagging.Reps);
                t.verifyEqual(bag.SelectedWindows_s(1:prefix),original.bagging.SelectedWindows_s(1:prefix));
                t.verifyEqual(bag.PoolIndices,original.bagging.PoolIndices);
                for index=bag.PoolIndices'
                    frequency=nnz(bag.SelectedWindows_s==actual.table.Window_s(index))/count;
                    t.verifyEqual(actual.table.BaggingSelectionFrequency(index),frequency);
                end
                t.verifyEqual(actual.table.BootstrapB(actual.selectedIndex),p.optimization.candidateResamples);
                t.verifyEqual(rng,state);
            end
            repeated=optimizeCoincidenceWindow(o.A,o.B,o.matches,p,model);
            t.verifyEqual(actual,repeated);
            p.optimization.bootstrapCandidates=1; p.optimization.baggingResamples=32;
            single=optimizeCoincidenceWindow(o.A,o.B,o.matches,p,model);
            t.verifyEqual(single.bagging.SelectedWindows_s,repmat(single.window,32,1));
            t.verifyEqual(single.bagging.SelectionFrequency(single.selectedIndex),1);
        end

        function customCountIsSavedInSettingsAndBothExportPaths(t)
            [o,p,~]=fixture(); p.optimization.baggingResamples=401;
            source=struct('startFile',"input_CH1.txt",'stopFile',"input_CH2.txt");
            result=analyzeTimestampData(o.A,o.B,p,source,"imported");
            t.assertTrue(result.optimization.valid,result.optimization.status);
            t.verifyEqual(result.uncertainty.bootstrap.resamples,p.uncertainty.resamples);
            folder=tempname; cleanup=onCleanup(@()rmdir(folder,'s'));
            options=struct('settings',true,'histogram',false,'results',false,'timestamps',false, ...
                'optimization',true,'unitSeconds',1e-12);
            exportSelectedResults(result,folder,"custom",options);
            saved=load(fullfile(folder,'custom_settings.mat'));
            t.verifyEqual(saved.params.optimization.baggingResamples,401);
            summary=readtable(fullfile(folder,'custom_optimization_summary.csv'),'TextType','string');
            t.verifyEqual(summary.BaggingReps,401);
            t.verifyEqual(summary.Config_baggingResamples,401);
            options=struct('histogram',false,'results',true,'uncertainty',false, ...
                'optimization',true,'unitSeconds',1e-12);
            exportBatchResult(result,folder,"batch",options);
            summary=readtable(fullfile(folder,'batch_optimization_summary.csv'),'TextType','string');
            t.verifyEqual(summary.BaggingReps,401);
            t.verifyEqual(summary.Config_baggingResamples,401);
            params=readtable(fullfile(folder,'batch_results.csv'), ...
                'VariableNamingRule','preserve','TextType','string');
            row=params.('参数')=="params.optimization.baggingResamples";
            t.verifyEqual(nnz(row),1); t.verifyEqual(str2double(string(params.('数值')(row))),401);

            options=struct('settings',false,'histogram',false,'results',false,'timestamps',false, ...
                'evaluation',true,'unitSeconds',1e-12);
            files=exportSelectedResults(result,folder,"scores",options);
            t.assertEqual(files,string(fullfile(folder,'scores_window_evaluation.csv')));
            scores=readtable(files,'TextType','string');
            scan=result.optimization.windowScan; bag=result.optimization.bagging;
            pool=bag.PoolIndices;
            t.verifyTrue(all(isnan(str2double(string(scores.Seed)))));
            t.verifyEqual(scores.W_ns,scan.Window_s*1e9,'AbsTol',1e-12);
            t.verifyEqual(logical(scores.Valid),scan.ValidCandidate);
            t.verifyEqual(scores.V(pool),bag.ScoreVariance(pool),'RelTol',1e-12);
            t.verifyEqual(scores.J(pool),scores.V(pool)./scores.Eta(pool).^2,'RelTol',1e-12);
            t.verifyEqual(scores.J_mean(pool),bag.ScoreMean(pool),'RelTol',1e-12);
            t.verifyEqual(scores.J_std(pool),bag.ScoreStd(pool),'RelTol',1e-12);
            t.verifyTrue(all(isnan(scores.J(~scan.ValidCandidate))));
            clear cleanup
        end

        function tiedScoresPreferSmallestWidthAndSeedWraps(t)
            p=defaultParams(); p.optimization.selection="bootstrap-bagging";
            p.uncertainty.seed=2^32-1;
            a=struct('time',((0:29)'+.5)/30);
            delta=[0;0;3.6e-9;4.9e-9;6.2e-9;-3.6e-9;-4.9e-9;-6.2e-9];
            b=struct('time',sort(reshape(a.time'+delta,[],1)));
            matches=struct('indexA',repelem((1:30)',8),'deltaT',repmat(delta,30,1));
            model=struct('valid',true,'peak',0,'sigma',.2e-9,'signalTotal',60,'backgroundDensity',5e9);
            widths=[1.2;1.3]*1e-9;
            capture=erf(widths/(2*sqrt(2)*model.sigma));
            bag=selectBootstrapBaggedWindow(a,b,matches,p,model,widths,[true;true], ...
                [3;3]*1e-9,capture,[1;1]);
            t.assertTrue(bag.valid,bag.status);
            t.verifyEqual(bag.Seed,99172);
            t.verifyEqual(bag.SelectedWindows_s,repmat(widths(1),101,1));
            t.verifyEqual(bag.SelectionFrequency,[1;0]);
            t.verifyEqual(bag.selectedIndex,1);
        end

        function existingCandidateControlCapsBaggingPoolAtEleven(t)
            [o,p,model]=fixture(); p.optimization.bootstrapCandidates=200;
            many=optimizeCoincidenceWindow(o.A,o.B,o.matches,p,model);
            t.assertTrue(many.valid);
            t.verifyLessThanOrEqual(numel(many.bagging.PoolIndices),11);
            p.optimization.bootstrapCandidates=1;
            single=optimizeCoincidenceWindow(o.A,o.B,o.matches,p,model);
            t.assertTrue(single.valid);
            t.verifyEqual(numel(single.bagging.PoolIndices),1);
            t.verifyEqual(single.status,"bagging-single-candidate");
            defaults=defaultParams(); t.verifyEqual(defaults.optimization.selection,"narrowest");
        end

        function fineGridReproducibilityAndTruthBlindness(t)
            [o,p,model]=fixture(); state=rng;
            a=optimizeCoincidenceWindow(o.A,o.B,o.matches,p,model);
            b=optimizeCoincidenceWindow(o.A,o.B,o.matches,p,model);
            t.verifyEqual(rng,state); t.assertTrue(a.valid,a.status);
            t.verifyEqual(a,b); t.verifyEqual(a.bagging.Reps,101);
            t.verifyEqual(a.bagging.Seed,mod(double(p.uncertainty.seed)+99173,2^32));
            minimum=2*sqrt(2)*model.sigma*erfinv(p.optimization.targetCapture);
            expected=unique([p.optimization.windowCandidates, ...
                ceil(minimum*(1:.025:1.4)/p.tdc.resolution)*p.tdc.resolution]);
            t.verifyEqual(a.table.Window_s,expected(:));
            bag=a.bagging; first=find(a.table.ValidCandidate,1);
            t.verifyEqual(bag.PoolIndices(1),first);
            t.verifyLessThanOrEqual(numel(bag.PoolIndices),min(11,p.optimization.bootstrapCandidates));
            t.verifyTrue(all(bag.PoolWindows_s<=1.4*a.table.Window_s(first)));
            t.verifyEqual(sum(a.table.BaggingSelectionFrequency,'omitnan'),1,'AbsTol',1e-14);
            t.verifyTrue(all(isnan(a.table.BaggingSelectionFrequency(setdiff((1:height(a.table))',bag.PoolIndices)))));
            % 删除所有真值字段，直接选窗仍得到相同的 Bagging 和正式 Bootstrap。
            aa=struct('time',o.A.time); bb=struct('time',o.B.time);
            mm=struct('deltaT',o.matches.deltaT,'indexA',o.matches.indexA);
            blind=optimizeCoincidenceWindow(aa,bb,mm,p,model);
            t.verifyEqual(blind,a);
            changed=p; changed.uncertainty.seed=1;
            other=optimizeCoincidenceWindow(aa,bb,mm,changed,model);
            t.verifyEqual(other.bagging.Seed,99174); t.verifyEqual(rng,state);
        end

        function aggregationMatchesSharedIndexConditionalVariance(t)
            [o,p,model]=fixture(); p.optimization.baggingResamples=401;
            r=optimizeCoincidenceWindow(o.A,o.B,o.matches,p,model);
            t.assertTrue(r.valid); bag=r.bagging; M=bag.BlockCount;
            anchor=min(M,max(1,floor(o.A.time(o.matches.indexA)/(p.measurementTime/M))+1));
            X=zeros(M,numel(bag.PoolIndices));
            for j=1:numel(bag.PoolIndices)
                index=bag.PoolIndices(j); width=r.table.Window_s(index);
                q=p; q.algorithm.sidebandGuard=r.table.SideGuard_s(index);
                edges=accidentalSideWindows(model,q,width);
                main=abs(o.matches.deltaT-model.peak)<=width/2;
                C=accumarray(anchor(main),1,[M 1]); S=zeros(M,size(edges,1));
                for k=1:size(edges,1)
                    mask=o.matches.deltaT>=edges(k,1) & o.matches.deltaT<edges(k,2);
                    S(:,k)=accumarray(anchor(mask),1,[M 1]);
                end
                X(:,j)=C-mean(S,2);
            end
            stream=RandStream('mt19937ar','Seed',bag.Seed); chosen=zeros(401,1);
            capture=r.table.CaptureEstimate(bag.PoolIndices)';
            scores=zeros(401,numel(capture));
            for k=1:401
                indices=randi(stream,M,M,1);
                score=M*var(X(indices,:),1,1)./capture.^2;
                scores(k,:)=score;
                [~,winner]=min(score); chosen(k)=bag.PoolWindows_s(winner);
            end
            t.verifyEqual(bag.SelectedWindows_s,chosen);
            t.verifyEqual(bag.ScoreVariance(bag.PoolIndices),(M*var(X,1,1))','RelTol',1e-12);
            t.verifyEqual(bag.ScoreMean(bag.PoolIndices),mean(scores,1)','RelTol',1e-12);
            t.verifyEqual(bag.ScoreStd(bag.PoolIndices),std(scores,0,1)','RelTol',1e-12);
            t.verifyEqual(bag.MeanSelectedWindow_s,mean(chosen));
            valid=find(r.table.ValidCandidate);
            [~,nearest]=min(abs(r.table.Window_s(valid)-mean(chosen)));
            t.verifyEqual(r.selectedIndex,valid(nearest));
            % 独立枚举全部 3^3 个重抽样，核对 M*var(X,1) 的总体方差口径。
            x=[2;4;9]; [a,b,c]=ndgrid(1:3); totals=x(a(:))+x(b(:))+x(c(:));
            t.verifyEqual(var(totals,1),3*var(x,1),'AbsTol',1e-12);
        end

        function projectionOutsidePoolGetsFormalBootstrapAndExport(t)
            [o,p,model]=fixture(); r=optimizeCoincidenceWindow(o.A,o.B,o.matches,p,model);
            t.assertTrue(r.valid);
            t.verifyFalse(ismember(r.selectedIndex,r.bagging.PoolIndices));
            t.verifyEqual(r.bagging.CacheBuildCount,numel(r.bagging.PoolIndices)+1);
            sampled=find(~cellfun(@isempty,r.candidateBootstrap));
            t.verifyEqual(sampled,r.selectedIndex);
            t.verifyTrue(isfinite(r.table.BootstrapU_side(r.selectedIndex)));
            t.verifyTrue(all(isfinite(r.table{r.selectedIndex,{'CI_side_lower','CI_side_upper'}})));
            t.verifyEqual(r.table.BootstrapB(r.selectedIndex),p.optimization.candidateResamples);
            result=analyzeTimestampData(o.A,o.B,p,o.source,"imported");
            t.verifyTrue(all(isnan(result.optimization.windowScan.TP)));
            folder=tempname; cleanup=onCleanup(@()rmdir(folder,'s'));
            options=struct('settings',false,'histogram',false,'results',false,'timestamps',false, ...
                'optimization',true,'unitSeconds',1e-12);
            exportSelectedResults(result,folder,"bag",options);
            summary=readtable(fullfile(folder,'bag_optimization_summary.csv'),'TextType','string');
            t.verifyEqual(summary.Selection,"bootstrap-bagging"); t.verifyEqual(summary.BaggingReps,101);
            scan=readtable(fullfile(folder,'bag_optimization_windows.csv'));
            t.verifyTrue(ismember('BaggingSelectionFrequency',scan.Properties.VariableNames));
            clear cleanup
        end

        function boundariesReturnExplicitDiagnostics(t)
            [o,p,model]=fixture(); r=optimizeCoincidenceWindow(o.A,o.B,o.matches,p,model);
            width=r.table.Window_s(find(r.table.ValidCandidate,1));
            one=optimizeCoincidenceWindow(o.A,o.B,o.matches,p,model,width);
            t.verifyTrue(one.valid); t.verifyEqual(one.status,"bagging-single-candidate");
            t.verifyEqual(one.table.BaggingSelectionFrequency,1);
            t.verifyEqual(one.bagging.SelectedWindowSD_s,0);
            no=optimizeCoincidenceWindow(o.A,o.B,o.matches,p,model,100e-9);
            t.verifyFalse(no.valid); t.verifyEqual(no.status,"no-valid-window");
            q=p; q.uncertainty.enabled=false;
            disabled=optimizeCoincidenceWindow(o.A,o.B,o.matches,q,model);
            t.verifyFalse(disabled.valid); t.verifyEqual(disabled.status,"bagging-requires-bootstrap");
            disabled=optimizeCoincidenceParameters(o.A,o.B,o.matches,q,"imported");
            t.verifyEqual(disabled.status,"bagging-requires-bootstrap");
            q=p; q.uncertainty.blockMode="manual"; q.uncertainty.blockSize=1;
            short=optimizeCoincidenceWindow(o.A,o.B,o.matches,q,model);
            t.verifyFalse(short.valid); t.verifyEqual(short.status,"insufficient-bagging-blocks");
            [bad,blocks]=selectBootstrapBaggedWindow(o.A,o.B,o.matches,p,model,width,true,1,1,1);
            t.verifyFalse(bad.valid); t.verifyEmpty(blocks);
            t.verifyEqual(bad.status,"bagging-score-unavailable");
            t.verifyFalse(bad.ValidCandidates);
        end

        function heldOutRunsBaggingOnlyOnTrainingBlocks(t)
            [o,p,~]=fixture(); p.uncertainty.blockMode="manual"; p.uncertainty.blockSize=.01;
            p.optimization.baggingResamples=32;
            profile clear; profile on;
            cleanup=onCleanup(@()profile('off'));
            v=validateAdaptiveSelection(o.A,o.B,o.matches,p,"simulation");
            profile off; info=profile('info'); clear cleanup
            t.assertTrue(v.valid,v.status);
            calls=info.FunctionTable(strcmp({info.FunctionTable.FunctionName},'selectBootstrapBaggedWindow'));
            t.assertEqual(numel(calls),1); t.verifyEqual(calls.NumCalls,1);
            t.verifyEmpty(intersect(v.trainingBlocks,v.evaluationBlocks));
            t.verifyEqual(v.summary.Window_s(4),v.trainingOptimization.window);
            t.verifyEqual(v.trainingOptimization.bagging.Reps,32);
            t.verifyEqual(v.summary.Duration_s,repmat(v.evaluationDuration,4,1));
        end
    end
end

function [o,p,model]=fixture()
persistent data peak
if isempty(data)
    q=defaultParams(); q.source.pairRate=2e4;
    q.detector.A.backgroundRate=1e5; q.detector.B.backgroundRate=1e5;
    q.optimization.mode="manual"; q.optimization.candidateResamples=100;
    q.uncertainty.resamples=100;
    data=runSimulation(q); peak=estimateCoincidencePeak(data.matches,q);
end
o=data; p=o.params; p.optimization.mode="recommend"; p.optimization.selection="bootstrap-bagging";
model=peak;
end
