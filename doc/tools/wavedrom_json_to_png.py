#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import subprocess
import shutil

def find_cli_command():
    """返回可直接由 subprocess 执行的 wavedrom-cli 命令前缀。"""
    cli_path = shutil.which("wavedrom-cli")
    if not cli_path and os.environ.get("APPDATA"):
        candidate = os.path.join(os.environ["APPDATA"], "npm", "wavedrom-cli.cmd")
        if os.path.isfile(candidate):
            cli_path = candidate

    if not cli_path:
        return None

    if os.name == "nt" and cli_path.lower().endswith((".cmd", ".bat")):
        cli_js = os.path.join(os.path.dirname(cli_path), "node_modules", "wavedrom-cli", "wavedrom-cli.js")
        node_candidates = [
            os.path.join(os.environ.get("ProgramFiles", ""), "nodejs", "node.exe"),
            shutil.which("node"),
        ]
        for node_path in node_candidates:
            if node_path and os.path.isfile(node_path) and os.path.isfile(cli_js):
                return [node_path, cli_js]

    return [cli_path]

def check_env():
    """检查系统环境是否支持 wavedrom-cli"""
    if not find_cli_command():
        print("[Error] 未找到 'wavedrom-cli'。请先执行 'npm install -g wavedrom-cli' 进行安装。")
        return False
    return True

def json_to_png(json_path, output_dir=None):
    """
    将单个 wave json 文件转换为 png
    """
    if not os.path.exists(json_path):
        print(f"[Warning] 文件不存在: {json_path}")
        return

    # 解析路径和文件名
    base_path, _ = os.path.splitext(json_path)
    file_name = os.path.basename(base_path)

    # 确定输出目录和输出文件路径
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
        png_path = os.path.join(output_dir, f"{file_name}.png")
    else:
        png_path = f"{base_path}.png"

    print(f"[Processing] 正在转换: {os.path.basename(json_path)} -> {os.path.basename(png_path)}")

    try:
        # wavedrom-cli 原生支持直接指定输出格式为 png
        # 内部命令格式: wavedrom-cli --input input.json --png output.png
        cmd = find_cli_command()
        if not cmd:
            print("[Error] 未找到 'wavedrom-cli'。请先执行 'npm install -g wavedrom-cli' 进行安装。")
            return
        cmd += ["--input", json_path, "--png", png_path]

        # 执行命令行调用
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        print(f"[Success] 转换成功!")
    except subprocess.CalledProcessError as e:
        print(f"[Failed] 转换失败! 错误信息:\n{e.stderr}")

def batch_convert(input_dir, output_dir=None):
    """批量转换目录下所有的 json 文件"""
    if not check_env():
        return

    # 过滤出目录下所有的 .json 文件
    json_files = [os.path.join(input_dir, f) for f in os.listdir(input_dir) if f.endswith('.json')]

    if not json_files:
        print(f"[Info] 在目录 '{input_dir}' 下未找到任何 .json 格式的时序图描述文件。")
        return

    print(f"[Info] 找到 {len(json_files)} 个时序图文件，开始批量处理...\n" + "-"*50)
    for json_file in json_files:
        json_to_png(json_file, output_dir)
    print("-"*50 + "\n[Info] 批量转换任务结束。")

if __name__ == "__main__":
    # ================= 配置区域 =================
    # 存放 WaveDrom json 源码的目录（可修改为你本地的实际路径）
    WAVE_SRC_DIR = "./wave_source"
    # 渲染生成的 PNG 图片存放目录
    IMAGE_OUT_DIR = "./wave_output"
    # ============================================

    # 示例一：单文件转换
    # json_to_png("./wave_source/apb_timing.json", "./wave_output")

    # 示例二：批量转换
    batch_convert(WAVE_SRC_DIR, IMAGE_OUT_DIR)
