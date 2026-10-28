import { createPlugin, pkgRootFrom } from '@deepwhale-cn/dsh-guard-core/plugin';
import { registerPdfKitApi } from './api.js';

const base = createPlugin({
  name: 'pdf-kit',
  pkgRoot: pkgRootFrom(import.meta.url),
  skillFile: 'skill/pdf-kit.md',
  binFile: 'bin/cli.mjs',
  description: 'PDF 批量合并 / 拆分 / 压缩 / 水印 / 提取文本 / 提取图片，一次处理整目录',
  whenToUse: '当用户要批量处理 PDF 时使用：合并多份、按页或每 N 页拆分、压缩体积、加文字水印、批量提取文本或图片。典型说法：「把这些 PDF 合并」「按页拆开」「压小一点」「加个机密水印」「把里面的图导出来」。不用于扫描件 OCR 或加密解密场景。',
});

/** 技能名（与 cordis.patch.yml 的行 id 对应） */
export const name = base.name;
/** 技能服务 + 面板要用的 HTTP 出口 */
export const inject = [...base.inject, 'webServer'];

/**
 * 先注册技能（CLI/Agent 用），再把面板用的 HTTP 出口挂上。
 * webServer 缺失时只影响面板，CLI 与 skill 照常 —— 不让可选能力阻断启动。
 */
export function apply(ctx) {
  base.apply(ctx);
  try {
    if (ctx.webServer && typeof ctx.webServer.register === 'function') {
      registerPdfKitApi(ctx);
      ctx.logger?.info?.('[pdf-kit] 已挂面板出口 /dsh-pdf-kit/api');
    }
  } catch (e) {
    ctx.logger?.warn?.('[pdf-kit] 面板出口注册失败（CLI/skill 不受影响）: ' + (e && e.message ? e.message : e));
  }
}
