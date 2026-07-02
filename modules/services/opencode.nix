{ flake, pkgs, ... }:
let
  unstablePkgs = import flake.inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config = { allowUnfree = true; };
  };
in
{
  environment.systemPackages = [ unstablePkgs.opencode ];
}
