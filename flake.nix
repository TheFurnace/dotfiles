{
  description = "Personal dotfiles";

  outputs = { self }:
    {
      homeManagerModules.default = { config, lib, ... }:
        let
          cfg = config.dotfiles;

          # Recursively walk self's .config/<relDir>, building xdg.configFile
          # entries. In mutable mode the source is a live symlink into
          # cfg.localPath; in immutable mode it is a plain store path.
          configFilesFrom = relDir: prefix:
            let
              entries = builtins.readDir "${self}/.config/${relDir}";
              sourceFor = name:
                if cfg.mutable
                then config.lib.file.mkOutOfStoreSymlink
                       "${cfg.localPath}/.config/${prefix}${name}"
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
          options.dotfiles = {

            mutable = lib.mkOption {
              type    = lib.types.bool;
              default = false;
              description = ''
                When false (default), config files are Nix store copies.
                A rebuild is required to pick up any change.

                When true, config files are live symlinks via mkOutOfStoreSymlink
                pointing into localPath. Edits to existing files take effect
                immediately (e.g. after `exec fish`); adding or removing files
                still requires a rebuild so the symlink set can be updated.
              '';
            };

            localPath = lib.mkOption {
              type    = lib.types.str;
              default = "";
              description = ''
                Absolute path to the local dotfiles checkout.
                Required (and only used) when mutable = true.
              '';
            };

          };

          config.xdg.configFile =
            configFilesFrom "git"        "git/"        //
            configFilesFrom "fish"       "fish/"       //
            configFilesFrom "oh-my-posh" "oh-my-posh/" //
            configFilesFrom "nvim"       "nvim/";
        };
    };
}
