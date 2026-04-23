{ nixpkgs, home-manager, homeModule, nixosModule }:
let
  # Keep helper defaults centralized so exported constructors behave the same.
  defaultSystem = "x86_64-linux";
in
{
  # Build a standalone Home Manager configuration that turns the dotfiles
  # module on with a small amount of caller-provided identity data.
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
        # Compose the reusable module with the minimal option values that every
        # concrete Home Manager configuration must provide.
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

  # Build a NixOS system configuration that also provisions the target user's
  # Home Manager environment and fish login shell.
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
      # Keep the user's home path consistent across users.users and the nested
      # Home Manager configuration.
      effectiveHomeDirectory =
        if homeDirectory != null then homeDirectory
        else if user ? home then user.home
        else "/home/${username}";
    in
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        # Compose the reusable NixOS module with a small host-specific shim.
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
