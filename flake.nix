{
  description = "Personal dotfiles";

  outputs = { self }: {
    homeManagerModules.default = { lib, ... }:
      let
        # Recursively build xdg.configFile entries for every regular file under `dir`.
        configFilesFrom = dir: prefix:
          let entries = builtins.readDir dir;
          in lib.foldl' (acc: name:
            let type = entries.${name};
            in if type == "regular"
               then acc // { "${prefix}${name}".source = "${dir}/${name}"; }
               else if type == "directory"
               then acc // (configFilesFrom "${dir}/${name}" "${prefix}${name}/")
               else acc
          ) { } (builtins.attrNames entries);
      in
      {
        xdg.configFile =
          configFilesFrom "${self}/.config/git"        "git/"        //
          configFilesFrom "${self}/.config/fish"       "fish/"       //
          configFilesFrom "${self}/.config/oh-my-posh" "oh-my-posh/" //
          configFilesFrom "${self}/.config/nvim"       "nvim/";
      };
  };
}
