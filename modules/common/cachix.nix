# CI pushes here; hosts pull pre-built closures.
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
