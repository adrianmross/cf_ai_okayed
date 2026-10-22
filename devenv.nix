# Node 22 and pnpm 10 for the workspace; wrangler comes from apps/worker's devDependencies.
# Secrets are declared in secretspec.toml and injected per command, never written to .dev.vars.
{ pkgs, ... }:
{
  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_22;
    pnpm.enable = true;
  };
  packages = with pkgs; [ git secretspec ];

  scripts.dev-local.exec = ''scripts/with-secrets.sh pnpm dev:local "$@"'';
  scripts.dev-worker.exec = ''scripts/with-secrets.sh pnpm dev:worker "$@"'';
  scripts.deploy-worker.exec = ''secretspec run -- pnpm --filter @okayed/worker run deploy "$@"'';

  enterShell = ''
    echo "okayed: node $(node --version), pnpm $(pnpm --version)"
  '';
}
