# A module that automatically imports everything else in the parent folder.
# Also supports host-specific modules in subdirectories named after the hostname.
# Hostname is passed via home-manager.extraSpecialArgs from the NixOS configuration.
{ lib, hostname ? "", ... }:

let
  # Collect all .nix files in current directory (excluding default.nix and subdirectories)
  topLevelFiles = with builtins;
    let
      dirContents = readDir ./.;
      fileNames = attrNames dirContents;
      regularFiles = filter (fn: fn != "default.nix" && dirContents.${fn} == "regular" && lib.hasSuffix ".nix" fn) fileNames;
    in
    map (fn: ./${fn}) regularFiles;

  # Collect host-specific modules from subdirectory matching hostname
  hostSpecificFiles = with builtins;
    let
      hostDir = ./${hostname};
      dirExists = pathExists hostDir;
      dirContents = if dirExists then readDir hostDir else { };
      fileNames = attrNames dirContents;
      regularFiles = filter (fn: dirContents.${fn} == "regular" && lib.hasSuffix ".nix" fn) fileNames;
    in
    if dirExists && hostname != "" then map (fn: hostDir + "/${fn}") regularFiles else [ ];
in
{
  imports = topLevelFiles ++ hostSpecificFiles;
}
