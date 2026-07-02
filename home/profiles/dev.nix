# Dev profile: direnv + nix-index + nix (loaded on top of common.nix).
{ flake, ... }:
{
  imports = [
    (flake.inputs.self + /home/modules/direnv.nix)
    (flake.inputs.self + /home/modules/nix-index.nix)
    (flake.inputs.self + /home/modules/nix.nix)
  ];
}
