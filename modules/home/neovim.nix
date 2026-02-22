{ config, pkgs, neovim-nightly-overlay, ... }:

let
  arto-vim = pkgs.vimUtils.buildVimPlugin {
    name = "arto-vim";
    src = pkgs.fetchFromGitHub {
      owner = "arto-app";
      repo = "arto.vim";
      rev = "b05936238ff835ceca43442bf4ab8e843e73815c";
      hash = "sha256-/Rk/t7Hm/VTa1KQptzd+1sZIiRR2l++tA98DSe9uwV4=";
    };
  };
in

{
  programs.neovim = {
    enable = true;
    package = pkgs.neovim;  # Uses neovim-nightly from overlay

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # Neovim plugins
    plugins = with pkgs.vimPlugins; [
      # UI
      noice-nvim
      nui-nvim
      mini-nvim
      nord-nvim
      lualine-nvim
      nvim-web-devicons
      dashboard-nvim
      which-key-nvim

      # Editor
      nvim-treesitter.withAllGrammars
      nvim-treesitter-textobjects

      # Completion/LSP
      nvim-lspconfig
      lspsaga-nvim
      trouble-nvim
      nvim-cmp
      cmp-nvim-lsp
      cmp-nvim-lsp-signature-help
      cmp-buffer
      cmp-path
      cmp-cmdline
      cmp-cmdline-history
      cmp_luasnip
      lspkind-nvim
      luasnip
      vim-vsnip
      conform-nvim
      none-ls-nvim

      # Copilot
      copilot-lua
      copilot-cmp
      CopilotChat-nvim
      copilot-vim

      # File operations
      bufferline-nvim
      telescope-nvim
      telescope-file-browser-nvim
      plenary-nvim

      # Git
      gitsigns-nvim
      lazygit-nvim

      # Other
      vim-wakatime

      # Arto
      arto-vim
    ];

    # LSP servers and other tools
    extraPackages = with pkgs; [
      # LSP servers
      lua-language-server
      nil  # Nix LSP

      # Formatters
      stylua
      nixpkgs-fmt
    ];

    initLua = ''
      -- ============================================================================
      -- Disable built-in plugins
      -- ============================================================================
      vim.g.loaded_gzip = 1
      vim.g.loaded_tar = 1
      vim.g.loaded_tarPlugin = 1
      vim.g.loaded_zip = 1
      vim.g.loaded_zipPlugin = 1
      vim.g.loaded_rrhelper = 1
      vim.g.loaded_2html_plugin = 1
      vim.g.loaded_vimball = 1
      vim.g.loaded_vimballPlugin = 1
      vim.g.loaded_getscript = 1
      vim.g.loaded_getscriptPlugin = 1
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
      vim.g.loaded_netrwSettings = 1
      vim.g.loaded_netrwFileHandlers = 1
      vim.g.loaded_matchit = 1
      vim.g.loaded_matchparen = 1

      -- ============================================================================
      -- Basic Options
      -- ============================================================================
      local opt = vim.opt

      -- Leader key
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      -- Encoding
      opt.encoding = "utf-8"
      opt.fileencoding = "utf-8"

      -- Line numbers
      opt.number = true
      opt.relativenumber = true

      -- Indentation
      opt.tabstop = 2
      opt.shiftwidth = 2
      opt.expandtab = true
      opt.autoindent = true
      opt.smartindent = true

      -- Search
      opt.ignorecase = true
      opt.smartcase = true
      opt.hlsearch = true
      opt.incsearch = true

      -- UI
      opt.termguicolors = true
      opt.background = "dark"
      opt.signcolumn = "yes"
      opt.cursorline = true
      opt.scrolloff = 8
      opt.sidescrolloff = 8
      opt.wrap = false

      -- Splits
      opt.splitright = true
      opt.splitbelow = true

      -- Performance
      opt.updatetime = 250
      opt.timeoutlen = 300

      -- Backup and swap
      opt.backup = false
      opt.writebackup = false
      opt.swapfile = false

      -- Clipboard
      opt.clipboard = "unnamedplus"

      -- Mouse
      opt.mouse = "a"

      -- ============================================================================
      -- Keymaps
      -- ============================================================================
      local keymap = vim.keymap.set
      local opts = { noremap = true, silent = true }

      -- Better window navigation
      keymap("n", "<C-h>", "<C-w>h", opts)
      keymap("n", "<C-j>", "<C-w>j", opts)
      keymap("n", "<C-k>", "<C-w>k", opts)
      keymap("n", "<C-l>", "<C-w>l", opts)

      -- Resize with arrows
      keymap("n", "<C-Up>", ":resize -2<CR>", opts)
      keymap("n", "<C-Down>", ":resize +2<CR>", opts)
      keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
      keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

      -- Buffer navigation
      keymap("n", "<S-l>", ":bnext<CR>", opts)
      keymap("n", "<S-h>", ":bprevious<CR>", opts)

      -- Clear search highlighting
      keymap("n", "<leader>h", ":nohlsearch<CR>", opts)

      -- Better paste
      keymap("v", "p", '"_dP', opts)

      -- Stay in indent mode
      keymap("v", "<", "<gv", opts)
      keymap("v", ">", ">gv", opts)

      -- Move text up and down
      keymap("v", "J", ":m '>+1<CR>gv=gv", opts)
      keymap("v", "K", ":m '<-2<CR>gv=gv", opts)

      -- ============================================================================
      -- Colorscheme
      -- ============================================================================
      vim.cmd([[colorscheme nord]])

      -- ============================================================================
      -- Plugin Configurations
      -- ============================================================================

      -- Telescope
      require("telescope").setup({
        defaults = {
          mappings = {
            i = {
              ["<C-j>"] = require("telescope.actions").move_selection_next,
              ["<C-k>"] = require("telescope.actions").move_selection_previous,
            },
          },
        },
        extensions = {
          file_browser = {
            hijack_netrw = true,
          },
        },
      })
      require("telescope").load_extension("file_browser")

      keymap("n", "<leader>ff", "<cmd>Telescope find_files<cr>", opts)
      keymap("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", opts)
      keymap("n", "<leader>fb", "<cmd>Telescope buffers<cr>", opts)
      keymap("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", opts)
      keymap("n", "<leader>fe", "<cmd>Telescope file_browser<cr>", opts)

      -- Treesitter
      require("nvim-treesitter").setup()
      vim.treesitter.language.register("markdown", "mdx")

      -- Enable treesitter-based highlighting and indentation
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          local ok = pcall(vim.treesitter.start, args.buf)
          if ok then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

      -- Treesitter textobjects
      require("nvim-treesitter-textobjects").setup({
        select = {
          enable = true,
          lookahead = true,
          keymaps = {
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
          },
        },
      })

      -- LSP Configuration
      -- Set capabilities for all LSP servers (cmp-nvim-lsp integration)
      vim.lsp.config('*', {
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
      })

      -- Keymaps on LSP attach
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local bufopts = { noremap = true, silent = true, buffer = args.buf }
          keymap("n", "gD", vim.lsp.buf.declaration, bufopts)
          keymap("n", "gd", vim.lsp.buf.definition, bufopts)
          keymap("n", "K", vim.lsp.buf.hover, bufopts)
          keymap("n", "gi", vim.lsp.buf.implementation, bufopts)
          keymap("n", "<C-k>", vim.lsp.buf.signature_help, bufopts)
          keymap("n", "<leader>rn", vim.lsp.buf.rename, bufopts)
          keymap("n", "<leader>ca", vim.lsp.buf.code_action, bufopts)
          keymap("n", "gr", vim.lsp.buf.references, bufopts)
          keymap("n", "<leader>f", function() vim.lsp.buf.format({ async = true }) end, bufopts)
        end,
      })

      -- lua_ls
      vim.lsp.config('lua_ls', {
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim" },
            },
          },
        },
      })

      vim.lsp.enable({ "lua_ls", "nil_ls" })

      -- nvim-cmp
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      local lspkind = require("lspkind")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "copilot" },
          { name = "nvim_lsp" },
          { name = "nvim_lsp_signature_help" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }),
        formatting = {
          format = lspkind.cmp_format({
            mode = "symbol_text",
            maxwidth = 50,
            ellipsis_char = "...",
          }),
        },
      })

      -- Command line completion
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = "path" },
          { name = "cmdline" },
          { name = "cmdline_history" },
        }),
      })

      cmp.setup.cmdline("/", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = "buffer" },
        },
      })

      -- Copilot
      require("copilot").setup({
        suggestion = { enabled = false },
        panel = { enabled = false },
      })

      require("copilot_cmp").setup()

      require("CopilotChat").setup({
        mappings = {
          submit_prompt = {
            normal = "<CR>",
            insert = "<C-s>",
          },
        },
      })

      keymap("n", "<leader>cc", "<cmd>CopilotChatToggle<cr>", opts)
      keymap("n", "<leader>ce", "<cmd>CopilotChatExplain<cr>", opts)
      keymap("n", "<leader>cr", "<cmd>CopilotChatReview<cr>", opts)
      keymap("n", "<leader>co", "<cmd>CopilotChatOptimize<cr>", opts)

      -- Conform (formatter)
      require("conform").setup({
        formatters_by_ft = {
          lua = { "stylua" },
          nix = { "nixpkgs_fmt" },
        },
        format_on_save = {
          timeout_ms = 500,
          lsp_fallback = true,
        },
      })

      -- Lualine
      require("lualine").setup({
        options = {
          theme = "nord",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
        },
      })

      -- Bufferline
      require("bufferline").setup({
        options = {
          diagnostics = "nvim_lsp",
          offsets = {
            {
              filetype = "NvimTree",
              text = "File Explorer",
              highlight = "Directory",
              text_align = "left",
            },
          },
        },
      })

      -- Gitsigns
      require("gitsigns").setup({
        signs = {
          add = { text = "│" },
          change = { text = "│" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
        },
      })

      -- Lazygit
      keymap("n", "<leader>gg", "<cmd>LazyGit<cr>", opts)

      -- Trouble
      require("trouble").setup()
      keymap("n", "<leader>xx", "<cmd>TroubleToggle<cr>", opts)
      keymap("n", "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>", opts)
      keymap("n", "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>", opts)

      -- Which-key
      require("which-key").setup()

      -- Noice
      require("noice").setup({
        lsp = {
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
        },
        presets = {
          bottom_search = true,
          command_palette = true,
          long_message_to_split = true,
        },
      })

      -- Dashboard
      require("dashboard").setup({
        theme = "doom",
        config = {
          header = {
            "",
            "███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
            "████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
            "██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
            "██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
            "██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
            "╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
            "",
          },
          center = {
            {
              icon = " ",
              desc = "Find File",
              key = "f",
              action = "Telescope find_files",
            },
            {
              icon = " ",
              desc = "Recent Files",
              key = "r",
              action = "Telescope oldfiles",
            },
            {
              icon = " ",
              desc = "Find Text",
              key = "g",
              action = "Telescope live_grep",
            },
          },
        },
      })

      -- Mini.nvim
      require("mini.pairs").setup()
      require("mini.comment").setup()
      require("mini.surround").setup()
    '';
  };
}
