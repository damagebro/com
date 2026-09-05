# 工艺实现模板

`impl_template/` 提供 stdcell、DesignWare、memory 和实现宏配置的初始模板。正式项目应将该目录复制到项目仓库后独立管理，正式 filelist 不得直接引用 `com/impl_template/`，也不应通过软链接继续指向本仓库的模板。

## Memory Shell

`memory/rtl/shell/com_*_shell.sv` 保留用于模板参考和 `com` 仓库自身仿真。正式项目不使用这些通用 shell，而使用 `py_tools_for_hw/mem_tool` 生成的 subsystem 专属文件，例如 `cpu_spram_shell.sv`、`npu_spram_shell.sv`。

复制 `impl_template/` 后，应以生成的 shell 替换项目中的通用 shell，并更新 `memory.f` 等 filelist，不能原样沿用其中的 `com_*_shell.sv` 条目。项目 RTL 例化生成后的模块；后端返回 SRAM Excel 和 PHY wrapper 后，再通过 `mem_tool -m inst` 更新项目 shell。

## Whole-chip 公共文件

`define/impl_define.sv` 和 `memory/rtl/model/com_tpram_reg.sv` 必须由总项目统一管理。它们属于 whole-chip 级文件，不属于单个 subsystem 的私有实现。

- `impl_define.sv`：项目统一维护实现宏、控制位宽和工艺选择，在依赖这些宏的 RTL 之前编译。
- `com_tpram_reg.sv`：项目统一维护 RAM 寄存器模型，每次编译只加入一份模块定义。
- `define/impl_define_sim.sv`：作为项目仿真配置的初始模板，按编译模式选择使用，避免与 `impl_define.sv` 重复定义宏。

上述文件可以从 `com/impl_template/` 复制，也可以从 `mem_tool/templates/rtl/` 复制。同一项目只能选择一套来源，复制后由项目仓库独立维护；各 subsystem 复用项目级文件，不再引入工具内或 `com` 内的另一份副本。

`com` 仓库自身的仿真 filelist 可以继续引用本目录。这些路径仅用于本仓库验证，不作为正式项目的集成路径。
