---@type ChadrcConfig
local M = {}

vim.opt.listchars = { eol = "↲" }
vim.opt.list = true

-- Path to overriding theme and highlights files
local highlights = require "custom.highlights"

M.ui = {
  theme = "everblush",
  theme_toggle = { "onedark", "one_light" },

  hl_override = {
    NvimTreeNormal = { bg = "#141b1e"},
    NvimTreeNormalNC = { bg = "#141b1e"},
    NvimTreeWinSeparator = { bg = "#141b1e",  fg = "#141b1e" },
    WinSeparator = { bg = "#141b1e"  },
    NavicSeparator = { bg = "#141b1e"},
    BufferLineSeparator = { bg = "#141b1e" },
    WhichKeySeparator = { bg = "#141b1e" },
    BufferLineSeparatorVisible = { bg = "#141b1e" },
    BufferLineSeparatorSelected = { bg = "#141b1e" },
    LineNr = { bg = "#141b1e" },
    NvimTreeOpenedFolderName = { bg = "#141b1e" },
    DapUILineNumber = { bg = "#141b1e" },
    BufferLineBackground = { bg = "#141b1e" },
  },
  hl_add = highlights.add,
  statusline = {
    theme = "minimal",
    separator_style = "round",
  },
  tabufline = {
    enabled = false,
    show_numbers = true,
  },
  cmp = {
    style = "flat_dark",
  },
}

M.plugins = "custom.plugins"

-- check core.mappings for table structure
M.mappings = require "custom.mappings"

return M
