{ ... }:

{
  # herdr has no home-manager module, so the config file is written directly
  # (same approach as zellij.nix). The package itself lives in
  # modules/home/default.nix.
  xdg.configFile."herdr/config.toml".text = ''
    # herdr configuration

    [keys]
    # herdr defaults to tmux-style prefix bindings (ctrl+b). The bindings below
    # are direct shortcuts instead -- they need no prefix -- so pane and tab
    # movement matches the zellij keybinds in zellij.nix.
    #
    # herdr accepts only one key per action, unlike zellij where several chords
    # can share an action. Where zellij binds three chords to a tab switch, the
    # ctrl+alt variant is kept here as the most portable of the three.
    #
    # Note: upstream warns that alt+<punctuation> and cmd/super chords depend on
    # the host terminal emitting them, so these may need swapping for ctrl+letter
    # chords if the terminal swallows them.

    # Pane focus -- mirrors zellij's "Alt [" / "Alt ]".
    focus_pane_left = "alt+["
    focus_pane_right = "alt+]"

    # Tab switching -- zellij binds Super/Ctrl/Alt-Shift variants; ctrl+alt is
    # the one kept here.
    previous_tab = "ctrl+alt+["
    next_tab = "ctrl+alt+]"
  '';
}
