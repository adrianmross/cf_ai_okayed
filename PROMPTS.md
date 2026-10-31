# Prompt history

okayed's design is mine: the problem, the grant format, the layered engine, and the rule that a model only drafts while
a deterministic engine decides. Several ideas, like hold-and-slide to choose how long an approval lasts, come from my
earlier work on unreleased projects (shown as [redacted]).

I built it with an AI coding assistant (Claude Code), which the Cloudflare assignment encourages and asks to see. These
are the prompts, lightly edited. Each is followed by the commits that came of it. Along the way I made the product and
design calls, used each build as it shipped, and reviewed the work before merging it. The prompts okayed itself sends
to Llama 3.3 are in [`packages/core/src/prompts.ts`](packages/core/src/prompts.ts).

## 1. The problem and the ground rules

The opening brief was one prompt; it's split here by the stage of work each part drove.

```text
okayed: a scoped-authority approval service for AI agents, on Cloudflare.

The problem: people tell their agents things like "I approve merging #182" or "go ahead and deploy the website".
That sentence is not an authorization anything can verify. okayed turns it into the narrowest exact, signed,
expiring grant, shows it to the person for confirmation, and lets any tool verify the grant before acting.

Requirements: Llama 3.3 on Workers AI; the Agents SDK with a Durable Object per user and a Workflow for the grant
lifecycle; a chat UI; per-user policy, pending requests, active grants and an audit log in the Durable Object.

Design rules:
- The model drafts; a deterministic engine decides. The LLM only turns plain language into a proposed grant and
  explains requests and decisions. Allow/deny and narrowing are pure, tested TypeScript.
- Least privilege by construction: grants pin exact targets (repo + PR + commit SHA; site + environment), the
  shortest reasonable lifetime and the fewest uses. The engine refuses anything broader than what the person said,
  and shows what it cut ("asked for X, granted Y, refused Z because ...").
- Ambiguity is a question, not a guess ("which site?", "which environment?").
- "Once" means exactly one use: the Durable Object decrements atomically; a second use is refused.
- Every grant is revocable at any time; expiry is enforced by the Workflow and by verifiers.

Grant format (v0, JSON, signed as a Nostr event; kinds are placeholders, not registered):
{v, id (JCS hash), iss, aud, act, res[], when[], nbf, exp, uses, risk, assurance, from{utterance, request}, nonce}.
Kinds: 4840 request, 4841 grant, 4842 revoke, 4843 use receipt, 4844 emergency stop, 34840 policy. Use NIP-40
expiration tags. assurance records how the person confirmed (a web click today; a hardware-key proof later).

Propose a short design doc and the grant shape. List out any paid Cloudflare features required.
```

- `docs: add design doc and v0 grant format`

## 2. The engine

```text
Skeleton out packages/engine: a pure engine. Policy = layered rules, where each layer can only narrow the one above;
a decision is allowed only if every layer allows; the reason names the first refusing layer; a "beyond" list shows
what was asked for but not granted. Add unit tests, including adversarial ones where the prompt tries to widen scope.
```

- `feat(engine): add pure policy, narrowing and use-check engine with tests`
- `feat(grant): add v0 grant format with JCS ids and signed Nostr events`

## 3. The Worker

```text
Skeleton out apps/worker: an Agents SDK agent and Durable Object per user; a Workflow for request -> propose ->
await confirm -> issue -> expire/revoke; an HTTP API for agents to submit requests and for tools to verify grants
(POST /verify).
```

- `feat(core): add provider-neutral service, grant lifecycle flow and in-memory adapters`
- `feat(worker): add Agents SDK agent, grant lifecycle Workflow and HTTP API`
- `chore: add dev:local script for running the Worker without a login`

## 4. The two UIs

```text
Skeleton out apps/web: a chat to set policy in plain words ("auto-approve read-only GitHub for 1 hour; ask me before
anything that spends money"), pending requests as a clear card (a plain sentence, what it allows, what it does not,
risk), confirm/deny/revoke, and an audit view.

Skeleton out apps/playground: write a policy, ask a question, see allow/deny with a one-sentence reason and a per-layer
breakdown, with one-tap "what if" edits. The headline demo: plain-language approval -> proposed grant -> engine narrows
it -> diff of what was cut.
```

No paid Cloudflare features were added: Workers, Durable Objects (SQLite), Workflows, the Workers AI free allocation
and static assets are all on the free plan.

- `feat(web): add chat UI for policy, request cards, grants and audit`
- `feat(playground): add in-browser policy playground and narrowing demo`
- `docs: add README, prompt history and screenshots`

## 5. Simpler UI, cleaner code

```text
Let's simplify the web policy view the same way we did the playground and [redacted]. Propose some code clean-ups.
```

- `fix(worker): refuse live-state sockets without the owner token`
- `feat(ui): add shared block components`
- `refactor(web): rebuild on shared blocks with tabs and a Debug switch`
- `refactor(playground): ask-your-policy view and words-to-grant view on shared blocks`
- `refactor(engine): split binding from narrowing and share one capping rule`
- `refactor(core): split records, card building and the snapshot view out of the service`
- `chore: flag unused code in typecheck; document the ui package`
- `docs: add code-by-layer and test-coverage chart`

## 6. Standing authority, and budgets

```text
Create some reasonable default postures, but leave it to the user to create the policies they want. What we have
right now are one-time approvals shown as a policy, but a policy is for repeat actions: with an expiration, bounded to
a couple of uses, or bounded on scored risk. Reference [redacted].
```

```text
Turn risk budgets off by default, and let them be global or local to single policies, actions or approvals.
```

- `feat(engine)!: standing policies with horizons, budgets and conditions`
- `feat(core): run standing policies with budgets, statements and top-ups`
- `feat(ui): edit standing policies in place, with budgets left and top-up`
- `docs: describe standing policies`
- `feat: make budgets opt-in, on one policy or shared across policies`
- `docs: describe opt-in and shared budgets`
- `docs: bring the prompt history up to date`

## 7. A chat demo on its own design system

```text
Skeleton out a chat demo where you ask for things that need permission and approve them with Face ID; the actions
are mocked. Different views can show receipts or transcripts. Use the latest shadcn, and show tool calls in the chat. The UI so far is still way too complex: it needs clear,
enjoyable configuration, and it doesn't need to cram everything onto one page. Siri Shortcuts is good inspiration for
building rules. Make your own design system for this project (it can be standalone) so it feels cohesive.
```

- `feat: add an agent client and an MCP server for agents`
- `feat(design): add okayed's design system on the latest shadcn`
- `feat: add passkey approvals and a demo chat agent with simulated tools`
- `feat(web): rebuild as a chat demo with Face ID approvals and Shortcuts-style policies`
- `feat(playground): rebuild on the design system`
- `fix(core): let the scripted assistant read denials however they arrive`
- `test: run the demo end to end in a browser with a virtual Face ID`
- `docs: describe the chat demo, passkey assurance and the design system`

## 8. Everyday words, approver apps, a registry, other models

```text
Which works better, rules or policies, and grants or approvals? Anything else language-wise we could improve?
```

```text
Let's plan the local approval through WebAuthn now, and an external authenticator like [redacted] later. Let's also
scaffold our own shadcn registry. Also analyze how different models perform at the interpretation, or something like
OpenAI's decision API.
```

The app now says rules, Allow / Ask me / Block, permissions, limits and Take back; the API, grant format and docs keep
the IAM terms.

- `feat(ui): say rules and permissions, and add "Always allow…"`
- `feat(core): push approvals to approver apps on other devices`
- `feat(design): publish the design system as a shadcn registry`
- `fix(engine): keep the place in "never deploy to production"`
- `feat(core): compare interpreters on an eval set, and draft with any OpenAI-compatible model`
- `refactor: list each assurance method once, and rename a playground constant`
- `fix(ui): say "your rules" when something is allowed, and name agents properly on tiles`
- `test(e2e): wait for the assistant to finish before sending the next message`
- `docs: describe the new words, approvers, the registry and interpreter evals`

## 9. Approval buttons, Cloudflare-native, and any platform

```text
Show different button configurations in the registry: a row layout or a main action with two secondaries, and flows
like single tap or swipe to approve. For Always allow, use the same config as [redacted]: hold the button and slide
up through duration, then swipe all the way through to confirm. The same for deny.
```

- `feat(design): approval actions in layouts and flows, with slide and hold-and-slide`
- `feat(playground): show every approval configuration in a Components view`
- `feat(core): a Deployer port, and wake URLs for paired approver apps`
- `feat(worker): run okayed as one Cloudflare-native Worker`
- `feat(web): approval buttons, timed rules, voice, and the Connect screen`
- `test: OAuth and MCP end to end, queue and archive checks, hold and slide in the browser`
- `docs: describe okayed on Cloudflare end to end, and the approval buttons`
- `feat: make the core platform-neutral: identity, connectors and the HTTP API`
- `feat(engine): capability packs, so any service's actions can be approved`
- `feat(design): show registered actions with the engine's words`
- `feat(node): run okayed on Node, from the same core`
- `feat: approve any service's actions, end to end`
- `feat(web): trust a CI workflow, and work with any registered action`
- `docs: describe the platform-neutral core: runtimes, packs, connectors, identity`
- `feat(engine): rules and limits for groups of agents`
- `feat(core): limits from outside the person, and agent groups`
- `feat(interop): OAuth scopes, rich authorization requests, UCAN, SCIM and organization policies`
- `feat: organization limits and SCIM provisioning on the Worker and on Node`
- `feat(web): show an organization's limits above your rules`
- `docs: Durable Objects, Cloudflare, and other permission systems`

## 10. Swipe to decide, and a quieter chat

```text
Make suggestions to declutter the UX and simplify interactions. Take inspiration from [redacted].
```

- `feat(design): swipe to decide, with a tested gesture model`
- `feat(design): the approval card asks in plain words, and payments are money cards`
- `feat(core): the demo assistant replies in one line, and gives its reasons in its own words`
- `feat(web): one line per action, and swipe everywhere`
- `feat(playground): every swipe configuration, payments included`
- `chore(mcp): keep the CLI executable`
- `test: drive the browser test by swipe and hold`
- `docs: swipe to decide, money cards and a quieter chat`

## 11. Live, and open to the public

CI and the deploy, then what showed up once it ran on the real Workers AI and I used it:

```text
Since this is public, what are some Cloudflare approaches to prevent abuse?
```

```text
Diagnose why the chat stops replying after going to another page and back. Propose a solution.
```

- `ci: add test, end-to-end and deploy workflows`
- `fix(worker): simulate streaming so Workers AI tool calls arrive whole`
- `docs: link the deployed demo and playground`
- `fix(worker): let the live assistant answer after a tool, and take amounts as strings`
- `feat(worker): limit model calls per person`
- `fix(web): no flash when a rule allows an action`
- `fix(web): keep the chat mounted on other pages`
- `fix(web): leave rule-approved tool calls to the server`
- `fix(web): show the saved chat after a reload`
- `fix(core): the assistant chats, asks for a missing repo and takes "prod"`
- `fix(design): the swipe holds while Face ID and signing run`

## 12. Sign-in, keys, and a stalled passkey

```text
How can we showcase OAuth2/OIDC integration more?
```

```text
If no passkey is set up, approvals in the chat stall instead of asking for one. Fix.
```

- `feat(web): reset the chat or the whole demo from Settings`
- `feat(playground): show sign-in providers, org limits and OAuth scopes`
- `feat(web): Reset chat sits in the chat header`
- `feat(design): one KeyChip for ids and keys, used in receipts and Settings`
- `feat(playground): a sign-in screen with provider logos and who signs what`
- `test(e2e): read receipt ids in their KeyChip form`
- `fix(web): a passkey prompt that never answers no longer hangs the approval`

## 13. Words → grant: a steady layout, hints and highlighting

```text
There's too much movement when using the app: switching between Balanced and Cautious makes the page jump. Things
should stay in place, and only the words or elements that change (like the number of rule cards) should change. Fix.
Recommend some shadcn prebuilt components and lazy-loading approaches, so it feels native.
```

```text
No duplicate or over-verbose explanations: move longer explanations and hints behind an info icon. And add syntax
highlighting to the playground's input box as you type, like in [redacted].
```

- `feat(playground): Words → grant explains its examples, queues pending requests and shows details`
- `feat(playground): ghost-text examples in Words → grant, and Add opens the queue builder`
- `feat(engine): highlight() marks what a sentence pins down, with positions`
- `feat(playground): color words as you type, hints behind info icons, steady Ask layout, lazy views`
- `perf(web): lazy-load Rules, Activity and Settings`
- `test(scripts): wait for the lazy Rules page in the web e2e`
