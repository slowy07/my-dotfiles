return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
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
    "IogaMaster/neocord",
    event = "VeryLazy",
    config = function()
      require "configs.discord"
    end,
  },
  {
    "nvchad/minty",
    lazy = true,
    config = function()
      require "configs.minty"
    end,
  },

  { "nvchad/showkeys", cmd = "ShowkeysToggle", opts = { position = "top-center" } },
  {
    "nvzone/typr",
    dependencies = "nvzone/volt",
    opts = {},
    cmd = { "Typr", "TyprStats" },
  },

  {
    "shellRaining/hlchunk.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require "configs.chunk"
    end
  },

  { "nvzone/volt",     lazy = true },
  { "nvzone/menu",     lazy = true },

  {
    "nvzone/timerly",
    dependencies = 'nvzone/volt',
    cmd = "TimerlyToggle",
    opts = {} -- optional
  },

  {
    "nvzone/floaterm",
    dependencies = "nvzone/volt",
    opts = {},
    cmd = "FloatermToggle",
  },

  { 'Civitasv/cmake-tools.nvim', opts = {} },

  {
    "slowy07/mywpm.nvim",
    event = "VeryLazy",
    config = function()
      require "configs.mywpm"
    end
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "vim", "lua", "vimdoc",
        "html", "css",
      },
      highlight = {
        enable = true,
      }
    },

    config = function(_, opts)
      local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
      parser_config.xvrlang = {
        install_info = {
          -- url = "https://github.com/WargaSlowy/xvrlang-treesitter",
          url = "~/Documents/project/xvrlang-treesitter",
          files = { "src/parser.c" },
          branch = "main",
          generate_requires_npm = false,
          requires_generate_from_grammar = false,
        },
        filetype = "xvr",
        vim.filetype.add({
          extension = {
            xvrlang = "xvr",
          }
        })
      }

      require("nvim-treesitter.configs").setup(opts)
    end
  },

  {
    "gisketch/triforce.nvim",
    dependencies = {
      "nvzone/volt",
    },
    config = function()
      require "configs.triforce"
    end,
  },

  -- markdown preview
  {
    "OXY2DEV/markview.nvim",
    lazy = false,
    preview = {
      icon_provider = "internal",
    }
  },

  -- todo nvim
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    lazy = false,
    config = function()
      require "configs.todo"
    end
  },

  -- trouble nvim
  {
    "folke/trouble.nvim",
    opts = {},
    lazy = false,
    cmd = "Trouble",
  }

}
