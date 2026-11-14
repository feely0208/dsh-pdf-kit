/**
 * 官方「全家桶应用 API」· OCR 客户端（Node 侧）
 *
 * 用途：把扫描件/图片/Office 文件交给 DeepSeek 官方 OCR 接口，按页返回文字。
 * 边界：
 *   · 只有显式跑 `ocr` 子命令才会联网；其它子命令完全本地，不碰网络。
 *   · Key 只从环境变量 DEEPSEEK_API_KEY 读，不落盘、不进日志。
 *   · 错误一律抛出 CloudError，由 CLI 统一转成「缺什么、怎么办」。
 */
import { readFileSync } from 'node:fs';
import { basename } from 'node:path';

const DEFAULT_BASE = 'https://api.deepseek.com';

export class CloudError extends Error {
  constructor(message, { hint = '', code = 4, extra = {} } = {}) {
    super(message);
    this.name = 'CloudError';
    this.hint = hint;
    this.code = code;
    this.extra = extra;
  }
}

export function baseUrl() {
  return (process.env.DEEPSEEK_BASE_URL || DEFAULT_BASE).replace(/\/+$/, '');
}

export function requireKey() {
  const key = process.env.DEEPSEEK_API_KEY;
  if (!key) {
    throw new CloudError('缺少 DEEPSEEK_API_KEY', {
      code: 3,
      hint: 'ocr 子命令要调用官方 OCR 接口，需要先设置环境变量：\n  export DEEPSEEK_API_KEY=sk-...\nKey 在 platform.deepseek.com 申请；不联网的本地命令（merge/split/compress 等）不受影响。',
    });
  }
  return key;
}

const STATUS_HINT = {
  400: '请求或文件不合法：确认 purpose 是 text_recognition / rich_layout_recognition，且文件格式受支持',
  402: '余额不足：到 platform.deepseek.com 充值后再试',
  408: '上传过慢（需 120 秒内传完、中途停顿不超过 30 秒）：换更小的文件或更好的网络',
  413: '文件超过 100 MiB：先压缩或拆分后再传',
  429: '并发识别数超上限（每账号 15 个）：等前面的跑完再试',
  500: '服务端处理失败：稍后重试',
  503: '服务繁忙：稍后重试',
  504: '识别超过 180 秒：换更小的文件',
};

/** 服务端会先发换行保持连接，JSON 前可能有空白；从头找第一个 '{' 再解析。 */
function parseJsonLoose(text) {
  const i = text.indexOf('{');
  if (i < 0) throw new CloudError('响应不是 JSON', { hint: `返回内容前 200 字：${text.slice(0, 200)}` });
  return JSON.parse(text.slice(i));
}

export async function ocrFile(filePath, { purpose = 'text_recognition' } = {}) {
  const key = requireKey();
  const bytes = readFileSync(filePath);
  const form = new FormData();
  form.set('purpose', purpose);
  form.set('file', new Blob([bytes]), basename(filePath));

  let res;
  try {
    res = await fetch(`${baseUrl()}/v1/tools/ocr`, {
      method: 'POST',
      headers: { authorization: `Bearer ${key}` },
      body: form,
    });
  } catch (e) {
    throw new CloudError('连不上 OCR 接口（网络错误）', {
      hint: `目标：${baseUrl()}/v1/tools/ocr\n原因：${e?.message || e}`,
    });
  }

  const raw = await res.text();
  let body;
  try {
    body = parseJsonLoose(raw);
  } catch (e) {
    throw new CloudError(`OCR 返回无法解析（HTTP ${res.status}）`, {
      hint: `返回内容前 200 字：${raw.slice(0, 200)}`,
      extra: { status: res.status },
    });
  }

  if (body.error) {
    throw new CloudError(`OCR 失败：${body.error.message || '未知错误'}`, {
      code: 4,
      hint: STATUS_HINT[res.status] || '参见官方文档 /zh-cn/guides/ocr',
      extra: { status: res.status, error: body.error },
    });
  }
  if (!res.ok) {
    throw new CloudError(`OCR 请求失败（HTTP ${res.status}）`, {
      code: 4,
      hint: STATUS_HINT[res.status] || '参见官方文档 /zh-cn/guides/ocr',
      extra: { status: res.status },
    });
  }
  if (!Array.isArray(body.pages)) {
    throw new CloudError('OCR 响应缺少 pages 字段', { hint: '接口结构可能已变更，参见官方文档' });
  }
  return body;
}
