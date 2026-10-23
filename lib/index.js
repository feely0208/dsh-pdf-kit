import { createPlugin, pkgRootFrom } from '@deepwhale-cn/dsh-guard-core/plugin';

export const { name, inject, apply } = createPlugin({
  name: 'pdf-kit',
  pkgRoot: pkgRootFrom(import.meta.url),
  skillFile: 'skill/pdf-kit.md',
  binFile: 'bin/cli.mjs',
  description: 'PDF 合并 / 拆分 / 压缩 / 加水印 / 提取文本与图片',
  whenToUse: '用户提到「PDF 工具箱」或任务属于该场景时使用',
});
