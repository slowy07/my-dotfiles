-- Aphelion: matches the Glyph Aphelion colorscheme.
-- Select with the normal NvChad theme menu or let the Glyph scheme picker select it.
local M = {}

M.base_30 = {
  white = "#f4f3ee",
  darker_black = "#0b0d12",
  black = "#101319", -- nvim bg
  black2 = "#171b24",
  one_bg = "#171b24",
  one_bg2 = "#1d2330",
  one_bg3 = "#3A435A",
  grey = "#3A435A",
  grey_fg = "#6b7488",
  grey_fg2 = "#7f889c",
  light_grey = "#DDDBCF",
  red = "#E34F4F",
  baby_pink = "#DE2B2B",
  pink = "#956dca",
  line = "#2a3142",
  green = "#69bfce",
  vibrant_green = "#7fd4e3",
  nord_blue = "#5599E2",
  blue = "#5679E3",
  yellow = "#e37e4f",
  sun = "#DE642B",
  purple = "#956dca",
  dark_purple = "#885AC4",
  teal = "#69bfce",
  orange = "#e37e4f",
  cyan = "#5599E2",
  statusline_bg = "#171b24",
  lightbg = "#1d2330",
  lightbg2 = "#171b24",
  pmenu_bg = "#3A435A",
  folder_bg = "#5679E3",
}

M.base_16 = {
  base00 = "#101319", -- default bg
  base01 = "#171b24",
  base02 = "#3A435A", -- selection bg
  base03 = "#6b7488", -- comments
  base04 = "#7f889c", -- line numbers
  base05 = "#f4f3ee", -- default fg
  base06 = "#DDDBCF",
  base07 = "#f4f3ee",
  base08 = "#E34F4F", -- variables / errors
  base09 = "#e37e4f", -- numbers / constants
  base0A = "#e37e4f", -- types / classes
  base0B = "#69bfce", -- strings
  base0C = "#5599E2", -- escapes / support
  base0D = "#5679E3", -- functions
  base0E = "#956dca", -- keywords
  base0F = "#DE2B2B", -- deprecated / tags
}

M.type = "dark"

M = require("base46").override_theme(M, "aphelion")

return M
