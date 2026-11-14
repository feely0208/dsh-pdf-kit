# PDF 工具箱

**一句话**：PDF 合并 / 按页拆分 / 压缩 / 整页文字水印 / 提取文本 / 导出内嵌图片。

## 什么时候用

用户提到「PDF 工具箱」，或要求 PDF 合并、拆分、压缩、加水印、提取文字、导出图片时使用。
适合批量、可重复、需要留下可核对产物的场景；一次性手工点选不是必须用它。

## 怎么调用

```bash
<cli 路径> --help
```

```bash
# 看效果（自造样例，不碰用户文件）
<cli 路径> --demo

# 统一形式：<子命令> [动作] --input <文件或目录> [--out <目录>] [--json]
<cli 路径> merge --input a.pdf,b.pdf --out out
<cli 路径> split --input report.pdf --out out
<cli 路径> split every-n --n 2 --input report.pdf
<cli 路径> compress --quality 60 --input big.pdf
<cli 路径> watermark --text "内部资料" --input a.pdf
<cli 路径> extract-text --input a.pdf
<cli 路径> extract-images --input a.pdf
```

也可以写成 `<cli 路径> pdf merge ...`（`pdf` 前缀可省略）。

## 各动作要点

| 子命令 | 可调选项 | 说明 |
|---|---|---|
| `merge` | `--input` 可重复或逗号分隔 | 至少 2 个 PDF；按给定顺序合并 |
| `split` | `--n N` 或动作 `every-n` | 默认按页；每 N 页一份 |
| `compress` | `--quality 1-95`、`--dpi 36-600` | 图片降采样 + JPEG 重编码 + 字体子集化 |
| `watermark` | `--text`（必填）、`--fontsize`、`--opacity 0.01-1` | 整页平铺文字水印，中文可用 |
| `extract-text` | — | 每页一个 UTF-8 `.txt` |
| `extract-images` | `--min-bytes N` | 导出页面内嵌图片原始字节 |

## 边界（必须向用户说清）

- **能**：合并、按页/每 N 页拆、有图 PDF 的压缩、文字水印、文本提取、内嵌图片导出；单文件、多文件、单层目录批量。
- **不能**：OCR（扫描件提不出文字）、解密/绕过受保护 PDF、编辑文字或版式、图片/Logo 水印、递归子目录。
- **不改输入文件**：只写输出目录（默认 `<输入目录>/_输出`）；同名自动加 `-1`/`-2`，不覆盖。
- **压缩不保证更小**：没有图片或已高度压缩时可能压不动，会如实报告「未变小」，不要承诺体积下降比例。
- **水印有文本层**：水印文字可被提取，不能当作防复制手段。
- 缺 python3 / PyMuPDF 时命令会明确报错并给安装命令，不会静默失败。先可用 `--probe` 检查环境。
- 退出码：`0` 成功 / `2` 参数或输入错误 / `3` 依赖缺失 / `4` 执行失败。给程序用 `--json`。

## 汇报建议

执行完把产物路径与核对数据（合并页数、拆分文件数、压缩前后字节数、抽出的 txt/图片数量）一并告诉用户；
不要说「已压缩」而不给前后体积，也不要在未跑通时声称成功。


## 扫描件 OCR（需要联网，先确认用户知情）

当 `extract-text` 抽出空文本、或输入是图片/扫描 PDF 时：

```sh
export DEEPSEEK_API_KEY=sk-...
dsh-pdf-kit ocr --input <文件或目录> --out <目录>
```

- 计费 1.5 元/千页；先告诉用户「这一步会把文件上传到 api.deepseek.com，并按页计费」再跑。
- 其它子命令不要加这个说明——它们不联网。
