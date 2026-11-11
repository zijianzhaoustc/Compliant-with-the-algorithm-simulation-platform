function runInferenceGuiSmoke(folder)
%RUNINFERENCEGUISMOKE Exercise actual app recalculate and results callbacks.
if ~isfolder(folder), mkdir(folder); end
app=CoincidenceSimulatorApp(); cleanup=onCleanup(@()delete(app));
n=800; a=linspace(.002,3.998,n)'; d=.3e-9*sqrt(2)*erfinv(2*((1:n)'-.5)/n-1);
p=defaultParams(); p.measurementTime=4; p.optimization.mode="manual"; p.uncertainty.enabled=false;
A=struct('time',a,'pairID',zeros(n,1),'type',repmat("measured",n,1)); B=A; B.time=a+d;
app.LastResult=analyzeTimestampData(A,B,p,struct(),'imported');
c=app.Controls; c.InferenceEnabled.Value=true; c.InferenceBlock.Value=.2;
c.InferenceB.Value=0; c.OptimizationMode.Value='manual'; c.BootstrapEnabled.Value=false;
cb=c.RecalculateButton.ButtonPushedFcn; cb(c.RecalculateButton,[]); drawnow;
assert(~isempty(app.LastResult.inference)); assert(isfinite(app.LastResult.inference.Cpair));
app.ParameterTabs.SelectedTab=app.InferenceTab;
exportapp(app.UIFigure,fullfile(folder,'inference_app.png'));
buttons=findall(app.InferenceTab,'Type','uibutton','Text','查看推断结果与独立验证图');
cb=buttons.ButtonPushedFcn; cb(buttons,[]); drawnow;
f=findall(groot,'Type','figure','Name','无分箱相关峰推断与验证');
assert(~isempty(f)); exportapp(f(1),fullfile(folder,'inference_viewer.png')); delete(f);
fprintf('GUI_SMOKE_PASSED Cpair=%.8g\n',app.LastResult.inference.Cpair);
end
