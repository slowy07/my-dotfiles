local util = require("lspconfig.util")

require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "clangd", "pyright", "gopls", "ts_ls", "rust_analyzer", "neocmake", "zls", "lua_ls",
  "nim_langserver", "rust_analyzer" }
vim.lsp.enable(servers)

vim.lsp.config.nim_langserver = {
  cmd = { "nimlangserver" },
  filetypes = { "nim" },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    on_dir(
      util.root_pattern '*.nimble' (fname) or vim.fs.dirname(vim.fs.find('.git', { path = fname, upward = true })[1])
    )
  end
}

vim.lsp.config.clangd = {
  filetypes = {
    "c", "cpp", "objc", "objcpp", "cuda", "cppm"
  }
}


-- read :h vim.lsp.config for changing options of lsp servers
