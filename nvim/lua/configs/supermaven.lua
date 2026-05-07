require("supermaven-nvim").setup({
  keymaps = {
    accept_suggestion = "<Tab>",
  },
  ignore_filetypes = {rust = true},
  log_level = "info",
})
