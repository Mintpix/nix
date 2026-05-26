{ flake, config, lib, ... }:

let
  secretsFile = flake.inputs.self + /secrets/secrets.yaml;

  # Dynamically extract secret key names from the encrypted YAML at eval time.
  # In a sops-encrypted YAML, key names are plaintext while values are ENC[AES256_GCM,...].
  # Pure Nix string parsing — no derivation needed, works on all architectures.
  secretsYaml = builtins.readFile secretsFile;
  lines = lib.strings.splitString "\n" secretsYaml;

  extractKey = line:
    let m = builtins.match "([a-zA-Z0-9_-]+): ENC\\[AES256_GCM.*" line;
    in if m != null then builtins.head m else null;

  secretKeyNames = builtins.filter (x: x != null) (map extractKey lines);

  # Convention: keys ending in "-password-hash" must be available during user creation
  isPasswordHash = name: lib.strings.hasSuffix "-password-hash" name;
in
{
  # sops-nix: decrypt secrets from /run/secrets/ at activation time
  # Each host uses its own SSH host ed25519 key for decryption
  sops.age = {
    sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    generateKey = false;
  };

  # Pure data pipeline — all secrets auto-declared from secrets.yaml.
  # To add a new secret: just add it to secrets/secrets.yaml.
  # Templates are declared in the modules that consume them, not here.
  sops.secrets = lib.genAttrs secretKeyNames (name: {
    sopsFile = secretsFile;
    neededForUsers = isPasswordHash name;
  });
}