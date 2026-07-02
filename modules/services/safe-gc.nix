# Safe garbage collection: keep only the last booted generation + the last
# successfully activated generation. Everything else is deleted.
#
# TODO: 待重构 — this module is complex and could be simplified.
#
# Two state files in /var/cache/safe-gc/:
# - last-booted:    store path of the last generation booted into
# - last-activated: store path of the last generation that activated successfully
#
# Cleanup runs:
#   - On activate (before switch-to-configuration copies .efi files)
#   - Monthly via systemd timer (automatic GC)
#
# /run is tmpfs (cleared each boot), so if the new config breaks startup,
# boot-successful never runs and old generations survive for bootloader rollback.
#
# Bootloader entries cleanup:
#   - systemd-boot: remove individual .conf files in /efi/loader/entries
#   - GRUB: regenerate grub.cfg via switch-to-configuration boot
{ lib, config, pkgs, ... }:
let
  stateDir = "/var/cache/safe-gc";
  bootedFile = "${stateDir}/last-booted";
  activatedFile = "${stateDir}/last-activated";
  nix = "${config.nix.package}/bin";

  # Shared cleanup script — called by both activation and timer.
  safeGcScript = pkgs.writeShellScript "safe-gc" ''
    set -euo pipefail

    booted=$([ -f ${bootedFile} ] && cat ${bootedFile} || true)
    activated=$([ -f ${activatedFile} ] && cat ${activatedFile} || true)
    newest=$(readlink -f /nix/var/nix/profiles/system 2>/dev/null || true)

    # Build keep list of generation numbers by matching store paths.
    # last-booted and last-activated are ALWAYS kept (rollback targets).
    keep=""
    shopt -s nullglob
    for link in /nix/var/nix/profiles/system-*-link; do
      gen=''${link#*-}; gen=''${gen%-link}
      path=$(readlink -f "$link")
      if { [ -n "$booted" ] && [ "$path" = "$booted" ]; } \
         || { [ -n "$activated" ] && [ "$path" = "$activated" ]; } \
         || [ "$path" = "$newest" ]; then
        keep="$keep $gen"
      fi
    done

    # Also preserve EFI entries for last-booted/last-activated even if
    # their generation links no longer exist.
    preserve_paths="$booted $activated"

    echo "safe-gc: keep=[$keep]"

    # Delete generations not in keep list.
    to_delete=""
    while IFS=' ' read -r gen rest; do
      [[ "$rest" == *"(current)"* ]] && continue
      case " $keep " in *" $gen "*) ;; *) to_delete="$to_delete $gen" ;; esac
    done < <(${nix}/nix-env --profile /nix/var/nix/profiles/system --list-generations)

    if [ -n "''${to_delete:-}" ]; then
      echo "safe-gc: deleting generations:$to_delete"
      ${nix}/nix-env --profile /nix/var/nix/profiles/system --delete-generations $to_delete
      ${nix}/nix-collect-garbage

      # Clean up EFI entries (only on systemd-boot machines with /efi).
      entries_dir="/efi/loader/entries"
      if [ -d "$entries_dir" ]; then
        for conf in "$entries_dir"/nixos-generation-*.conf; do
          [ -f "$conf" ] || continue
          gen=''${conf##*nixos-generation-}; gen=''${gen%.conf}
          # Skip if generation link still exists (not deleted).
          [ -e "/nix/var/nix/profiles/system-''${gen}-link" ] && continue
          # Check if this entry's store path is a preserve target.
          conf_path=$(${pkgs.gnugrep}/bin/grep -o 'init=[^ ]*' "$conf" 2>/dev/null | head -1 || true)
          conf_path=''${conf_path#init=}
          conf_path=''${conf_path%/init}
          skip=false
          for p in $preserve_paths; do
            [ "$conf_path" = "$p" ] && skip=true && break
          done
          if [ "$skip" = "true" ]; then
            echo "safe-gc: preserving bootloader entry (rollback target): $(basename "$conf")"
          else
            rm -f "$conf"; echo "safe-gc: removed bootloader entry: $(basename "$conf")"
          fi
        done
      fi

      # Regenerate GRUB config to remove entries for deleted generations.
      if [ -f /boot/grub/grub.cfg ]; then
        echo "safe-gc: regenerating GRUB config"
        /nix/var/nix/profiles/system/bin/switch-to-configuration boot || \
          echo "safe-gc: WARNING: failed to regenerate GRUB config"
      fi
    fi

    mkdir -p ${stateDir}
    echo "$newest" > ${activatedFile}
  '';
in
{
  options.safe-gc = {
    enable = lib.mkEnableOption "safe garbage collection (keep only booted + activated)";
  };

  config = lib.mkIf config.safe-gc.enable {
    nix.gc.automatic = lib.mkForce false;

    # On activate: run cleanup.
    system.activationScripts.safe-gc = {
      text = ''
        ${safeGcScript}
      '';
    };

    # Monthly automatic GC via timer.
    systemd.services.safe-gc = {
      description = "Safe garbage collection";
      serviceConfig = {
        Type = "oneshot";
      };
      path = [ pkgs.nix pkgs.gnugrep ];
      script = ''
        ${safeGcScript}
      '';
    };
    systemd.timers.safe-gc = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "monthly";
        Persistent = true;
      };
    };

    # On boot: record which generation was booted.
    systemd.services.boot-successful = {
      description = "Mark this boot as successful";
      after = [ "multi-user.target" ];
      wants = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        mkdir -p ${stateDir}
        echo "$(readlink -f /run/current-system)" > ${bootedFile}
      '';
    };
  };
}
