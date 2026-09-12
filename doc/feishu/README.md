# COM RTL 飞书同步计划与脚本

## 当前章节顺序

以仓库根目录 SUMMARY.md 为发布清单，飞书根页面为“COMMON RTL 文档”，与 HW Tool 文档使用独立页面和状态。默认父节点沿用已授权知识库，也可通过 --parent-url 指定。

2026-09-12清单为2个分组、11篇源文档，加上根页共14页：

1. Common IP：仓库概览 → Common IP手册 → AXI/EBUS DMA手册 → CSR手册 → 工艺实现模板 → FIFO微架构 → DMA生成指南。
2. 仿真验证环境：同步FIFO → AXI/DMA → CSR Bus → CSR Package。

按现有文件发布，保留正文与原有页面链接。未列入清单的本地文档不发布；清单内页面链接转换为飞书链接，其余文件链接指向GitHub。章节调整需要显式使用 --sync-tree，删除退出清单的页面还需已获授权并加 --delete-removed，详见下方目录保护。

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

## 目录保护（2026-09-12）

普通推送会在写入前检查实际知识库、父节点、文档身份、子节点集合与章节顺序，包含历史归档和旧节点。远端缺失、被移到首页、归档失效或出现未登记子页面时停止，不根据本地状态猜测归属。章节删除、移动或在已有章节中间插入需要显式使用 `--sync-tree`；该参数也不能跳过远端状态异常。

`python -B doc/feishu/push_summary.py --check-tree` 只读联网检查，不修改飞书；`--dry-run` 仅预览本地清单。显式章节同步每次移动前检查目标，移动后验证实际父节点，失败保留pending以阻止盲目重试。正文推送前后再次验证完整受管目录。

仅在已授权删除退出清单的页面时使用 `--sync-tree --delete-removed`；它在正文发布成功后由叶子向上删除旧页及临时归档，并记录删除任务与旧页面状态。COMMON RTL 实际推送还需 `--push`。默认不自动删除。

检查不能阻止用户或其他程序在检查后改动飞书；无法将多次远端操作变为原子事务。检测到冲突会停止，已完成的单项移动可能需要核对后恢复。
