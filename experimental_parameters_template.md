# E 组真实 SPDC 参数模板 — NOT_RUN

状态：`NOT_RUN`。A–D 的研究设计参数不得作为真实光源/器件参数代填。

继续执行 E 组前需要：

- 有效 SPDC pair rate，或受约束且可复核的估计方法；
- A/B 两路光路总效率与探测器 PDE；
- A/B 暗计数率、杂散背景率；
- 探测器 jitter、死时间、后脉冲概率与寿命/实测延迟分布；
- FPGA 自研 TDC 与 Swabian TDC 各自独立的分辨率、jitter、死时间、固定偏置、DNL/INL 响应；
- 实际采集时长、符合窗口、寻峰与校准流程；
- 参数来源、测量日期、不确定度和适用工作点。

补齐后，从 `paperSimulationConfigs.m` 的显式 BASE 复制结构，建立独立 `E-*` 配置；不要修改 A–D BASE，也不要把 E 数据写入既有运行目录。
