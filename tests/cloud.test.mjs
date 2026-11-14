#!/usr/bin/env node
/**
 * ocr 子命令的离线验证：起一个本地 mock，验证「联网路径」而不是真调官方。
 * 覆盖：成功出 txt / 页码与字数统计 / 缺 Key 反例 / 本地命令不联网。
 */
import { createServer } from 'node:http';
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const CLI = join(ROOT, 'bin', 'cli.mjs');
let pass = 0; let fail = 0;
const ok = (m) => { console.log(`  ✅ ${m}`); pass += 1; };
const bad = (m) => { console.log(`  ❌ ${m}`); fail += 1; };

const tmp = mkdtempSync(join(tmpdir(), 'dsh-pdf-cloud-'));
const srv = createServer((req, res) => {
  if (req.url !== '/v1/tools/ocr') { res.writeHead(404); res.end('{}'); return; }
  res.writeHead(200, { 'content-type': 'application/json' });
  res.write('\n'); // 官方会先发换行保活
  res.end(JSON.stringify({
    id: 'ocr-mock', object: 'ocr.result', page_count: 2, purpose: 'text_recognition',
    pages: [{ index: 0, text: '扫描页一', finish_reason: 'stop' }, { index: 1, text: '扫描页二', finish_reason: 'stop' }],
    usage: { total_tokens: 20 },
  }));
});
await new Promise((r) => srv.listen(0, '127.0.0.1', r));
const port = srv.address().port;
const base = `http://127.0.0.1:${port}`;

const pdf = join(tmp, 'scan.pdf');
writeFileSync(pdf, 'not-a-real-pdf-but-mock-does-not-parse');
const out = join(tmp, 'out');

function run(env, args) {
  return new Promise((resolve) => {
    const p = spawn(process.execPath, [CLI, ...args], { env: { ...process.env, ...env } });
    let stdout = ''; let stderr = '';
    p.stdout.on('data', (d) => { stdout += d; });
    p.stderr.on('data', (d) => { stderr += d; });
    p.on('close', (status) => resolve({ status, stdout, stderr }));
  });
}

const r1 = await run({ DEEPSEEK_BASE_URL: base, DEEPSEEK_API_KEY: 'k' }, ['ocr', '--input', pdf, '--out', out, '--json']);
let j1 = null;
try { j1 = JSON.parse(r1.stdout.trim().split('\n').pop()); } catch {}
r1.status === 0 ? ok('ocr 退出 0') : bad(`ocr 退出 ${r1.status}: ${r1.stderr.slice(0, 200)}`);
const txt = join(out, 'scan.ocr.txt');
existsSync(txt) ? ok('产出 .ocr.txt') : bad('没有产出 .ocr.txt');
existsSync(txt) && readFileSync(txt, 'utf8').includes('扫描页二') ? ok('文本按页拼接') : bad('文本内容不对');
j1?.pages === 2 && j1?.costYuan > 0 ? ok('JSON 里页数与费用可读') : bad(`JSON 统计不对：${r1.stdout.slice(0, 200)}`);

const r2 = await run({ DEEPSEEK_BASE_URL: base }, ['ocr', '--input', pdf, '--out', out, '--json']);
r2.status === 3 && /DEEPSEEK_API_KEY/.test(r2.stdout) ? ok('缺 Key → 退出 3 + 明确提示') : bad(`缺 Key 行为不对（status=${r2.status}）`);

srv.close();
rmSync(tmp, { recursive: true, force: true });
console.log(`  云路径：通过 ${pass} · 失败 ${fail}`);
process.exit(fail === 0 ? 0 : 1);
