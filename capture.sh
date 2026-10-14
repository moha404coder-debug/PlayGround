#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
/usr/bin/time -p pwd
if [[ -z "${CAPTURE_URL:-}" ]]; then
  echo 'Set CAPTURE_URL.' >&2
  exit 1
fi
if [[ -z "${CAPTURE_DIR:-}" ]]; then
  echo 'Set CAPTURE_DIR.' >&2
  exit 1
fi
/usr/bin/time -p mkdir -p "$CAPTURE_DIR"
/usr/bin/time -p node --input-type=module <<'NODE'
import { readFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { createRequire } from 'node:module';
const runtime = join(process.env.HOME, '.local/share/omgithub-playwright');
const require = createRequire(join(runtime, 'node_modules/playwright/package.json'));
const { chromium } = require('playwright');
const config = JSON.parse(readFileSync(join(runtime, process.platform === 'darwin' ? 'metal.json' : 'linux.json'), 'utf8'));
if (process.platform === 'linux') process.env.DISPLAY ||= ':' + readFileSync(join(runtime, 'display'), 'utf8').trim();
const url = process.env.CAPTURE_URL, output = process.env.CAPTURE_DIR;
if (!url || !output) { console.error('Set CAPTURE_URL and CAPTURE_DIR.'); process.exit(1); }
mkdirSync(output, { recursive: true });
const transient = (error) => { throw Object.assign(error, { exitCode: 75 }); };
let browser;
try {
  browser = await chromium.launch({ ...config.browser.launchOptions, timeout: 30000 }).catch(transient);
  for (const [name, width, height] of [['desktop', 1440, 900], ['mobile', 390, 844]]) {
    const page = await browser.newPage({ viewport: { width, height } }).catch(transient);
    page.setDefaultTimeout(30000);
    page.on('pageerror', (error) => console.error(error.message));
    const response = await page.goto(url, { waitUntil: 'load', timeout: 45000 }).catch(transient);
    if (!response?.ok()) {
      const status = response?.status();
      throw Object.assign(new Error(`HTTP ${status} loading preview`), { exitCode: !response || [408, 429, 500, 502, 503, 504].includes(status) ? 75 : 1 });
    }
    await page.locator(process.env.CAPTURE_READY_SELECTOR || 'body').waitFor({ state: 'visible' });
    await page.waitForFunction(() => document.fonts.status === 'loaded');
    let reason = 'not-found';
    let clicked = false;
    if (process.env.CAPTURE_AUTO_START !== 'false') {
      const selector = process.env.CAPTURE_START_SELECTOR || '';
      const candidate = selector ? page.locator(selector) : page.locator('button, input[type="button"], input[type="submit"], [role="button"]');
      const deadline = Date.now() + 3000;
      const controls = await candidate.all();
      const matches = [];
      for (const control of controls) {
        if (!await control.isVisible() || !await control.isEnabled()) continue;
        const eligible = await control.evaluate((element, explicit) => {
          if (element.closest('a[href], form') || element.getAttribute('aria-disabled') === 'true') return false;
          if (explicit) return true;
          const label = element.getAttribute('aria-label') || element.value || element.textContent || '';
          return /^(?:start|play)(?:\s+(?:game|now))?$/i.test(label.trim());
        }, Boolean(selector)).catch(() => false);
        if (eligible) matches.push(control);
      }
      if (matches.length === 1) {
        try {
          await matches[0].click({ trial: true, timeout: 2000 });
          await matches[0].click({ timeout: 2000, noWaitAfter: true });
          clicked = true;
        } catch (error) {
          if (error.name === 'TimeoutError') reason = 'not-actionable';
          else throw error;
        }
      } else if (matches.length > 1) {
        reason = 'ambiguous';
      } else if (Date.now() >= deadline) {
        reason = 'not-found';
      }
    } else {
      reason = 'disabled';
    }
    console.log(`Capture ${name}: auto-start ${clicked ? 'clicked' : reason}`);
    await page.waitForTimeout(1000);
    await page.screenshot({ path: join(output, `final-${name}.png`), timeout: 30000 }).catch((error) => {
      if (error.name === 'TimeoutError' || !browser.isConnected()) transient(error);
      throw error;
    });
    await page.close();
  }
} catch (error) {
  console.error(error);
  process.exitCode = error.exitCode || 1;
} finally {
  await browser?.close().catch((error) => { console.error(error); process.exitCode ||= 75; });
}
NODE
