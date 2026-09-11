# COM RTL Library

`com/`是面向芯片前端设计的可综合SystemVerilog公共RTL仓库，提供基础数据通路、FIFO、CDC、RAM适配、AXI/EBUS数据搬运和CSR访问配套模块。仓库中的模块统一使用`com_`前缀，强调可复用接口、明确的vld/rdy握手语义，以及可独立运行的模块级回归环境。

当前Common IP、AXI和CSR主体功能已进入稳定维护阶段。模块参数、接口和行为以对应手册为准；复杂实现的设计取舍记录在微架构文档中，README只提供仓库级入口。

## 文档导航

| 内容                | 文档                                                                | 说明                                     |
| ------------------- | ------------------------------------------------------------------- | ---------------------------------------- |
| Common IP接口与使用 | [common_rtl_manual.md](doc/common_rtl_manual.md)                     | 仲裁、pipe、FIFO、RAM adapter和CDC       |
| Common IP微架构     | [common_rtl_uarch.md](doc/common_rtl_uarch.md)                       | SRAM FIFO、异步FIFO等复杂模块的实现说明  |
| AXI与DMA            | [common_rtl_dma_manual.md](doc/common_rtl_dma_manual.md)             | EBUS协议、AXI读写通道和DMA burst拆分     |
| CSR                 | [common_rtl_csr_manual.md](doc/common_rtl_csr_manual.md)             | AMBA bridge与CSR fabric，配套CSR Tool使用 |
| RTL编码规范         | [coding_style.md](doc/coding_style.md)                               | 端口、信号、时序逻辑、例化和断言代码风格 |
| 工艺实现模板        | [impl_template/README.md](impl_template/README.md)                   | stdcell、ECC、memory shell和项目集成边界 |
| CSR Tool            | [csr_tool/README.md][csr-tool-readme]                                | CSR寄存器RTL生成与集成                   |
| Memory Tool         | [mem_tool/README.md][mem-tool-readme]                                | SRAM需求、shell生成和PHY集成流程         |
| RTL Filelist Tool   | [rtl_flist_mgr/README.md][rtl-flist-tool-readme]                     | TOML filelist解析与输出                  |

[csr-tool-readme]: https://github.com/damagebro/py_tools_for_hw/blob/main/csr_tool/README.md
[mem-tool-readme]: https://github.com/damagebro/py_tools_for_hw/blob/main/mem_tool/README.md
[rtl-flist-tool-readme]: https://github.com/damagebro/py_tools_for_hw/blob/main/rtl_flist_mgr/README.md

## RTL组成

| 目录             | 主要内容                                                                |
| ---------------- | ----------------------------------------------------------------------- |
| `common/`        | 仲裁器、pipe、同步/异步FIFO、RAM adapter、CDC和基础控制模块                |
| `axi/`           | AXI读写通道仲裁、清除、regslice、extended burst和EBUS/AXI DMA              |
| `csr/`           | APB/AHB-Lite/AXI-Lite bridge、regslice、CDC、仲裁、timeout和package engine |
| `impl_template/` | 项目初始工艺模板，不进入通用core                                         |
| `sim/`           | 各模块族的独立testbench、Makefile、GTKWave和Verdi波形配置                  |
| `filelist/`      | 按是否依赖项目impl划分的两个TOML core                                    |

文件清单按实现依赖划分，而不是按RTL目录划分：

- [com_base_ip.toml](filelist/com_base_ip.toml)：`dmg:com:base_ip`，仅依赖本仓库文件，包含基础模块、同步FIFO、RAM adapter、AXI通道和非CDC的CSR模块。
- [com_ip_need_impl.toml](filelist/com_ip_need_impl.toml)：`dmg:com:ip_need_impl`，自动依赖`dmg:com:base_ip`，额外包含CDC、异步FIFO和CSR CDC共6个模块，需要项目提供impl实现。DMA生成模板不在当前有效清单中。

SRAM FIFO、`com_dp_ram`和CSR package read只暴露RAM接口，不直接例化SRAM shell，因此仍属于`base_ip`；实际使用时由上层连接存储器。`com_define.sv`随`base_ip`作为编译前置文件引入，定义参数和信号断言宏；定义`COM_ASSERT_ON`后启用断言。

`ip_need_impl`通过`[fileset.cdc].depend`引入`base_ip`，为当前模块使用的断言宏提供前置文件`com_define.sv`。其模块调用包括内部的`com_cdc_rstn`、`com_async_fifo_reg`以及项目impl提供的`com_cdc_sig`。

## 主要模块族

### Common IP

- `com_arbiter_rr/wrr/iwrr`：轮询、加权轮询和交织加权轮询仲裁。
- `com_pipe_*`：valid、ready和双向regslice流水控制。
- `com_sync_fifo_*`：寄存器、SRAM、多写端口、prefetch和full-bypass FIFO。
- `com_async_fifo_reg*`：支持任意深度编码的异步FIFO，以及精确写侧水线版本。
- `com_ram_*`：多端口访问仲裁、单口/双口适配和partial-write RMW处理。
- `com_cdc_*`：单bit同步、握手CDC和双时钟域复位协同。

详细参数与接口见[Common IP手册](doc/common_rtl_manual.md)。

### AXI与DMA

`axi/`将AXI读写通道拆分为独立模块，提供仲裁、复位清除和双向regslice。`com_axi_extd_wr/rd`负责大长度访问的burst拆分，`com_axi_dma`是DMA生成模板，实现EBUS与AXI之间的数据搬运、边界拆分、响应合并和读数据缓存。项目必须通过[py_gen_dma](axi/py_gen_dma/README.md)生成`${prefix}_axi_dma`，并使用相同prefix的SRAM shell。

协议、buffer配置和burst拆分示例见[AXI/DMA手册](doc/common_rtl_dma_manual.md)。

### CSR

`csr/`围绕统一CSR vld/rdy接口提供APB、AHB-Lite和AXI-Lite转换，以及regslice、CDC、仲裁和超时接管。`com_csr_pkg_wr/rd`可通过EBUS批量执行内存中的CSR配置包，减少CPU参与大量寄存器访问的负担。

接口定义、顺序规则、超发限制和package格式见[CSR手册](doc/common_rtl_csr_manual.md)。

## 仿真回归

`sim/`中的环境彼此独立，统一把编译产物放入各自的`bin/`目录。当前首选WSL/Linux下的Verilator与GTKWave，同时保留VCS/Verdi和Xcelium入口。

```bash
cd sim/sim_fifo
source ENV.sh
make vlt
make vlt_wave
```

| 回归环境                                           | 覆盖内容                              |
| -------------------------------------------------- | ------------------------------------- |
| [sim_fifo](sim/sim_fifo/README.md)                 | 同步寄存器FIFO和SRAM FIFO             |
| [sim_afifo](sim/sim_afifo/README.md)               | 普通与精确水线异步FIFO                |
| [sim_arbiter](sim/sim_arbiter/README.md)           | RR、WRR和IWRR仲裁                     |
| [sim_pipe](sim/sim_pipe/README.md)                 | valid/ready pipe与regslice            |
| [sim_ram](sim/sim_ram/README.md)                   | RAM仲裁、adapter与RMW                 |
| [sim_cdc](sim/sim_cdc/README.md)                   | CDC handshake与复位协议               |
| [sim_simo](sim/sim_simo/README.md)                 | 单输入多输出握手                      |
| [sim_axi](sim/sim_axi/README.md)                   | AXI extended burst与DMA               |
| [sim_csr](sim/sim_csr/README.md)                   | AMBA bridge、CSR fabric与连续访问性能 |
| [sim_csr_pkg](sim/sim_csr_pkg/README.md)           | CSR package解析、跳转和EBUS读写       |

VCS使用`make com`、`make run`和`make verdi`；Xcelium使用对应Makefile中的`make sim`入口。每个回归的目标选择、波形文件和额外参数以该目录README为准。

## 项目集成

不需要工艺实现的项目只引入`dmg:com:base_ip`；需要CDC、异步FIFO或CSR CDC时引入`dmg:com:ip_need_impl`，并在项目上层filelist中先引入实际impl core。COM不固定impl的core名称或路径，也不自动引用`impl_template/`。展开filelist不会检查外部模块是否已提供，项目仍需通过编译和展开检查实现依赖。

项目impl须提供`impl_define.sv`中的实现配置和CDC使用的`com_cdc_sig`。实际impl core的名称和路径由项目定义。

使用DMA时，由项目filelist引入生成的`${prefix}_axi_dma`和配套的`${prefix}_spram_shell`，并提供DMA使用的`COM_MEM_CTRL_W`等实现配置。`axi/com_axi_dma.sv`保留在仓库中作为生成模板，已从`ip_need_impl`的有效fileset中排除；引入该core不会自动引入DMA模板或项目生成的DMA。

`impl_template/`是后端工艺库的初始模板，应复制到项目的`impl/`后独立维护工艺宏、memory model、SRAM shell、PHY wrapper和stdcell wrapper，不得直接作为量产实现目录。

同一项目中的`impl_define.sv`和公共memory model只保留一份，由whole-chip filelist统一引入。SRAM shell应使用Memory Tool按`subsys_prefix`生成；不同subsystem使用不同prefix，同一subsystem内需要强制区分PPA约束的memory可通过`MEM_USER`指定唯一名称。

提交RTL前应遵循[编码规范](doc/coding_style.md)，运行受影响模块族的回归，并检查对应GTKWave或Verdi波形配置仍能正确加载。
