{ self }:
{ config, lib, ... }:
let
  cfg = config.dotfiles;

  # Recursively map files from this repo's .config tree into xdg.configFile.
  #
  # In immutable mode, sources come from the flake store path.
  # In mutable mode, sources become out-of-store symlinks into cfg.localPath so
  # edits to existing files are reflected immediately.
  configFilesFrom = relDir:
    let
      sourceDir = "${self}/.config" + lib.optionalString (relDir != "") "/${relDir}";
      entries = builtins.readDir sourceDir;
      destinationFor = name:
        if relDir == "" then name else "${relDir}/${name}";
      sourceFor = destination:
        if cfg.mutable
        then config.lib.file.mkOutOfStoreSymlink
          "${cfg.localPath}/.config/${destination}"
        else "${self}/.config/${destination}";
    in
    lib.foldl' (acc: name:
      let
        type = entries.${name};
        destination = destinationFor name;
      in
      if type == "regular"
      then acc // { "${destination}".source = sourceFor destination; }
      else if type == "directory"
      then acc // (configFilesFrom destination)
      # Ignore entries such as symlinks or special files. We only export the
      # regular files and directories that Home Manager can manage directly.
      else acc
    ) { } (builtins.attrNames entries);
in
{
  config = lib.mkIf cfg.enable {
    # Treat .config/ in this repo as the canonical source of truth for config
    # file contents. New files are discovered on the next evaluation.
    xdg.configFile = configFilesFrom "";
  };
}
