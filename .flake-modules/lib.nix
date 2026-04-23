{ nixpkgs, home-manager, homeModule, nixosModule }:
let
  defaultSystem = "x86_64-linux";
in
{
  mkHomeConfiguration = {
    system ? defaultSystem,
    username,
    homeDirectory,
    stateVersion,
    mutable ? false,
    localPath ? "",
    extraModules ? [ ],
  }:
    home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      modules = [
        homeModule
        {
          dotfiles = {
            enable = true;
            inherit username homeDirectory mutable localPath;
          };

          home.stateVersion = stateVersion;
        }
      ] ++ extraModules;
    };

  mkNixosConfiguration = {
    system ? defaultSystem,
    hostname,
    username,
    homeDirectory ? null,
    stateVersion,
    nixosStateVersion ? stateVersion,
    mutable ? false,
    localPath ? "",
    user ? { },
    extraModules ? [ ],
  }:
    let
      effectiveHomeDirectory =
        if homeDirectory != null then homeDirectory
        else if user ? home then user.home
        else "/home/${username}";
    in
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        nixosModule
        ({ ... }: {
          networking.hostName = hostname;
          system.stateVersion = nixosStateVersion;

          users.users.${username} = {
            isNormalUser = true;
            home = effectiveHomeDirectory;
            extraGroups = [ "wheel" ];
          } // user;

          dotfiles = {
            enable = true;
            username = username;
            homeDirectory = effectiveHomeDirectory;
            inherit stateVersion mutable localPath;
          };
        })
      ] ++ extraModules;
    };
}
