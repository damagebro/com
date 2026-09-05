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
|---|impl_template/  工艺实现模板，复制到项目仓库后独立管理；正式项目的memory shell由mem_tool生成。
```

# 正式项目集成

正式项目不得直接引用本仓库 `impl_template/` 中的 RTL 或 filelist。应先将 `impl_template/` 复制到项目仓库，由项目独立管理工艺配置、公共模型和实现文件，并将 filelist 路径改为项目内路径。

`impl_template/memory/rtl/shell/com_*_shell.sv` 仅供模板参考和 `com` 仓库自身验证使用。正式项目使用 `py_tools_for_hw/mem_tool` 生成的 `<subsys_prefix>_*_shell.sv`，替换项目副本中的通用 shell，并在项目 RTL 和 filelist 中使用生成的模块。

特别是 `impl_template/define/impl_define.sv` 和 `impl_template/memory/rtl/model/com_tpram_reg.sv`，均属于 whole-chip 级公共文件。应复制到总项目仓库统一维护，每个项目只保留一份，由顶层 filelist 统一引入，各 subsystem 不再分别复制或重复编译。也可从 `mem_tool/templates/rtl/` 获取对应文件，但同一项目只能选用一套来源。

完整说明见 [impl_template/README.md](impl_template/README.md)。
