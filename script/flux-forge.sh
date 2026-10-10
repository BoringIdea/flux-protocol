#!/usr/bin/env bash
# Flux Protocol — forge wrapper with --network monad|bsc|hyperliquid|local
# Examples:
#   ./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network monad --broadcast
#   ./script/flux-forge.sh script script/AuctionActions.s.sol:BidAuction --network bsc --broadcast
#   ./script/flux-forge.sh cast balance 0x... --network hyperliquid
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

NETWORK="${FLUX_NETWORK:-${DEPLOY_CHAIN:-monad}}"
FORGE_ARGS=()
EXTRA_BROADCAST=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --network)
      NETWORK="$2"
      shift 2
      ;;
    *)
      FORGE_ARGS+=("$1")
      shift
      ;;
  esac
done

case "$NETWORK" in
  monad | monad_testnet) RPC_ALIAS="monad" ;;
  bsc | bsc_testnet) RPC_ALIAS="bsc" EXTRA_BROADCAST=(--legacy) ;;
  hyperliquid | hyperliquid_testnet | hyperevm) RPC_ALIAS="hyperliquid" ;;
  local | anvil) RPC_ALIAS="local" ;;
  *)
    echo "Unknown --network '$NETWORK'. Use monad | bsc | hyperliquid | local (see config/networks.json)." >&2
    exit 1
    ;;
esac

# Apply chain-specific broadcast flags only when broadcasting
if printf '%s\n' "${FORGE_ARGS[@]}" | grep -qx -- '--broadcast'; then
  FORGE_ARGS+=("${EXTRA_BROADCAST[@]}")
fi

exec forge "${FORGE_ARGS[@]}" --rpc-url "$RPC_ALIAS"
