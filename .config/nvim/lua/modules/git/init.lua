local config = require('modules.git.config')

return {
  {
    'lewis6991/gitsigns.nvim',
    event = { "CursorHold", "CursorHoldI" },
    config = config.gitsigns,
  },
  {
    "kdheepak/lazygit.nvim",
    lazy = true,
    cmd = {
        "LazyGit",
        "LazyGitConfig",
        "LazyGitCurrentFile",
        "LazyGitFilter",
        "LazyGitFilterCurrentFile",
    },
    -- optional for floating window border decoration
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    -- setting the keybinding for LazyGit with 'keys' is recommended in
    -- order to load the plugin when the command is run for the first time
    keys = {
        { "lg", "<cmd>LazyGit<cr>", desc = "LazyGit" }
    }
  }
}
