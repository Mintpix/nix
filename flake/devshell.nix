{ inputs, ... }:
{
  perSystem = { pkgs, ... }: {
    formatter = pkgs.nixpkgs-fmt;

    devShells.default = pkgs.mkShell {
      name = "nic-shell";
      meta.description = "Shell environment for modifying this Nix configuration";
      packages = with pkgs; [
        just
        nixd
        sops
        ssh-to-age
        jq
      ];
    };
  };
}
