import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const combosPath = path.join(repoRoot, "landing-page", "combos.json");
const outDir = path.join(repoRoot, "landing-page", "assets", "characters");
const remoteBase = "https://tekken8combo.kagewebsite.com/tpl/img/char";

const slugAliases = new Map([
  ["jack-8", "jack8"],
  ["jack_8", "jack8"],
]);

function toSlug(characterId) {
  const normalized = String(characterId || "").trim().toLowerCase();
  if (!normalized) return "";
  return slugAliases.get(normalized) || normalized;
}

async function downloadCharacter(slug) {
  const url = `${remoteBase}/${slug}.jpg`;
  const targetPath = path.join(outDir, `${slug}.jpg`);
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} for ${url}`);
  }
  const bytes = Buffer.from(await response.arrayBuffer());
  await fs.writeFile(targetPath, bytes);
}

async function main() {
  const raw = await fs.readFile(combosPath, "utf8");
  const data = JSON.parse(raw);
  const characterIds = Object.keys(data)
    .filter((id) => Array.isArray(data[id]) && data[id].length > 0)
    .map(toSlug)
    .filter(Boolean)
    .filter((id, index, list) => list.indexOf(id) === index)
    .sort((a, b) => a.localeCompare(b));

  await fs.rm(outDir, { recursive: true, force: true });
  await fs.mkdir(outDir, { recursive: true });

  let ok = 0;
  let failed = 0;
  for (const slug of characterIds) {
    try {
      await downloadCharacter(slug);
      ok += 1;
    } catch (error) {
      failed += 1;
      console.warn(`Failed to download ${slug}: ${error.message}`);
    }
  }

  console.log(`Synced character portraits: ${ok} downloaded, ${failed} failed.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
