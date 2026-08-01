#!/usr/bin/env node

// 生成「本次发布更新说明」预览（仅展示，不写入仓库、不消费 release 片段）。
// 用于 CI（tag-release.yml）在打 tag 时把面向用户的改动汇总成一份说明文字，
// 作为 artifact 供开发者下载参考。仓库的 CHANGELOG.md 与 .release-notes 片段
// 仍由本地 scripts/release.sh 在正式发布时处理。

import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { buildChangelogEntry, loadReleaseNoteFragments } from "./lib/release-notes.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");

async function readVersion() {
  if (process.env.RELEASE_PREVIEW_VERSION) return process.env.RELEASE_PREVIEW_VERSION;
  const raw = await readFile(path.join(root, "package.json"), "utf8");
  return JSON.parse(raw).version;
}

async function main() {
  const version = await readVersion();
  const date = (process.env.RELEASE_PREVIEW_DATE || new Date().toISOString().slice(0, 10));
  const fragmentsDir = path.join(root, ".release-notes");

  const { fragments } = await loadReleaseNoteFragments(fragmentsDir);
  const entry = buildChangelogEntry({
    version,
    date,
    fragments,
    allowEmpty: true,
  });

  // 同时写文件（供 artifact 上传）并打印到日志。
  const outPath = path.join(root, "RELEASE_NOTES_PREVIEW.md");
  await (await import("node:fs/promises")).writeFile(outPath, entry);
  process.stdout.write(`\n${entry}\n`);
  process.stdout.write(`Release notes preview written to ${outPath}\n`);
}

main().catch((error) => {
  process.stderr.write(`generate-release-notes-preview: ${error.message}\n`);
  process.exitCode = 1;
});
