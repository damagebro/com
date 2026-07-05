# Memory Tool

## 简介

`mem_tool`用于汇总芯片项目中的SRAM/ROM需求，生成前后端交付使用的Excel，并把后端提供的SRAM PHY wrapper集成到统一memory shell中。

```text
生成subsystem专属memory shell
    → 前端例化memory shell
    → 仿真生成*.lst
    → 生成memory requirement Excel
    → 后端生成SRAM PHY及wrapper
    → 前端生成集成PHY的shell
    → 编译检查所有memory shape
```

当前支持`spram`、`tpram1ck`、`tpram2ck`和`sprom`，前三类同时提供ECC shell。生成文件默认放在`mem_tool/build/`。

## 用户指南

### 芯片前端

1. 先根据subsystem名称生成专属shell：

```bash
python3 ./src/main.py -p cpu -m init -w ./build
```

2. 在项目RTL中例化`cpu_*_shell`或`cpu_ecc_*_shell`，正确配置`DATA_W`、`DEPTH`、`STRB_W`和`MEM_USER`。其中`cpu`是示例`subsys_prefix`，实际项目应替换为对应subsystem名称。
3. 通过项目仿真收集`spram.lst`、`tpram1ck.lst`、`tpram2ck.lst`和`sprom.lst`。
4. 生成提交给后端的SRAM需求：

```bash
python3 ./src/main.py -p cpu -m excel -w ./build \
    -x cpu_memory_require.xlsx -xcka 1500 -xckb 1000
```

时钟参数映射：

| Memory类型 | 写时钟 | 读时钟 |
| --- | --- | --- |
| `spram` | A时钟：`xcka` | A时钟：`xcka` |
| `tpram1ck` | A时钟：`xcka` | A时钟：`xcka` |
| `sprom` | - | A时钟：`xcka` |
| `tpram2ck` | A时钟：`xcka` | B时钟：`xckb` |

只有`tpram2ck`需要A/B两个时钟，其余memory的全部访问都使用A时钟。未指定`xckb`时，B时钟频率默认等于`xcka`。

5. 后端返回更新后的Excel和PHY wrapper后，生成集成RTL：

```bash
python3 ./src/main.py -p cpu -m inst -w ./build \
    -x cpu_memory_require.xlsx
```

6. 集成后定义`COM_RAM_NFOUND_CHK`重新编译，确认所有应使用SRAM PHY的memory shape均已匹配。

不同subsystem必须使用不同的`subsys_prefix`。即使SRAM尺寸相同，也应形成独立的需求和wrapper，避免频率、电压或其他PPA约束不同却误用同一个实现。

同一subsystem内，如果相同尺寸仍需要不同的SRAM实现，应设置不同的`MEM_USER`。`MEM_USER=0`表示默认需求，非零值用于手工区分特殊PPA或实现要求。

### 芯片后端

后端根据Excel中的`prefix`、memory类型、深度、位宽、strobe、频率、实例数量和PPA目标选择memory compiler配置。不同`prefix`属于不同subsystem，不应仅因尺寸相同而合并；同一`prefix`下不同`MEM_USER`也应作为独立需求处理。

后端返回：

1. 保留`subsys_prefix`并更新了`suffix`等wrapper命名信息的Excel。
2. 符合统一端口约定的SRAM PHY wrapper RTL。
3. 仿真model及Liberty、LEF、GDS等实现视图。
4. 无法直接实现的shape所需拆分、拼接或参数调整建议。

### 芯片验证

验证阶段默认使用RTL model完成基础读写、partial write和ECC功能验证；集成PHY wrapper后再次进行编译及读写冒烟检查。签收时应核对Excel shape数量、RTL实例数量和后端macro数量，并开启`COM_RAM_NFOUND_CHK`检查遗漏项。

## RTL开发者集成说明

### RTL目录

```text
memory/
├── rtl/
│   ├── shell/
│   │   ├── com_spram_shell.sv
│   │   ├── com_tpram1ck_shell.sv
│   │   ├── com_tpram2ck_shell.sv
│   │   ├── com_sprom_shell.sv
│   │   ├── com_sprom_manual.sv
│   │   └── com_ecc_*_shell.sv
│   └── model/
│       └── com_tpram_reg.sv
└── memory.f
```

`rtl/shell/*.sv`是所有shell的唯一人工维护源，其中`com_*`仅表示通用原始模板。脚本输出到项目使用时，会把`com_`替换为`<subsys_prefix>_`。`rtl/model`提供未集成SRAM PHY时使用的寄存器模型。

### Shell分类

| 项目生成Shell | 原始模板 | 对外访问方式 | 说明 |
| --- | --- | --- | --- |
| `<subsys_prefix>_spram_shell` | `com_spram_shell` | 单端口，`ce_n/we_n/addr` | 同一拍只能执行一种访问 |
| `<subsys_prefix>_tpram1ck_shell` | `com_tpram1ck_shell` | 单时钟独立读写端口 | 读写共享时钟 |
| `<subsys_prefix>_tpram2ck_shell` | `com_tpram2ck_shell` | 双时钟独立读写端口 | 读写可位于不同时钟域 |
| `<subsys_prefix>_sprom_shell` | `com_sprom_shell` | 单读端口 | 物理ROM shell |
| `<subsys_prefix>_sprom_manual` | `com_sprom_manual` | 单读端口 | 需要人工填写内容的ROM模板 |
| `<subsys_prefix>_ecc_*_shell` | `com_ecc_*_shell` | 对应普通RAM接口 | 在普通shell外增加SECDED保护 |

公共参数：

| 参数 | 含义 |
| --- | --- |
| `DATA_W` | 用户数据位宽 |
| `DEPTH` | memory深度 |
| `STRB_W` | partial write strobe数量，要求`DATA_W%STRB_W==0` |
| `MEM_USER` | 同一subsystem内区分相同shape的不同实现需求 |
| `REQ_PIPE` | ECC shell请求侧pipeline，范围为0或1 |
| `RSP_PIPE` | ECC shell返回侧pipeline，范围为0或1 |
| `ECC_DW` | 单个SECDED分组保护的数据位宽 |

### Subsystem隔离与MEM_USER

`-p/--subsys_prefix`是SRAM需求的一级隔离维度。它同时进入生成shell名称、Excel的`prefix`字段和PHY wrapper名称。例如CPU与NPU都使用`1024x128`的SRAM时，仍分别生成：

```text
cpu_spram_1024x128_wrapper
npu_spram_1024x128_wrapper
```

两者不能因为尺寸相同而自动合并，因为工作频率、电压、物理区域和PPA目标可能不同。

`MEM_USER`是同一subsystem内部的二级隔离维度。相同`DEPTH/DATA_W/STRB_W`默认共享一项需求；需要不同实现时，为实例设置不同的非零`MEM_USER`。报告和Excel会把它作为独立条件，默认suffix使用`usr<MEM_USER>`。

### RTL model与PHY选择

普通RAM shell使用以下规则：

1. 定义`COM_RAM_AS_REG`时强制使用`com_tpram_reg`。
2. 小memory默认使用寄存器模型；当前判断为`DEPTH<30`或`DATA_W*DEPTH<1024`。
3. 其他memory优先匹配脚本注入的SRAM PHY wrapper。
4. 未命中PHY且未定义`COM_RAM_NFOUND_CHK`时，默认回退到RTL model。
5. 定义`COM_RAM_NFOUND_CHK`后，未命中PHY会故意例化不存在的`*_not_found`模块，使编译失败。

相关宏：

| 宏 | 作用 |
| --- | --- |
| `COM_RAM_AS_REG` | 强制RAM使用寄存器模型 |
| `COM_RAM_AS_BBOX` | 将shell内部实现视为black box |
| `COM_RAM_NFOUND_CHK` | 检查应使用PHY但未匹配的memory |
| `COM_REPORT_OFF` | 关闭memory shape报告 |
| `COM_ECC_USE_RTL` | 使用自研SECDED RTL；未定义时使用Synopsys实现 |

报告代码由`synopsys translate_off/on`隔离，不参与综合。默认开启报告，定义`COM_REPORT_OFF`后关闭。

### SRAM PHY集成区

每个普通shell包含以下marker：

```systemverilog
// Start of user logic.
// End of user logic.
```

`rtl_gen.py`只替换两个marker之间的内容，为Excel中的每个shape生成条件分支和wrapper instance。分支条件由`DEPTH`、`DATA_W`、`STRB_W`和`MEM_USER`组成。

默认wrapper命名为：

```text
{subsys_prefix}_{mem_type}_{depth}x{width}[x{strb_w}][_{suffix}]_wrapper
```

wrapper端口使用shell内部统一信号：

1. `spram/tpram1ck`：`clk`、写端口、读端口及`i_cfg_mem_ctrl`。
2. `tpram2ck`：独立`wr_clk/rd_clk`、写端口、读端口及`i_cfg_mem_ctrl`。
3. `sprom`：`clk`、读端口及`i_cfg_mem_ctrl`。

同一组条件只能对应一个wrapper；Excel中重复条件会被脚本拒绝。

### ECC实现

ECC shell将`DATA_W`拆分为若干`ECC_DW`分组，每组使用SECDED编码。最后不足一个完整分组时，会单独生成last ECC group。

物理RAM row布局为：

```text
{partial_write_flag, last_ecc, normal_ecc[], original_data}
```

主要行为：

1. Full write更新全部原始数据和ECC位，并清除`partial_write_flag`。
2. Partial write只更新命中的原始数据bit，并置位`partial_write_flag`。
3. 读取到`partial_write_flag=1`的row时直接返回原始数据，不进行ECC纠错，同时屏蔽CE/UE报告。
4. ECC物理RAM使用bit write enable，确保任意partial write都能独立更新数据和最高位flag。
5. `REQ_PIPE/RSP_PIPE`分别控制请求侧和返回侧寄存。

`i_cfg_ecc_ctrl`定义：

| Bit | 含义 |
| --- | --- |
| `[0]` | `correct_n`：0开启纠错，1关闭纠错 |
| `[1]` | ECC注错使能 |
| `[3:2]` | 注错值 |

### ROM人工维护

生成`<subsys_prefix>_sprom_manual.sv`后，设计者需要在`USER_EDIT_REQUIRED`区域填写ROM数据。该文件只在不存在时生成，后续执行`init/inst`不会覆盖人工修改。

### RTL模板同步

修改`rtl/shell/*.sv`后执行：

```bash
python3 ./src/get_rtl_template.py
```

该命令抓取全部shell并重新生成`src/rtl_template.py`。提交前可检查是否同步：

```bash
python3 ./src/get_rtl_template.py --check
```

运行`mem_tool`时，`rtl_gen.py`只读取`rtl_template.py`，不再访问原始`rtl/shell`目录。因此修改shell后必须同步模板。

### 新增或修改Shell

1. 在`memory/rtl/shell`中完成并检查原始RTL。
2. 保留唯一的PHY插入marker和fallback分支。
3. 更新`memory.f`及必要的宏定义。
4. 执行`get_rtl_template.py`同步Python模板。
5. 更新`rtl_gen.py`中的端口映射或memory类型列表。
6. 增加对应单元测试并执行完整生成流程。

## 脚本开发者

### Python模块

| 文件 | 职责 |
| --- | --- |
| `main.py` | 主入口和工作模式调度 |
| `config.py` | CLI、JSON配置及优先级处理 |
| `model.py` | `MemoryShape`数据模型和公共校验 |
| `report.py` | `.lst`解析、去重和实例聚合 |
| `excel_io.py` | Excel生成与读取 |
| `rtl_gen.py` | 模块改名、PHY instance生成和RTL输出 |
| `get_rtl_template.py` | 从原始shell生成Python模板 |
| `rtl_template.py` | 自动生成的RTL字符串字典 |
| `gen_sram_excel.py` | 旧命令兼容入口 |

### 工作模式

| Mode | 输入 | 输出 |
| --- | --- | --- |
| `init` | `rtl_template.py` | 不含PHY instance的子系统shell |
| `excel` | `build/*.lst` | memory requirement Excel |
| `inst` | Excel或`*.lst` | 已注入PHY instance的子系统shell |
| `rpt_by_run_sim` | 项目filelist | 尚未实现 |

CLI显式参数优先于JSON配置。`-w/--work_path`指定输入和输出目录；`-x/--excel_name`只接受文件名，文件位于work path下。

### MemoryShape

`MemoryShape`使用`dataclass`统一保存和校验：

```text
mem_type, prefix, suffix, depth, width, strb_w, mem_user,
instance_num, hierarchy, wr_clk_mhz, rd_clk_mhz, ppa_target
```

主要约束：

1. `mem_type`必须属于支持列表。
2. `prefix/suffix`必须是合法SystemVerilog标识符。
3. `depth/width/strb_w`必须为正整数。
4. `width`必须可被`strb_w`整除。
5. `sprom`不支持write strobe。

### Report与Excel

`.lst`解析采用严格格式，非法非空行会报告文件名和行号。相同shape会聚合实例数量和hierarchy。

Excel使用固定sheet名`memory_list`，按表头名称读取，因此允许调整列顺序。主要字段包括：

```text
mem_type, prefix, suffix, depth, width, strb_w, mem_user,
wr_clk_MHz, rd_clk_MHz, ppa_target, instance_num,
capacity_KiB, hierachy
```

`hierachy`是当前Excel中的兼容字段名，读取时也接受拼写正确的`hierarchy`。

### RTL生成安全性

1. PHY插入marker必须各出现一次且顺序正确，否则立即报错。
2. RTL输出先写同目录临时文件，再原子替换目标文件。
3. 文件内容不变时不重复写入。
4. `*_sprom_manual.sv`存在时禁止覆盖。
5. 空memory类型保留`if(0)`哨兵，保证后续fallback `else`语法完整。
6. Excel中相同条件重复时拒绝生成，避免不可达的`else if`。

### 配置与错误处理

推荐入口：

```bash
python3 ./src/main.py --config ./config/sram_cfg.example.json
```

命令行参数可以覆盖JSON。非法mode、缺失Excel、非法频率、错误report格式和模板不同步均应明确失败。`rpt_by_run_sim`当前返回未实现错误，不会静默成功。

`gen_sram_excel.py`仅用于兼容旧命令，实际功能由`main.py`及其他模块实现。

### 测试

```bash
python3 -m unittest discover -s tests -v
python3 ./src/get_rtl_template.py --check
```

当前测试覆盖：

1. RTL源文件与`rtl_template.py`同步。
2. `.lst`解析、shape聚合和错误行定位。
3. Excel末行读取和重复条件检查。
4. ROM manual文件保护。
5. RTL重复生成幂等性。
6. 空memory类型fallback。
7. `COM_RAM_NFOUND_CHK`默认及严格模式语义。
8. JSON配置和CLI覆盖关系。

新增解析规则、Excel字段、memory类型或RTL生成行为时，应同步增加fixture和回归测试。
