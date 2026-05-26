{ flake, pkgs, ... }:
{

  system.activationScripts.syncEfiMirror = {
    text = ''
      # Verify mount point exists before syncing to prevent accidental deletion
      if mountpoint -q /efi1; then
        echo "Updating secondary EFI partition (/efi1)..."
        ${pkgs.rsync}/bin/rsync -a --delete /efi/ /efi1/
      else
        echo "Warning: /efi1 is not mounted, skipping EFI sync." >&2
      fi
    '';
  };
}
