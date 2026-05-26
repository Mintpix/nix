{ config, lib, pkgs, ... }:

{
  services.sanoid = {
    enable = true;

    templates.snap_style = {
      monthly = 2; # Keep 2 monthly snapshots
      yearly = 1;
      autosnap = true;
      autoprune = true;
    };

    datasets = {
      "rpool/nix" = { use_template = [ "snap_style" ]; };
      "rpool/home" = { use_template = [ "snap_style" ]; };
    };
  };
}
