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

# Decrypt secrets/*.yaml using ~/.ssh/id_ed25519 (no temp key files)
[group('secrets')]
d:
  @SOPS_AGE_KEY=$(ssh-to-age -private-key < ~/.ssh/id_ed25519) sh -c 'for f in secrets/*.yaml; do [ -e "$f" ] || continue; case "$f" in *.decrypted.yaml) continue ;; esac; out="${f%.yaml}.decrypted.yaml"; sops -d --input-type yaml --output-type yaml "$f" > "$out"; done'

# Encrypt secrets/*.decrypted.yaml back and delete the decrypted files
[group('secrets')]
e:
  @SOPS_AGE_KEY=$(ssh-to-age -private-key < ~/.ssh/id_ed25519) sh -c 'for f in secrets/*.decrypted.yaml; do [ -e "$f" ] || continue; out="${f%.decrypted.yaml}.yaml"; if sops -e --input-type yaml --output-type yaml --output "$out" "$f"; then rm "$f"; else exit 1; fi; done'

# Activate the configuration
[group('Main')]
run:
  nix run

# Activate a host configuration (e.g. just ac MskNAS)
[group('Main')]
ac host:
  nix run .#activate {{host}}