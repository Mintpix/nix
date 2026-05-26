# Sops templates for user-related secrets (p10k URL)
# Only imported on servers, not WSL
{ config, ... }:
{
  # p10k URL — readable by mp for shell.nix (raw secret is root-only 0400)
  sops.templates."p10k-url" = {
    content = config.sops.placeholder."p10k-url";
    path = "/run/secrets/p10k-url";
    mode = "0644";
  };
}
