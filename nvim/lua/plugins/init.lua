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

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  -- {
  -- 	"nvim-treesitter/nvim-treesitter",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"vim", "lua", "vimdoc",
  --      "html", "css"
  -- 		},
  -- 	},
  -- },

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
    dependencies = "nvzone/volt",
    event = "VeryLazy",
    config = function()
      require "configs.mywpm"
    end
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
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
  },

  {
    "OXY2DEV/markview.nvim",
    lazy = false,
},

{
  'richwomanbtc/overleaf.nvim',
lazy = false,
  config = function()
    require('overleaf').setup({
      cookie = 's%3A752DdyZE89sWKTeSg267rCa6kX9pPoxE.pIYlmst60FSjHwqCVNnRo7qxpFlTmnD3jFU6dgBLYh8',
    })
  end,
  build = 'cd node && npm install',
}

}
