{ pkgs, exampleHomeConfiguration }:
let
  validateFishConfig = pkgs.writeShellApplication {
    name = "validate-fish-config";
    runtimeInputs = [ pkgs.fish pkgs.findutils ];
    text = builtins.replaceStrings
      [ "@exampleHomeConfigurationActivationPackage@" ]
      [ (toString exampleHomeConfiguration.activationPackage) ]
      (builtins.readFile ./validations/validate-fish-config.sh);
  };

  validateNeovimConfig = pkgs.writeShellApplication {
    name = "validate-neovim-config";
    runtimeInputs = [ pkgs.findutils pkgs.lua pkgs.neovim ];
    text = builtins.readFile ./validations/validate-neovim-config.sh;
  };

  validateOhMyPoshConfig = pkgs.writeShellApplication {
    name = "validate-oh-my-posh-config";
    runtimeInputs = [ pkgs.oh-my-posh ];
    text = builtins.readFile ./validations/validate-oh-my-posh-config.sh;
  };

  validateKittyConfig = pkgs.writeShellApplication {
    name = "validate-kitty-config";
    runtimeInputs = [ pkgs.kitty pkgs.python3 ];
    text = builtins.readFile ./validations/validate-kitty-config.sh;
  };

  validatePwshConfig = pkgs.writeShellApplication {
    name = "validate-pwsh-config";
    runtimeInputs = [ pkgs.gnugrep pkgs.powershell ];
    text = builtins.readFile ./validations/validate-pwsh-config.sh;
  };

  validateSetupScript = pkgs.writeShellApplication {
    name = "validate-setup-script";
    runtimeInputs = [ pkgs.bash pkgs.coreutils pkgs.findutils ];
    text = builtins.readFile ./validations/validate-setup-script.sh;
  };

  validateInstallScript = pkgs.writeShellApplication {
    name = "validate-install-script";
    runtimeInputs = [ pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.nix pkgs.util-linux ];
    text = builtins.readFile ./validations/validate-install-script.sh;
  };

  validateDotfilesConfig = pkgs.writeShellApplication {
    name = "validate-dotfiles-config";
    runtimeInputs = [
      validateFishConfig
      validateInstallScript
      validateNeovimConfig
      validateOhMyPoshConfig
      validateKittyConfig
      validatePwshConfig
      validateSetupScript
    ];
    text = builtins.readFile ./validations/validate-dotfiles-config.sh;
  };

  # Subset of validators that do not require network access or impure Nix
  # evaluation, so they can run inside a standard Nix build sandbox as a
  # flake check. validate-install-script is intentionally excluded because it
  # invokes `nix` with --impure and uses util-linux `script` to drive a PTY.
  validateConfigLints = pkgs.writeShellApplication {
    name = "validate-config-lints";
    runtimeInputs = [
      validateFishConfig
      validateKittyConfig
      validateNeovimConfig
      validateOhMyPoshConfig
      validatePwshConfig
      validateSetupScript
    ];
    text = ''
      validate-fish-config
      validate-neovim-config
      validate-oh-my-posh-config
      validate-kitty-config
      validate-pwsh-config
      validate-setup-script
    '';
  };
in
{
  validationPackages = {
    inherit
      validateConfigLints
      validateDotfilesConfig
      validateFishConfig
      validateInstallScript
      validateKittyConfig
      validateNeovimConfig
      validateOhMyPoshConfig
      validatePwshConfig
      validateSetupScript
      ;
  };
}
