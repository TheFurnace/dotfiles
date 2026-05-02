{ self }:
{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles;

  gitCompletionPwshSrc = pkgs.fetchFromGitHub {
    owner = "kzrnm";
    repo = "git-completion-pwsh";
    rev = "v1.4.0";
    hash = "sha256-0wc4ae731oT59gyplEnw92a8Ce1GaxmE9zqn/x7TA2U=";
  };
in
{
  config = lib.mkIf cfg.enable {
    xdg.dataFile."powershell/Modules/git-completion" = {
      source = "${gitCompletionPwshSrc}/src";
      recursive = true;
    };
  };
}
