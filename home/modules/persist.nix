{ pkgs, ... }:
{
  home.persistence."/persist".directories = [
    ".vscode-server"
  ];

  # GC old vscode-server versions (keep only latest).
  systemd.user.timers.vscode-server-gc = {
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
  systemd.user.services.vscode-server-gc = {
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "vscode-server-gc" ''
        dir="$HOME/.vscode-server/bin"
        [ -d "$dir" ] || exit 0
        ls -1dt "$dir"/*/ 2>/dev/null | tail -n +2 | while read -r old; do
          rm -rf "$old"
        done
      ''}";
    };
  };
}
