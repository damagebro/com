# py_gen_dma

`gen_dma.py` 用于从公共 `../com_axi_dma.sv` 生成 subsystem 或项目私有的 DMA RTL。

## 使用示例

```bash
python gen_dma.py --gen-cfg cpu_dma_cfg.json
python gen_dma.py -c cpu_dma_cfg.json
```

也可以不使用配置文件，直接通过命令行指定：

```bash
python gen_dma.py -p cpu -o build
```

## 生成规则

- `com_axi_dma` 替换为 `cpu_axi_dma`
- `com_spram_shell` 替换为 `cpu_spram_shell`

## 注意事项

DMA read buffer 内部会例化 SRAM shell，因此该脚本和 `impl_template/memory/mem_tool` 生成的 SRAM shell 强相关。

同一个 subsystem/project 中，DMA 生成时使用的 `prefix` 必须和 memory shell 生成时使用的 `subsys_prefix` 保持一致。否则生成后的 DMA 会例化不存在的 SRAM shell module，导致 filelist 编译找不到模块。

## cfg.json

配置文件只保留用户常改的字段：

```json
{
    "prefix": "cpu",
    "out_dir": "build",
    "rch_buf_depth": [0, 32, 0, 64, 128]
}
```

| field           | description                                    |
| --------------- | ---------------------------------------------- |
| `prefix`        | subsystem/project 前缀，默认生成 `${prefix}_axi_dma` |
| `out_dir`       | 生成 RTL 的输出目录                                |
| `rch_buf_depth` | 每个 read channel 的 read data buffer 深度          |

`spram_shell` 不放在配置文件中，默认由 `prefix` 推导：

```text
dma_module  = <prefix>_axi_dma
spram_shell = <prefix>_spram_shell
```

## read data buffer 参数

`rch_buf_depth[i]` 会写入生成后 `${prefix}_axi_dma.sv` 的 `RCH_BUF_DEPTH[i]`。它表示第 `i` 个 read channel 的 read data buffer 深度，单位是 ebus read data beat，也就是 `DW` bit 数据宽度。

配置规则：

- `RCH_BUF_DEPTH[i]=0`：该 read channel 不使用 read buffer，AXI R data 直接 bypass 到 ebus read data 侧，不产生 SRAM。
- `0 < RCH_BUF_DEPTH[i] <= RCH_MAX_REG_FIFO_DEPTH`：buffer 全部使用寄存器 FIFO，不产生 SRAM。当前 `RCH_MAX_REG_FIFO_DEPTH=16`。
- `RCH_BUF_DEPTH[i] > RCH_MAX_REG_FIFO_DEPTH`：超过寄存器 FIFO 的部分使用 `com_spram_shell` 生成 SRAM。

SRAM 尺寸关系：

| item             | value                                             | description                  |
| ---------------- | ------------------------------------------------- | ---------------------------- |
| `REG_FIFO_DEPTH` | `min(RCH_BUF_DEPTH[i], RCH_MAX_REG_FIFO_DEPTH)`   | 前段寄存器 FIFO 深度                |
| `RAM_FIFO_DEPTH` | `RCH_BUF_DEPTH[i] - RCH_MAX_REG_FIFO_DEPTH`       | 需要 SRAM 承载的 FIFO 深度          |
| `RAM_ONE_DEPTH`  | `RAM_FIFO_DEPTH / 2`                              | 单个 SRAM bank 深度              |
| `RAM_DW`         | `DW + 1`                                          | SRAM 数据位宽，额外 1bit 保存 last    |
| SRAM instance    | `2` 个 `com_spram_shell`                           | 每个 read channel 使用 2 个 bank  |

因此，每个 read channel 如果启用 SRAM buffer，会例化 2 个 SRAM：

```text
DATA_W = DW + 1
DEPTH  = (RCH_BUF_DEPTH[i] - RCH_MAX_REG_FIFO_DEPTH) / 2
```

`RCH_BUF_DEPTH` 建议使用偶数，并且如果需要 SRAM buffer，深度应大于 `RCH_MAX_REG_FIFO_DEPTH`。修改 `RCH_BUF_DEPTH` 后，需要同步更新 memory tool 的 SRAM requirement，使 `${prefix}_spram_shell` 中存在对应 `DATA_W/DEPTH` 的 SRAM shape。
