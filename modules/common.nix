# Base config for all hosts. Server profile: modules/server.nix. Home: home/*.
{ flake, pkgs, lib, config, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  profile = config.homeProfile;

  # Auto-discover users: scan home/users/*/ directories.
  # Each directory name is a username. If <user>/<profile>.nix exists,
  # auto-create the user and import its home-manager config.
  usersDir = self + /home/users;
  userDirs = builtins.attrNames (builtins.readDir usersDir);
  discoveredUsers = builtins.filter (name:
    builtins.pathExists (usersDir + "/${name}/${profile}.nix")
  ) userDirs;

  # Generate users.users entries: isNormalUser for non-root, nothing for root.
  mkUserEntry = name: {
    isNormalUser = name != "root";
  };

  # Generate home-manager.users entries with profile import.
  mkHomeEntry = name: {
    imports = [ (usersDir + "/${name}/${profile}.nix") ];
  };
in
{
  imports = [
    flake.inputs.home-manager.nixosModules.home-manager
    ./common/sops.nix
    ./common/user-config.nix
    ./common/cachix.nix
  ];

  options = {
    homeProfile = lib.mkOption {
      type = lib.types.str;
      default = "server";
      description = "Home-manager profile: determines which user modules to load from home/users/<user>/<profile>.nix";
    };

    # Exposed for other modules that need to iterate over discovered users.
    discoveredUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "List of usernames auto-discovered from home/users/*/ matching current homeProfile";
      default = discoveredUsers;
    };
  };

  config = {
    # home-manager shared config
    home-manager.extraSpecialArgs = {
      hostname = config.networking.hostName;
      inherit flake;
    };

    # Backup existing files on conflict instead of erroring
    home-manager.backupFileExtension = "backup";

    # Auto-wire: create users + home-manager from discovered user dirs
    users.users = lib.genAttrs discoveredUsers mkUserEntry;
    home-manager.users = lib.genAttrs discoveredUsers mkHomeEntry;

    programs.git.enable = true;
    programs.nix-ld.enable = true;
    programs.zsh.enable = true;

    time.timeZone = "Asia/Shanghai";
    i18n.defaultLocale = "en_US.UTF-8";
    environment.systemPackages = with pkgs; [ vim git wget curl util-linux ];

    nix.settings = {
      auto-optimise-store = false;
      experimental-features = [ "flakes" "nix-command" "ca-derivations" ];
      # Allow wheel users to push unsigned store paths (needed for deploy.sh --local)
      trusted-users = [ "root" "@wheel" ];
    };
    nix.optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };

    system.stateVersion = "25.11";
  };
}
