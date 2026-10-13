#!/usr/bin/env bash
# Load test for Tycho testnet: deploys N wallets via WalletFactory and runs nekroddos `send` load.
#
#   ./run.sh            run natively (needs Node.js 18+, npm, git, Rust/cargo)
#   ./run.sh --docker   run inside a container (needs docker or podman only)
#
# Configuration lives in .env (created from .env.example on the first run).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

DEPLOYER="$ROOT/wallet-deployer"
NETWORK="tycho_testnet"
DEPLOYMENTS="$DEPLOYER/deployments/$NETWORK"
NEKRODDOS_DIR="$ROOT/.nekroddos"
NEKRODDOS_REPO="https://github.com/broxus/nekroddos.git"

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- docker mode
if [[ "${1:-}" == "--docker" ]]; then
  ENGINE="${DOCKER:-$(command -v docker || command -v podman || true)}"
  [[ -n "$ENGINE" ]] || die "docker or podman is required for --docker mode"
  [[ -f .env ]] || cp .env.example .env
  # shellcheck disable=SC1091
  set -a; source .env; set +a

  log "Building image (nekroddos ref: ${NEKRODDOS_REF:-master})"
  "$ENGINE" build -t tycho-testnet-wallets-test \
    --build-arg NEKRODDOS_REF="${NEKRODDOS_REF:-master}" \
    --build-arg CACHE_BUST="$(git ls-remote "$NEKRODDOS_REPO" "${NEKRODDOS_REF:-master}" 2>/dev/null | cut -c1-12 || date +%s)" \
    .

  log "Starting container"
  TTY_FLAGS=(-i); [[ -t 0 ]] && TTY_FLAGS=(-it)
  USER_FLAGS=(--user "$(id -u):$(id -g)")
  [[ "$(basename "$ENGINE")" == podman ]] && USER_FLAGS=(--userns=keep-id)
  exec "$ENGINE" run --rm "${TTY_FLAGS[@]}" "${USER_FLAGS[@]}" \
    -e HOME=/tmp -v "$ROOT:/work:Z" -w /work \
    tycho-testnet-wallets-test ./run.sh
fi

# ---------------------------------------------------------------- config
if [[ ! -f .env ]]; then
  cp .env.example .env
  log "Created .env from .env.example"
fi
# shellcheck disable=SC1091
set -a; source .env; set +a

: "${JRPC_ENDPOINT:=https://rpc-testnet.tychoprotocol.com/rpc}"
: "${WALLETS:=100}" "${BALANCE:=2}" "${RPS:=50}" "${ITERATIONS:=100}" "${NEKRODDOS_REF:=master}"
: "${LOAD_ENDPOINTS:=}" "${ENDPOINT_MODE:=rr}"
export JRPC_ENDPOINT WALLETS BALANCE

for tool in node npm; do
  command -v "$tool" >/dev/null || die "'$tool' is not installed (or use ./run.sh --docker)"
done
if [[ -z "${NEKRODDOS_BIN:-}" ]]; then
  command -v git >/dev/null || die "'git' is not installed (or use ./run.sh --docker)"
  command -v cargo >/dev/null || die "'cargo' is not installed, see https://rustup.rs (or use ./run.sh --docker)"
fi

# ---------------------------------------------------------------- npm deps
if [[ ! -d "$DEPLOYER/node_modules" ]]; then
  log "Installing npm dependencies"
  (cd "$DEPLOYER" && npm ci --no-audit --no-fund)
fi

# ---------------------------------------------------------------- seed phrase
if [[ -z "${PHRASE:-}" ]]; then
  PHRASE="$(cd "$DEPLOYER" && node -e "console.log(require('everscale-crypto').generateBip39Phrase(12))")"
  sed -i.bak "s/^PHRASE=.*/PHRASE=\"$PHRASE\"/" .env && rm -f .env.bak
  log "PHRASE was empty: generated a new seed phrase and saved it to .env (keep it safe)"
fi
export PHRASE
export BROXUS_PHRASE="$PHRASE" # name expected by nekroddos

WALLET_ADDRESS="$(cd "$DEPLOYER" && node --no-deprecation scripts/wallet.js address)"
export WALLET_ADDRESS
log "Your wallet: $WALLET_ADDRESS"

# ---------------------------------------------------------------- nekroddos
if [[ -z "${NEKRODDOS_BIN:-}" ]]; then
  log "Building nekroddos ($NEKRODDOS_REF)"
  if [[ ! -d "$NEKRODDOS_DIR/.git" ]]; then
    git clone "$NEKRODDOS_REPO" "$NEKRODDOS_DIR"
  fi
  git -C "$NEKRODDOS_DIR" fetch --quiet origin "$NEKRODDOS_REF"
  git -C "$NEKRODDOS_DIR" checkout --quiet --detach FETCH_HEAD
  (cd "$NEKRODDOS_DIR" && cargo build --release)
  NEKRODDOS_BIN="$NEKRODDOS_DIR/target/release/nekroddos"
fi

# ---------------------------------------------------------------- wallets
deployed_count="$(cat "$DEPLOYMENTS/.wallets" 2>/dev/null || echo 0)"
if [[ -f "$DEPLOYMENTS/Contract__factory.json" && "$deployed_count" -ge "$WALLETS" ]]; then
  log "Reusing $deployed_count wallets from a previous run (delete wallet-deployer/deployments to redeploy)"
else
  # Keep the previous deployment for reference instead of deleting it.
  [[ -d "$DEPLOYMENTS" ]] && mv "$DEPLOYMENTS" "$DEPLOYMENTS.$(date +%Y%m%d-%H%M%S)"
  # factory deploy (5) + wallets (BALANCE each) + gas (1 per wallet) + reserve
  REQUIRED=$(( WALLETS * (BALANCE + 1) + 10 ))
  log "Checking wallet balance (need $REQUIRED test tokens)"
  (cd "$DEPLOYER" && node --no-deprecation scripts/wallet.js wait "$REQUIRED")

  cd "$DEPLOYER"
  # Random nonce gives a fresh factory address on every deployment.
  log "Deploying WalletFactory"
  NONCE="$(date +%s)" npx locklift deploy --disable-build -n "$NETWORK"
  log "Deploying $WALLETS wallets with $BALANCE tokens each"
  npx locklift run --disable-build -n "$NETWORK" -s scripts/01_start.ts
  npx locklift run --disable-build -n "$NETWORK" -s scripts/02_stats.ts
  echo "$WALLETS" > "$DEPLOYMENTS/.wallets"
  cd "$ROOT"
fi

# ---------------------------------------------------------------- load
# nekroddos reads <project_root>/.env and <project_root>/deployments/<network>/
ln -sf ../.env "$DEPLOYER/.env"

# LOAD_ENDPOINTS: comma/space separated; a bare host or IP means http://<host>:8080/rpc
ENDPOINTS=()
for ep in ${LOAD_ENDPOINTS//,/ }; do
  [[ "$ep" == *://* ]] || ep="http://$ep:8080/rpc"
  ENDPOINTS+=("$ep")
done
[[ ${#ENDPOINTS[@]} -gt 0 ]] || ENDPOINTS=("$JRPC_ENDPOINT")
ENDPOINT_ARGS=()
for ep in "${ENDPOINTS[@]}"; do ENDPOINT_ARGS+=(--endpoints "$ep"); done

log "Starting load: $WALLETS wallets x $ITERATIONS transfers, $RPS tx/s"
echo "Endpoints ($ENDPOINT_MODE mode): ${ENDPOINTS[*]}"
export RUST_LOG="${RUST_LOG:-info}"
exec "$NEKRODDOS_BIN" \
  --project-root "$DEPLOYER" \
  "${ENDPOINT_ARGS[@]}" \
  --endpoint-mode "$ENDPOINT_MODE" \
  --network "$NETWORK" \
  send \
  --total-wallets "$WALLETS" \
  --rps "$RPS" \
  --num-iterations "$ITERATIONS"
