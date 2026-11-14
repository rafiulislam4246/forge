---
name: mobile-responsive
description: "Check and fix how a site actually behaves on phones. Loads the page at real device sizes, detects horizontal scroll, off-screen elements, rigid widths, overflowing images, tap targets under 44px and unreadable text, screenshots every size, and records the result as browser evidence. Use after building or changing any UI, before claiming a page works, when something looks wrong on a phone, or when asked to make a site responsive. Triggers on: mobile responsive, check mobile, responsive check, does it work on phone, mobile broken, make it responsive, test on devices, horizontal scroll, mobile layout, phone view."
user_invocable: true
---

# mobile-responsive

Most mobile bugs are not subtle. The page scrolls sideways, a card is wider
than the screen, a button is too small to hit, a label renders at 10px. They
survive because nobody opens the page on a phone: the desktop browser looks
fine, the tests pass, and the work gets called done.

This skill replaces the opinion with a measurement.

**Never claim a page works on mobile without running the checker on it.** A
passing test suite is not evidence about layout, and neither is a desktop
screenshot.

---

## 1. Run the check

```sh
node ~/.claude/skills/mobile-responsive/scripts/check.mjs <url> --out ./responsive-report
```

A local dev server must be running first. Start it, wait for it to be
listening, then point the checker at it. For a static file, a `file://` URL
works.

Useful flags:

| Flag | Default | Why |
|---|---|---|
| `--devices` | all six | `iphone-se,iphone-15,pixel-7,ipad-mini,ipad-pro,desktop`. Narrow it while iterating. |
| `--out` | `./responsive-report` | screenshots and `report.json` land here |
| `--wait` | `1200` | raise it for pages that animate or fetch on load |

`iphone-se` at 375px is the one that matters most: it is the narrowest screen
still in real use, so it fails first. Check it before the others.

Exit code is 1 when a blocker is found, so this works as a gate and not only as
a report.

If it reports that playwright is missing:

```sh
npm i playwright --prefix ~/.claude/skills/mobile-responsive
```

Browsers are usually already cached from another project; if not, add
`npx playwright install chromium`.

---

## 2. What it finds, and what each one means

| Severity | Finding | The real-world symptom |
|---|---|---|
| blocker | `horizontal-scroll` | The page slides sideways. Everything feels misaligned and the user can swipe into empty space. |
| blocker | `offscreen-elements` | Named elements sit past the right edge. This is the cause list for the scroll above. |
| blocker | `viewport-meta` | No viewport meta, so the phone renders at ~980px and shrinks it. Every text is tiny. |
| major | `rigid-width` | A fixed `width` or `min-width` wider than the screen, which cannot shrink. |
| major | `media-overflow` | An image or iframe wider than the screen. Usually a missing `max-width: 100%`. |
| major | `small-tap-targets` | Under 44px tall. Apple and Google both use 44px; smaller means mis-taps. Mobile only. |
| major | `tiny-text` | Under 12px. Mobile only. |
| major | `console-errors` | JavaScript failing on this viewport, which often explains an empty section. |
| minor | `small-body-text` | Running text at 12 to 14px. Readable, but tiring. |
| minor | `unbreakable-text` | A long unbroken string forcing the page wide. `overflow-wrap: anywhere`. |

The report names the offending element with its tag, id and first classes, so
the fix goes straight to the right line instead of being hunted for.

---

## 3. Fix in this order

Work top down. The first two fixes usually remove most of the rest, because one
overflowing element drags the whole page wide.

1. **Horizontal scroll.** Find it from the `offscreen-elements` list, worst
   `overBy` first. Do not paper over it with `overflow-x: hidden` on the body:
   that hides the symptom, keeps the broken layout, and breaks scroll anchoring.
   Fix the element.
2. **Rigid widths.** `width: 600px` becomes `width: 100%; max-width: 600px`. In
   Tailwind, `w-[600px]` becomes `w-full max-w-[600px]`.
3. **Media.** `max-width: 100%; height: auto`, or `w-full h-auto`.
4. **Wide tables and code blocks.** These are legitimately wide. Wrap them in a
   scroll container rather than forcing them to shrink.
5. **Tap targets.** `min-height: 44px` and real padding. An icon button needs a
   44px hit area even when the icon is 20px.
6. **Text.** Body copy at 16px or more. Below 16px, iOS Safari zooms the page
   when an input is focused, which is its own bug.

After each fix, re-run the checker. The numbers either move or they do not.

---

## 4. Then look at it

The checker catches geometry. It cannot tell you the layout is ugly, that two
sections collide visually, or that the hero reads badly on a narrow screen.
Open the screenshots in `--out` and look at every one, phone sizes first.

For side-by-side work across many devices at once, Responsively App shows the
page in 30+ device frames with mirrored scrolling and clicks:

```sh
brew install --cask responsively
```

It is the right tool while designing. The checker is the right tool for proving.

---

## 5. Record the evidence

If the project uses Forge, this is what opens the UI gate:

```sh
forge evidence add browser pass "mobile-responsive check on /dashboard" \
  "6 devices, 0 blockers, iphone-se clean, screenshots in responsive-report/"
```

Record a failure as a failure. An unverified page is reported as unverified,
never as working.

---

## 6. Build it right the first time

The checks above are a safety net, not a method. When writing the UI:

- Start at 375px and widen. Designing desktop-first and squeezing down is what
  produces these bugs in the first place.
- Prefer flow and intrinsic sizing: `max-width`, `min()`, `clamp()`, `flex-wrap`,
  `grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr))`. These adapt
  without breakpoints.
- Reach for a fixed pixel width only when the thing genuinely has a fixed size.
- Use container queries for components that appear in differently sized slots,
  since a component does not know the page width it will live in.
- Give every interactive element a 44px hit area from the start.
- Respect the safe areas on notched phones: `padding: env(safe-area-inset-*)`.
