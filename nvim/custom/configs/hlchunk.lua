require("hlchunk").setup {
  chunk = {
    use_tresitter = true,
    chars = {
      right_arrow = "─",
    },
    style = {
      { fg = "#e5c76b" },
      { bg = "#e57474" },
    },
    error_sign = true,
  },
  indent = {
    chars = { "┊" },

    style = {
      "#232a2d",
    },
  },
  blank = {
    enable = false,
  },
}
