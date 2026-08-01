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

async function readChangesFile() {
  const changesPath = path.join(root, ".release-notes", "changes.md");
  try {
    const content = await readFile(changesPath, "utf8");
    const trimmed = content.trim();
    return trimmed.length > 0 ? trimmed : null;
  } catch (error) {
    if (error?.code === "ENOENT") return null;
    throw error;
  }
}

async function main() {
  const version = await readVersion();
  const date = (process.env.RELEASE_PREVIEW_DATE || new Date().toISOString().slice(0, 10));
  const fragmentsDir = path.join(root, ".release-notes");

  const { fragments } = await loadReleaseNoteFragments(fragmentsDir);
  const manualNotes = await readChangesFile();

  // 优先用固定单文件 changes.md；为空时回退到片段机制；再为空则允许空说明。
  const entry = buildChangelogEntry({
    version,
    date,
    fragments,
    manualNotes: manualNotes ?? undefined,
    allowEmpty: !manualNotes,
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
