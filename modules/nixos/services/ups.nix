{ flake, pkgs, ... }:

{
  services.apcupsd = {
    enable = true;
    configText = ''
      UPSNAME TGBOX
      UPSCABLE usb
      UPSTYPE usb

      MINUTES 5       # Shutdown when battery runtime <= 5 minutes
      BATTERYLEVEL 5  # Shutdown when battery level < 5%
      TIMEOUT 600     # Wait 600s after power loss before shutdown (0 = disabled)
    '';
  };
}
