#!/usr/bin/env bash
# Deploy NixOS configurations: build, push to Cachix, activate, rollback.
#
# Usage:
#   deploy.sh                          # current host (by hostname)
#   deploy.sh <host> [host...] [flags] # deploy one or more hosts
#   deploy.sh arm [flags]              # all ARM hosts (parallel)
#   deploy.sh x86 [flags]              # all x86 hosts (parallel)
#   deploy.sh arm MskNAS [flags]       # ARM hosts + MskNAS (parallel)
#
# Flags:
#   --build          only build closures locally, don't activate
#   --push           build + push closures to Cachix, don't activate
#   --local          local build, push closure via SSH, then activate
#   --rollback       rollback to previous generation (no build/activate)
#   --auto-rollback  activate, auto-rollback failed hosts on failure
#   --dry-run        don't actually activate (only affects activation)
#   --user <u>       SSH user for remote hosts (default: from ~/.ssh/config)
#   --help           show this help message
#
# Stages (when --build/--push present, no activation):
#   1. --build:  nix build --print-out-paths (local)
#   2. --push:   nix build + cachix push (local)
#   3. activate: remote build (from Cachix) + switch (default, no flags)
#
# Arch keywords (arm/x86) auto-expand by scanning hardware imports in hosts/*.nix.
# Hosts without hardware imports (box, nixwsl) are excluded from arch groups.
# Local detection: if <host> == $(hostname), always local nixos-rebuild.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
FLAKE="$SCRIPT_DIR"
HOSTNAME=$(hostname)
CACHIX_NAME="mp"

# --- Help ---
print_help() {
  sed -n '2,/^set /p' "$0" | sed 's/^# \?//' | sed '/^set /d' >&2
  exit 0
}

# --- Parse arguments ---
do_build=false
do_push=false
local_build=false
do_rollback=false
auto_rollback=false
dry_run=false
ssh_user=""
raw_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build)         do_build=true; shift ;;
    --push)          do_push=true; shift ;;
    --local)         local_build=true; shift ;;
    --rollback)      do_rollback=true; shift ;;
    --auto-rollback) auto_rollback=true; shift ;;
    --dry-run)       dry_run=true; shift ;;
    --user)          ssh_user="$2"; shift 2 ;;
    --help|-h)       print_help ;;
    -*) echo "Unknown flag: $1" >&2; exit 1 ;;
    *)  raw_args+=("$1"); shift ;;
  esac
done

# No args → deploy current host
if [[ ${#raw_args[@]} -eq 0 ]]; then
  raw_args=("$HOSTNAME")
fi

# --- Expand arch keywords ---
expand_arch() {
  local pattern="$1"
  # Scan hosts/*.nix (not hardware/ subdir) for hardware imports matching pattern.
  # Returns space-separated hostnames (basename without .nix).
  local files
  files=$(grep -l "$pattern" "$SCRIPT_DIR"/hosts/*.nix 2>/dev/null || true)
  for f in $files; do
    basename "$f" .nix
  done
}

hosts=()
for arg in "${raw_args[@]}"; do
  case "$arg" in
    arm) hosts+=($(expand_arch 'arm-')) ;;
    x86) hosts+=($(expand_arch 'x86-')) ;;
    *)   hosts+=("$arg") ;;
  esac
done

# --- Deduplicate (preserve order) ---
declare -A seen=()
unique_hosts=()
for h in "${hosts[@]}"; do
  if [[ -z "${seen[$h]:-}" ]]; then
    seen[$h]=1
    unique_hosts+=("$h")
  fi
done

# --- Pre-flight check ---
if [[ ! -f "$FLAKE/flake.nix" ]]; then
  echo "Error: flake.nix not found at $FLAKE" >&2
  exit 1
fi

# --- Determine nixos-rebuild action ---
if $dry_run; then
  action="dry-run"
else
  action="switch"
fi

# --- Determine mode ---
# --build/--push: only build/push, don't activate
# --rollback: only rollback, don't build/activate
# --auto-rollback: activate + auto-rollback on failure
# default: remote build + activate
# --local: local build + SSH copy closure + activate
only_build=false
if $do_build || $do_push; then
  only_build=true
fi

# --- Validate flag combinations ---
if $do_rollback && $auto_rollback; then
  echo "Error: --rollback and --auto-rollback are mutually exclusive" >&2
  exit 1
fi
if $do_rollback && $only_build; then
  echo "Error: --rollback cannot be combined with --build/--push" >&2
  exit 1
fi
if $auto_rollback && $only_build; then
  echo "Error: --auto-rollback cannot be combined with --build/--push" >&2
  exit 1
fi
if $local_build && $only_build; then
  echo "Error: --local cannot be combined with --build/--push" >&2
  exit 1
fi

# --- Check cachix for --push ---
if $do_push; then
  if ! command -v cachix >/dev/null 2>&1; then
    echo "Error: cachix not found in PATH. Install with: nix profile install nixpkgs#cachix" >&2
    exit 1
  fi
  if [[ -z "${CACHIX_AUTH_TOKEN:-}" ]]; then
    echo "Error: CACHIX_AUTH_TOKEN environment variable not set" >&2
    exit 1
  fi
fi

# --- Build closure for a single host (returns store path on stdout) ---
build_one() {
  local host="$1"
  local prefix="$2"
  echo "${prefix}Building $host..."
  nix build "$FLAKE#nixosConfigurations.$host.config.system.build.toplevel" \
    --no-link --print-out-paths 2>&1
}

# --- Push closures to Cachix ---
push_closures() {
  local -a paths=()
  local host prefix

  # Collect all store paths (build if needed, --print-out-paths is fast if cached)
  for host in "${unique_hosts[@]}"; do
    prefix="[$host] "
    echo "${prefix}Resolving closure..."
    local path
    path=$(nix build "$FLAKE#nixosConfigurations.$host.config.system.build.toplevel" \
      --no-link --print-out-paths 2>/dev/null) || {
      echo "${prefix}Error: failed to resolve closure" >&2
      return 1
    }
    paths+=("$path")
  done

  echo "Pushing ${#paths[@]} closure(s) to Cachix ($CACHIX_NAME)..."
  cachix push "$CACHIX_NAME" "${paths[@]}"
}

# --- Rollback a single host ---
rollback_one() {
  local host="$1"
  local prefix="$2"

  if [[ "$host" == "$HOSTNAME" ]]; then
    echo "${prefix}Rolling back $host (local)..."
    sudo nixos-rebuild switch --rollback 2>&1
  else
    local target="$host"
    if [[ -n "$ssh_user" ]]; then
      target="$ssh_user@$host"
    fi
    echo "${prefix}Rolling back $host..."
    ssh "$target" 'nixos-rebuild switch --rollback' 2>&1
  fi
}

# --- Deploy (activate) a single host ---
deploy_one() {
  local host="$1"
  local prefix="$2"

  if [[ "$host" == "$HOSTNAME" ]]; then
    # Local: ignore --local flag, just sudo nixos-rebuild
    echo "${prefix}Deploying $host (local)..."
    sudo nixos-rebuild "$action" --flake "$FLAKE#$host" 2>&1
  else
    # Remote: prefix user@ if --user is set
    local target="$host"
    local build="$host"
    if [[ -n "$ssh_user" ]]; then
      target="$ssh_user@$host"
      build="$ssh_user@$host"
    fi
    if $local_build; then
      # Local build, push closure: no --build-host (default = local),
      # nixos-rebuild builds locally then copies closure to target.
      echo "${prefix}Deploying $host (local build → push closure)..."
      nixos-rebuild "$action" --flake "$FLAKE#$host" \
        --target-host "$target" --sudo 2>&1
    else
      # Remote build: copy flake, remote evaluates + builds + activates.
      # When closures are in Cachix, remote substitutes instead of building.
      echo "${prefix}Deploying $host (remote build)..."
      nixos-rebuild "$action" --flake "$FLAKE#$host" \
        --target-host "$target" --sudo --build-host "$build" 2>&1
    fi
  fi
}

# --- Run a function on all hosts in parallel, collect results ---
run_parallel() {
  local func="$1"

  if [[ ${#unique_hosts[@]} -eq 1 ]]; then
    # Single host: no prefix, direct output
    if $func "${unique_hosts[0]}" ""; then
      succeeded+=("${unique_hosts[0]}")
    else
      failed+=("${unique_hosts[0]}")
    fi
    return
  fi

  # Multiple hosts: parallel with [host] prefix
  declare -A pids=()

  for host in "${unique_hosts[@]}"; do
    prefix="[$host] "
    $func "$host" "$prefix" &
    pids[$host]=$!
  done

  # Wait for all
  for host in "${unique_hosts[@]}"; do
    if wait "${pids[$host]}" 2>/dev/null; then
      succeeded+=("$host")
    else
      failed+=("$host")
    fi
  done
}

# --- Summary ---
print_summary() {
  echo ""
  echo "=== Deploy Summary ==="
  if [[ ${#succeeded[@]} -gt 0 ]]; then
    echo "✓ ${succeeded[*]}"
  fi
  if [[ ${#failed[@]} -gt 0 ]]; then
    echo "✗ ${failed[*]}"
  fi
}

# --- Main execution ---
succeeded=()
failed=()

if $do_rollback; then
  # --- Rollback mode ---
  run_parallel rollback_one
  print_summary
  [[ ${#failed[@]} -eq 0 ]]
  exit $?
fi

if $only_build; then
  # --- Build/Push mode (no activation) ---
  if $do_build; then
    run_parallel build_one
  fi
  if $do_push; then
    # --push already includes build, so if --build was also done, just push
    if $do_build; then
      # Build already done, collect paths and push
      push_closures || { echo "Push failed" >&2; exit 1; }
    else
      # --push alone: build + push
      run_parallel build_one
      push_closures || { echo "Push failed" >&2; exit 1; }
    fi
  fi
  print_summary
  [[ ${#failed[@]} -eq 0 ]]
  exit $?
fi

# --- Activate mode (default, --local, or --auto-rollback) ---
run_parallel deploy_one

# Auto-rollback failed hosts
if $auto_rollback && [[ ${#failed[@]} -gt 0 ]]; then
  echo ""
  echo "=== Auto-rollback failed hosts: ${failed[*]} ==="
  # Save original results
  orig_failed=("${failed[@]}")
  # Reset for rollback phase
  succeeded=()
  failed=()
  # Only rollback the failed hosts
  unique_hosts=("${orig_failed[@]}")
  run_parallel rollback_one
  echo ""
  echo "=== Rollback Summary ==="
  if [[ ${#succeeded[@]} -gt 0 ]]; then
    echo "✓ rolled back: ${succeeded[*]}"
  fi
  if [[ ${#failed[@]} -gt 0 ]]; then
    echo "✗ rollback failed: ${failed[*]}"
  fi
  # Report original activation failures as failed
  failed=("${orig_failed[@]}")
fi

print_summary
[[ ${#failed[@]} -eq 0 ]]
