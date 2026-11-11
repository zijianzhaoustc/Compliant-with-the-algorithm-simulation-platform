classdef TestUnbinnedMath < matlab.unittest.TestCase
    methods (Test)
        function normalizedAndAnalyticMass(t)
            for kind=["gaussian","doublegaussian"]
                m=model(kind); [~,F]=evaluateIRF([],m,[-100 100]*1e-9);
                t.verifyEqual(F,1,'AbsTol',1e-12);
                q=integral(@(x)evaluateIRF(x,m,[-100 100]*1e-9),-100e-9,100e-9,'AbsTol',1e-10);
                t.verifyEqual(q,1,'AbsTol',1e-7);
                [~,small]=evaluateIRF([],m,[-.5 .5]*1e-9);
                t.verifyGreaterThanOrEqual(F,small);
                t.verifyGreaterThanOrEqual(small,0);
            end
        end
        function concavityScoreAndZeroBackground(t)
            m=model("gaussian"); d=linspace(-1,1,101)'*1e-9;
            r=solveUnbinnedAmplitude(d,m,1e9,[-10 10]*1e-9);
            t.verifyGreaterThan(r.N,0); t.verifyLessThan(abs(r.score),1e-8);
            t.verifyLessThan(r.curvature,0);
            zero=solveUnbinnedAmplitude(d,m,0,[-10 10]*1e-9);
            t.verifyEqual(zero.N,101,'AbsTol',1e-7);
            boundary=solveUnbinnedAmplitude(d,m,1e15,[-10 10]*1e-9);
            t.verifyEqual(boundary.status,"boundary-fit"); t.verifyEqual(boundary.N,0);
            empty=solveUnbinnedAmplitude([],m,0,[-10 10]*1e-9);
            t.verifyEqual(empty.status,"no-events");
            m.mu=1; bad=solveUnbinnedAmplitude([],m,1,[-10 10]*1e-9);
            t.verifyEqual(bad.status,"unidentifiable-domain");
        end
        function validationAndFiniteGate(t)
            o=inferenceOptions(); o.model="invalid";
            t.verifyError(@()validateInferenceOptions(o),'CoincidenceSim:InvalidIRF');
            t.verifyError(@()unbinnedBackground([], -1,[-1 1]),'CoincidenceSim:InvalidBackground');
            m=model("gaussian");
            t.verifyError(@()solveUnbinnedAmplitude(30e-9,m,1,[-20 20]*1e-9),'CoincidenceSim:InvalidInference');
            [b,q]=unbinnedBackground([-2 0 2],struct('intercept',10,'slope',2),[-2 2]);
            t.verifyEqual(b,[6 10 6]); t.verifyEqual(q,32);
            m=model("doublegaussian"); m.alpha=0;
            [~,~,meta]=evaluateIRF([],m,[-20 20]*1e-9);
            t.verifyFalse(meta.identifiable);
            t.verifyEqual(meta.status,"unidentifiable-response");
            m.alpha=.2; m.sigma2=m.sigma1*1.01;
            [~,~,meta]=evaluateIRF([],m,[-20 20]*1e-9);
            t.verifyFalse(meta.identifiable);
        end
    end
end
function m=model(kind)
m=struct('type',kind,'mu',0,'sigma1',.3e-9,'sigma2',1.2e-9,'alpha',.2,'delta',.7e-9);
end
