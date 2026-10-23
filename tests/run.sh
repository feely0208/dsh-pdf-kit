#!/bin/bash
# @deepwhale-cn/dsh-pdf-kit · 双向验证
# 自己造 PDF 样例（python fitz），逐项核对产物；反例必须非 0 + 有提示。
set -uo pipefail
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
cd "$(dirname "$0")/.."
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
bad(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

PY=$(command -v python3 || true)
[ -z "$PY" ] && PY=/opt/homebrew/bin/python3
CLI="node bin/cli.mjs"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/dsh-pdf-kit-test.XXXXXX")
cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT
SRC="$TMP/src"
OUT="$TMP/out"
mkdir -p "$SRC" "$OUT"

echo ""
echo "  @deepwhale-cn/dsh-pdf-kit · 双向验证"
echo "  ────────────────────────────────────────────────"

# ---------------------------------------------------------------- 造样例
$PY - "$SRC" <<'PY' 2>/dev/null
import pymupdf as fitz, os, random, sys
src = sys.argv[1]

def png(w, h, noise=False):
    if noise:
        data = bytes(random.getrandbits(8) for _ in range(w * h * 3))
    else:
        row = bytearray()
        for x in range(w):
            row += bytes((int(255 * x / max(w - 1, 1)), 120, 60))
        data = bytes(row) * h
    pix = fitz.Pixmap(fitz.csRGB, w, h, data, 0)
    return pix.tobytes("png")

def make(path, label, chinese=False, image=False):
    d = fitz.open()
    for i in range(2):
        p = d.new_page(width=595, height=842)
        p.insert_text((64, 90), f"DSH PDF KIT {label} PAGE {i + 1}", fontsize=20)
        p.insert_text((64, 130), "Hello from dsh-pdf-kit test fixture.", fontsize=14)
        if chinese:
            p.insert_text((64, 170), "深鲸文档 中文测试", fontsize=16, fontname="china-s")
        if image and i == 0:
            p.insert_image(fitz.Rect(64, 220, 304, 380), stream=png(240, 160))
    d.save(path)
    d.close()

make(os.path.join(src, "a.pdf"), "A", chinese=True, image=True)
make(os.path.join(src, "b.pdf"), "B")

# 重图 PDF：给 compress 用（噪声几乎不可压缩，重编码后应显著变小）
d = fitz.open()
noise = png(1000, 750, noise=True)
for _ in range(2):
    p = d.new_page(width=595, height=842)
    p.insert_image(fitz.Rect(50, 60, 545, 430), stream=noise)
    p.insert_text((50, 480), "Heavy image document for compress test.", fontsize=14)
d.save(os.path.join(src, "heavy.pdf"))
d.close()
PY
[ -f "$SRC/a.pdf" ] && ok "样例生成：a.pdf / b.pdf / heavy.pdf" || { bad "样例生成失败"; exit 1; }

pagecount(){ $PY -c "import pymupdf as fitz,sys; print(fitz.open(sys.argv[1]).page_count)" "$1" 2>/dev/null; }
pdftext(){ $PY -c "import pymupdf as fitz,sys; print(fitz.open(sys.argv[1])[0].get_text())" "$1" 2>/dev/null; }
countpdf(){ ls "$1"/*.pdf 2>/dev/null | wc -l | tr -d ' '; }

# ---------------------------------------------------------------- 0. 基础
echo ""
echo "  【基础】"
$CLI --help >/dev/null 2>&1 && ok "--help 退出 0" || bad "--help 失败"
$CLI --help 2>&1 | grep -q "PDF 工具箱" && ok "--help 有说明" || bad "--help 无说明"
$CLI >/dev/null 2>&1; [ $? -eq 0 ] && ok "无参数打印帮助并退出 0" || bad "无参数退出非 0"
$CLI --probe --json 2>/dev/null | $PY -c "import json,sys; d=json.load(sys.stdin); assert d['ok'] and d['fitz']" \
  && ok "--probe 报告 PyMuPDF 版本" || bad "--probe 失败"
DEMO=$($CLI --demo 2>&1); [ $? -eq 0 ] && echo "$DEMO" | grep -q "演示完成" \
  && ok "--demo 全流程退出 0" || bad "--demo 失败"

# ---------------------------------------------------------------- 1. merge
echo ""
echo "  【merge 合并】"
$CLI merge --input "$SRC/a.pdf,$SRC/b.pdf" --out "$OUT/merge" --json > "$TMP/merge.json" 2>/dev/null
[ $? -eq 0 ] && ok "merge 退出 0" || bad "merge 退出非 0"
M=$(ls "$OUT/merge"/*.pdf 2>/dev/null | head -1)
MPC=$(pagecount "$M")
[ "$MPC" = "4" ] && ok "合并后 4 页（2+2）" || bad "合并页数不对：${MPC:-空}"
pdftext "$SRC/b.pdf" | grep -q "PAGE 1" && [ "$(pdftext "$M")" = "$(pdftext "$SRC/a.pdf")" ] \
  && ok "合并后第 1 页保留 A 的内容" || bad "合并内容异常"
$CLI merge --input "$SRC/a.pdf" --out "$OUT/merge1" >/dev/null 2>&1
[ $? -ne 0 ] && ok "反例：只给 1 个 PDF → 非 0" || bad "单文件 merge 竟然成功"
$CLI merge --input "$SRC/a.pdf,$SRC/b.pdf" --out "$OUT/merge" >/dev/null 2>&1
[ "$(countpdf "$OUT/merge")" = "2" ] && ok "同名不覆盖（第二次加序号，共 2 个）" || bad "同名被覆盖：$(countpdf "$OUT/merge") 个"

# ---------------------------------------------------------------- 2. split
echo ""
echo "  【split 拆分】"
$CLI split --input "$SRC/a.pdf" --out "$OUT/split" --json > "$TMP/split.json" 2>/dev/null
[ $? -eq 0 ] && ok "split 按页退出 0" || bad "split 失败"
[ "$(countpdf "$OUT/split")" = "2" ] && ok "按页拆成 2 个文件" || bad "按页文件数不对：$(countpdf "$OUT/split")"
ALL1=1
for f in "$OUT/split"/*.pdf; do [ "$(pagecount "$f")" = "1" ] || ALL1=0; done
[ "$ALL1" = "1" ] && ok "拆出的每个文件都是 1 页" || bad "拆分后页数不对"
$CLI split every-n --n 2 --input "$SRC/a.pdf" --out "$OUT/every" --json > "$TMP/every.json" 2>/dev/null
[ $? -eq 0 ] && [ "$(countpdf "$OUT/every")" = "1" ] \
  && [ "$(pagecount "$(ls "$OUT/every"/*.pdf | head -1)")" = "2" ] \
  && ok "每 2 页一份：1 个文件 × 2 页" || bad "every-n 结果不对"
$CLI split --n 1 --input "$SRC/b.pdf" --out "$OUT/every2" >/dev/null 2>&1
[ "$(countpdf "$OUT/every2")" = "2" ] && ok "split --n 1 等价按页" || bad "split --n 1 失败"
$CLI pdf split --input "$SRC/a.pdf" --out "$OUT/prefix" >/dev/null 2>&1 \
  && ok "带前缀写法 pdf split 可用" || bad "pdf split 前缀失败"

# 默认输出目录：<输入目录>/_输出，且输入目录不被写入
mkdir -p "$TMP/inp" && cp "$SRC/a.pdf" "$TMP/inp/a.pdf"
$CLI split --input "$TMP/inp/a.pdf" >/dev/null 2>&1
[ -d "$TMP/inp/_输出" ] && [ "$(countpdf "$TMP/inp/_输出")" = "2" ] \
  && ok "默认输出到 <输入目录>/_输出" || bad "默认输出目录不对"
[ "$(ls "$TMP/inp" | wc -l | tr -d ' ')" = "2" ] && ok "输入目录只新增 _输出，未混入产物" || bad "输入目录被写脏"

# ---------------------------------------------------------------- 3. compress
echo ""
echo "  【compress 压缩】"
$CLI compress --quality 60 --input "$SRC/heavy.pdf" --out "$OUT/compress" --json > "$TMP/compress.json" 2>/dev/null
[ $? -eq 0 ] && ok "compress 退出 0" || bad "compress 失败"
CB=$($PY -c "import json;d=json.load(open('$TMP/compress.json'));print(d['results'][0]['stats']['beforeBytes'])" 2>/dev/null)
CA=$($PY -c "import json;d=json.load(open('$TMP/compress.json'));print(d['results'][0]['stats']['afterBytes'])" 2>/dev/null)
[ "${CA:-0}" -lt "${CB:-0}" ] && ok "压缩后体积变小：${CB}B → ${CA}B" || bad "压缩后未变小：${CB}B → ${CA}B"
CF=$(ls "$OUT/compress"/*.pdf | head -1)
[ "$(pagecount "$CF")" = "2" ] && ok "压缩后页数不变（2 页）" || bad "压缩丢页"
$CLI compress --input "$SRC/heavy.pdf" --out "$OUT/compress" >/dev/null 2>&1
[ "$(countpdf "$OUT/compress")" = "2" ] && ok "compress 同名加序号" || bad "compress 覆盖了旧文件"

# ---------------------------------------------------------------- 4. watermark
echo ""
echo "  【watermark 水印】"
$CLI watermark --text "INTERNAL" --input "$SRC/a.pdf" --out "$OUT/wm" --json > "$TMP/wm.json" 2>/dev/null
[ $? -eq 0 ] && ok "watermark 退出 0" || bad "watermark 失败"
WF=$(ls "$OUT/wm"/*.pdf | head -1)
[ "$(pagecount "$WF")" = "2" ] && ok "水印后页数不变" || bad "水印后页数异常"
pdftext "$WF" | grep -q "INTERNAL" && ok "水印文字可从产物中读出（已真正写入页面）" || bad "产物里找不到水印文字"
pdftext "$SRC/a.pdf" | grep -q "INTERNAL" && bad "输入文件被写了水印" || ok "输入文件未被修改（无 INTERNAL）"
$CLI watermark --text "深鲸水印" --input "$SRC/a.pdf" --out "$OUT/wm-cn" >/dev/null 2>&1
pdftext "$(ls "$OUT/wm-cn"/*.pdf | head -1)" | grep -q "深鲸水印" && ok "中文水印可写入并读出" || bad "中文水印失败"
$CLI watermark --input "$SRC/a.pdf" --out "$OUT/wm-bad" >/dev/null 2>&1
[ $? -ne 0 ] && ok "反例：缺 --text → 非 0" || bad "缺 --text 竟然成功"

# ---------------------------------------------------------------- 5. extract-text
echo ""
echo "  【extract-text 提取文本】"
$CLI extract-text --input "$SRC/a.pdf" --out "$OUT/text" --json > "$TMP/text.json" 2>/dev/null
[ $? -eq 0 ] && ok "extract-text 退出 0" || bad "extract-text 失败"
[ "$(ls "$OUT/text"/*.txt 2>/dev/null | wc -l | tr -d ' ')" = "2" ] && ok "每页一个 txt（2 页 → 2 个）" || bad "txt 数量不对"
grep -q "PAGE 1" "$OUT/text/a-p001.txt" 2>/dev/null && ok "第 1 页文本可核对（含 PAGE 1）" || bad "第 1 页文本异常"
grep -q "深鲸文档" "$OUT/text/a-p001.txt" 2>/dev/null && ok "中文文本 UTF-8 正常写出" || bad "中文文本丢失"

# ---------------------------------------------------------------- 6. extract-images
echo ""
echo "  【extract-images 导出图片】"
$CLI extract-images --input "$SRC/a.pdf" --out "$OUT/img" --json > "$TMP/img.json" 2>/dev/null
[ $? -eq 0 ] && ok "extract-images 退出 0" || bad "extract-images 失败"
[ "$(ls "$OUT/img"/*.png 2>/dev/null | wc -l | tr -d ' ')" = "1" ] && ok "导出 1 张内嵌图片" || bad "图片数量不对：$(ls "$OUT/img" 2>/dev/null | wc -l)"
$PY -c "
import pymupdf as fitz,sys
d=fitz.open(sys.argv[1]); assert d[0].rect.width>0; print('ok')
" "$(ls "$OUT/img"/*.png | head -1)" >/dev/null 2>&1 && ok "导出的 PNG 可被重新打开" || bad "导出的 PNG 损坏"

# ---------------------------------------------------------------- 7. 反例 / 输入保护
echo ""
echo "  【反例与输入保护】"
BEFORE=$($PY -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$SRC/a.pdf" 2>/dev/null)
$CLI compress --input "$TMP/nope.pdf" --out "$OUT/nope" >"$TMP/err.txt" 2>&1
[ $? -ne 0 ] && grep -q "输入不存在" "$TMP/err.txt" && ok "反例：不存在文件 → 非 0 + 明确提示" || bad "不存在文件未明确报错"
$CLI compress --input "$TMP/nope.pdf" --out "$OUT/nope" --json >"$TMP/err.json" 2>/dev/null
$PY -c "import json;d=json.load(open('$TMP/err.json'));assert d['ok'] is False and d['error']" 2>/dev/null \
  && ok "--json 模式下错误结构可解析" || bad "--json 错误结构异常"
$CLI frobnicate --input "$SRC/a.pdf" >"$TMP/cmd.txt" 2>&1
[ $? -ne 0 ] && grep -q "未知子命令" "$TMP/cmd.txt" && ok "反例：未知子命令 → 非 0 + 提示" || bad "未知子命令未明确报错"
$CLI split --input "$SRC/a.pdf" --n 0 >/dev/null 2>&1
[ $? -ne 0 ] && ok "反例：--n 0 → 非 0" || bad "--n 0 未被拦截"
AFTER=$($PY -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$SRC/a.pdf" 2>/dev/null)
[ "$BEFORE" = "$AFTER" ] && ok "全流程结束后输入文件哈希不变" || bad "输入文件被改动"

echo ""
echo "  ────────────────────────────────────────────────"
echo "  通过 $PASS · 失败 $FAIL"
echo ""
[ "$FAIL" -eq 0 ] || exit 1
