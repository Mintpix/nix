# Auto-declare sops secrets from secrets.yaml.
# Disabled on containers (boot.isContainer) — they get secrets bind-mounted.
{ flake, config, lib, options, ... }:

let
  secretsFile = flake.inputs.self + /secrets/secrets.yaml;

  # Auto-extract secret key names from sops YAML (keys are plaintext, values are ENC[...]).
  secretsYaml = builtins.readFile secretsFile;
  lines = lib.strings.splitString "\n" secretsYaml;

  extractKey = line:
    let m = builtins.match "([a-zA-Z0-9_-]+): ENC\\[AES256_GCM.*" line;
    in if m != null then builtins.head m else null;

  secretKeyNames = builtins.filter (x: x != null) (map extractKey lines);

  isPasswordHash = name: lib.strings.hasSuffix "-password-hash" name;

  enabled = !(config.boot.isContainer or false) && !(config.wsl.enable or false);
  sopsAvailable = options ? sops;
in
{
  config = lib.optionalAttrs sopsAvailable {
    sops.age = {
      # /etc/ssh/ssh_host_ed25519_key works in activation phase (after impermanence bind mount).
      # /persist/etc/ssh/ssh_host_ed25519_key works in initrd phase (neededForUsers),
      # because /persist is mounted early (neededForBoot = true) but /etc/ssh/ symlink
      # hasn't been created yet by impermanence.
      sshKeyPaths = lib.mkIf enabled [
        "/persist/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key"
      ];
      generateKey = false;
    };

    # All secrets auto-declared from secrets.yaml. Just add keys there.
    sops.secrets = lib.mkIf enabled (lib.genAttrs secretKeyNames (name: {
      sopsFile = secretsFile;
      neededForUsers = isPasswordHash name;
    }));
  };
}
