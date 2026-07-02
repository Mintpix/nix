# x86 VPS hardware: shared base for sg (Hyper-V EFI) and la (QEMU BIOS).
#
# Common: disko, low-memory optimization, x86_64 platform.
# Each host imports this and adds its own disk-config + bootloader + drivers.
{ flake, lib, ... }:
{
  imports = [
    flake.inputs.disko.nixosModules.disko
  ];

  # 严格限制 nix 资源使用，防止 1G 小内存机器 OOM 卡死
  nix.settings = {
    max-jobs = 1;
    cores = 1;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
