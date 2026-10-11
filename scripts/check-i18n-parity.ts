#!/usr/bin/env tsx
/**
 * scripts/check-i18n-parity.ts
 *
 * Vérifie que les clés i18n sont identiques entre FR et EN.
 * Exit 1 si des clés manquent d'un côté.
 */

import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');

const LOCALES = ['fr', 'en'] as const;
type Locale = typeof LOCALES[number];

function loadCatalog(locale: Locale): Record<string, string> {
  const path = resolve(ROOT, 'src', 'i18n', `${locale}.json`);
  try {
    return JSON.parse(readFileSync(path, 'utf-8'));
  } catch {
    console.error(`❌ Impossible de lire ${path}`);
    process.exit(1);
  }
}

const catalogs = Object.fromEntries(
  LOCALES.map((l) => [l, loadCatalog(l)])
) as Record<Locale, Record<string, string>>;

const allKeys = new Set<string>();
for (const l of LOCALES) {
  for (const k of Object.keys(catalogs[l])) allKeys.add(k);
}

let hasError = false;
const missing: Record<Locale, string[]> = { fr: [], en: [] };

for (const key of allKeys) {
  for (const l of LOCALES) {
    if (!(key in catalogs[l])) {
      missing[l].push(key);
      hasError = true;
    }
  }
}

if (!hasError) {
  console.log(`✅ i18n parity OK (${allKeys.size} clés, ${LOCALES.length} locales)`);
  process.exit(0);
}

console.error('❌ i18n parity BROKEN');
for (const l of LOCALES) {
  if (missing[l].length > 0) {
    console.error(`\n  Clés manquantes dans ${l}.json :`);
    for (const k of missing[l]) console.error(`    - ${k}`);
  }
}
process.exit(1);
