# Copilot CLI with BYOK env injection.
# Installed for all non-root discovered users. Requires /run/secrets/copilot-env
# (rendered by sops on the host, or bind-mounted into containers).
{ flake, pkgs, lib, config, ... }:
let
  unstablePkgs = import flake.inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config = { allowUnfree = true; };
  };
  envFile = "/run/secrets/copilot-env";
  copilotWrapper = pkgs.writeShellScriptBin "copilot" ''
    if [ -f "${envFile}" ]; then
      set -a
      source "${envFile}"
      set +a
    fi
    exec ${unstablePkgs.github-copilot-cli}/bin/copilot "$@"
  '';
  # All discovered users except root
  copilotUsers = builtins.filter (name: name != "root") config.discoveredUsers;
in
{
  home-manager.users = lib.genAttrs copilotUsers (_: {
    programs.github-copilot-cli = {
      enable = true;
      package = copilotWrapper;
      settings = {
        autoUpdate = false;
        model = "glm-5.2";
      };
    };
  });
}
