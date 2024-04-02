-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- This is where you actually apply your config choices

-- 背景透過
config.window_background_opacity = 1

-- Font
config.font = wezterm.font("FiraCode Nerd Font", { italic = false })
config.font_size = 14.0
config.use_ime = true

-- Color scheme:
config.color_scheme = 'Everforest Dark (Gogh)'

-- Full screen for macOS
config.native_macos_fullscreen_mode = true

-- Mouse bindings
config.mouse_bindings = {
  -- Ctl + Click to open link in browser
  {
    event={Up={streak=1, button="Left"}},
    mods="CMD",
    action="OpenLinkAtMouseCursor",
  },
}

-- Keybindings
local act = wezterm.action
local window = wezterm.window

config.keys = {
  -- Cmd+dで新しいペインを作成(画面を分割)
  {
    key = 'd',
    mods = 'CMD',
    action = act.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  -- Cmd+Shift+dで新しいペインを作成(画面を分割)
  {
    key = 'd',
    mods = 'CMD|SHIFT',
    action = act.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  -- Cmd+wで現在のペインを閉じる
  {
    key = 'w',
    mods = 'CMD',
    action = act.CloseCurrentPane { confirm = true },
  },
  -- Ctrl+Backspaceで前の単語を削除
  {
    key = "Backspace",
    mods = "CTRL",
    action = act.SendKey {
      key = "w",
      mods = "CTRL",
    },
  },
  -- Cmd+Ctrl+fでフルスクリーン
  {
    key = "f",
    mods = "CMD|CTRL",
    action = act.ToggleFullScreen,
  },
  -- Cmd+[で一つ前のペインに移動
  {
    key = '[',
    mods = 'CMD',
    action = act.ActivatePaneDirection 'Prev',
  },
  -- Cmd+]で一つ先のペインに移動
  {
    key = ']',
    mods = 'CMD',
    action = act.ActivatePaneDirection 'Next',
  },
}

-- and finally, return the configuration to wezterm
return config
