local config = {}

function config.nvim_treesitter()
  vim.treesitter.language.register('markdown', 'mdx')
  return require('nvim-treesitter.configs').setup({
    ensure_installed = 'all',
    highlight = {
      enable = true,
      disable = {},
    }
  })
end

return config
