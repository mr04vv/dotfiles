{ config, lib, pkgs, ... }:

let
  # Own plugin, developed here and published separately:
  # https://github.com/mr04vv/herdr-pane-navigator
  paneNavigator = {
    source = "mr04vv/herdr-pane-navigator";
    # Pinned so a rebuild cannot silently pull a different version. Bump this
    # after tagging a release upstream.
    ref = "v0.1.4";
  };

  # Third-party plugin: renders a real Chromium view inside a Herdr pane and
  # drives it over CDP. https://github.com/ogulcancelik/herdr-browser
  # Requires the [experimental] kitty_graphics flag below, plus Bun and a
  # Chrome/Chromium binary at runtime (not managed here).
  herdrBrowser = {
    source = "ogulcancelik/herdr-browser";
    # Upstream publishes no release tags yet, so this pins the commit that was
    # vendored. Bump after verifying a newer HEAD upstream.
    ref = "be6888b71cf4eb5939ee79a746bd1a1c22ade046";
  };
in
{
  # herdr owns its plugin tree (it fetches, unpacks, and records plugins under
  # ~/.config/herdr/plugins), so nix cannot declare the installed state
  # directly. Installing is idempotent for an already-present ref, so this just
  # re-runs on activation; the guard keeps it quiet when herdr is absent.
  home.activation.herdrPaneNavigator = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x "${pkgs.herdr}/bin/herdr" ]; then
      ${pkgs.herdr}/bin/herdr plugin install ${paneNavigator.source} \
        --ref ${paneNavigator.ref} --yes >/dev/null 2>&1 || true
    fi
  '';

  # Same install-on-activation pattern as pane-navigator above: herdr owns the
  # plugin tree, install is idempotent for a present ref, and the guard keeps it
  # quiet when herdr is absent.
  home.activation.herdrBrowser = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x "${pkgs.herdr}/bin/herdr" ]; then
      ${pkgs.herdr}/bin/herdr plugin install ${herdrBrowser.source} \
        --ref ${herdrBrowser.ref} --yes >/dev/null 2>&1 || true
    fi
  '';

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

    # Agents step through the sidebar list in order -- herdr has no agent
    # equivalent of navigate_workspace_up/down, so cycling is the closest thing
    # to picking one off the list. Same bracket pair, third modifier.
    #
    # If the terminal sends the shifted glyph rather than shift+bracket, herdr
    # also accepts "alt+{" / "alt+}" for these.
    previous_agent = "alt+shift+["
    next_agent = "alt+shift+]"

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
    # shifted variants and keep the same letters. new_tab is the exception: both
    # prefix+n and prefix+shift+n go to workspace/resize below, so it sits on t
    # alongside rename_tab.
    new_tab = "prefix+t"
    close_tab = "prefix+shift+x"
    rename_tab = "prefix+shift+t"

    # herdr defaults new_workspace to prefix+shift+n; the unshifted letter is
    # used instead so it pairs with resize_mode below. herdr silently disables
    # the losing action on a duplicate, so every action needs a key of its own
    # rather than being left to collide.
    new_workspace = "prefix+n"

    # split_vertical takes prefix+r, herdr's default for resize_mode, so resize
    # moves to the shifted counterpart of new_workspace above.
    resize_mode = "prefix+shift+n"

    # zellij "Ctrl p" then w opens the tab/session switcher; herdr's equivalent
    # picker keeps the same letter.
    workspace_picker = "prefix+w"

    # Navigate mode (prefix+g / prefix+w) walks the workspace list with the arrow
    # keys by default. j/k are bound so the list is driven vi-style, matching the
    # j/k herdr already uses for navigate_pane_down/up. These are navigate-mode
    # local shortcuts and are independent from the focus_pane_* binds above.
    navigate_workspace_up = "k"
    navigate_workspace_down = "j"

    # Custom navigator from herdr/pane-navigator. The built-in one lists
    # workspace -> tab -> agent but never the pane's terminal title, which is
    # the only thing distinguishing several Claude panes from each other.
    # prefix+p sits next to the built-in prefix+w picker rather than replacing
    # it, since the built-in still renders the tree more compactly.
    [[keys.command]]
    key = "prefix+p"
    type = "plugin_action"
    command = "pane-navigator.open"
    description = "navigate workspaces, tabs, and panes by title"

    # Sidebar agent rows. The default rows show only where an agent lives
    # (workspace/tab) and which agent it is, which does not say what any of them
    # is working on, so a conversation-summary line is added for both agents --
    # with several agent panes open it is the only thing distinguishing them.
    #
    # This is the conversation title, not the prompt text; herdr exposes no raw
    # prompt to the sidebar.
    #
    # Claude Code puts a summary in its terminal title, so terminal_title_stripped
    # is enough there. Codex does not name threads on its own: with
    # terminal_title = ["thread-title"] an unnamed thread falls back to the raw
    # session UUID, which is what the sidebar was showing. The $codex_title token
    # is filled in by the Stop hook in ~/.codex/codex-title.sh, which summarizes
    # the conversation and reports it with `herdr pane report-metadata --token`.
    # A $-token renders empty until something reports it, so the row is harmless
    # when the hook is absent.
    [ui.sidebar.agents.rows_by_agent]
    claude = [
      ["state_icon", "workspace", "tab"],
      [{ token = "terminal_title_stripped", fg = "#f0e68c" }],
      ["agent"],
    ]
    codex = [
      ["state_icon", "workspace", "tab"],
      [{ token = "$codex_title", fg = "#f0e68c" }],
      ["agent"],
    ]

    # Kitty graphics protocol, required by the herdr-browser plugin to render
    # its Chromium view in a pane. Ghostty (see ghostty.nix) supports it. Kept
    # last so it stays its own table -- no keys follow that could leak into it.
    [experimental]
    kitty_graphics = true
  '';
}
