# 使用说明

1. 启动不依赖其他库的简单testbench
```
cd ./sim/sim_no_depend/
source ENV.sh;   #初始化环境变量
make com;        #编译
make run;        #运行vcs仿真
make verdi;      #启动verdi看波形;     其他仿真环境也依赖这几步;
```


2. 通过com_axi_dma仿真环境，熟悉ebus/axi协议;
```
cd ./sim/sim_dma/
source ENV.sh;
make com run;   #编译+运行;
make verdi;
```


# common_ip简介
```
|com/
|---|filelist/
|---|common/   基础ip, fifo/artbier/cdc/pipe流水线控制等;
|---|axi/      简化axi协议的ebus协议，可以发任意大的burst_len;  (1)ebus->axi转换路径自动拆分burst, 不跨地址边界;  (2)多路仲裁成1路axi; (3)axi复位保护;  (4)插regslice打拍等;
|---|csr/      自定义寄存器总线协议, 配套csr_tool;
|---|img/      基础图像处理ip通用模块;
|---|impl_template/  工艺库相关文件(stdcell/design_ware/sram等), 每个项目新产生一个该目录，不要使用本文件夹里的rtl模块。 目前主要是sram封装成shell;   配套mem_tool, 根据rtl例化sram_shell参数值，自动提取所有sram尺寸并生成excel;   sram_excel与前后端交互， 后端返回真实sram_lib，再通过mem_tool集成到sram_shell中;
```
