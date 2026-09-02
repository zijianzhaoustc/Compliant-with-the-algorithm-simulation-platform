function results = runTimePerformanceSweep(outputFile)
%RUNTIMEPERFORMANCESWEEP 按时间性能汇总表的参数组合执行仿真。
%   对探测器抖动、TDC 抖动和 TDC 分辨率做单因素扫描，其他两项
%   保持默认值 150/10/10 ps。每个唯一组合使用种子 1、2、3、4，
%   同一批时间戳分别做最大值寻峰和高斯拟合寻峰。

if nargin<1, outputFile="outputs/time_performance_simulation/time_performance_results.csv"; end
detectorValues=[0 50 100 150 200 300 500];
tdcJitterValues=[0 5 10 20 50 100];
resolutionValues=[1 5 10 20 50 100];
base=[150 10 10];

% 基准组合在三组扫描中重复，只保留一次，每个种子共 17 组。
configs=[detectorValues(:),repmat(base(2:3),numel(detectorValues),1); ...
    repmat(base(1),numel(tdcJitterValues)-1,1),tdcJitterValues(tdcJitterValues~=base(2))', ...
        repmat(base(3),numel(tdcJitterValues)-1,1); ...
    repmat(base(1:2),numel(resolutionValues)-1,1),resolutionValues(resolutionValues~=base(3))'];

nRows=4*size(configs,1); values=nan(nRows,14); row=0;
for seed=1:4
    for c=1:size(configs,1)
        row=row+1; detectorPs=configs(c,1); tdcPs=configs(c,2); resolutionPs=configs(c,3);
        p=defaultParams(); p.seed=seed;
        p.detector.A.jitter=detectorPs*1e-12; p.detector.B.jitter=detectorPs*1e-12;
        p.tdc.A.jitter=tdcPs*1e-12; p.tdc.B.jitter=tdcPs*1e-12;
        p.tdc.resolution=resolutionPs*1e-12;
        p.algorithm.peakMethod="maximum";
        maximum=runSimulation(p);

        gaussianParams=maximum.params; gaussianParams.algorithm.peakMethod="gaussian";
        gaussian=recalculateAnalysis(maximum,gaussianParams);
        values(row,:)=[seed,detectorPs,tdcPs,resolutionPs, ...
            maximum.metrics.TrueSigma*1e12,maximum.metrics.FWHM*1e12, ...
            maximum.metrics.PeakPositionError*1e12,maximum.metrics.Recall,maximum.metrics.F1, ...
            gaussian.metrics.TrueSigma*1e12,gaussian.metrics.FWHM*1e12, ...
            gaussian.metrics.PeakPositionError*1e12,gaussian.metrics.Recall,gaussian.metrics.F1];
        fprintf('Completed %d/%d: seed=%d, detector=%g ps, TDC=%g ps, resolution=%g ps\n', ...
            row,nRows,seed,detectorPs,tdcPs,resolutionPs);
    end
end

names={'Seed','DetectorJitterPs','TdcJitterPs','TdcResolutionPs', ...
    'MaxTrueSigmaPs','MaxFwhmPs','MaxPeakErrorPs','MaxRecall','MaxF1', ...
    'GaussianTrueSigmaPs','GaussianFwhmPs','GaussianPeakErrorPs','GaussianRecall','GaussianF1'};
results=array2table(values,'VariableNames',names);
writetable(results,outputFile);
end
