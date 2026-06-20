# Cachix binary cache — shared by all hosts.
# The CI runner builds closures locally and pushes them here, so remote
# hosts can pull pre-built artifacts instead of building on-device.
{ ... }:
{
  nix.settings = {
    substituters = [
      "https://mp.cachix.org"
    ];
    trusted-public-keys = [
      "mp.cachix.org-1:3Z/77e31DIAJpHEiVCPDPeXkaTZEqKimJlmLcnUwgOE="
    ];
  };
}
