# Like GNU `make`, but `just` rustier.
# https://just.systems/
# run `just` from this directory to see available commands

# Default command when 'just' is run without arguments
default:
  @just --list

# Update nix flake
[group('Main')]
update:
  nix flake update

# Lint nix files
[group('dev')]
lint:
  nix fmt

# Check nix flake
[group('dev')]
check:
  nix flake check

# Manually enter dev shell
[group('dev')]
dev:
  nix develop

# Decrypt secrets/*.yaml → secrets/*.decrypted.yaml
[group('secrets')]
d:
  @SOPS_AGE_KEY=$(ssh-to-age -private-key < ~/.ssh/id_ed25519) sh -c 'for f in secrets/*.yaml; do [ -e "$f" ] || continue; case "$f" in *.decrypted.yaml) continue ;; esac; out="${f%.yaml}.decrypted.yaml"; sops -d --input-type yaml --output-type yaml "$f" > "$out"; done'

# Encrypt secrets/*.decrypted.yaml → *.yaml, delete plaintext
[group('secrets')]
e:
  @SOPS_AGE_KEY=$(ssh-to-age -private-key < ~/.ssh/id_ed25519) sh -c 'for f in secrets/*.decrypted.yaml; do [ -e "$f" ] || continue; out="${f%.decrypted.yaml}.yaml"; if sops -e --input-type yaml --output-type yaml --output "$out" "$f"; then rm "$f"; else exit 1; fi; done'

# Decrypt secrets/*.md → root dir .md files
[group('secrets')]
dd:
  @SOPS_AGE_KEY=$(ssh-to-age -private-key < ~/.ssh/id_ed25519) sh -c 'for f in secrets/*.md; do [ -e "$f" ] || continue; name="${f##*/}"; sops -d --output "$name" "$f"; done'

# Encrypt root dir .md → secrets/*.md, delete plaintext, sync (remove stale secrets/*.md)
[group('secrets')]
ed:
  @SOPS_AGE_KEY=$(ssh-to-age -private-key < ~/.ssh/id_ed25519) sh -c 'files=$(for f in *.md; do [ -e "$f" ] && echo "$f"; done); for f in *.md; do [ -e "$f" ] || continue; cp "$f" "secrets/$f" && sops -e -i "secrets/$f" && rm "$f" || rm -f "secrets/$f"; done; [ -z "$files" ] || for f in secrets/*.md; do [ -e "$f" ] || continue; name="${f##*/}"; echo "$files" | grep -qx "$name" || rm -f "$f"; done'

# Deploy: just dp [hosts...] [flags]
#   just dp                  # current host (by hostname)
#   just dp <host>           # remote build (copy flake, fast)
#   just dp <host> --local   # local build, push closure via SSH
#   just dp <host> --build   # only build closure, don't activate
#   just dp <host> --push    # build + push closure to Cachix, don't activate
#   just dp <host> --build --push  # build + push to Cachix, don't activate
#   just dp <host> --rollback      # rollback to previous generation
#   just dp <host> --auto-rollback # activate, auto-rollback on failure
#   just dp arm              # parallel, all ARM hosts
#   just dp x86              # parallel, all x86 hosts
#   just dp arm MskNAS       # ARM hosts + MskNAS (parallel)
#   just dp <host> --dry-run # dry-run
#   just dp --help           # show full help
[group('Main')]
dp *args='':
  ./deploy.sh {{args}}

# Build a host closure without deploying
[group('dev')]
build host:
  nix build .#nixosConfigurations.{{host}}.config.system.build.toplevel

# Activate home-manager on non-NixOS hosts (Ubuntu/Arch/etc.)
#   just hm              # current user, plain profile
#   just hm mp-dev       # specific user-profile
#   just hm mp-server    # server profile
[group('Main')]
hm config='mp-plain':
  home-manager switch --flake .#{{config}}
