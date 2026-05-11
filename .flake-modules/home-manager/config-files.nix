{ self }:
{ config, lib, ... }:
let
  cfg = config.dotfiles;

  # Recursively map files from this repo's .config tree into xdg.configFile.
  #
  # relDir tracks the source path below .config/ inside the flake.
  # prefix tracks the destination path below ~/.config/ for Home Manager.
  #
  # In immutable mode, sources come from the flake store path.
  # In mutable mode, sources become out-of-store symlinks into cfg.localPath so
  # edits to existing files are reflected immediately.
  configFilesFrom = relDir: prefix:
    let
      entries = builtins.readDir "${self}/.config/${relDir}";
      sourceFor = name:
        if cfg.mutable
        then config.lib.file.mkOutOfStoreSymlink
          "${cfg.localPath}/.config/${prefix}${name}"
        else "${self}/.config/${relDir}/${name}";
    in
    lib.foldl' (acc: name:
      let
        type = entries.${name};
      in
      if type == "regular"
      then acc // { "${prefix}${name}".source = sourceFor name; }
      else if type == "directory"
      then acc // (configFilesFrom "${relDir}/${name}" "${prefix}${name}/")
      # Ignore entries such as symlinks or special files. We only export the
      # regular files and directories that Home Manager can manage directly.
      else acc
    ) { } (builtins.attrNames entries);
in
{
  config = lib.mkIf cfg.enable {
    # Treat .config/ in this repo as the canonical source of truth for config
    # file contents. New files are discovered on the next evaluation.
    xdg.configFile =
      configFilesFrom "git" "git/" //
      configFilesFrom "kitty" "kitty/" //
      configFilesFrom "nvim" "nvim/" //
      configFilesFrom "oh-my-posh" "oh-my-posh/" //
      configFilesFrom "powershell" "powershell/";
  };
}
