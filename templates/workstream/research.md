# Research - {{TITLE}}

_pending_

Fill this before architecture. The point is to replace assumptions with facts
about *this* codebase, not to produce a literature review. Delete the guidance
lines as you answer them.

## The actual request

What was asked, in the requester's terms. Then what they appear to want
underneath it, if those differ, and which of the two this workstream serves.

## What already exists here

The code that already does some of this, with file paths. Most "new features"
are partly built already, and the expensive mistake is building a second one
beside the first.

| Exists | Where | Reuse, extend or replace |
|---|---|---|
|  |  |  |

## Constraints that are not negotiable

The schema that cannot change, the API contract other code depends on, the
deploy target, the auth model, the rate limit, the client's deadline. Each with
the file or fact that proves it.

## Prior art and sources

External docs, with URLs and version numbers, for every library or API this
will touch. Quote the specific behaviour relied on rather than summarising it:
version drift is the usual cause of code that looks right and fails.

## Open questions

The things that cannot be settled by reading. Mark each as blocking or not. Ask
the blocking ones before writing the architecture.

## What would make this fail

The failure modes worth designing against, ranked. Being honest here is what
turns the plan from a wish list into engineering.
