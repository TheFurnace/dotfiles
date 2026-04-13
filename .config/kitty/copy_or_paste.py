"""
Kitten: copy_or_paste
Windows Terminal-style right-click behaviour:
  - If text is selected → copy to clipboard and clear the selection.
    (Trailing-space stripping is handled by kitty via strip_trailing_spaces.)
  - If nothing is selected → paste from clipboard.
"""

from kittens.tui.handler import result_handler


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return
    if w.screen.has_selection():
        w.copy_to_clipboard()
        w.screen.clear_selection()
    else:
        boss.paste_from_clipboard()
