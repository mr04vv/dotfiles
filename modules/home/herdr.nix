{ ... }:

{
  # herdr has no home-manager module, so the config file is written directly
  # (same approach as zellij.nix). The package itself lives in
  # modules/home/default.nix.
  xdg.configFile."herdr/config.toml".text = ''
    # herdr configuration

    [theme]
    # catppuccin is herdr's default base; every token that matters for contrast
    # is overridden below, so the base only supplies the few tokens herdr does
    # not expose in [theme.custom].
    name = "catppuccin"

    # The palette is matched to Ghostty's "Desert" theme (set in ghostty.nix) so
    # herdr's chrome sits on the same sand/khaki scale as the panes it wraps.
    #
    # The reason for overriding at all: catppuccin's stock surface0/surface1 sit
    # only a few shades off panel_bg, which made the selected sidebar row
    # effectively invisible. surface1 is the selected-row background, so it is
    # pushed to a clearly lighter khaki that reads at a glance.
    [theme.custom]
    panel_bg = "#2b2b2b"    # sidebar background, one step darker than Desert's #333333
    surface0 = "#4a4336"    # unselected hover / separators
    surface1 = "#7a6a3f"    # selected row background -- the main contrast fix
    surface_dim = "#3a3a3a"
    overlay0 = "#8a8a8a"    # borders
    overlay1 = "#b0a48c"
    text = "#ffffff"        # Desert foreground
    subtext0 = "#c9bfa8"

    # Accent and the named colors track the Desert palette entries.
    accent = "#f0e68c"      # Desert palette 3 (khaki)
    yellow = "#f0e68c"
    green = "#98fb98"       # Desert palette 2
    red = "#ff5555"         # Desert palette 9
    blue = "#87ceff"        # Desert palette 12
    teal = "#ffd700"        # Desert palette 14
    peach = "#cd853f"       # Desert palette 4
    mauve = "#ffdead"       # Desert palette 5

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

    # Prefix for the actions left at their defaults. ctrl+p shadows "previous
    # history entry" in zsh and completion-cycling in Neovim for panes herdr
    # captures the key from, which is accepted here in exchange for keeping the
    # prefix off ctrl+b.
    prefix = "ctrl+p"

    # Pane focus -- option+arrow, matching zellij's "Alt <arrow>" binds. Since
    # herdr takes a single key per action, the arrows replace zellij's
    # "Alt [" / "Alt ]" pair rather than sitting alongside it.
    focus_pane_left = "alt+left"
    focus_pane_right = "alt+right"
    focus_pane_up = "alt+up"
    focus_pane_down = "alt+down"

    # Tab switching -- zellij binds Super/Ctrl/Alt-Shift variants; ctrl+alt is
    # the one kept here.
    previous_tab = "ctrl+alt+["
    next_tab = "ctrl+alt+]"

    # Workspace switching on cmd+option+[]. These are unset by default; the
    # bracket pair mirrors the tab binds one modifier up.
    previous_workspace = "cmd+alt+["
    next_workspace = "cmd+alt+]"

    # The remaining actions follow zellij's pane/tab mode letters, so the muscle
    # memory carries over: what zellij reaches as "Ctrl p" then a letter is
    # "prefix" then the same letter here.
    #
    # zellij pane mode: n=new, x=close, f=fullscreen, r=right split, d=down
    # split, c=rename. herdr has no generic "new pane", so n is left out and the
    # two split actions cover it.
    zoom = "prefix+f"           # zellij fullscreen; herdr default was prefix+z
    split_vertical = "prefix+r"   # zellij "split right"
    split_horizontal = "prefix+d" # zellij "split down"
    close_pane = "prefix+x"
    rename_pane = "prefix+c"

    # zellij tab mode: n=new, x=close, r=rename. herdr's defaults put new_tab on
    # prefix+c, which collides with rename_pane above, so tabs move to the
    # shifted variants and keep the same letters.
    new_tab = "prefix+shift+n"
    close_tab = "prefix+shift+x"
    rename_tab = "prefix+shift+t"

    # prefix+shift+n is new_tab above, which is herdr's default for
    # new_workspace, so that action is moved here to keep it reachable. herdr
    # silently disables the losing action on a duplicate, so it needs a key of
    # its own rather than being left to collide.
    new_workspace = "prefix+shift+c"

    # split_vertical takes prefix+r, herdr's default for resize_mode, so resize
    # moves to the zellij letter for its own resize mode.
    resize_mode = "prefix+n"

    # zellij "Ctrl p" then w opens the tab/session switcher; herdr's equivalent
    # picker keeps the same letter.
    workspace_picker = "prefix+w"
  '';
}
