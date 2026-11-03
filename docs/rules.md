# Rules, approvers and interpreting people

What the app says, how standing rules and limits work, who can approve, and how well okayed reads people.

## Words

The app speaks in everyday words. The API, the grant format and the docs keep the IAM ones:

| In the app | In the API and docs |
|---|---|
| a **request** ("Assistant wants to…") | request (kind 4840) |
| **Allow** · **Ask me** · **Block** | `allow` · `ask` · `deny` |
| a **rule** | a rule in your layer of the policy |
| a **permission** | a grant (kind 4841) |
| a **receipt** | a use receipt (kind 4843) |
| a **limit**, in uses or points | a budget (`budget`, `budgets`) |
| **Take back** · **Stop everything** | revoke (4842) · emergency stop (4844) |

## Standing rules

A one-time okay is the narrow case. Most of the time you want an agent to get on with things:

> “always allow merges in okayed when checks pass for 2 weeks, up to 30 merges”

That becomes a rule: repo `adrianmross/okayed`, condition `checks.pass`, a 14-day horizon and a limit of 30. Each
merge under it is allowed as its own one-time permission, pinned to the PR's head commit, and the permission names
the rule that allowed it. **Always allow…** on an approval card builds the same kind of rule from a real request.

**Limits are optional.** Put one on a single rule ("up to 30 merges"), or add a limit shared across rules: global
("everything, 100 points this week"), for one action ("merges, 10 a day") or for one agent ("the assistant, 50 points
this week, counting what I allow too"). Points weigh actions by risk. When a limit runs out, the next request asks
you, the card says what used it up, and one tap resets it.

New users start from the **Balanced** preset and no limits: reads, comments, merges with passing checks, and staging
deploys are allowed; production deploys and spending ask. These are ordinary rules you can change in Rules, by
tapping a word, or in words. The model's draft of a rule can't widen what you said.

## Approvers

Every approval signs the same thing: the card, a hash of its exact draft, and a nonce. Today the approver is local, a
passkey in the browser. The approver is a port, so an approval can also go to an app on another device, such as a
phone: pair the app's public key (`POST /approvers`), and okayed keeps what's waiting in an inbox the app reads with
a signed request (NIP-98). The app answers with a signed approval event (kind 4845), which becomes the grant's proof
(`assurance.method: "approver"`). A `Notifier` port can wake the app; the wake carries nothing. okayed's side is
built and tested end to end. No app ships with it yet.

## Interpreting people

The model only drafts, so it never decides, but a better reader asks fewer needless questions. `packages/core`
drafts with Workers AI (Llama 3.3 by default), or any OpenAI-compatible endpoint (`DRAFTER=openai-compatible`), and
falls back to the model-free heuristic. Twenty eval cases, from plain okays to prompt injections, are scored by what
the engine ends up doing with each draft:

```bash
pnpm --filter @okayed/core test interpret                     # the heuristic: 18/20 intent, 17/20 outcome
EVAL_MODELS="cf:@cf/meta/llama-3.3-70b-instruct-fp8-fast,cf:@cf/openai/gpt-oss-120b" \
  CLOUDFLARE_ACCOUNT_ID=… CLOUDFLARE_API_TOKEN=… pnpm --filter @okayed/core test interpret
EVAL_MODELS="openai:gpt-5-mini" OPENAI_API_KEY=… pnpm --filter @okayed/core test interpret
```

Part of the work is a bounded choice (is this an okay, a rule or a question; which pending request; which site), and
the intent column scores it on its own. Fast decision models, such as OpenAI's Decisions API, fit that part. See
[`design.md`](design.md#interpreting-people).
