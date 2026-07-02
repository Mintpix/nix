# Sanoid: ZFS snapshot management for npool datasets (NAS only).
{ ... }:

{
  services.sanoid = {
    enable = true;

    templates.snap_style = {
      monthly = 2;
      yearly = 1;
      autosnap = true;
      autoprune = true;
    };

    datasets = {
      "npool/shared" = { use_template = [ "snap_style" ]; };
    };
  };
}
