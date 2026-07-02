# Memory Tool

`mem_tool` 用于生成带子系统前缀的 SRAM/ROM shell、汇总 memory shape，并生成前后端交互使用的 Excel。

## 目录结构

```text
memory/
├─ rtl/
│  ├─ shell/                 # SRAM/ROM、ECC shell 的唯一 RTL 模板源
│  └─ model/                 # 通用寄存器 memory model
├─ memory.f
└─ mem_tool/
   ├─ config/                # 配置示例
   ├─ src/                   # Python 源码
   ├─ templates/sim/         # VCS 仿真模板
   ├─ tests/fixtures/        # 测试输入
   └─ run.sh
```

## 常用命令

在 `mem_tool` 目录执行：

```bash
# 生成带 cpu 前缀的 shell
python3 ./src/gen_sram_excel.py -p cpu -m init -w ./build/

# 根据 list 或 Excel 生成已集成 memory wrapper 的 shell
python3 ./src/gen_sram_excel.py -p cpu -m inst -w ./build/
python3 ./src/gen_sram_excel.py -p cpu -m inst -w ./build/ \
    -x cpu_memory_require.xlsx

# 根据 build/ 下的 memory list 生成 Excel
python3 ./src/gen_sram_excel.py -p cpu -m excel -w ./build/ \
    -x cpu_memory_require.xlsx -xcka 1500 -xckb 1000
```

`-m rpt_by_run_sim` 的 VCS 自动收集流程尚未实现。

## ROM 人工维护

生成 ROM shell 时会同时生成 `<prefix>_sprom_manual.sv`。该文件需要设计者：

1. 按 ROM 实例修改模块名或文件组织。
2. 在 `USER_EDIT_REQUIRED` 区域完整填写 ROM 数据。
3. 将修改后的文件纳入项目源码管理。

工具只在目标文件不存在时生成 `*_sprom_manual.sv`；后续重复运行不会覆盖人工修改。

## 配置

预留配置格式见 `config/sram_cfg.example.json`；当前入口以命令行参数为准。脚本会自动定位上级 `memory/rtl/shell`，因此不依赖启动时的工作目录。

## 数据流程

1. `init`：从 `rtl/shell` 复制模板并替换子系统前缀。
2. `rpt_by_run_sim`：通过仿真收集 memory shape，当前为待实现功能。
3. `excel`：读取 `spram.lst`、`tpram1ck.lst`、`tpram2ck.lst`、`sprom.lst` 并生成 Excel。
4. `inst`：读取 Excel 或 memory list，把对应 memory wrapper 实例写入生成的 shell。
