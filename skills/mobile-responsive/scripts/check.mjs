#!/usr/bin/env node
// Mobile responsive checker.
//
//   node check.mjs <url> [--out DIR] [--devices a,b] [--wait MS] [--json]
//
// Opens a page at several device sizes and looks for the failures that
// actually reach users on a phone, rather than for CSS opinions:
//
//   BLOCKER  horizontal scroll, or content sitting outside the viewport
//   MAJOR    tap targets under 44px, text under 14px, images overflowing
//   MINOR    very long unbroken strings, viewport meta missing
//
// Writes a full-page screenshot per device and exits non-zero when a blocker
// is found, so it can be used as a gate rather than only as a report.

import { mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

// Playwright is resolved at runtime rather than imported, so this script works
// from any directory: the project being checked, the skill's own folder, or a
// sibling project that already has it installed.
const loadChromium = () => {
  const here = dirname(fileURLToPath(import.meta.url));
  const bases = [];
  if (process.env.PLAYWRIGHT_DIR) bases.push(process.env.PLAYWRIGHT_DIR);
  for (let d = process.cwd(); d !== dirname(d); d = dirname(d)) bases.push(d);
  bases.push(here, join(here, '..'));
  for (const b of bases) {
    const pkg = join(b, 'node_modules', 'playwright');
    if (!existsSync(pkg)) continue;
    try {
      return createRequire(join(b, 'noop.js'))('playwright').chromium;
    } catch { /* try the next one */ }
  }
  try {
    return createRequire(import.meta.url)('playwright').chromium;
  } catch { /* fall through to the message below */ }
  console.error(
    'playwright not found.\n' +
    '  install it once, in this skill folder or in the project:\n' +
    `    npm i playwright --prefix "${join(here, '..')}"\n` +
    '  or point at an existing copy:\n' +
    '    PLAYWRIGHT_DIR=/path/to/project node check.mjs <url>'
  );
  process.exit(2);
};
const chromium = loadChromium();

const DEVICES = {
  'iphone-se':    { w: 375,  h: 667,  dpr: 2, mobile: true,  label: 'iPhone SE / small Android' },
  'iphone-15':    { w: 393,  h: 852,  dpr: 3, mobile: true,  label: 'iPhone 15 / 16' },
  'pixel-7':      { w: 412,  h: 915,  dpr: 2.6, mobile: true, label: 'Pixel 7 / large Android' },
  'ipad-mini':    { w: 768,  h: 1024, dpr: 2, mobile: true,  label: 'iPad mini (portrait)' },
  'ipad-pro':     { w: 1024, h: 1366, dpr: 2, mobile: true,  label: 'iPad Pro (portrait)' },
  'desktop':      { w: 1440, h: 900,  dpr: 1, mobile: false, label: 'Laptop' },
};

const args = process.argv.slice(2);
const url = args.find(a => !a.startsWith('--'));
const flag = (name, def) => {
  const i = args.indexOf(`--${name}`);
  return i === -1 ? def : args[i + 1];
};
const wantJson = args.includes('--json');

if (!url) {
  console.error('usage: node check.mjs <url> [--out DIR] [--devices iphone-se,desktop] [--wait 1200]');
  process.exit(2);
}

const outDir = resolve(flag('out', './responsive-report'));
const waitMs = Number(flag('wait', 1200));
const picked = flag('devices', Object.keys(DEVICES).join(','))
  .split(',').map(s => s.trim()).filter(d => DEVICES[d]);

if (!picked.length) {
  console.error(`no known devices. available: ${Object.keys(DEVICES).join(', ')}`);
  process.exit(2);
}

mkdirSync(outDir, { recursive: true });

// Runs inside the page. Everything here must be self-contained.
//
// targetWidth is the device width we asked for, and the comparisons use it
// rather than window.innerWidth. On a mobile context Chromium grows the layout
// viewport to fit overflowing content, so innerWidth reports 901 on a 375px
// phone showing a 900px image: measuring against it hides the exact bug.
const audit = ({ targetWidth, isMobile }) => {
  const vw = targetWidth;
  const out = { findings: [], meta: {} };
  const add = (severity, type, message, detail) =>
    out.findings.push({ severity, type, message, detail });

  const describe = (el) => {
    const id = el.id ? `#${el.id}` : '';
    const cls = typeof el.className === 'string' && el.className.trim()
      ? '.' + el.className.trim().split(/\s+/).slice(0, 3).join('.')
      : '';
    const txt = (el.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 40);
    return `${el.tagName.toLowerCase()}${id}${cls}${txt ? ` "${txt}"` : ''}`;
  };

  const visible = (el) => {
    const s = getComputedStyle(el);
    if (s.display === 'none' || s.visibility === 'hidden' || Number(s.opacity) === 0) return false;
    const r = el.getBoundingClientRect();
    return r.width > 0 && r.height > 0;
  };

  // 1. Viewport meta. Without it a phone renders at ~980px and scales down.
  const vp = document.querySelector('meta[name="viewport"]');
  out.meta.viewport = vp ? vp.getAttribute('content') : null;
  if (!vp) {
    add('blocker', 'viewport-meta',
      'No <meta name="viewport">: phones will render this at desktop width and shrink it.',
      'add <meta name="viewport" content="width=device-width, initial-scale=1">');
  } else if (/user-scalable\s*=\s*no|maximum-scale\s*=\s*1/.test(vp.getAttribute('content') || '')) {
    add('major', 'viewport-locked',
      'Viewport blocks zooming, which fails WCAG 1.4.4 and hurts low-vision users.',
      vp.getAttribute('content'));
  }

  // 2. Horizontal scroll. The single most common real mobile bug.
  const docW = Math.max(
    document.body ? document.body.scrollWidth : 0,
    ...[...document.querySelectorAll('body > *')].map(e => Math.ceil(e.getBoundingClientRect().right))
  );
  out.meta.scrollWidth = docW;
  out.meta.viewportWidth = vw;
  out.meta.innerWidth = window.innerWidth;
  if (docW > vw + 1) {
    add('blocker', 'horizontal-scroll',
      `Page scrolls sideways: content is ${docW}px wide in a ${vw}px viewport (${docW - vw}px over).`,
      'users see a shifted layout and can swipe into empty space');
  }

  // 3. Which elements actually stick out. This is what makes the bug fixable.
  const offenders = [];
  for (const el of document.querySelectorAll('body *')) {
    if (!visible(el)) continue;
    const r = el.getBoundingClientRect();
    if (r.width === 0) continue;
    const over = Math.round(r.right - vw);
    if (over > 1) {
      const s = getComputedStyle(el);
      // Ignore things deliberately parked offscreen (carousels, a11y text).
      if (s.position === 'fixed' || s.position === 'absolute') {
        const parentClipped = el.closest('[style*="overflow"],.overflow-hidden');
        if (parentClipped) continue;
      }
      offenders.push({ el: describe(el), overBy: over, width: Math.round(r.width) });
    }
  }
  offenders.sort((a, b) => b.overBy - a.overBy);
  if (offenders.length) {
    add(docW > vw + 1 ? 'blocker' : 'major', 'offscreen-elements',
      `${offenders.length} element(s) extend past the right edge.`,
      offenders.slice(0, 8));
  }

  // 4. Fixed pixel widths wider than the screen.
  const rigid = [];
  for (const el of document.querySelectorAll('body *')) {
    if (!visible(el)) continue;
    const s = getComputedStyle(el);
    const w = parseFloat(s.width);
    if (s.minWidth && s.minWidth.endsWith('px') && parseFloat(s.minWidth) > vw) {
      rigid.push({ el: describe(el), minWidth: s.minWidth });
    } else if (w > vw && s.maxWidth === 'none' && el.children.length === 0) {
      rigid.push({ el: describe(el), width: Math.round(w) + 'px' });
    }
  }
  if (rigid.length) {
    add('major', 'rigid-width',
      `${rigid.length} element(s) are wider than the screen and cannot shrink.`,
      rigid.slice(0, 6));
  }

  // 5. Images that overflow, the classic missing max-width:100%.
  const badImgs = [];
  for (const img of document.querySelectorAll('img, video, svg, canvas, iframe')) {
    if (!visible(img)) continue;
    const r = img.getBoundingClientRect();
    if (r.width > vw + 1) badImgs.push({ el: describe(img), width: Math.round(r.width) });
  }
  if (badImgs.length) {
    add('major', 'media-overflow',
      `${badImgs.length} image/media element(s) are wider than the screen.`,
      badImgs.slice(0, 6));
  }

  // 6. Tap targets. Apple and Google both say 44px; smaller is a miss-tap.
  // Only meaningful with a finger, so this is skipped on desktop widths.
  const small = [];
  const tappable = 'a[href], button, input:not([type=hidden]), select, textarea, [role="button"], [onclick]';
  if (isMobile) {
    for (const el of document.querySelectorAll(tappable)) {
      if (!visible(el)) continue;
      const r = el.getBoundingClientRect();
      if (r.height < 44 || r.width < 24) {
        small.push({ el: describe(el), size: `${Math.round(r.width)}x${Math.round(r.height)}` });
      }
    }
  }
  if (small.length) {
    add('major', 'small-tap-targets',
      `${small.length} tappable element(s) are under 44px tall.`,
      small.slice(0, 8));
  }

  // 7. Text too small to read on a phone. A 12px label and 11px body copy are
  // not the same problem, so they are not reported at the same severity, and
  // neither matters at desktop width.
  const tiny = [];
  const smallish = [];
  if (isMobile) {
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    const seen = new Set();
    let n;
    while ((n = walker.nextNode())) {
      const t = n.textContent.trim();
      if (t.length < 8) continue;
      const el = n.parentElement;
      if (!el || seen.has(el) || !visible(el)) continue;
      seen.add(el);
      const fs = parseFloat(getComputedStyle(el).fontSize);
      if (!fs) continue;
      if (fs < 12) tiny.push({ el: describe(el), fontSize: fs + 'px' });
      else if (fs < 14 && t.length > 60) smallish.push({ el: describe(el), fontSize: fs + 'px' });
    }
  }
  if (tiny.length) {
    add('major', 'tiny-text',
      `${tiny.length} text element(s) render under 12px, which is hard to read on a phone.`,
      tiny.slice(0, 6));
  }
  if (smallish.length) {
    add('minor', 'small-body-text',
      `${smallish.length} block(s) of running text under 14px.`,
      smallish.slice(0, 4));
  }

  // 8. Unbreakable strings, which force the page wide on a narrow screen.
  const longWords = [];
  for (const el of document.querySelectorAll('p, span, a, li, h1, h2, h3, td, div')) {
    if (!visible(el) || el.children.length) continue;
    const word = (el.textContent || '').trim().split(/\s+/).find(w => w.length > 28);
    if (word) longWords.push({ el: describe(el), word: word.slice(0, 40) });
  }
  if (longWords.length) {
    add('minor', 'unbreakable-text',
      `${longWords.length} very long unbroken string(s); add overflow-wrap: anywhere.`,
      longWords.slice(0, 4));
  }

  return out;
};

const run = async () => {
  const browser = await chromium.launch();
  const results = [];
  let blockers = 0, majors = 0;

  for (const name of picked) {
    const d = DEVICES[name];
    const ctx = await browser.newContext({
      viewport: { width: d.w, height: d.h },
      deviceScaleFactor: d.dpr,
      isMobile: d.mobile,
      hasTouch: d.mobile,
      userAgent: d.mobile
        ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
        : undefined,
    });
    const page = await ctx.newPage();
    const consoleErrors = [];
    page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text().slice(0, 160)); });
    page.on('pageerror', e => consoleErrors.push(String(e).slice(0, 160)));

    let loadError = null;
    try {
      await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
    } catch (e) {
      try {
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 20000 });
      } catch (e2) {
        loadError = String(e2.message || e2).split('\n')[0];
      }
    }

    if (loadError) {
      results.push({ device: name, label: d.label, loadError, findings: [] });
      console.log(`\n### ${name} (${d.w}x${d.h}) ${d.label}\n  COULD NOT LOAD: ${loadError}`);
      await ctx.close();
      continue;
    }

    await page.waitForTimeout(waitMs);
    const res = await page.evaluate(audit, { targetWidth: d.w, isMobile: d.mobile });
    const shot = `${outDir}/${name}.png`;
    await page.screenshot({ path: shot, fullPage: true });

    if (consoleErrors.length) {
      res.findings.push({
        severity: 'major', type: 'console-errors',
        message: `${consoleErrors.length} console error(s) on this viewport.`,
        detail: [...new Set(consoleErrors)].slice(0, 4),
      });
    }

    blockers += res.findings.filter(f => f.severity === 'blocker').length;
    majors += res.findings.filter(f => f.severity === 'major').length;
    results.push({ device: name, label: d.label, width: d.w, height: d.h, screenshot: shot, ...res });

    console.log(`\n### ${name}  ${d.w}x${d.h}  ${d.label}`);
    if (!res.findings.length) {
      console.log('  clean');
    } else {
      for (const f of res.findings) {
        console.log(`  [${f.severity.toUpperCase()}] ${f.type}: ${f.message}`);
        if (Array.isArray(f.detail)) {
          for (const d2 of f.detail.slice(0, 5)) console.log(`      - ${JSON.stringify(d2)}`);
        } else if (f.detail) {
          console.log(`      ${f.detail}`);
        }
      }
    }
    console.log(`  screenshot: ${shot}`);
    await ctx.close();
  }

  await browser.close();

  const report = { url, when: new Date().toISOString(), blockers, majors, results };
  writeFileSync(`${outDir}/report.json`, JSON.stringify(report, null, 2));

  console.log(`\n${'='.repeat(60)}`);
  console.log(`URL       ${url}`);
  console.log(`Devices   ${picked.length}`);
  console.log(`BLOCKERS  ${blockers}`);
  console.log(`MAJOR     ${majors}`);
  console.log(`Report    ${outDir}/report.json`);
  console.log(`Shots     ${outDir}/`);
  if (wantJson) console.log(JSON.stringify(report));
  process.exit(blockers > 0 ? 1 : 0);
};

run().catch(e => { console.error('check failed:', e.message); process.exit(2); });
