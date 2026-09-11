# COM RTL 飞书同步计划与脚本

## 章节顺序计划

以仓库根目录 SUMMARY.md 为发布清单，飞书根页面为“COMMON RTL 文档”，与 HW Tool 文档使用独立页面和状态。默认父节点沿用另一个仓库已有配置，也可通过 --parent-url 指定。首轮为6个分组、18篇源文档，加上根页共25页。

1. 入门与规范：仓库概览、模块分类和filelist入口 → RTL编码规范。
2. Common IP：使用手册 → FIFO微架构。使用手册保留当前仲裁、基础逻辑、pipe、SIMO、counter、RAM、FIFO、CDC的章节顺序；微架构单独成页。
3. AXI与DMA：EBUS/DMA手册 → DMA生成指南。
4. CSR：概述 → 集成框图 → CSR接口 → AMBA Bridge → CSR Fabric → CSR Package → 性能验证，保留在一篇手册内。
5. 工艺实现与项目集成：impl模板、项目维护边界、memory与stdcell接入。
6. 仿真验证：Pipe → SIMO → 仲裁 → 同步FIFO → 异步FIFO → RAM → CDC → AXI/DMA → CSR Bus → CSR Package。

首轮按现有文件发布，不重写正文或拆分模块页。分组页自动生成子页面导航，源文件内标题保留。ai_prompt.md、ai_answer.md、handoff_common_rtl.md、doc/plan和同步脚本说明不发布。CSR详细计划暂留本地；已纳入的手册通过正文链接仍可跳转到GitHub源文件。其他仓库工具文档保留原有GitHub链接，不重复导入。后续若需要模块级拆页，应先调整清单和链接映射再推送。

## 运行

脚本从 py_tools_for_hw/doc/feishu 的现有实现复制适配，本仓库可以独立运行。依赖 Python 3.10+、requests、Markdown：

```powershell
python -m pip install requests Markdown
# 在 com 仓库根目录执行，默认预览，不联网、不读取凭据
python -B doc/feishu/push_summary.py
python -B doc/feishu/push_summary.py --dry-run
# 确认目录后执行实际推送
python -B doc/feishu/push_summary.py --push
# 其他目标需使用独立状态文件
python -B doc/feishu/push_summary.py --push --parent-url https://example.feishu.cn/wiki/NODE_TOKEN --state out/feishu_other/state.json
```

凭据为 FEISHU_APP_ID、FEISHU_APP_SECRET 环境变量，支持Windows用户环境变量；不写入文件。实际推送需要应用与目标知识库已有文档、知识库及图片权限。本轮只准备脚本和离线预览，不验证远端权限或执行推送。

## 同步行为与边界

本地Markdown为内容源。脚本上传表格、代码、本地图片，把已导入文档链接改为飞书页面，其他仓库内文件链接指向 damagebro/com 的 main 分支。跨文档标题锚点降级到页面顶部并记录警告；远程图片不下载，遇到无法上传的图片停止。源文档和本地图片不因同步修改。

out/feishu_summary 保存 state.json、转换缓存和report.json，已加入Git忽略。状态记录源文件与页面对应关系，必须保留；再次执行跳过未变化页面，更新已有页面时检查远端版本。远端编辑冲突或结果不明确的写入会停止，需核对后恢复，不能删除状态盲目重推。

只管理脚本创建的页面，不删除旧章节。新页按创建顺序追加；已有页面移动或排序不自动执行，结束时检查实际顺序。因此正式首推前应确定 SUMMARY.md 顺序。文档发布结果、图片和实际API兼容性需在正式推送后回读验证。

## 离线检查

```powershell
python -B -m unittest discover -s doc/feishu -p "test_*.py"
python -B doc/feishu/push_summary.py --dry-run
```
