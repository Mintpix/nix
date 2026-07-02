{ ... }:

{
  services.apcupsd = {
    enable = true;
    configText = ''
      UPSNAME TGBOX
      UPSCABLE usb
      UPSTYPE usb

      MINUTES 5
      BATTERYLEVEL 5
      TIMEOUT 600
    '';
  };
}
