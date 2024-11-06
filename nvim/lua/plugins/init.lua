return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    config = function()
      require "configs.conform"
    end,
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require("nvchad.configs.lspconfig").defaults()
      require "configs.lspconfig"
    end,
  },

  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "lua-language-server",
        "stylua",
        "html-lsp",
        "css-lsp",
        "prettier",
      },
    },
  },

  {
    "shellRaining/hlchunk.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require "configs.chunk"
      --
    end,
  },

  {
    "wakatime/vim-wakatime",
    lazy = false,
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    ---@module "ibl"
    ---@type ibl.config
    opts = {},
    enabled = false,
  },

  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    config = function()
      require "configs.inline-diagnostics"
    end,
  },

  {
    "IogaMaster/neocord",
    event = "VeryLazy",
    config = function()
      require "configs.discord"
    end,
  },
  { "nvchad/volt",     lazy = true },
  {
    "nvchad/minty",
    lazy = true,
    config = function()
      require "configs.minty"
    end,
  },

  -- {
  --   "hrsh7th/nvim-cmp",
  --   dependencies = {
  --     {
  --       "supermaven-inc/supermaven-nvim",
  --       opts = {},
  --     },
  --   },
  --
  --   opts = function (_, opts)
  --     opts.sources[1].trigger_chars = {"-"}
  --     table.insert(opts.sources, 1, {name = "supermaven"})
  --   end
  -- },

  { "nvchad/menu",     lazy = true },

  { "nvchad/showkeys", cmd = "ShowkeysToggle", opts = { position = "top-center" } },

  { "nvchad/timerly",  cmd = "TimerlyToggle" }

  --
  -- {
  -- 	"nvim-treesitter/nvim-treesitter",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"vim", "lua", "vimdoc",
  --      "html", "css"
  -- 		},
  -- 	},
  -- },
}
