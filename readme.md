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

| 目录             | 主要内容                                                                  | Filelist core    |
| ---------------- | ------------------------------------------------------------------------- | ---------------- |
| `common/`        | 仲裁器、pipe、同步/异步FIFO、RAM adapter、CDC和基础控制模块               | `dmg:com:common` |
| `axi/`           | AXI读写通道仲裁、清除、regslice、extended burst和EBUS/AXI DMA             | `dmg:com:axi`    |
| `csr/`           | APB/AHB-Lite/AXI-Lite bridge、regslice、CDC、仲裁、timeout和package engine | `dmg:com:csr`    |
| `impl_template/` | 项目初始工艺模板，包括实现宏、stdcell wrapper、ECC wrapper和memory shell  | 不进入通用core   |
| `sim/`           | 各模块族的独立testbench、Makefile、GTKWave和Verdi波形配置                 | 仿真环境自行引用 |
| `filelist/`      | `rtl_flist_mgr`使用的结构化TOML core                                      | `dmg:com:all`    |

`dmg:com:axi`和`dmg:com:csr`均依赖`dmg:com:common`；`dmg:com:all`聚合三组稳定RTL。`com_define.sv`属于Common IP的编译前置文件，定义参数和信号断言宏。定义`COM_ASSERT_ON`后启用断言，未定义时不会为RTL引入额外断言依赖。

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

`axi/`将AXI读写通道拆分为独立模块，提供仲裁、复位清除和双向regslice。`com_axi_extd_wr/rd`负责大长度访问的burst拆分，`com_axi_dma`在EBUS与AXI之间完成数据搬运、边界拆分、响应合并和读数据缓存。需要按subsystem生成专属DMA时，使用[py_gen_dma](axi/py_gen_dma/README.md)。

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

正式项目可以通过`filelist/*.toml`选择Common、AXI、CSR或完整RTL集合，但不得直接引用本仓库的`impl_template/`作为量产实现目录。`impl_template/`是后端工艺库的初始模板，应复制到项目的`impl/`后独立维护工艺宏、memory model、SRAM shell、PHY wrapper和stdcell wrapper。

同一项目中的`impl_define.sv`和公共memory model只保留一份，由whole-chip filelist统一引入。SRAM shell应使用Memory Tool按`subsys_prefix`生成；不同subsystem使用不同prefix，同一subsystem内需要强制区分PPA约束的memory可通过`MEM_USER`指定唯一名称。

提交RTL前应遵循[编码规范](doc/coding_style.md)，运行受影响模块族的回归，并检查对应GTKWave或Verdi波形配置仍能正确加载。
