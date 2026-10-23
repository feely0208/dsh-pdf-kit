# @deepwhale-cn/dsh-pdf-kit

[![Listed on dsh-plugin.org](https://dsh-plugin.org/badges/listed.svg)](https://dsh-plugin.org/plugins/feely0208/dsh-pdf-kit)

**PDF 批量处理工具箱**：合并、按页拆分、压缩、整页文字水印、提取文本、导出内嵌图片 —— 一条命令出产物，不改原文件。

**关键词**：PDF 合并 · PDF 拆分 · PDF 压缩 · PDF 加水印 · PDF 提取文字 · PDF 导出图片 · PDF 工具箱 · pdf-kit

## 不装会怎样

手上几十份 PDF 要合并、要按章节拆、要压到能发邮件、要盖「内部资料」水印、要把文字和图片扒出来 ——
用在线网站意味着把文件上传给陌生人；用 Acrobat 意味着一份份点；自己写脚本又容易写坏页序、
把原文件覆盖掉、或者压缩完反而更大。这个插件把这几件事做成一条可重复、可核对的命令：
**输入只读、输出独立目录、同名自动加序号**。

## 能做什么

| 子命令 | 做什么 | 可核对的产物 |
|---|---|---|
| `merge` | 多个 PDF 按给定顺序合并 | 一个 PDF，页数 = 各输入页数之和 |
| `split` | 按页拆成单页，或每 N 页一份 | 多个 PDF，每个页数固定 |
| `compress` | 重存 + 图片降采样 / JPEG 重编码 + 字体子集化 | 一个 PDF，通常体积明显变小，页数不变 |
| `watermark` | 整页平铺文字水印（支持中文） | 一个 PDF，文字可从产物中提取出来核对 |
| `extract-text` | 每页文本各导出一个 UTF-8 `.txt` | 每页一个 txt，页数一致 |
| `extract-images` | 导出页面内嵌图片原始字节 | 每页每图的图片文件（PNG/JPEG 等） |

- 支持单文件、多文件（`--input a.pdf,b.pdf`）或整个目录（非递归，处理目录下所有 `.pdf`）。
- **输入永远只读**；输出默认写到 `<输入目录>/_输出`，可用 `--out` 指定。
- 同名不覆盖：已存在 `x.pdf` 时自动写成 `x-1.pdf`、`x-2.pdf`。
- `--json` 给脚本/CI 用；`--demo` 自造样例跑完整流程并打印所有产物路径。

## 不能做什么

- ❌ **不做 OCR**：扫描件/图片型 PDF 提不出文字，只会得到空 txt 或图片。
- ❌ **不处理加密/受保护 PDF**：需要密码的文件会报错退出，不会绕过。
- ❌ **不是 PDF 编辑器**：不改文字、不删页、不改版式；merge/split 按整页搬运。
- ❌ **不保证压缩后一定更小**：没有图片、或本就高度压缩的文件可能压不动，产物会如实报告「未变小」。
- ❌ **水印是文字层**：水印文字可被提取，不能当作防复制手段；不提供图片/Logo 水印、不提供密码保护。
- ⚠️ 目录批量是**单层**的，不会递归子目录。合并顺序对目录输入按文件名排序，对显式列表按给定顺序。

## 安装

```bash
dsh plugin --profile web add @deepwhale-cn/dsh-pdf-kit
```

依赖 **python3 + PyMuPDF**（PDF 读写由 python 完成）。缺依赖时命令会明确报「缺什么、怎么装」：

```bash
brew install python3
python3 -m pip install PyMuPDF
```

检查本机环境：

```bash
dsh-pdf-kit --probe
```

## 用法

```bash
# 看效果（自造样例，不碰你的文件）
dsh-pdf-kit --demo

# 合并
dsh-pdf-kit merge --input a.pdf,b.pdf --out out

# 按页拆 / 每 2 页一份
dsh-pdf-kit split --input report.pdf --out out
dsh-pdf-kit split every-n --n 2 --input report.pdf

# 压缩 + 加水印 + 提文本 + 导图片
dsh-pdf-kit compress --quality 60 --input big.pdf
dsh-pdf-kit watermark --text "内部资料" --input a.pdf
dsh-pdf-kit extract-text --input a.pdf
dsh-pdf-kit extract-images --input a.pdf

# 给程序：JSON 输出
dsh-pdf-kit merge --input a.pdf,b.pdf --json
```

退出码：`0` 成功 / `2` 参数或输入错误 / `3` 依赖缺失 / `4` 执行失败。

## 自测

```bash
bash tests/run.sh
```

测试会自己用 python fitz 造样例 PDF，逐项核对合并页数、拆分文件数、压缩后体积、水印文字、
文本内容、图片可重新打开，并验证「输入文件哈希不变」「不存在文件必须非 0 且明确提示」等反例。

## License

MIT © 温州深鲸智能科技有限公司
