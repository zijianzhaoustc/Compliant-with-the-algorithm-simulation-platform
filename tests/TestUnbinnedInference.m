classdef TestUnbinnedInference < matlab.unittest.TestCase
    %TESTUNBINNEDINFERENCE Deterministic kernel, leakage and label isolation.
    methods (Test)
        function boundaryProtectionAndEmptyBlocks(t)
            o=inferenceOptions(); o.blockSeconds=1; o.domain=[-.1 .1];
            A=struct('time',[.5;.99;1.01;1.5]); B=struct('time',[.51;1;1.51]);
            z=splitTimestampBlocks(A,B,4,o.domain,o);
            t.verifyEqual([z.items.pairCount],[1 1 0 0]);
            t.verifyEqual(sum([z.items.exposure]),3.2,'AbsTol',1e-14);
            t.verifyEqual(z.items(1).countA,1); t.verifyEqual(z.items(2).countA,1);
        end
        function spillMatchesMemoryAndKeepsZeroBlocks(t)
            [A,B,p]=fixture(); p.inference.maxPairsInMemory=50;
            z=splitTimestampBlocks(A,B,p.measurementTime,p.inference.domain,p.inference);
            t.verifyTrue(z.spilled); t.verifyLessThanOrEqual(z.maxResidentPairs,50);
            n=sum([z.items.pairCount]);
            p.inference.maxPairsInMemory=5e6;
            q=splitTimestampBlocks(A,B,p.measurementTime,p.inference.domain,p.inference);
            t.verifyEqual(sum([q.items.pairCount]),n);
        end
        function labelsCannotAffectInference(t)
            [A,B,p]=fixture(); r=crossFitUnbinned(A,B,p);
            A.pairID(:)=0; B.pairID(:)=0; q=crossFitUnbinned(A,B,p);
            t.verifyEqual(rmfield(r,'truth_Nrec'),rmfield(q,'truth_Nrec'));
            t.verifyEqual(r.truth_Nrec,800); t.verifyTrue(isnan(q.truth_Nrec));
            t.verifyGreaterThan(r.Cpair,180); t.verifyLessThan(r.Cpair,220);
            t.verifyTrue(isnan(r.etaB_given_A));
            t.verifyEqual(intersect(r.folds{1}.trainingBlocks,r.folds{1}.evaluationBlocks),zeros(1,0));
        end
        function emptySingleChannelAndNoFakeIntervals(t)
            p=defaultParams(); p.measurementTime=4; p.inference.bootstrapCount=2;
            p.inference.blockSeconds=.2;
            A=struct('time',zeros(0,1)); B=struct('time',.5);
            q=crossFitUnbinned(A,B,p);
            t.verifyTrue(isnan(q.Cpair)); t.verifyTrue(all(isnan(q.bootstrap.CI95),'all'));
            t.verifyEqual(q.status,"insufficient-events");
        end
        function bootstrapReproducibleAndPreservesRng(t)
            [A,B,p]=fixture(); p.inference.bootstrapCount=3; state=rng;
            a=crossFitUnbinned(A,B,p); b=crossFitUnbinned(A,B,p);
            t.verifyEqual(a.bootstrap,b.bootstrap); t.verifyEqual(rng,state);
            t.verifyEqual(height(a.bootstrap.samples),3);
            t.verifyTrue(all(isnan(a.bootstrap.CI95),'all'));
        end
        function doubleGaussianFitsContinuousDelays(t)
            o=inferenceOptions(); o.model="doublegaussian"; o.maxIterations=600;
            m=model("doublegaussian"); u=((1:1000)'-.5)/1000;
            d=[m.sigma1*sqrt(2)*erfinv(2*u(1:800)/.8-1); ...
                m.delta+m.sigma2*sqrt(2)*erfinv(2*(u(801:end)-.8)/.2-1)];
            f=fitTimeResponse(d,1,0,o);
            t.verifyTrue(f.valid); t.verifyGreaterThan(f.model.sigma2,f.model.sigma1);
            t.verifyEqual(f.N,1000,'AbsTol',1);
        end
        function legacyDisabledAndImportedIntegerPrecision(t)
            p=defaultParams(); p.measurementTime=.01; p.source.pairRate=1000;
            p.optimization.mode="manual"; p.uncertainty.enabled=false;
            old=rmfield(p,'inference'); a=runSimulation(old); b=runSimulation(p);
            t.verifyEqual(a,b); t.verifyEmpty(a.inference);
            root=string(tempname); mkdir(root); cleanup=onCleanup(@()rmdir(root,'s'));
            fa=fullfile(root,'a.txt'); fb=fullfile(root,'b.txt');
            writelines(["90071992547409920";"90071992547410920"],fa);
            writelines(["90071992547409923";"90071992547410923"],fb);
            q=importTimestampFiles(fa,fb,1e-12,p,false,struct('durationSeconds',1));
            t.verifyEqual(q.B.time-q.A.time,repmat(3e-12,2,1),'AbsTol',1e-24);
            t.verifyEqual(q.params.measurementTime,1); t.verifyEqual(q.source.exposureSource,"declared");
            t.verifyError(@()importTimestampFiles(fa,fb,1e-12,p,false,struct('durationSeconds',1e-12)), ...
                'CoincidenceSim:InvalidDuration');
        end
        function exportMeasuredManifestAndUnknownBackground(t)
            [A,B,p]=fixture(); root=string(tempname); mkdir(root);
            cleanup=onCleanup(@()rmdir(root,'s'));
            fa=fullfile(root,'a.txt'); fb=fullfile(root,'b.txt');
            writematrix(A.time,fa); writematrix(B.time,fb);
            manifest=table(fa,fb,1,4,0, ...
                'VariableNames',{'startFile','stopFile','unitSeconds','durationSeconds','rawOrigin'});
            result=analyzeRateEfficiency(manifest,p,fullfile(root,'result'));
            t.verifyTrue(isnan(result.inference_truth_Nrec));
            t.verifyTrue(isnan(result.inference_etaB_given_A));
            t.verifyEqual(result.exposure_source,"declared");
            t.verifyTrue(isfile(fullfile(root,'result','dataset_0001','settings_used.json')));
            t.verifyTrue(isfile(fullfile(root,'result','dataset_0001','IRF_validation.png')));
        end
    end
end
function m=model(kind)
m=struct('type',kind,'mu',0,'sigma1',.3e-9,'sigma2',1.2e-9,'alpha',.2,'delta',.7e-9);
end
function [A,B,p]=fixture()
p=defaultParams(); p.measurementTime=4; p.inference.enabled=true;
p.inference.blockSeconds=.2; p.inference.bootstrapCount=0;
p.inference.initialSigma=.3e-9;
u=((1:800)'-.5)/800;
a=linspace(.002,3.998,800)'; d=.3e-9*sqrt(2)*erfinv(2*u-1);
A=struct('time',a,'pairID',(1:800)'); B=struct('time',a+d,'pairID',(1:800)');
end
