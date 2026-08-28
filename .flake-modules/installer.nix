# Builds the interactive `nix run` installer for all supported platforms.
{ nixpkgs, home-manager, self }:
let
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  mkApp = system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      hmPackage = home-manager.packages.${system}.home-manager;

      setupShellScript = import ./lib/setup-shell.nix {
        defaultUserExpr = "\${SUDO_USER:-}";
        defaultHomeExpr = "";
        sudoCommand = "sudo nix run \$DOTFILES_URL -- setup-shell";
        initSwitchCommand = "nix run \$DOTFILES_URL";
      };

      installer = pkgs.writeShellApplication {
        name = "install-dotfiles";
        # Keep the app independent of whatever happens to be installed on the
        # host. The integration runner starts it with an unusable inherited
        # PATH and therefore enforces this list as the executable contract.
        runtimeInputs = [
          pkgs.coreutils
          pkgs.diffutils
          pkgs.gawk
          pkgs.getent
          pkgs.git
          pkgs.gnugrep
          pkgs.gnused
          pkgs.nix
          hmPackage
        ];
        text = ''
          ${setupShellScript}
          export DOTFILES_INSTALLER_SYSTEM=${pkgs.lib.escapeShellArg system}
          ${builtins.readFile ./installer.sh}
        '';
      };
    in
    {
      type = "app";
      program = "${installer}/bin/install-dotfiles";
    };

  appsForSystem = system: { default = mkApp system; };
in
{
  apps = builtins.listToAttrs (map
    (system: { name = system; value = appsForSystem system; })
    systems);
}
