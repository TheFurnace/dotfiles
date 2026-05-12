: "${DOTFILES_REPO:?DOTFILES_REPO is not set. This should be set by the dotfiles dev shell.}"
kitty_bin="$(readlink -f "$(command -v kitty)")"
kitty_lib="$(dirname "$kitty_bin")/../lib/kitty"

python -m py_compile "$DOTFILES_REPO/.config/kitty/copy_or_paste.py"
PYTHONPATH="$kitty_lib${PYTHONPATH:+:$PYTHONPATH}" python - <<'PY'
import os
import sys
import kitty.config

bad_lines = []
kitty.config.load_config(
    os.path.join(os.environ["DOTFILES_REPO"], ".config/kitty/kitty.conf"),
    accumulate_bad_lines=bad_lines,
)

if bad_lines:
    for bad_line in bad_lines:
        print(bad_line, file=sys.stderr)
    raise SystemExit(1)
PY
