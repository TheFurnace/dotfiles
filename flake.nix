{
  description = "Personal dotfiles";

  outputs = { self }: {
    homeManagerModules.default = { ... }: {
      # ── oh-my-posh theme ───────────────────────────────────────────────────
      programs.oh-my-posh.settings = builtins.fromJSON (
        builtins.readFile "${self}/.config/oh-my-posh/themes/lambda.omp.json"
      );

      # ── Git ────────────────────────────────────────────────────────────────
      programs.git.includes = [{ path = "${self}/.config/git/config"; }];

      # ── Fish functions ─────────────────────────────────────────────────────
      xdg.configFile."fish/functions/bwrap-clean.fish".source =
        "${self}/.config/fish/functions/bwrap-clean.fish";
      xdg.configFile."fish/functions/config.fish".source =
        "${self}/.config/fish/functions/config.fish";

      # ── Neovim ────────────────────────────────────────────────────────────
      xdg.configFile."nvim".source = "${self}/.config/nvim";
    };
  };
}
