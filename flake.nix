{
  description = "Personal dotfiles";

  outputs = { self }:
    let
      # Build a home-manager module that maps all files under
      # .config/{git,fish,oh-my-posh,nvim} to their xdg equivalents.
      #
      # mutable = false (homeManagerModules.default):
      #   Sources are nix store copies — immutable, lockable via flake.lock.
      #   A rebuild is required to pick up any change.
      #
      # mutable = true (homeManagerModules.mutable):
      #   Sources use mkOutOfStoreSymlink, pointing directly at the working
      #   dotfiles directory. Edits to existing files take effect after
      #   `exec fish` with no rebuild. Adding/removing files still needs one.
      mkDotfilesModule = mutable: { config, lib, ... }:
        let
          dotfilesDir = "/home/dev/.dotfiles";

          configFilesFrom = relDir: prefix:
            let
              entries = builtins.readDir "${self}/.config/${relDir}";
              sourceFor = name:
                if mutable
                then config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/.config/${prefix}${name}"
                else "${self}/.config/${relDir}/${name}";
            in lib.foldl' (acc: name:
              let type = entries.${name};
              in if type == "regular"
                 then acc // { "${prefix}${name}".source = sourceFor name; }
                 else if type == "directory"
                 then acc // (configFilesFrom "${relDir}/${name}" "${prefix}${name}/")
                 else acc
            ) { } (builtins.attrNames entries);
        in
        {
          xdg.configFile =
            configFilesFrom "git"        "git/"        //
            configFilesFrom "fish"       "fish/"       //
            configFilesFrom "oh-my-posh" "oh-my-posh/" //
            configFilesFrom "nvim"       "nvim/";
        };
    in
    {
      homeManagerModules.default = mkDotfilesModule false;
      homeManagerModules.mutable  = mkDotfilesModule true;
    };
}
