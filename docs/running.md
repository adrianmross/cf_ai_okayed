# Running okayed

Locally with no Cloudflare login, as an agent would use it, and deployed to Cloudflare.

## Run it locally

Requires Node 22 and pnpm 10. With [devenv](https://devenv.sh), `direnv allow` (or `devenv shell`) pins both. The
secrets are declared in `secretspec.toml`, so with [secretspec](https://secretspec.dev) they can stay in your own
secret store instead of `.dev.vars`: `secretspec check` asks for any that are missing, then `dev-local`, `dev-worker`
and `deploy-worker` run with only the declared secrets.

```bash
pnpm install
pnpm test                      # engine, grant, core, client, MCP and worker tests
cp apps/worker/.dev.vars.example apps/worker/.dev.vars
# put 64 hex chars in ISSUER_SECRET:  node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
pnpm build:site                # the web app, the playground (/playground) and the registry (/r), for the Worker
pnpm dev:local                 # one Worker on :8787 serves all of it, with no Cloudflare login
pnpm e2e                       # the API, remote MCP over OAuth, then the demo in a browser with a virtual Face ID
```

Open <http://localhost:8787>. For hot reload while working on the UI, run `pnpm dev:web` (:5173) and
`pnpm dev:playground` (:5174) next to the Worker.

`dev:local` runs every part except Workers AI: Durable Objects, the Workflow, OAuth and remote MCP, Queues, R2 and
the static site are all simulated locally. The assistant is then played by a scripted model that reads intent with
okayed's own anchors, and drafting uses the model-free `HeuristicDrafter`, so the whole demo works offline. To use
Llama 3.3 and voice, run `wrangler login` and then `pnpm dev:worker`. The model only drafts; okayed still decides.

Face ID works on `localhost`: browsers treat it as a secure context. Passkeys are bound to the Worker's own origin
and to any origin in `WEB_ORIGINS`.

### Talk to it like an agent

```bash
API=http://localhost:8787
# In the web app: Settings → Add agent → copy the token. Or:
read U OWNER < <(curl -s -X POST $API/api/users | node -pe 'const j=JSON.parse(require("fs").readFileSync(0));j.userId+" "+j.ownerToken')
AGENT=$(curl -s -X POST $API/api/u/$U/agents -H "authorization: Bearer $OWNER" -d '{"name":"assistant"}' | node -pe 'JSON.parse(require("fs").readFileSync(0)).token')

# 1. The agent asks.
curl -s -X POST $API/api/u/$U/requests -H "authorization: Bearer $AGENT" \
  -d '{"act":"github.pr.merge","res":["github:adrianmross/okayed/pull/182@3f9a1c2e4b5d6f708192a3b4c5d6e7f801234567"],"why":"reviewed, CI green"}'

# 2. The person says yes in the web app ("I approve merging #182"), or:
curl -s -X POST $API/api/u/$U/chat -H "authorization: Bearer $OWNER" -d '{"text":"I approve merging #182"}'
curl -s -X POST $API/api/u/$U/cards/<card id>/confirm -H "authorization: Bearer $OWNER"

# 3. The agent collects the signed grant (long-polls up to 20 s).
curl -s "$API/api/u/$U/requests/<request id>?wait=10" -H "authorization: Bearer $AGENT"

# 4. A tool verifies before acting. "consume": true spends a use atomically.
curl -s -X POST $API/api/u/$U/verify -d '{"event":<grant event>,"aud":"agent:assistant","act":"github.pr.merge","res":"github:…","consume":true}'
```

Or let okayed perform the action: `POST /api/u/:user/tools/github/merge {grant, owner, repo, number, sha}`. The
Worker verifies and consumes the grant, checks `checks.pass` when the grant requires it (without spending the use if
the checks fail), then merges with its own `GITHUB_TOKEN`, passing GitHub's `sha` guard so a moved head is refused.
The agent never holds the token.

### Use it from any MCP agent

okayed is a **remote MCP server** at `/mcp`. Add `https://<your okayed>/mcp` to Claude, Cursor or any MCP client. The
client registers itself and sends you to okayed's Connect screen; allowing it makes the client one of your agents.
Its OAuth token can ask for permission and use what it's given, and nothing else. Disconnect it in Settings.

The tools:

- `okayed_actions` lists the actions and how to name exact targets.
- `okayed_request` asks before acting. It returns at once if one of your rules allows the action; otherwise it waits for you.
- `okayed_status` keeps waiting on a request.
- `okayed_merge_pr` merges through okayed's tool.
- `okayed_deploy_site` deploys through okayed's tool (Cloudflare Pages, below).

Grants stay inside okayed (or the MCP process), so the agent sees what it may do but never holds a credential.

For a local agent, `apps/mcp` runs the same tools over stdio with a token from Settings:

```json
{
  "mcpServers": {
    "okayed": {
      "command": "node",
      "args": ["/path/to/okayed/apps/mcp/src/main.ts"],
      "env": { "OKAYED_API": "https://okayed.<you>.workers.dev", "OKAYED_USER": "<user id>", "OKAYED_TOKEN": "agt_…" }
    }
  }
}
```

For code that isn't an MCP agent, `packages/client` does the same in a few lines:

```ts
const okayed = new OkayedClient({ api, user, token });
const a = await okayed.ask("github.pr.merge", [prResource("adrianmross", "okayed", 182, sha)], "CI is green");
if (a.status === "granted") await okayed.merge(a.event!, { owner: "adrianmross", repo: "okayed", number: 182, sha });
```

## Deploy (Cloudflare)

Everything runs on the free plan. One command builds the site, creates the queue and deploys the Worker; KV is created
on first deploy.

```bash
cd apps/worker
npx wrangler login
pnpm run deploy
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))" | npx wrangler secret put ISSUER_SECRET
```

Or add the `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` and `ISSUER_SECRET` repository secrets and run the
**deploy** workflow. Optional, each off until you set it:

| To | Set |
|---|---|
| Sign in with **Cloudflare Access** instead of an owner token | Put an Access application in front of the Worker; vars `ACCESS_TEAM` (your `<team>.cloudflareaccess.com`) and `ACCESS_AUD` (the application's AUD tag) |
| Check sign-ups with **Turnstile** | Secret `TURNSTILE_SECRET`; build with `VITE_TURNSTILE_SITE_KEY` |
| Route model calls through **AI Gateway** (logs, caching, rate limits) | Var `AI_GATEWAY` (the gateway id) |
| **Real deploys** with just-in-time API tokens | Secret `CF_API_TOKEN` (permission: Account API Tokens: Edit, nothing else); vars `CF_ACCOUNT_ID` and `CF_PAGES_SITES`, e.g. `{"okayed.dev":{"project":"okayed-site","branches":{"production":"main","staging":"staging"}}}` |
| Archive every signed event to **R2** | Uncomment `r2_buckets` in `wrangler.jsonc` (R2 needs billing enabled on the account) |
| Merge real PRs | A GitHub App (vars `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION`, secret `GITHUB_APP_KEY`), or secret `GITHUB_TOKEN`: fine-grained, pull-request write on the demo repo only |
| Sign in with **another OIDC provider** | Vars `OIDC_ISSUER` and `OIDC_AUDIENCE`; the provider's ID token is the bearer token |
| Approve **other services' actions** | Var `CAPABILITY_PACKS` (e.g. `slack,email,cloudflare-dns,aws-s3`) or `CAPABILITY_PACKS_JSON` |
| Post to **Slack** | Secret `SLACK_BOT_TOKEN`, var `SLACK_WORKSPACE`, and the `slack` pack |
| Change **DNS** with zone-scoped tokens | Var `CF_DNS_ZONES` (`{"okayed.dev":"<zone id>"}`), with `CF_ACCOUNT_ID`, `CF_API_TOKEN` and the `cloudflare-dns` pack |
| Set **organization limits** by group | Var `ORG_POLICY` (JSON, [interop.md](interop.md)); groups come from sign-in (OIDC claims, or Access) |
| Provision people and groups over **SCIM** | Secret `SCIM_TOKEN`; point the IdP at `https://<your okayed>/scim/v2`; var `SCIM_SUBJECT` if the sign-in subject isn't in `externalId` |

### Use the components in your own app

The Worker serves okayed's design system as a shadcn registry at `/r/`. See
[Install from the registry](design-system.md#install-from-the-registry).

## Repository layout

```
packages/engine      pure decision engine: anchors, binding, narrowing, standing policies, budgets, use checks
packages/grant       grant format v0: JCS, ids, Nostr events, BIP-340 signatures, per-user issuer keys
packages/core        the platform-neutral service: ports (Store, Signer, Drafter, Lifecycle, Clock, Notifier), the
                     HTTP API on Request/Response, identity (OIDC, workload identity), connectors and credentials,
                     capability pack setup, approvers (passkeys, paired apps), drafters, the demo's tools, evals
packages/connectors  GitHub (token or GitHub App), Cloudflare (Pages, DNS, just-in-time tokens), Slack
packages/interop     other permission systems: an organization's policy by group, SCIM, OIDC and SAML groups,
                     Cloudflare Access identity, OAuth scopes, rich authorization requests (RFC 9396), UCAN
packages/design      okayed's design system: tokens, the latest shadcn components, AI Elements for chat, and
                     okayed's approval card, receipts, rule tiles and Shortcuts-style editor, also served as a
                     shadcn registry (docs/design-system.md)
packages/client      a dependency-free client for agents: ask, wait, merge
apps/worker          Cloudflare: OkayedAgent (Durable Object per user), OkayedChat (AIChatAgent), OkayedMcp
                     (remote MCP over OAuth), OkayedDirectory (SCIM), the Workflow, Workers AI, Access, Queues,
                     the API and the site
apps/web             the demo (Chat, Rules, Activity, Settings), React on @okayed/design, and /r/ (the registry)
apps/playground      at /playground: ask your rules, build one, see every component configuration, and watch words
                     narrow into a grant; the engine in the browser
apps/node            the same API on Node: SQLite, in-process timers, no build step
apps/mcp             MCP server so any MCP agent asks okayed before acting
docs/                design notes, grant format, design system, Cloudflare architecture, other permission
                     systems
scripts/             smoke.mjs (API end to end), mcp-remote.mjs (OAuth and MCP), e2e-web.mjs (the demo in a browser)
```
