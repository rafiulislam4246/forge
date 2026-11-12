# Audit scope

_pending_

Fill before reading code. An audit without a declared scope becomes a tour of
whatever was interesting, and the things that matter go unchecked.

## What is being audited

The system, and the boundary of this audit: which directories, which services,
which environments.

## Why now

What prompted it. A suspected bug, a launch, a handover, a client complaint.
This decides what severity means below.

## Severity definitions for this audit

| Severity | Means here |
|---|---|
| blocker | breaks for users now, or loses or exposes data |
| major | wrong behaviour under conditions that will occur |
| minor | correct but fragile, confusing or unmaintainable |
| note | worth knowing, no action required |

## Checklist

The passes this audit will make. Tick as each completes, so a partial audit is
visibly partial.

- [ ] Does it run from a clean clone, following only its own documentation
- [ ] Tests: present, passing, and asserting something real
- [ ] Correctness of the main paths, read against the requirements
- [ ] Error and edge paths: what happens on bad input, timeout, empty state
- [ ] Authentication and authorisation, enforced where it is claimed to be
- [ ] Secrets: none committed, none logged
- [ ] Data: schema integrity, migrations reversible, no silent data loss
- [ ] User-visible surfaces driven in a real browser, every interactive element
- [ ] Performance of the paths that carry real volume
- [ ] Observability: would a failure here be noticed without a user reporting it
- [ ] Dependencies: versions, known advisories, abandoned packages

## Out of scope

What this audit will not look at, so the gaps are known rather than assumed
covered.
